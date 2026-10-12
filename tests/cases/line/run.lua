local opts = {
	key = "LINE",
	level = vim.log.levels.DEBUG,
	single_line = false,
	output = "print",
	use_timestamp = false,
	probe = true,
}
local log = require("log")
log.setup(opts)

local function test1()
	log.error("error1")
	log.warn(3.141)
	log.info(nil)
	log.debug(false)
	log.probe(-31e-3)
	log.watch("CATEGORY", "format %d %s", 31, "foo")
end

local function test2()
	test1()
end

local function test3()
	test2()
end

test3()
