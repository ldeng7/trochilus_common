require("test.common").boot()

local time_util = require "trochilus.common.util.time"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_parse_time = function()
    luaunit.assertEquals(time_util.parse_time("1974-09-04 16:23:20"), 147515000)
    luaunit.assertEquals(time_util.parse_time("xixi"), 0)
end

luaunit.LuaUnit.run()
