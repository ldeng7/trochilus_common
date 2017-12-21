require("test.common").boot()

local luaunit_util = require "trochilus.common.util.luaunit.luaunit"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_mock_loaded_packages = function()
    local p = {aa = 1}
    luaunit_util.mock_loaded_packages({
        pp = p
    })
    p = require "pp"
    luaunit.assertEquals(p.aa, 1)
end

luaunit.LuaUnit.run()
