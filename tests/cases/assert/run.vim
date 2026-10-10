source $KIBI2_REPO_ROOT/tests/common.vim

lua config = require("kibi2.logger.config")
lua log = require("kibi2.logger.logger")
lua config.setup({})
lua config.output = "print"
lua config.level = vim.log.levels.ERROR

CASE log ERROR

lua log.assert(true, "true", "bar")
lua log.assert(false, "test case for log.assert ERROR", "bar")

call Snapshot({'desc': 'ERROR' })

lua config.setup({})
lua config.level = vim.log.levels.DEBUG

CASE log trace

lua log.assert(false, "test case for log.assert trace back", "bar")

call Snapshot({ 'nomessage' })