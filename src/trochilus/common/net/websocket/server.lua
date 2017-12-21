local type, setmetatable = type, setmetatable
local ngx = ngx
local string_lower, string_char, string_find = string.lower, string.char, string.find
local band, rshift = bit.band, bit.rshift

local protocol = require "trochilus.common.util.websocket.protocol"
local proto_recv_frame = protocol.recv_frame
local proto_send_frame = protocol.send_frame

local exports = {}

local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
local mt = {__index = exports}

local get_header = function(headers, key)
    local val = headers[key]
    if "table" == type(val) then val = val[1] end
    return val or ""
end

exports.new = function(_, opts)
    local req = ngx.req
    local resp_header = ngx.header

    if req.http_version() <= 1.0 then return nil, "bad http version" end
    if ngx.headers_sent then return nil, "response header already sent" end
    req.read_body()

    local headers = req.get_headers()
    local val = get_header(headers, "upgrade")
    if string_lower(val) ~= "websocket" then return nil, "bad request header: upgrade" end
    val = get_header(headers, "connection")
    if not string_find(string_lower(val), "upgrade", 1, true) then return nil, "bad request header: connection" end
    val = get_header(headers, "sec-websocket-version")
    if val ~= "13" then return nil, "bad request header: ws version" end

    val = get_header(headers, "sec-websocket-key")
    if 0 == #val then return nil, "bad request header: ws key" end
    resp_header["Sec-WebSocket-Accept"] = ngx.encode_base64(ngx.sha1_bin(val .. GUID))

    val = get_header(headers, "sec-websocket-protocol")
    if 0 ~= #val then resp_header["Sec-WebSocket-Protocol"] = val end

    resp_header["Upgrade"] = "websocket"
    resp_header["Content-Type"] = nil

    ngx.status = 101
    local ok, err = ngx.send_headers()
    if not ok then return nil, err end
    ok, err = ngx.flush(true)
    if not ok then return nil, err end
    local sock, err = req.socket(true)
    if not ok then return nil, err end

    if "table" ~= type(opts) then opts = {} end
    if opts.timeout then sock:settimeout(opts.timeout) end
    return setmetatable({
        sock = sock,
        max_payload_len = opts.max_payload_len or 65535,
        send_masked = opts.send_masked,
    }, mt)
end

exports.set_timeout = function(self, time)
    local sock = self.sock
    if not sock then return nil, nil, "not initialized" end
    return sock:settimeout(time)
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
    return send_frame(self, true, 0x8, payload)
end

exports.send_ping = function(self, data)
    return send_frame(self, true, 0x9, data)
end

exports.send_pong = function(self, data)
    return send_frame(self, true, 0xa, data)
end

return exports
