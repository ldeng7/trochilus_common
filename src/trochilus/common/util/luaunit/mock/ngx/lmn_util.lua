local ffi = require "ffi"

ffi.cdef[[
// quote
char* lmn_escape_uri(const char* str, int len_in, int* len);
char* lmn_quote_sql_str(const char* str, int len_in, int* len);
char* lmn_unescape_uri(const char* str, int len_in, int* len);

// str
unsigned int lmn_crc32(const char* str, int len_in);
char* lmn_decode_base64(const char* str, int len_in, int* len);
char* lmn_encode_base64(const char* str, int len_in, int padding, int* len);
char* lmn_hmac_sha1(const char* key, int len_in_k, const char* str, int len_in_s, int* len);
char* lmn_md5(const char* str, int len_in, int* len);
char* lmn_md5_bin(const char* str, int len_in, int* len);
char* lmn_sha1_bin(const char* str, int len_in, int* len);
]]

local lib_lmn = ffi.load(os.getenv("OPRPATH") .. "/trochilus_common/lib/libtrochilus.so")

local exports = {}

exports.lib_lmn = lib_lmn

exports.define_str_func = function(func, do_str_cast)
    return function(str)
        if do_str_cast then str = tostring(str) end
        local l = ffi.new("int[1]")
        local bytes = lib_lmn[func](str, #str, l)
        -- just for unit tests, so no free of bytes here
        return ffi.string(bytes, l[0])
    end
end

return exports
