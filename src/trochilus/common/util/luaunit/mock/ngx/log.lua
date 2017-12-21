local LOG_LEVELS_NAME = {
    "DEBUG", "INFO", "NOTICE", "WARN", "ERR", "CRIT", "ALERT", "EMERG", "STDERR"
}
local do_log = false
for _, a in ipairs(arg) do
    if a == "-v" then do_log = true end
end

local log = function(level, ...)
    if do_log and level >= 5 then
        local ai = {...}
        for i, a in ipairs(ai) do ai[i] = tostring(a) end
        print("[" .. (LOG_LEVELS_NAME[level] or "???") .. "]" .. table.concat(ai))
        --print(debug.traceback("", 2))
    end
end

local exports = {}

exports.mixin = function(ngx)
    ngx.DEBUG, ngx.INFO, ngx.NOTICE, ngx.WARN, ngx.ERR, ngx.CRIT, ngx.ALERT, ngx.EMERG, ngx.STDERR =
        1, 2, 3, 4, 5, 6, 7, 8, 9
    ngx.log = log
end

return exports
