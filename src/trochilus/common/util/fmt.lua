local type, pairs, tostring = type, pairs, tostring
local table_concat = table.concat

local exports = {}

local sprint
sprint = function(o)
    local typ = type(o)
    if "string" == typ then
        return '"' .. o .. '"'
    elseif "table" == typ then
        local t, t1 = {"{"}, {}
        for k, v in pairs(o) do
            local te = {"["}
            if "string" == type(k) then
                te[#te + 1] = '"' .. k .. '"'
            else
                te[#te + 1] = tostring(k)
            end
            te[#te + 1] = "] = "
            te[#te + 1] = sprint(v, te)
            t1[#t1 + 1] = table_concat(te)
        end
        t[#t + 1] = table_concat(t1, ", ")
        t[#t + 1] = "}"
        return table_concat(t)
    else
        return tostring(o)
    end
end
exports.sprint = sprint

return exports
