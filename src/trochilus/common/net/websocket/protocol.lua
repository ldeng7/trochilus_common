local type, tostring = type, tostring
local string_byte, string_char, string_sub = string.byte, string.char, string.sub
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local table_concat, math_random, math_ceil = table.concat, math.random, math.ceil

local exports = {}

local OPCODES = {
    CONTINUATION = 0x0,
    TEXT         = 0x1,
    BINARY       = 0x2,
    CLOSE        = 0x8,
    PING         = 0x9,
    PONG         = 0xa,
}
local OPCODES_NAME = {
    "continuation", "text", "binary", "custom", "custom", "custom", "custom", "custom",
    "close", "ping", "pong", "custom", "custom", "custom", "custom", "custom",
}

local get_payload_len = function(sock, byte)
    local payload_len = band(byte, 0x7f)

    if payload_len == 126 then
        local data, err = sock:receive(2)
        if not data then return nil, err end
        payload_len = bor(lshift(string_byte(data, 1), 8), string_byte(data, 2))

    elseif payload_len == 127 then
        local data, err = sock:receive(8)
        if not data then return nil, err end
        if (string_byte(data, 1) ~= 0) or (string_byte(data, 2) ~= 0) or (string_byte(data, 3) ~= 0) or
                (string_byte(data, 4) ~= 0) then return nil, "payload too long" end
        payload_len = bor(lshift(string_byte(data, 5), 24), lshift(string_byte(data, 6), 16),
            lshift(string_byte(data, 7), 8), string_byte(data, 8))
        if payload_len >= 1073741824 then return nil, "payload len too large" end
    end

    return payload_len
end

local read_masking_payload = function(rest_data, msg_start_byte, payload_len)
    local mask1, mask2, mask3, mask4 = string_byte(rest_data, 1), string_byte(rest_data, 2),
        string_byte(rest_data, 3), string_byte(rest_data, 4)
    local msg_len = payload_len - msg_start_byte + 1
    local arr, i, ib = {}, 1, msg_start_byte + 4
    local jend = math_ceil(msg_len / 4)
    for j = 1, jend do
        arr[i]     = string_char(bxor(string_byte(rest_data, ib) or 0,     mask1))
        arr[i + 1] = string_char(bxor(string_byte(rest_data, ib + 1) or 0, mask2))
        arr[i + 2] = string_char(bxor(string_byte(rest_data, ib + 2) or 0, mask3))
        arr[i + 3] = string_char(bxor(string_byte(rest_data, ib + 3) or 0, mask4))
        i, ib = i + 4, ib + 4
    end
    return table_concat(arr, nil, 1, msg_len)
end

local recv_close_frame = function(rest_data, payload_len, masking)
    if payload_len == 0 then return "", OPCODES_NAME[OPCODES.CLOSE], nil end
    if payload_len < 2 then return nil, nil, "invalid status code for close frame" end

    local msg, code
    if masking then
        local byte = bxor(string_byte(rest_data, 5), string_byte(rest_data, 1))
        code = bor(lshift(byte, 8), bxor(string_byte(rest_data, 6), string_byte(rest_data, 2)))
        msg = read_masking_payload(rest_data, 3, payload_len)
    else
        local byte = string_byte(rest_data, 1)
        code = bor(lshift(byte, 8), string_byte(rest_data, 2))
        msg = string_sub(rest_data, 3)
    end

    return msg, OPCODES_NAME[OPCODES.CLOSE], code
end

exports.recv_frame = function(sock, max_payload_len, force_masking)
    local data, err = sock:receive(2)
    if not data then return nil, nil, err end

    local byte = string_byte(data, 1)
    local fin = band(byte, 0x80) ~= 0
    local opcode = band(byte, 0x0f)

    byte = string_byte(data, 2)
    local masking = band(byte, 0x80) ~= 0
    if force_masking and not masking then return nil, nil, "unmasked" end

    local payload_len, err = get_payload_len(sock, byte)
    if not payload_len then return nil, nil, err end
    if opcode >= OPCODES.CLOSE then -- a control frame
        if not fin then return nil, nil, "non fin for control frame" end
        if payload_len >= 126 then return nil, nil, "payload len too large" end
    end
    if payload_len > max_payload_len then return nil, nil, "exceeding max_payload_len" end

    local rest_len = (masking and (payload_len + 4)) or payload_len
    local rest_data
    if rest_len > 0 then
        rest_data, err = sock:receive(rest_len)
        if not rest_data then return nil, nil, err end
    else
        rest_data = ""
    end

    if opcode == OPCODES.CLOSE then return recv_close_frame(rest_data, payload_len, masking) end
    local msg = (masking and read_masking_payload(rest_data, 1, payload_len)) or rest_data
    return msg, OPCODES_NAME[opcode], (not fin and "again") or nil
end


local build_frame = function(fin, opcode, payload, masking)
    local payload_len = #payload
    if payload_len > 0x7fffffff then return nil, "payload too long" end
    local arr = {"", "", "", "", ""}

    arr[1] = string_char((fin and bor(0x80, opcode)) or opcode)

    local byte2
    if payload_len <= 125 then
        byte2 = payload_len
    elseif payload_len <= 65535 then
        byte2 = 126
        arr[3] = string_char(band(rshift(payload_len, 8), 0xff), band(payload_len, 0xff))
    else
        byte2 = 127
        arr[3] = string_char(0, 0, 0, 0,
            band(rshift(payload_len, 24), 0xff), band(rshift(payload_len, 16), 0xff),
            band(rshift(payload_len, 8), 0xff), band(payload_len, 0xff))
    end

    if masking then
        byte2 = bor(byte2, 0x80)
        local key = math_random(0xffffffff)
        local mask1, mask2, mask3, mask4 = band(rshift(key, 24), 0xff), band(rshift(key, 16), 0xff),
            band(rshift(key, 8), 0xff), band(key, 0xff)
        arr[4] = string_char(mask1, mask2, mask3, mask4)

        local bytes, i = {}, 1
        local jend = math_ceil(payload_len / 4)
        for j = 1, jend do
            bytes[i]     = string_char(bxor(string_byte(payload, i) or 0,     mask1))
            bytes[i + 1] = string_char(bxor(string_byte(payload, i + 1) or 0, mask2))
            bytes[i + 2] = string_char(bxor(string_byte(payload, i + 2) or 0, mask3))
            bytes[i + 3] = string_char(bxor(string_byte(payload, i + 3) or 0, mask4))
            i = i + 4
        end
        payload = table_concat(bytes, nil, 1, payload_len)
    end

    arr[2], arr[5] = string_char(byte2), payload
    return table_concat(arr)
end
exports.build_frame = build_frame


function exports.send_frame(sock, fin, opcode, payload, max_payload_len, masking)
    payload = (payload and tostring(payload)) or ""
    local payload_len = #payload
    if payload_len > max_payload_len then return nil, "payload too long" end

    if opcode >= OPCODES.CLOSE then -- a control frame
        if not fin then return nil, "non fin for control frame" end
        if payload_len >= 126 then return nil, "payload len too large" end
    end

    local frame, err = build_frame(fin, opcode, payload, masking)
    if not frame then return nil, err end

    local nbyte, err = sock:send(frame)
    if not nbyte then return nil, err end
    return nbyte
end


return exports
