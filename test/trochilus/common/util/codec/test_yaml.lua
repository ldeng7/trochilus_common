require("test.common").boot()

local yaml_util = require "trochilus.common.util.codec.yaml"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_decode = function()
    luaunit.assertEquals(yaml_util.decode_string("a: 1\nb: bb\nc:\n  d: dd\n  e:\n    - 2\n    - ee"), {
        a = 1, b = "bb", c = {d = "dd", e = {2, "ee"}}
    })
    luaunit.assertEquals(yaml_util.decode_string("a"), nil)
end

luaunit.LuaUnit.run()
