local type, pairs, tonumber, tostring = type, pairs, tonumber, tostring
local string_gmatch, string_find, string_sub, string_lower, string_upper, string_byte =
    string.gmatch, string.find, string.sub, string.lower, string.upper, string.byte
local table_concat = table.concat
local socket_tcp, encode_args, re_match = ngx.socket.tcp, ngx.encode_args, ngx.re.match
local log, DEBUG = ngx.log, ngx.DEBUG

local HTTP = {
    ["1.0"] = " HTTP/1.0\r\n",
    ["1.1"] = " HTTP/1.1\r\n"
}
local USER_AGENT = "lua-resty-http/0.07 (Lua) ngx_lua/" .. ngx.config.ngx_lua_version

local format_request = function(params)
    local req = {
        params.method,
        " ",
        params.path,
        "",
        "",
        HTTP[params.version] or HTTP["1.1"],
        true, true, true
    }

    local uri_args = params.uri_args
    for _, _ in pairs(uri_args) do
        req[4] = "?"
        req[5] = encode_args(uri_args)
        break
    end

    local i = 7
    for key, val in pairs(params.headers) do
        local typ = type(val)
        if typ ~= "table" then
            req[i] = key
            req[i + 1] = ": "
            req[i + 2] = tostring(val)
            req[i + 3] = "\r\n"
            i = i + 4
        else
            for _, e in pairs(val) do
                req[i] = key
                req[i + 1] = ": "
                req[i + 2] = tostring(e)
                req[i + 3] = "\r\n"
                i = i + 4
            end
        end
    end

    req[i] = "\r\n"
    local body = params.body
    if body then req[i + 1] = body end
    return req
end

local receive_status = function(sock)
    local line, err = sock:receive("*l")
    if not line then return nil, nil, err end
    return tonumber(string_sub(line, 10, 12)), string_sub(line, 6, 8)
end

local receive_headers = function(sock)
    local headers = {}
    repeat
        local line, err = sock:receive("*l")
        if not line then return nil, err end
        for key, val in string_gmatch(line, "([^:%s]+):%s*(.+)") do
            local val_h = headers[key]
            local typ = type(val_h)
            if "nil" == typ then
                headers[key] = val
            elseif "string" == typ then
                headers[key] = {val_h, val}
            elseif "table" == typ then
                val_h[#val_h + 1] = val
            end
        end
    until string_find(line, "^%s*$")
    return headers, nil
end

local should_receive_body = function(method, code)
    if method == "HEAD" then return false end
    if code == 204 or code == 304 then return false end
    if code >= 100 and code < 200 then return false end
    return true
end

local chunked_read_body = function(sock)
    local chunks = {}
    repeat
        local line, err = sock:receive("*l")
        if not line then return nil, err end
        local length = tonumber(line, 16)
        if not length then return nil, "unable to read chunksize" end

        if length > 0 then
            local chunk, err = sock:receive(length)
            if not chunk then return nil, err end
            chunks[#chunks + 1] = chunk
        end
        sock:receive(2) -- read \r\n
    until length == 0
    return table_concat(chunks)
end

local read_body = function(sock, content_length)
    if not content_length then
        return sock:receive("*a")
    end
    return sock:receive(content_length)
end


local send_request = function(self, params)
    params.method = string_upper(params.method or "GET")
    params.version = params.version or "1.1"
    params.path = params.path or "/"
    params.headers = params.headers or {}
    params.uri_args = params.uri_args or {}

    local sock = self._sock
    local body = params.body
    local headers = params.headers

    if body and not headers["Content-Length"] then
        headers["Content-Length"] = #body
    end
    if not headers["Host"] then
        local host, port = params.host, params.port
        if ((params.scheme == "https") and (port ~= 443)) or ((params.scheme ~= "https") and (port ~= 80)) then
            host = host .. ":" .. port
        end
        headers["Host"] = host
    end
    if not headers["User-Agent"] then
        headers["User-Agent"] = USER_AGENT
    end
    if params.version == 1.0 and not headers["Connection"] then
        headers["Connection"] = "Keep-Alive"
    end

    local nbyte, err = sock:send(format_request(params))
    if not nbyte then return nil, err end
    return true
end

local recv_response = function(self, params)
    local sock = self._sock
    local status, version, err = receive_status(sock)
    if not status then return nil, err end
    local headers, err = receive_headers(sock)
    if not headers then return nil, err end
    local out = {
        status = status,
        headers = headers
    }

    local h = headers["Connection"]
    if h then
        h = string_lower(h)
        if (version == "1.1" and h == "close") or (version == "1.0" and h ~= "keep-alive") then
            self.keepalive = false
        end
    else
        self.keepalive = false
    end

    if should_receive_body(params.method, status) then
        local body
        h = headers["Transfer-Encoding"]
        h = h and string_lower(h)
        if version == "1.1" and h == "chunked" then
            body, err = chunked_read_body(sock)
        else
            body, err = read_body(sock, tonumber(headers["Content-Length"]))
        end
        if not body then return nil, err end
        out.body = body
    end

    return out
end


local exports = {}

function exports.new(timeout)
    local sock, err = socket_tcp()
    if not sock then return nil, err end
    if timeout then sock:settimeout(timeout) end
    return {_sock = sock}
end

function exports.parse_uri(uri)
    local m, err = re_match(uri, [[^(http[s]?)://([^:/]+)(?::(\d+))?(.*)]], "jo")
    if not m then return nil end
    local scheme, host, port, path = m[1], m[2], m[3], m[4]
    port = tonumber(port) or ("https" == scheme and 443) or 80
    if not path or "" == path then path = "/" end
    return scheme, host, port, path
end

function exports.request(self, params)
    local sock = self._sock
    params = params or {}
    if params.uri then
        params.scheme, params.host, params.port, params.path = exports.parse_uri(params.uri)
        if not params.scheme then return nil, "failed to match uri" end
    end

    local host, port = params.host, params.port
    local c, err = sock:connect(host, port)
    if not c then return nil, err end

    if params.scheme == "https" then
        local ok, err = sock:sslhandshake(nil, host, false)
        if not ok then return nil, err end
    end

    local res, err = send_request(self, params)
    if not res then return nil, err end
    res, err = recv_response(self, params)
    if not res then return nil, err end
    if false ~= self.keepalive then
        local ok, err = sock:setkeepalive()
        if not ok then log(DEBUG, err) end
    end

    return res, nil
end

return exports
