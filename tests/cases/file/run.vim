source $KIBI2_REPO_ROOT/tests/common.vim

lua << EOF
  local opts = {
  	log = {
		level = vim.log.levels.DEBUG,
		single_line = false,
		output = "file",
		file_name = "./gen-output.txt",
		use_timestamp = false,
		probe = true,
  	},
  }
  require("kibi2.config").setup(opts)
  log = require("kibi2.logger")
EOF

CASE log.xxx(...)
		lua log.error("error")
		lua log.warn(3.14)
		lua log.info(nil)
		lua log.debug(false)
		lua log.probe(-3e-3)
		lua log.watch("CATEGORY", "format %d %s", 38, "foo")

call Snapshot({ 'desc': 'log file', 'file': 'gen-output.txt' })