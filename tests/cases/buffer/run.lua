local opts = {
	key = "KB2",
	level = vim.log.levels.DEBUG,
	single_line = true,
	output = "buffer",
	buffer_name = "kibi2://log",
	use_timestamp = true,
	probe = true,
	monitor = true,
}
local logger = require("kibi2.logger")
local log = logger.new()
logger.setup(log, opts)

local function test()
	logger.error(log, "error")
	logger.warn(log, true)
	logger.info(log, nil, nil)
	logger.debug(log, 4e8)
	logger.probe(log, -3e-3)
	logger.watch(log, "CATEGORY", "format %d %s", 38, "foo")
	logger.info(log, { "CATEGORY", "format %d %s", 38, "foo" })
	logger.warn(log, "CATEGORY")
	logger.debug(log, "%s %d", "test no = ", 1003)
	vim.wait(1)
end

test()
