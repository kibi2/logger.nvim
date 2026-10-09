source $KIBI2_REPO_ROOT/tests/common.vim

lua << EOF
  local opts = {
  	log = {
		level = vim.log.levels.DEBUG,
		single_line = true,
		output = "buffer",
		buffer_name = "kibi2://log",
		use_timestamp = true,
		probe = true,
		monitor = true,
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
		lua log.info({"CATEGORY", "format %d %s", 38, "foo"})
		lua log.warn("CATEGORY")
		lua log.debug("%s %d", "test no = ", 1003)
		lua vim.wait(1)

let bufnr = -1
for buf in getbufinfo()
  " echomsg buf.name
  if buf.name =~# 'kibi2://log'
    let bufnr = buf.bufnr
    break
  endif
endfor

" echomsg bufnr
let lines = bufnr > 0 ? getbufline(bufnr, 1, '$') : []
for line in lines
	echomsg line
endfor

call Snapshot({})