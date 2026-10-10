local api = vim.api -- Neovim
local bo = vim.bo
local fn = vim.fn

local config = require("kibi2.logger.config")

-- =============================================================================

local M = {}

local levels = vim.log.levels

local level_names = {}
local PREFIX = "KB2"
local uv = vim.loop
local queue = {}
local scheduled = false
local log_bufnr = nil

for name, value in pairs(levels) do
	level_names[value] = name
end

local last_mem = 0
local last_time = uv.hrtime()

-- =============================================================================
--#region Private

---@return integer
local function get_tick()
	local bufnr = api.nvim_get_current_buf()
	return api.nvim_buf_get_changedtick(bufnr)
end

---@return integer
local function get_mem_mb()
	return collectgarbage("count") / 1024
end

---@return string
local function get_monitor()
	if not config.monitor then
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

---@param value any
---@return string
local function stringify(value)
	local v_type = type(value)

	if v_type == "table" then
		local normalized = normalize_for_log(value)
		if config.single_line then
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

---@return string
local function get_timestamp()
	if not config.use_timestamp then
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

local function get_bufnr_by_name(name)
	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		local buf_name = api.nvim_buf_get_name(bufnr)
		if buf_name:match(vim.pesc(name) .. "$") then
			return bufnr
		end
	end
	return nil
end

local category_hl_map = {}
local category_match_id = {}
api.nvim_set_hl(0, "Kibi2Log_Entry", { fg = "#55ffff", bold = true })
api.nvim_set_hl(
	0,
	"Kibi2Log_Error",
	{ fg = "#ffffff", bg = "#ff0000", bold = true }
)
api.nvim_set_hl(0, "Kibi2Log_num", { fg = "#cc55cc", bold = true })
api.nvim_set_hl(0, "Kibi2Log_Multi_Byte", { bg = "#664422", bold = true })

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

local aug = api.nvim_create_augroup("Kbi2LogHL", { clear = true })
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

---@return number
local function ensure_log_buf()
	if log_bufnr and api.nvim_buf_is_valid(log_bufnr) then
		return log_bufnr
	end
	log_bufnr = get_bufnr_by_name(config.buffer_name)
	if log_bufnr then
		return log_bufnr
	end
	---@type number
	log_bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_name(log_bufnr, config.buffer_name)

	bo[log_bufnr].buftype = "nofile"
	bo[log_bufnr].bufhidden = "hide"
	bo[log_bufnr].swapfile = false
	register_autocmds(log_bufnr)
	return log_bufnr
end

local function flush_buffer(buf_string)
	local bufnr = ensure_log_buf()
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

local initialized = false
local function flush_file(buf_string)
	local file = config.file_name or "/tmp/kibi2.log"
	if not initialized then
		local fds = io.open(file, "w")
		if fds then
			fds:close()
		else
			error("kibi2: failed to open log file: " .. file)
		end
		initialized = true
	end
	local fds = io.open(file, "a")
	if fds then
		fds:write(buf_string .. "\n")
		fds:close()
	end
end

local function flush()
	scheduled = false
	if #queue == 0 then
		return
	end
	local buf_string = table.concat(queue, "\n")
	buf_string = buf_string:gsub("\r", "")
	if config.output == "buffer" then
		flush_buffer(buf_string)
	elseif config.output == "file" then
		flush_file(buf_string)
	end
	queue = {}
end

---@param msg string
local function write_buffer(msg)
	table.insert(queue, msg)
	if not scheduled then
		scheduled = true
		vim.schedule(flush)
	end
end

local unpack = table.unpack or unpack -- Lua 5.1/5.2 compatibility
local palette = {
	"#ff5555",
	"#55aaaa",
	"#ffff55",
	"#aaff55",
	"#aa55ff",
	"#ffaa55",
}

local assigned = {}
local used = {}

local function pick_color(cat)
	if assigned[cat] then
		return assigned[cat]
	end
	local hash = fn.sha256(cat)
	local base = (fn.str2nr(hash:sub(1, 8), 16) % #palette) + 1
	for i = 0, #palette - 1 do
		local idx = ((base + i - 1) % #palette) + 1
		local color = palette[idx]
		if not used[color] then
			assigned[cat] = color
			used[color] = true
			return color
		end
	end
	local color = palette[base]
	assigned[cat] = color
	return color
end

local function ensure_category_highlight(category)
	if category_hl_map[category] then
		return category_hl_map[category]
	end

	local hl = "Kibi2Log_" .. category
	local color = pick_color(category)

	api.nvim_set_hl(0, hl, { fg = color, bold = true })

	category_hl_map[category] = hl
	return hl
end

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

---@param force boolean
---@param level integer
---@param opts? table
---@param fmt any
---@param ... unknown
local function emit(force, level, opts, fmt, ...)
	if not force and level < config.level then
		return
	end
	if opts == nil or fmt == nil then
		return
	end
	local category = opts and opts.category
	if category then
		local bufnr = ensure_log_buf()
		local hl = ensure_category_highlight(category)
		ensure_match(bufnr, category, hl)
	end
	local info = debug.getinfo(3, "Sl")
	local file = info and (info.short_src:match("([^/\\]+)$")) or "?"
	local line = info and info.currentline or 0
	local args = { ... }
	local msg
	if type(fmt) == "string" or #args == 0 then
		local ok, result = pcall(function()
			return string.format(fmt, unpack(args))
		end)
		if ok then
			msg = result
		end
	end
	if not msg then
		local args = { fmt, ... }
		local parts = vim.tbl_map(stringify, args)
		msg = table.concat(parts, " ")
	end
	local ts = get_timestamp()
	local mon = get_monitor()
	local name = level_names[level]
	if force then
		name = "🟧PRB"
	elseif category then
		name = category
	end
	local final = string.format(
		"[%s]%s%s[%s][%s %d] %s",
		PREFIX,
		ts,
		mon,
		name,
		file,
		line,
		msg
	)
	if config.output == "buffer" then
		write_buffer(final)
	elseif config.output == "file" then
		write_buffer(final)
	elseif config.output == "print" then
		print(final)
	end
end

--#endregion
-- =============================================================================
-- Public API

---@param ... unknown
function M.debug(...)
	emit(false, levels.DEBUG, {}, ...)
end

---@param ... unknown
function M.info(...)
	emit(false, levels.INFO, {}, ...)
end

---@param ... unknown
function M.warn(...)
	emit(false, levels.WARN, {}, ...)
end

---@param ... unknown
function M.error(...)
	emit(false, levels.ERROR, {}, ...)
end

---@param ... unknown
function M.probe(...)
	if not config.probe then
		return
	end
	emit(true, levels.ERROR, {}, ...)
end

---@param category string
---@param ... unknown
function M.watch(category, ...)
	if levels.DEBUG < config.level then
		return
	end
	emit(false, levels.DEBUG, { category = category }, ...)
end

---@return boolean
function M.is_debug()
	return levels.DEBUG >= config.level
end

---@param condition any
---@param message string
---@param ... unknown
function M.assert(condition, message, ...)
	if M.is_debug() then
		assert(condition, message, ...)
	end
	if not condition then
		M.error(message, ...)
	end
end

return M
