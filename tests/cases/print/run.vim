source $KIBI2_REPO_ROOT/tests/common.vim

lua << EOF
  local opts = {
  	log = {
		level = vim.log.levels.DEBUG,
		single_line = true,
		output = "print",
		use_timestamp = true,
		probe = true,
  	},
  }
  require("kibi2.config").setup(opts)
  log = require("kibi2.logger")
EOF

CASE log.xxx(...)
		lua log.error("error")
		lua log.warn(true)
		lua log.info(nil, nil)
		lua log.debug(4e8)
		lua log.probe(-3e-3)
		lua log.watch("CATEGORY", "format %d %s", 38, "foo")

call Snapshot({})