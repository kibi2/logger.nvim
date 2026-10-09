source $KIBI2_REPO_ROOT/tests/common.vim

lua require("kibi2.config").setup({})
lua require("kibi2.config").log.output = "print"
lua require("kibi2.config").log.level = vim.log.levels.ERROR
lua log = require("kibi2.logger")

CASE log ERROR

lua log.assert(true, "true", "bar")
lua log.assert(false, "test case for log.assert ERROR", "bar")

call Snapshot({'desc': 'ERROR' })

lua require("kibi2.config").setup({})
lua require("kibi2.config").log.level = vim.log.levels.DEBUG

CASE log trace

lua log.assert(false, "test case for log.assert trace back", "bar")

call Snapshot({ 'nomessage' })