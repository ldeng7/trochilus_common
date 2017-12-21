local ffi = require "ffi"
local string_util = require "trochilus.common.util.string"
local util = require "trochilus.common.util.luaunit.mock.ngx.lmn_util"
local lib_lmn = util.lib_lmn
local define_str_func = util.define_str_func

local encode_args = function(args)
    local escape_uri = define_str_func("lmn_escape_uri")
    local t, i = {}, 1
    for k, v in pairs(args) do
        k = escape_uri(k)
        local typ = type(v)
        if "boolean" == typ then
            if v then
                t[i] = k
                i = i + 1
            end
        elseif "string" == typ or "number" == typ then
            t[i] = string.format("%s=%s", k, escape_uri(tostring(v)))
            i = i + 1
        elseif "table" == typ then
            for _, vv in pairs(v) do
                typ = type(vv)
                if "boolean" == typ then
                    if vv then
                        t[i] = k
                        i = i + 1
                    end
                elseif "string" == typ or "number" == typ then
                    t[i] = string.format("%s=%s", k, escape_uri(tostring(vv)))
                    i = i + 1
                else
                    return error(string.format("attempt to use %s as query arg value", typ))
                end
            end
        else
            return error(string.format("attempt to use %s as query arg value", typ))
        end
    end
    return table.concat(t, "&")
end

local decode_args = function(str)
    local unescape_uri = define_str_func("lmn_unescape_uri")
    local t, i = {}, 1
    local args = string_util.split(str, "&")
    for _, arg in ipairs(args) do
        local pos = string.find(arg, "=", 1, true)
        if pos then
            local k = unescape_uri(string.sub(arg, 1, pos - 1))
            local v = unescape_uri(string.sub(arg, pos + 1))
            t[i] = {k, v}
        else
            t[i] = {unescape_uri(arg), true}
        end
        i = i + 1
    end

    local out = {}
    for _, e in ipairs(t) do
        local k, typ = e[1], type(out[e[1]])
        if "nil" == typ then
            out[k] = e[2]
        elseif "string" == typ then
            out[k] = {out[k], e[2]}
        elseif "table" == typ then
            out[k][#out[k] + 1] = e[2]
        end
    end
    return out
end

local encode_base64 = function(str, no_pad)
    local l = ffi.new("unsigned int[1]")
    local bytes = lib_lmn.lmn_encode_base64(str, #str, ((no_pad and 0) or 1), l)
    return ffi.string(bytes, l[0])
end

local hmac_sha1 = function(key, str)
    local l = ffi.new("unsigned int[1]")
    local bytes = lib_lmn.lmn_hmac_sha1(key, #key, str, #str, l)
    return ffi.string(bytes, l[0])
end

local exports = {}

exports.mixin = function(ngx)
    ngx.decode_args = decode_args
    ngx.encode_args = encode_args
    ngx.escape_uri = define_str_func("lmn_escape_uri")
    ngx.quote_sql_str = define_str_func("lmn_quote_sql_str", true)
    ngx.unescape_uri = define_str_func("lmn_unescape_uri")

    ngx.crc32_short = function(str) return lib_lmn.lmn_crc32(str) end
    ngx.crc32_long = function(str) return lib_lmn.lmn_crc32(str) end
    ngx.encode_base64 = encode_base64
    ngx.decode_base64 = define_str_func("lmn_decode_base64")
    ngx.hmac_sha1 = hmac_sha1
    ngx.md5 = define_str_func("lmn_md5")
    ngx.md5_bin = define_str_func("lmn_md5_bin")
    ngx.sha1_bin = define_str_func("lmn_sha1_bin")
end

return exports
