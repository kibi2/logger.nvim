local opts = {
	key = "KB2",
	level = vim.log.levels.DEBUG,
	single_line = false,
	output = "print",
	use_timestamp = true,
	probe = false,
}
local logger = require("kibi2.logger")
local log = logger.new()
logger.setup(log, opts)

local function test()
	logger.error(log, "error")
	logger.warn(log, true)
	logger.warn(log, 1, "二", false, 1.414, { 1, 2, 3 })
	logger.info(log, nil, nil)
	logger.info(log, { "one", 2, "three" })
	logger.debug(log, 4e8)
	logger.probe(log, -3e-3)
	logger.watch(log, "CATEGORY", "format %d %s", 38, "foo")
	logger.watch(log, "CATEGORY1", "format %d %s", 31, "bar")
	logger.watch(log, "CATEGORY2", "format %d %s", 32, "bar")
	logger.watch(log, "CATEGORY3", "format %d %s", 33, "bar")
	logger.watch(log, "CATEGORY4", "format %d %s", 34, "bar")
	logger.watch(log, "CATEGORY5", "format %d %s", 35, "bar")
	logger.watch(log, "CATEGORY6", "format %d %s", 36, "bar")
	logger.watch(log, "CATEGORY7", "format %d %s", 37, "bar")
	logger.watch(log, "CATEGORY8", "format %d %s", 38, "bar")
	logger.watch(log, "CATEGORY9", "format %d %s", 39, "bar")
end

test()
