local string_sub, string_rep, string_gsub = string.sub, string.rep, string.gsub
local encode_base64 = ngx.encode_base64
local string_util = require "trochilus.common.util.string"
local string_split = string_util.split
local hmac = require "ext.github.jkeys089.lua-resty-hmac.hmac"

local exports = {}

exports.ALGOS = {
    HS256 = "HS256",
    HS512 = "HS512"
}

local ALGOS_CLS = {
    HS256 = "hmac_sha",
    HS512 = "hmac_sha"
}

-- new/init

local HS_ALGOS = {
    HS256 = hmac.ALGOS.SHA256,
    HS512 = hmac.ALGOS.SHA512
}

local hs_init = function(self)
    self.hmac = hmac.new(nil, self.key, HS_ALGOS[self.algo])
end

local CLSES_INIT = {
    hmac_sha = hs_init
}

exports.new = function(algo, key)
    local cls = ALGOS_CLS[algo]
    if not cls then return nil end
    local self = {
        cls = cls,
        algo = algo,
        key = key
    }
    CLSES_INIT[cls](self)
    return self
end

-- sign

local hs_sign = function(self, s)
    local dig = self.hmac:final(s)
    if not dig then return nil end
    return encode_base64(dig)
end

local CLSES_SIGN = {
    hmac_sha = hs_sign
}

exports.verify = function(self, jwt_str, ensure_std)
    local es = string_split(jwt_str, ".", true, 3)
    if #es < 3 then return false end
    local s = string_sub(jwt_str, 1, #es[1] + #es[2] + 1)
    local dig_cal = CLSES_SIGN[self.cls](self, s)
    if not dig_cal then return false end

    local dig_prov = es[3]
    if not ensure_std then
        dig_prov = string_gsub(dig_prov, "-", "+")
        dig_prov = string_gsub(dig_prov, "_", "/")
    end
    local j = #dig_prov % 4
    if j > 0 then dig_prov = dig_prov .. string_rep("=", 4 - j) end
    return dig_cal == dig_prov
end

return exports
