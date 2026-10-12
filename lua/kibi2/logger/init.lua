local api = vim.api -- Neovim
local bo = vim.bo
local fn = vim.fn
local uv = vim.loop
local levels = vim.log.levels

local config = require("kibi2.logger.config")

-- =============================================================================

local M = {}

---@class Logger
---@field config table<string,any>
---@field scheduled boolean
---@field queue string[]
---@field log_bufnr number|nil
---@field initialized boolean
---@field assigned table<string,integer>
---@field used boolean[]

---@return Logger
function M.new()
	---@type Logger
	return {
		config = config.setup({}),
		scheduled = false,
		queue = {},
		log_bufnr = nil,
		initialized = false,
		assigned = {},
		used = {},
	}
end

local level_names = {}

local last_mem = 0
local last_time = uv.hrtime()

local category_hl_map = {}
local category_match_id = {}

local aug = api.nvim_create_augroup("Kbi2LogHL", { clear = true })
local palette = {
	"#ff5555",
	"#55aaaa",
	"#ffff55",
	"#aaff55",
	"#aa55ff",
	"#ffaa55",
}

-- =============================================================================
--#region Private

local function initialize()
	for name, value in pairs(levels) do
		level_names[value] = name
	end
	api.nvim_set_hl(0, "Kibi2Log_Entry", { fg = "#55ffff", bold = true })
	api.nvim_set_hl(
		0,
		"Kibi2Log_Error",
		{ fg = "#ffffff", bg = "#ff0000", bold = true }
	)
	api.nvim_set_hl(0, "Kibi2Log_num", { fg = "#cc55cc", bold = true })
	api.nvim_set_hl(0, "Kibi2Log_Multi_Byte", { bg = "#664422", bold = true })
end

---@return integer
local function get_tick()
	local bufnr = api.nvim_get_current_buf()
	return api.nvim_buf_get_changedtick(bufnr)
end

---@return integer
local function get_mem_mb()
	return collectgarbage("count") / 1024
end

---@param self Logger
---@return string
local function get_monitor(self)
	if not self.config.monitor then
		return ""
	end
	local current_mem = get_mem_mb()
	local delta_mem = current_mem - last_mem
	return string.format("[%d:%d(+%d)MB]", get_tick(), current_mem, delta_mem)
end

---@param value any
---@return any
local function normalize_for_log(value)
	local v_type = type(value)
	if v_type ~= "table" then
		return value
	end
	local mt = getmetatable(value)
	if mt and mt.__tostring then
		return tostring(value)
	end
	local result = {}
	for key, val in pairs(value) do
		result[key] = normalize_for_log(val)
	end
	return result
end

---@param self Logger
---@param value any
---@return string
local function stringify(self, value)
	local v_type = type(value)
	if v_type == "table" then
		local normalized = normalize_for_log(value)
		if self.config.single_line then
			return string.format(
				"<table> %s",
				vim.inspect(normalized, {
					newline = " ",
					indent = "",
					depth = 4,
				})
			)
		else
			return string.format("<table>\n%s", vim.inspect(value))
		end
	elseif v_type == "string" then
		return string.format("<string> %s", value)
	else
		return string.format("<%s> %s", v_type, tostring(value))
	end
end

---@param self Logger
---@return string
local function get_timestamp(self)
	if not self.config.use_timestamp then
		return ""
	end
	local now = uv.hrtime()
	if not last_time then
		last_time = now
		---@type string
		return os.date("[%H:%M:%S]")
	end
	local delta_ms = (now - last_time) / 1e6
	last_time = now
	return string.format("[+%.0fms]", delta_ms)
end

---@param name string
---@return number|nil
local function get_bufnr_by_name(name)
	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		local buf_name = api.nvim_buf_get_name(bufnr)
		if buf_name:match(vim.pesc(name) .. "$") then
			return bufnr
		end
	end
	return nil
end

