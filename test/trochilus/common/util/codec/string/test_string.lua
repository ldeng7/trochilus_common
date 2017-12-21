require("test.common").boot()

local string_util = require "trochilus.common.util.codec.string.string"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_ucs16_to_gbk = function()
    luaunit.assertEquals(string_util.ucs16_to_gbk({}), "")
    luaunit.assertEquals(string_util.ucs16_to_gbk({65536, 97, 128}), "a")
    luaunit.assertEquals(string_util.ucs16_to_gbk({32599, 29577, 20964}), "\194\222\211\241\183\239")
end

test_gbk_to_ucs16 = function()
    luaunit.assertEquals(string_util.gbk_to_ucs16(""), {})
    luaunit.assertEquals(string_util.gbk_to_ucs16("a\153\57"), {97})
    luaunit.assertEquals(string_util.gbk_to_ucs16("\194\222\211\241\183\239"), {32599, 29577, 20964})
end

test_ucs16_to_utf8 = function()
    luaunit.assertEquals(string_util.ucs16_to_utf8({}), "")
    luaunit.assertEquals(string_util.ucs16_to_utf8({65536, 97, 65536}), "a")
    luaunit.assertEquals(string_util.ucs16_to_utf8({65536, 2047, 65536}), "\223\191")
    luaunit.assertEquals(string_util.ucs16_to_utf8({65536, 65535, 65536}), "\239\191\191")
    luaunit.assertEquals(string_util.ucs16_to_utf8({32599, 29577, 20964}), "罗玉凤")
end

test_utf8_to_ucs16 = function()
    luaunit.assertEquals(string_util.utf8_to_ucs16(""), {})
    luaunit.assertEquals(string_util.utf8_to_ucs16("", 0), {})
    luaunit.assertEquals(string_util.utf8_to_ucs16("", 1), {})

    luaunit.assertEquals(string_util.utf8_to_ucs16("a"), {97})
    luaunit.assertEquals(string_util.utf8_to_ucs16("a", 0), {})
    luaunit.assertEquals(string_util.utf8_to_ucs16("a", 1), {97})
    luaunit.assertEquals(string_util.utf8_to_ucs16("a", 2), {97})

    luaunit.assertEquals(string_util.utf8_to_ucs16("\223\191"), {2047})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\223\191", 0), {})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\223\191", 1), {2047})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\223\191", 2), {2047})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\128"), {0})

    luaunit.assertEquals(string_util.utf8_to_ucs16("\239\191\191"), {65535})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\239\191\191", 0), {})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\239\191\191", 1), {65535})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\239\191\191", 2), {65535})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\224\128\128"), {0})

    luaunit.assertEquals(string_util.utf8_to_ucs16("罗玉凤"), {32599, 29577, 20964})
    luaunit.assertEquals(string_util.utf8_to_ucs16("罗玉凤", 1), {32599})
    luaunit.assertEquals(string_util.utf8_to_ucs16("罗玉凤", 3), {32599, 29577, 20964})
    luaunit.assertEquals(string_util.utf8_to_ucs16("罗玉凤", 4), {32599, 29577, 20964})

    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103"),
        {97, 98, 99, 100, 101, 102, 103})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 1),
        {97})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 2),
        {97, 98})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 3),
        {97, 98, 99})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 4),
        {97, 98, 99, 100})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 5),
        {97, 98, 99, 100, 101})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 7),
        {97, 98, 99, 100, 101, 102, 103})
    luaunit.assertEquals(string_util.utf8_to_ucs16("\192\97\224\98\99\224\128\100\240\101\102\103", 8),
        {97, 98, 99, 100, 101, 102, 103})
end

test_utf8_truncate = function()
    luaunit.assertEquals(string_util.utf8_truncate("", 0), "")
    luaunit.assertEquals(string_util.utf8_truncate("", 1), "")
    luaunit.assertEquals(string_util.utf8_truncate("罗玉凤", 0), "")
    luaunit.assertEquals(string_util.utf8_truncate("罗玉凤", 1), "罗")
    luaunit.assertEquals(string_util.utf8_truncate("罗玉凤", 3), "罗玉凤")
    luaunit.assertEquals(string_util.utf8_truncate("罗玉凤", 4), "罗玉凤")
end

luaunit.LuaUnit.run()
