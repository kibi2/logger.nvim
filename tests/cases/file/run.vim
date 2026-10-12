source $KIBI2_REPO_ROOT/tests/common.vim

lua << EOF
  local opts = {
	key = "LG1",
	level = vim.log.levels.DEBUG,
	-- level = vim.log.levels.ERROR,
	single_line = false,
	output = "file",
	file_name = "./gen-output1.txt",
	use_timestamp = false,
	probe = true,
  }
  logger = require("kibi2.logger")
  log1 = logger.new()
  logger.setup(log1, opts)
  log2 = logger.new()
  opts.key = "LG2"
  logger.setup(log2, opts)
  log2.config.file_name = "./gen-output2.txt"
EOF

CASE log.xxx(...)
		lua logger.error(log1, "error1")
		lua logger.error(log2, "error2")
		lua logger.warn(log1, 3.141)
		lua logger.warn(log2, 3.142)
		lua logger.info(log1, nil)
		lua logger.info(log2, nil)
		lua logger.debug(log1, false)
		lua logger.debug(log2, true)
		lua logger.probe(log1, -31e-3)
		lua logger.probe(log2, -32e-3)
		lua logger.watch(log1, "CATEGORY", "format %d %s", 31, "foo")
		lua logger.watch(log2, "CATEGORY", "format %d %s", 32, "foo")
  		lua log2.config.level = vim.log.levels.ERROR
		lua logger.error(log1, "error1")
		lua logger.error(log2, "error2")
		lua logger.warn(log1, 3.141)
		lua logger.warn(log2, 3.142)
		lua logger.watch(log1, "CATEGORY", "format %d %s", 31, "foo")
		lua logger.watch(log2, "CATEGORY", "format %d %s", 32, "foo")

call Snapshot({ 'desc': 'log file 1', 'file': 'gen-output1.txt' })
call Snapshot({ 'desc': 'log file 2', 'file': 'gen-output2.txt' })