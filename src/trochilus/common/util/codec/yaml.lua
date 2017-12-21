local io_open = io.open
local string_gsub = string.gsub
local os_getenv = os.getenv
local log, ERR = ngx.log, ngx.CRIT
local ffi = require "ffi"
local cjson = require "cjson.safe"
local json_decode = cjson.decode

ffi.cdef[[
char* yaml2json(const char* str, int len_in, int* len);
void freeStr(const char* str);
]]
local lib = ffi.load(os.getenv("OPRPATH") .. "/trochilus_common/lib/libtrochilus.so")

local exports = {}

local env_sub = function(s)
    return '"' .. (os_getenv(s) or "") .. '"'
end

local decode_string = function(s)
    s = string_gsub(s, "%!env ([%w_]+)", env_sub)
    local l = ffi.new("int[1]")
    local json = lib.yaml2json(s, #s, l)
    if not json then return nil end
    ffi.gc(json, lib.freeStr)
    json = ffi.string(json, l[0])
    return json_decode(json)
end
exports.decode_string = decode_string

exports.decode_file = function(path)
    local f = io_open(path, "r")
    if not f then
        log(ERR, "failed to open yaml file")
        return nil
    end
    local s = f:read("*a")
    f:close()
    if not s then
        log(ERR, "failed to read yaml file")
        return nil
    end
    return decode_string(s)
end

return exports
