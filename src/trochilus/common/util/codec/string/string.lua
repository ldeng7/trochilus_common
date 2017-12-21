local ipairs, unpack = ipairs, unpack
local table_concat, bit_band, bit_rshift = table.concat, bit.band, bit.rshift
local string_len, string_byte, string_char = string.len, string.byte, string.char

local t_ucs16_to_gbk = require "trochilus.common.util.codec.string.data.ucs16_to_gbk"
local t_gbk_to_ucs16 = require "trochilus.common.util.codec.string.data.gbk_to_ucs16"

local t_ucs16_to_ansi = {
    gbk = t_ucs16_to_gbk
}
local t_ansi_to_ucs16 = {
    gbk = t_gbk_to_ucs16
}

local exports = {}

local ucs16_to_ansi = function(arr_ucs, enc)
    local t = t_ucs16_to_ansi[enc]
    local out, i = {}, 1
    for _, u in ipairs(arr_ucs) do
        local c = t[u + 1]
        if c and c ~= 0 then
            out[i] = c
            i = i + 1
        end
    end
    return table_concat(out)
end

local ansi_to_ucs16 = function(s, enc)
    local t = t_ansi_to_ucs16[enc]
    local out, i = {}, 1
    local l, j = string_len(s), 1
    while j <= l do
        local c = string_byte(s, j)
        if c < 0x80 then
            out[i] = c
            i = i + 1
        else
            j = j + 1
            if j > l then break end
            c = c * 0x100 + string_byte(s, j) - 0x8000
            local u = t[c + 1]
            if u ~= 0 then
                out[i] = u
                i = i + 1
            end
        end
        j = j + 1
    end
    return out
end    

exports.ucs16_to_gbk = function(arr_ucs)
    return ucs16_to_ansi(arr_ucs, "gbk")
end

exports.gbk_to_ucs16 = function(s)
    return ansi_to_ucs16(s, "gbk")
end

local ucs16_to_utf8 = function(arr_ucs)
    local out, i = {}, 1
    for _, u in ipairs(arr_ucs) do
        if u < 0x80 then
            out[i] = u
            i = i + 1
        elseif u < 0x800 then
            out[i] = bit_rshift(u, 6) + 0xc0
            i = i + 1
            out[i] = bit_band(u, 0x3f) + 0x80
            i = i + 1
        elseif u < 0x10000 then
            out[i] = bit_rshift(u, 12) + 0xe0
            i = i + 1
            out[i] = bit_band(bit_rshift(u, 6), 0x3f) + 0x80
            i = i + 1
            out[i] = bit_band(u, 0x3f) + 0x80
            i = i + 1
        end
    end
    return string_char(unpack(out))
end
exports.ucs16_to_utf8 = ucs16_to_utf8

local utf8_to_ucs16 = function(s, len)
    local out, i = {}, 1
    local l, j = string_len(s), 1
    while (j <= l) and ((not len) or (i <= len)) do
        local c = string_byte(s, j)
        if c < 0x80 then
            out[i] = c
            j = j + 1
            i = i + 1
        elseif bit_band(c, 0xe0) == 0xc0 then
            local u = (c - 0xc0) * 0x40
            j = j + 1
            if j > l then break end
            c = string_byte(s, j)
            if bit_band(c, 0xc0) == 0x80 then
                u = u + (c - 0x80)
                j = j + 1
                out[i] = u
                i = i + 1
            end
        elseif bit_band(c, 0xf0) == 0xe0 then
            local u = (c - 0xe0) * 0x1000
            j = j + 1
            if j > l then break end
            c = string_byte(s, j)
            if bit_band(c, 0xc0) == 0x80 then
                u = u + (c - 0x80) * 0x40
                j = j + 1
                if j > l then break end
                c = string_byte(s, j)
                if bit_band(c, 0xc0) == 0x80 then
                    u = u + (c - 0x80)
                    j = j + 1
                    out[i] = u
                    i = i + 1
                end
            end
        else
            j = j + 1
        end
    end
    return out
end
exports.utf8_to_ucs16 = utf8_to_ucs16

exports.utf8_truncate = function(s, len)
    return ucs16_to_utf8(utf8_to_ucs16(s, len))
end

return exports
