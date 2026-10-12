local logger = require("kibi2.logger")
local log = logger.new()
log.config.level = vim.log.levels.DEBUG
log.config.output = "print"

logger.assert(log, false, "test case for log.assert trace back", "bar")
