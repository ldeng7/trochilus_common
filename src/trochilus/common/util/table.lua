local setmetatable, type = setmetatable, type

local exports = {}

local try_ghost_mt = {}
try_ghost_mt.__index = function(t, k)
    return setmetatable({}, try_ghost_mt)
end

exports.try = function(t, k)
    if "table" == type(t) then
        local v = t[k]
        if nil ~= v then return v end
    end
    return setmetatable({}, try_ghost_mt)
end

return exports
