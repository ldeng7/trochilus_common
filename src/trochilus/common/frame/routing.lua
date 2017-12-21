local ipairs, pairs, type = ipairs, pairs, type
local string_byte, string_sub, string_lower = string.byte, string.sub, string.lower
local table_concat = table.concat
local re_match = ngx.re.match
local log, CRIT = ngx.log, ngx.CRIT

local string_util = require "trochilus.common.util.string"
local string_split = string_util.split

local routes = {
    s = {},
    re = {}
}

local get_controller = function(es, prefix)
    local t = {}
    for _, e in ipairs(es) do
        if #e > 0 then t[#t + 1] = e end
    end
    local package_name = prefix .. "controller." .. table_concat(t, ".")
    return require(package_name)
end

local exports = {}

exports.on_init_worker = function(routes_items, prefix)
    log(CRIT, "routing on_init_worker")
    if "string" ~= type(prefix) then prefix = "" end
    if #prefix > 0 then prefix = prefix .. "." end

    for _, s in ipairs(routes_items) do
        local es, es_plain = string_split(s, "/"), {}
        for i, e in ipairs(es) do
            if (#e >= 2) and (58 == string_byte(e, 1)) then  -- ':'
                es[i] = "(?<" .. string_sub(e, 2) .. ">[\\S^/]+)"
            else
                es_plain[#es_plain + 1] = e
            end
        end

        if #es == #es_plain then
            routes.s[s] = get_controller(es, prefix)
            log(CRIT, "add route: ", s)
        else
            local re = "^" .. table_concat(es, "/") .. "$"
            routes.re[re] = get_controller(es_plain, prefix)
            log(CRIT, "add regex route: ", re)
        end
    end
end

local CTX_KEY_ROUTING_ARGS = "common:routing_args"
exports.CTX_KEY_ROUTING_ARGS = CTX_KEY_ROUTING_ARGS

exports.route = function(ngx)
    local uri = ngx.var.uri
    local p = routes.s[uri]
    if not p then
        for re, pp in pairs(routes.re) do
            local m = re_match(uri, re, "jo")
            if m then
                ngx.ctx[CTX_KEY_ROUTING_ARGS], p = m, pp
                break
            end
        end
    end
    if not p then return ngx.exit(404) end

    local f = string_lower(ngx.req.get_method())
    f = p[f]
    if not f then return ngx.exit(405) end
    return f(ngx)
end

return exports
