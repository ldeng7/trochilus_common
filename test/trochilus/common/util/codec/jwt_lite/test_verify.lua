require("test.common").boot()
require("ffi").load("/usr/lib/x86_64-linux-gnu/libcrypto.so", true)

local verify = require "trochilus.common.util.codec.jwt_lite.verify"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_verify = function()
    local j = verify.new(verify.ALGOS.HS256, "my$ecretK3y")
    luaunit.assertTrue(verify.verify(j,
        "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoidGVzdCJ9.ZxW8go9hz3ETCSfxFxpwSkYg_602gOPKearsf6DsxgY"))
    luaunit.assertFalse(verify.verify(j,
        "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoidGVzdCJ9.ZxW8go9hz3ETCSfxFxpwSkYg_602gOPKearsf6DsxgY123"))
end

luaunit.LuaUnit.run()
