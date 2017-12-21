local re_match, os_time = ngx.re.match, os.time

local exports = {}

exports.parse_time = function(s, regex)
    if not regex then
        regex = "(?<y>\\d+)-(?<M>\\d+)-(?<d>\\d+) (?<h>\\d+):(?<m>\\d+):(?<s>\\d+)"
    end
    local m = re_match(s, regex, "jo")
    if not m then return 0 end
    return os_time({year = m.y, month = m.M, day = m.d, hour = m.h, min = m.m, sec = m.s})
end

return exports
