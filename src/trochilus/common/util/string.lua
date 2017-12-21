local type = type
local len, char_at, sub, find = string.len, string.byte, string.sub, string.find

local exports = {}

exports.endswith = function(s, appd)
    local ls, la = len(s), len(appd)
    if ls >= la then
        return sub(s, ls - la + 1, ls) == appd
    end
    return false
end

exports.split = function(s, sep, plain, limit)
    if "" == sep then return nil end
    if nil == plain then plain = true end
    if limit and limit < 1 then limit = nil end

    local out, i, j = {}, 1, 1
    while true do
        if limit and j > limit then
            out[j] = sub(s, i)
            break
        end
        local ib, ie = find(s, sep, i, plain)
        if not ib then
            out[j] = sub(s, i)
            break
        end

        out[j] = sub(s, i, ib - 1)
        j = j + 1
        i = ie + 1
    end
    return out
end

exports.startswith = function(s, pref)
    return sub(s, 1, len(pref)) == pref
end

exports.trim = function(s)
    local l = len(s)
    local ib, ie = l + 1, 0
    for i = 1, len(s) do
        local c = char_at(s, i)
        if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
            ib = i
            break
        end
    end
    for i = len(s), 1, -1 do
        local c = char_at(s, i)
        if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
            ie = i
            break
        end
    end
    return sub(s, ib, ie)
end

return exports
