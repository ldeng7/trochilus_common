require("test.common").boot()

local string_util = require "trochilus.common.util.string"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_endswith = function()
    luaunit.assertEquals(string_util.endswith("", ""), true)
    luaunit.assertEquals(string_util.endswith("", "a"), false)

    luaunit.assertEquals(string_util.endswith("abc", ""), true)
    luaunit.assertEquals(string_util.endswith("abc", "c"), true)
    luaunit.assertEquals(string_util.endswith("abc", "bc"), true)
    luaunit.assertEquals(string_util.endswith("abc", "abc"), true)
    luaunit.assertEquals(string_util.endswith("abc", "d"), false)
    luaunit.assertEquals(string_util.endswith("abc", "abcd"), false)
end

test_split = function()
    luaunit.assertEquals(string_util.split("", ""), nil)
    luaunit.assertEquals(string_util.split("", "a"), {""})

    luaunit.assertEquals(string_util.split("a", ""), nil)
    luaunit.assertEquals(string_util.split("a", "a"), {"", ""})
    luaunit.assertEquals(string_util.split("a", "b"), {"a"})
    luaunit.assertEquals(string_util.split("a", "bc"), {"a"})
    luaunit.assertEquals(string_util.split("aa", "a"), {"", "", ""})
    luaunit.assertEquals(string_util.split("aa", "aa"), {"", ""})
    luaunit.assertEquals(string_util.split("aa", "b"), {"aa"})
    luaunit.assertEquals(string_util.split("aaa", "a"), {"", "", "", ""})
    luaunit.assertEquals(string_util.split("aaa", "aa"), {"", "a"})
    luaunit.assertEquals(string_util.split("aaa", "aaa"), {"", ""})

    luaunit.assertEquals(string_util.split("aba", "a"), {"", "b", ""})
    luaunit.assertEquals(string_util.split("ba", "a"), {"b", ""})
    luaunit.assertEquals(string_util.split("baa", "a"), {"b", "", ""})
    luaunit.assertEquals(string_util.split("ab", "a"), {"", "b"})
    luaunit.assertEquals(string_util.split("aab", "a"), {"", "", "b"})
    luaunit.assertEquals(string_util.split("abacda", "a"), {"", "b", "cd", ""})
    luaunit.assertEquals(string_util.split("bacda", "a"), {"b", "cd", ""})
    luaunit.assertEquals(string_util.split("abacd", "a"), {"", "b", "cd"})
    luaunit.assertEquals(string_util.split("bacd", "a"), {"b", "cd"})

    luaunit.assertEquals(string_util.split("b", "a", true, 0), {"b"})
    luaunit.assertEquals(string_util.split("b", "a", true, 1), {"b"})
    luaunit.assertEquals(string_util.split("bacad", "a", true, 0), {"b", "c", "d"})
    luaunit.assertEquals(string_util.split("bacad", "a", true, 1), {"b", "cad"})
    luaunit.assertEquals(string_util.split("bacad", "a", true, 2), {"b", "c", "d"})
    luaunit.assertEquals(string_util.split("bacad", "a", true, 3), {"b", "c", "d"})
end

test_startswith = function()
    luaunit.assertEquals(string_util.startswith("", ""), true)
    luaunit.assertEquals(string_util.startswith("", "a"), false)

    luaunit.assertEquals(string_util.startswith("abc", ""), true)
    luaunit.assertEquals(string_util.startswith("abc", "a"), true)
    luaunit.assertEquals(string_util.startswith("abc", "ab"), true)
    luaunit.assertEquals(string_util.startswith("abc", "abc"), true)
    luaunit.assertEquals(string_util.startswith("abc", "d"), false)
    luaunit.assertEquals(string_util.endswith("abc", "abcd"), false)
end

test_trim = function()
    luaunit.assertEquals(string_util.trim(""), "")
    luaunit.assertEquals(string_util.trim(" \t"), "")
    luaunit.assertEquals(string_util.trim(" \t\n"), "")

    luaunit.assertEquals(string_util.trim(" a"), "a")
    luaunit.assertEquals(string_util.trim(" \ta"), "a")
    luaunit.assertEquals(string_util.trim("a "), "a")
    luaunit.assertEquals(string_util.trim("a \t"), "a")
    luaunit.assertEquals(string_util.trim(" a "), "a")
end

luaunit.LuaUnit.run()
