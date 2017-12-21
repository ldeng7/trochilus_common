local type, ipairs = type, ipairs
local decode_base64 = ngx.decode_base64
local log, ERR = ngx.log, ngx.ERR

local dns_resolver = require "resty.dns.resolver"
local dns_resolver_new = dns_resolver.new
local cjson = require "cjson.safe"
local json_decode = cjson.decode
local http = require "trochilus.common.util.http_lite"
local http_new, http_request = http.new, http.request

local exports = {}

exports.new = function(host, opts)
    return {
        host = host,
        dns_port = opts.dns_port,
        dns_timeout = opts.dns_timeout,
        dns_retrans = opts.dns_retrans,
        api_port = opts.api_port,
        api_timeout = opts.api_timeout,
        kv_indices = {}
    }
end

exports.query_dns = function(self, serv_name)
    local resolver, err = dns_resolver_new(nil, {
        nameservers = {{self.host, self.dns_port}},
        timeout = self.dns_timeout,
        retrans = self.dns_retry,
    })
    if not resolver then log(ERR, err); return nil end

    local res, err = resolver:query(serv_name .. ".service.consul",
        {qtype = resolver.TYPE_SRV, additional_section = true})
    if not res then log(ERR, err); return nil end
    if res.errcode then
        log(ERR, "dns err code: ", res.errcode, ", err: ", res.errstr)
        return nil
    end

    local arr_srv, i, map_a = {}, 1, {}
    for _, e in ipairs(res) do
        if resolver.TYPE_SRV == e.type then
            local name, port = e.target, e.port
            if name and port then
                arr_srv[i] = {name, port}
                i = i + 1
            end
        elseif resolver.TYPE_A == e.type then
            local name, host = e.name, e.address
            if name and host then
                map_a[name] = host
            end
        end
    end

    local out, i = {}, 1
    for _, e in ipairs(arr_srv) do
        local name = e[1]
        local host = map_a[name]
        if host then
            out[i] = {host, e[2]}
            i = i + 1
        end
    end
    return out
end

local api_get = function(self, path)
    local c, err = http_new(self.api_timeout)
    if not c then return nil, err end
    local req = {
        host = self.host,
        port = self.api_port,
        path = path
    }

    local resp, err = http_request(c, req)
    if not resp then return nil, err end
    resp = json_decode(resp.body)
    if nil == resp then return nil, "invalid json" end
    return resp
end

exports.api_list_nodes = function(self)
    local resp, err = api_get(self, "/v1/catalog/nodes")
    if not resp then return nil, err end

    if "table" ~= type(resp) then return nil, nil, "invalid resp" end
    local t, i = {}, 1
    for _, e in ipairs(resp) do
        if ("table" == type(e)) and e.Address then
            t[i] = e.Address
            i = i + 1
        end
    end
    return t
end

exports.api_kv_read = function(self, key)
    local resp, err = api_get(self, "/v1/kv/" .. key)
    if not resp then return nil, nil, err end

    if ("table" ~= type(resp)) or ("table" ~= type(resp[1])) then return nil, nil, "invalid resp" end
    resp = resp[1]
    local v, idx = resp["Value"], resp["ModifyIndex"]
    if "string" ~= type(v) then return nil, nil, "invalid resp" end
    v = decode_base64(v)
    if not v then return nil, nil, "invalid value" end

    local prev_idx = self.kv_indices[key]
    self.kv_indices[key] = idx
    return v, idx ~= prev_idx
end

exports.api_kv_write = function(self, key, value)
    local c, err = http_new(self.api_timeout)
    if not c then return nil, err end
    local req = {
        method = "PUT",
        host = self.host,
        port = self.api_port,
        path = "/v1/kv/" .. key,
        body = value
    }

    local resp, err = http_request(c, req)
    if not resp then return nil, err end
    return true
end

return exports
