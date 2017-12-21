require("test.common").boot()

local redis_util = require "trochilus.common.util.redis"
local conf = require "test.conf"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_query = function()
    local red = redis_util.new(conf.redis)
    redis_util.query(red, false, "del", "kk")
    redis_util.query(red, false, "set", "kk", 7)
    local res = redis_util.query(red, false, "get", "kk")
    redis_util.query(red, false, "del", "kk")
    luaunit.assertEquals(res, "7")
end

local RK = "sbc:test"
test_hmset_heavy = function()
    local red = redis_util.new(conf.redis)
    redis_util.query(red, false, "del", RK)
    local res = redis_util.hmset_heavy(red, RK, {aa = "11", bb = ""})
    luaunit.assertTrue(res)
    res = redis_util.query(red, false, "hmget", RK, "aa", "bb")
    luaunit.assertEquals(res, {"11", ""})
end

luaunit.LuaUnit.run()
