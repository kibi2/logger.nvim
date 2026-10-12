local logger = require("kibi2.logger")
local log = logger.new()
log.config.level = vim.log.levels.ERROR
log.config.output = "print"

logger.assert(log, true, "true", "bar")
logger.assert(log, false, "test case for log.assert ERROR", "bar")