---@param bufnr number
local function apply_log_highlight(bufnr)
	local winid = fn.bufwinid(bufnr)
	if winid == -1 then
		return
	end
	api.nvim_win_call(winid, function()
		fn.clearmatches()
		fn.matchadd("Kibi2Log_Multi_Byte", "[^\\x00-\\x7F]")
		fn.matchadd("Kibi2Log_Entry", "===")
		--fn.matchadd("Kibi2Log_Error", [[\[[0-9,]\+\]]])
		fn.matchadd("Kibi2Log_num", "\\[[0-9,]\\+\\]")
		fn.matchadd("Kibi2Log_Error", "\\[ERROR\\]")
		for cat, hl in pairs(category_hl_map) do
			fn.matchadd(hl, "\\[" .. cat .. "\\]")
		end
	end)
end

---@param bufnr number
local function register_autocmds(bufnr)
	api.nvim_create_autocmd("BufWinEnter", {
		group = aug,
		buffer = bufnr,
		callback = function(args)
			--if args.buf == log_bufnr then
			apply_log_highlight(args.buf)
			--end
		end,
	})
end

---@param self Logger
---@return number
local function ensure_log_buf(self)
	if self.log_bufnr and api.nvim_buf_is_valid(self.log_bufnr) then
		return self.log_bufnr
	end
	self.log_bufnr = get_bufnr_by_name(self.config.buffer_name)
	if self.log_bufnr then
		return self.log_bufnr
	end
	---@type number
	self.log_bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_name(self.log_bufnr, self.config.buffer_name)
	bo[self.log_bufnr].buftype = "nofile"
	bo[self.log_bufnr].bufhidden = "hide"
	bo[self.log_bufnr].swapfile = false
	register_autocmds(self.log_bufnr)
	return self.log_bufnr
end

---@param self Logger
---@param buf_string string
local function flush_buffer(self, buf_string)
	local bufnr = ensure_log_buf(self)
	api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(buf_string, "\n"))
	local line_count = api.nvim_buf_line_count(bufnr)
	local win = fn.bufwinid(bufnr)
	if win ~= -1 then
		api.nvim_win_set_cursor(win, { line_count, 0 })
		api.nvim_win_call(win, function()
			-- vim.cmd("normal! 3kzz")
		end)
	end
end

---@param self Logger
---@param buf_string string
local function flush_file(self, buf_string)
	local file = self.config.file_name or "/tmp/kibi2.log"
	if not self.initialized then
		local fds = io.open(file, "w")
		if fds then
			fds:close()
		else
			error("kibi2: failed to open log file: " .. file)
		end
		self.initialized = true
	end
	local fds = io.open(file, "a")
	if fds then
		fds:write(buf_string .. "\n")
		fds:close()
	end
end

---@param self Logger
local function flush(self)
	self.scheduled = false
	if #self.queue == 0 then
		return
	end
	local buf_string = table.concat(self.queue, "\n")
	buf_string = buf_string:gsub("\r", "")
	if self.config.output == "buffer" then
		flush_buffer(self, buf_string)
	elseif self.config.output == "file" then
		flush_file(self, buf_string)
	end
	self.queue = {}
end

---@param self Logger
---@param msg string
local function write_buffer(self, msg)
	table.insert(self.queue, msg)
	if not self.scheduled then
		self.scheduled = true
		vim.schedule(function()
			flush(self)
		end)
	end
end

