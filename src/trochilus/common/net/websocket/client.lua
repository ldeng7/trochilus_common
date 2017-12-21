local type, setmetatable = type, setmetatable
local ngx = ngx
local string_char, string_find = string.char, string.find
local table_concat = table.concat
local band, rshift = bit.band, bit.rshift

local random = require "resty.random"
local random_bytes = random.bytes
local protocol = require "trochilus.common.util.websocket.protocol"
local proto_recv_frame = protocol.recv_frame
local proto_send_frame = protocol.send_frame

local exports = {}

local mt = { __index = exports }

exports.new = function(self, opts)
    local sock, err = ngx.socket.tcp()
    if not sock then return nil, err end

    if "table" ~= type(opts) then opts = {} end
    if opts.timeout then sock:settimeout(opts.timeout) end
    return setmetatable({
        sock = sock,
        max_payload_len = opts.max_payload_len or 65535,
        send_unmasked = opts.send_unmasked,
    }, mt)
end

exports.connect = function(self, uri, opts)
    local sock = self.sock
    if not sock then return nil, nil, "not initialized" end

    local m, err = ngx.re.match(uri, [[^(wss?)://([^:/]+)(?::(\d+))?(.*)]], "jo")
    if not m then return nil, (err or "bad websocket uri") end
    local scheme, host, port, path = m[1], m[2], m[3], m[4]
    port = port or 80
    if 0 == #path then path = "/" end

    if "table" ~= type(opts) then opts = {} end
    local req_header_proto, req_header_origin
    local val = opts.protocols
    if val then
        req_header_proto = "\r\nSec-WebSocket-Protocol: "
        if "table" == type(val) then
            req_header_proto = req_header_proto .. table_concat(val, ",")
        else
            req_header_proto = req_header_proto .. val
        end
    end
    val = opts.origin
    if val then req_header_origin = "\r\nOrigin: " .. val end

    local sock_opts = {}
    val = opts.pool
    if val then sock_opts.pool = val end
    local ok, err = sock:connect(host, port, sock_opts)
    if not ok then return nil, err end
    if scheme == "wss" then
        ok, err = sock:sslhandshake(false, host, opts.ssl_verify)
        if not ok then return nil, err end
    end

    local req = {
        "GET ", path, " HTTP/1.1\r\nUpgrade: websocket\r\nHost: ", host, ":", port,
        "\r\nConnection: Upgrade",
        "\r\nSec-WebSocket-Version: 13",
        "\r\nSec-WebSocket-Key: ", ngx.encode_base64(random_bytes(16)),
        "\r\nConnection: Upgrade"
    }
    local i = #req + 1
    if req_header_proto then
        req[i] = req_header_proto
        i = i + 1
    end
    if req_header_origin then
        req[i] = req_header_origin
        i = i + 1
    end
    req[i] = "\r\n\r\n"

    local nbyte, err = sock:send(req)
    if not nbyte then return nil, err end
    local resp, err = sock:receiveuntil("\r\n\r\n")()
    if not resp then return nil, err end
    return 1
end

exports.set_timeout = function(self, time)
    local sock = self.sock
    if not sock then return nil, nil, "not initialized" end
    return sock:settimeout(time)
end

exports.set_keepalive = function(self, ...)
    local sock = self.sock
    if not sock then return nil, nil, "not initialized" end
    return sock:setkeepalive(...)
end

exports.recv_frame = function(self)
    if self.fatal then return nil, nil, "fatal error happened" end
    local sock = self.sock
    if not sock then return nil, nil, "not initialized" end

    local data, typ, err = proto_recv_frame(sock, self.max_payload_len, true)
    if not data and not string_find(err, "timeout", 1, true) then self.fatal = true end
    return data, typ, err
end

local send_frame = function(self, fin, opcode, payload)
    if self.fatal then return nil, "fatal error happened" end
    if self.closed then return nil, "closed" end
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    local nbyte, err = proto_send_frame(sock, fin, opcode, payload, self.max_payload_len, self.send_masked)
    if not nbyte then self.fatal = true end
    return nbyte, err
end
exports.send_frame = send_frame

exports.send_text = function(self, data)
    return send_frame(self, true, 0x1, data)
end

exports.send_binary = function(self, data)
    return send_frame(self, true, 0x2, data)
end

exports.send_close = function(self, code, msg)
    local payload = ""
    if code then
        if type(code) ~= "number" or code > 0x7fff then return nil, "bad status code" end
        payload = string_char(band(rshift(code, 8), 0xff), band(code, 0xff)) .. (msg or "")
    end
    local nbyte, err = send_frame(self, true, 0x8, payload)
    self.closed = true
    return nbyte, err
end

exports.send_ping = function(self, data)
    return send_frame(self, true, 0x9, data)
end

exports.send_pong = function(self, data)
    return send_frame(self, true, 0xa, data)
end

function exports.close(self)
    if self.fatal then return nil, "fatal error happened" end
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    if not self.closed then
        send_frame(self, true, 0x8, "")
        self.closed = true
    end
    return sock:close()
end

return exports
