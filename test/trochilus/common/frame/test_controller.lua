require("test.common").boot()

local controller = require "trochilus.common.frame.controller"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_check_args_v0 = function()
    local args = {
        data = '{"aa":3}'
    }
    luaunit.assertEquals(controller.check_args_v0(args), true)
    luaunit.assertEquals(args.data, {aa = 3})

    args.business_type = "1"
    luaunit.assertEquals(controller.check_args_v0(args), false)
end

luaunit.LuaUnit.run()
