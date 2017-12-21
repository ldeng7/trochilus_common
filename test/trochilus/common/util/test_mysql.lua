require("test.common").boot()

local mysql_util = require "trochilus.common.util.mysql"
local conf = require "test.conf"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_query = function()
    local my = mysql_util.new(conf.mysql)
    mysql_util.query(my, false, "DROP TABLE tests;")
    mysql_util.query(my, false, [[
        CREATE TABLE tests (
            `id` int NOT NULL AUTO_INCREMENT,
            i int NOT NULL,
            s varchar(32) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY index_i (i)
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
    ]])
    mysql_util.query(my, false, 'INSERT INTO tests(i, s) VALUES (1, "sss");')
    local res = mysql_util.query(my, false, "SELECT i, s FROM tests LIMIT 1;")
    luaunit.assertEvalToTrue(res)
    luaunit.assertEvalToTrue(res[1])
    luaunit.assertEquals(res[1].i, 1)
    luaunit.assertEquals(res[1].s, "sss")
end

test_sql = function()
    luaunit.assertEquals(mysql_util.sql("#{a}", {a = 7}), "7")
    luaunit.assertEquals(mysql_util.sql("#{a}", {a = { 7 }}), "'7'")
    luaunit.assertEquals(mysql_util.sql("INSERT INTO t(#{as})", {as = { typ = "/", {"a", "b"} }}),
        "INSERT INTO t(a, b)")
    luaunit.assertEquals(mysql_util.sql("VALUES (#{s})", {s = { typ = ",", {7, 8} }}),
        "VALUES ('7', '8')")
    luaunit.assertEquals(mysql_util.sql("UPDATE t SET #{m}", {m = { typ = ":", {a = 7, b = 8} }}),
        "UPDATE t SET a = '7', b = '8'")
    luaunit.assertEquals(mysql_util.sql("UPDATE t SET #{avs}", {avs = { typ = "=", {"a", "b"}, {7, 8} }}),
        "UPDATE t SET a = '7', b = '8'")
    luaunit.assertEquals(mysql_util.sql("VALUES #{s}", {s = { typ = "(", {{7, 8}, {17, 18}} }}),
        "VALUES ('7', '8'), ('17', '18')")
end

test_null_to_nil = function()
    local t = {}
    mysql_util.null_to_nil(t)
    luaunit.assertEquals(t, {})

    t = {aa = 1, bb = ngx.null}
    mysql_util.null_to_nil(t)
    luaunit.assertEquals(t, {aa = 1, bb = nil})
end

luaunit.LuaUnit.run()
