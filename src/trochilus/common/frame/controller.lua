local type = type
local log, ERR = ngx.log, ngx.ERR
local cjson = require "cjson.safe"
local json_encode, json_decode = cjson.encode, cjson.decode

local exports = {}

local check_args_v0 = function(args)
    local data = args.data
    if "string" ~= type(data) then
        return false, 400, 1, "data not set"
    end

    local data_o = json_decode(data)
    if "table" ~= type(data_o) then
        return false, 400, 1, "failed to decode arg data"
    end
    args.data = data_o
    return true
end
exports.check_args_v0 = check_args_v0

local check_args = function(body)
    local args = json_decode(body)
    if "table" ~= type(args) then
        return nil, 400, 1, "failed to decode body"
    end
    return args
end
exports.check_args = check_args

exports.check_body_args_v0 = function(ngx, method)
    local req = ngx.req
    if method and (method ~= req.get_method()) then
        return nil, 405, 1, "only " .. method .. " allowed"
    end

    req.read_body()
    local args = req.get_post_args()
    if "table" ~= type(args) then
        return nil, 400, 1, "invalid post body"
    end

    local ok, status, code, msg = check_args_v0(args)
    if not ok then
        return nil, status, code, msg
    end
    return args
end

exports.check_body_args = function(ngx, method)
    local req = ngx.req
    if method and (method ~= req.get_method()) then
        return nil, 405, 1, "only " .. method .. " allowed"
    end

    req.read_body()
    local body = req.get_body_data()
    if not body then
        return nil, 400, 1, "invalid post body"
    end

    local args, status, code, msg = check_args(body)
    if not args then
        return nil, status, code, msg
    end
    return args
end

exports.handle_req = function(ngx, check, serve)
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    local args, status, code, msg = check(ngx)
    if not args then
        ngx.status = status
        ngx.say(json_encode({code = code, message = msg}))
        return
    end

    local ctx = {}
    local data = serve(ctx, args)
    if not data then
        if ctx.err then log(ERR, ctx.err) end
        ngx.status = ctx.status or 500
        ngx.say(json_encode({code = ctx.code or 1, message = ctx.msg or "internal error"}))
        return
    end

    if "table" == type(data) then
        local resp = {code = 0, message = "success", data = data}
        ngx.say(json_encode(resp))
    elseif true == data then
        ngx.say('{"code": 0, "message": "success"}')
    else
        ngx.say(data)
    end
end

return exports