---@param self Logger
---@param cat string
---@return integer
local function pick_color(self, cat)
	if self.assigned[cat] then
		return self.assigned[cat]
	end
	local hash = fn.sha256(cat)
	local base = (fn.str2nr(hash:sub(1, 8), 16) % #palette) + 1
	for i = 0, #palette - 1 do
		local idx = ((base + i - 1) % #palette) + 1
		local color = palette[idx]
		if not self.used[color] then
			self.assigned[cat] = color
			self.used[color] = true
			return color
		end
	end
	local color = palette[base]
	self.assigned[cat] = color
	return color
end

---@param self Logger
---@param category string
---@return string
local function ensure_category_highlight(self, category)
	if category_hl_map[category] then
		return category_hl_map[category]
	end
	local hl = "Kibi2Log_" .. category
	local color = pick_color(self, category)
	api.nvim_set_hl(0, hl, { fg = color, bold = true })
	category_hl_map[category] = hl
	return hl
end

---@param bufnr number
---@param category string
---@param hl string
local function ensure_match(bufnr, category, hl)
	if category_match_id[category] then
		return
	end
	api.nvim_buf_call(bufnr, function()
		local pattern = "\\[" .. category .. "\\]"
		local id = fn.matchadd(hl, pattern)
		category_match_id[category] = id
	end)
end

---@param self Logger
---@param fmt string
---@param ... unknown
---@return string
local function get_message(self, fmt, ...)
	local args = { ... }
	local message
	if type(fmt) == "string" or #args == 0 then
		local ok, result = pcall(function()
			local unpack = table.unpack or unpack -- Lua 5.1/5.2 compatibility
			return string.format(fmt, unpack(args))
		end)
		if ok then
			message = result
		end
	end
	if not message then
		local args = { fmt, ... }
		local parts = vim.tbl_map(function(value)
			return stringify(self, value)
		end, args)
		message = table.concat(parts, " ")
	end
	return message
end

---@param key string
---@return string
local function get_key(key)
	if #key == 0 then
		return ""
	else
		return string.format("[%s]", key)
	end
end

---@param self Logger
---@param force boolean
---@param level integer
---@param opts? table
---@param fmt any
---@param ... unknown
local function emit(self, force, level, opts, fmt, ...)
	if not force and level < self.config.level then
		return
	end
	if opts == nil or fmt == nil then
		return
	end
	local category = opts and opts.category
	if category then
		local bufnr = ensure_log_buf(self)
		local hl = ensure_category_highlight(self, category)
		ensure_match(bufnr, category, hl)
	end
	local info = debug.getinfo(4, "Sl")
	local file = info and (info.short_src:match("([^/\\]+)$")) or "?"
	local line = info and info.currentline or 0
	local message = get_message(self, fmt, ...)
	local ts = get_timestamp(self)
	local mon = get_monitor(self)
	local name = level_names[level]
	if force then
		name = "🟧PRB"
	elseif category then
		name = category
	end
	local final = string.format(
		"%s%s%s[%s][%s %d] %s",
		get_key(self.config.key),
		ts,
		mon,
		name,
		file,
		line,
		message
	)
	if self.config.output == "buffer" then
		write_buffer(self, final)
	elseif self.config.output == "file" then
		write_buffer(self, final)
	elseif self.config.output == "print" then
		print(final)
	end
end

--#endregion
-- =============================================================================
-- Public API

---@param ... unknown
function M:debug(...)
	emit(self, false, levels.DEBUG, {}, ...)
end

---@param ... unknown
function M:info(...)
	emit(self, false, levels.INFO, {}, ...)
end

---@param ... unknown
function M:warn(...)
	emit(self, false, levels.WARN, {}, ...)
end

---@param ... unknown
function M:error(...)
	emit(self, false, levels.ERROR, {}, ...)
end

---@param ... unknown
function M:probe(...)
	if not self.config.probe then
		return
	end
	emit(self, true, levels.ERROR, {}, ...)
end

---@param category string
---@param ... unknown
function M:watch(category, ...)
	assert(type(category) == "string", "category must be a stringt")
	if levels.DEBUG < self.config.level then
		return
	end
	emit(self, false, levels.DEBUG, { category = category }, ...)
end

---@return boolean
function M:is_debug()
	return levels.DEBUG >= self.config.level
end

---@param condition boolean
---@param message string|nil
---@param ... unknown
function M:assert(condition, message, ...)
	assert(type(condition) == "boolean", "condition must be a boolean")
	if M.is_debug(self) then
		assert(condition, message, ...)
	end
	if not condition then
		M.error(self, message, ...)
	end
end

---@param opts table<string,any>|nil
function M:setup(opts)
	opts = opts or {}
	assert(type(opts) == "table", "opts must be a table")
	self.config = config.setup(opts)
end

initialize()

return M
