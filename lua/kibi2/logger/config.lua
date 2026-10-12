local M = {}

---@type table<string, any>
local default_config = {
	key = "",
	level = vim.log.levels.ERROR,
	output = "file", -- "buffer", "file", "print"
	buffer_name = "kibi2://log",
	file_name = "/tmp/kibi2.log",
	use_timestamp = false,
	single_line = true,
	probe = true,
	monitor = false,
}

---@param opts table<string, any>
---@return table<string, any>
function M.setup(opts)
	return vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts)
end

return M
