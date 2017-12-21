local math_abs = math.abs
local shared = ngx.shared
local ngx_now = ngx.now

local exports = {}

function exports.new(shm_key, key, rate, burst)
    local dict = shared[shm_key]
    if not dict then return nil, "shm not found" end
    local self = {
        dict = dict,
        excess_key = "backet:e:" .. key,
        last_key = "backet:l:" .. key,
        rate = rate,
        burst = burst,
    }
    return self
end

function exports.check_in(self)
    local now = ngx_now()
    local dict = self.dict
    local rate = self.rate

    local excess = dict:get(self.excess_key)
    if excess then
        local last = dict:get(self.last_key)
        local elapsed = math_abs(now - last)
        excess = excess - rate * elapsed + 1
        if excess < 0 then excess = 0 end
        if excess > self.burst then return nil end
    else
        excess = 0
    end

    dict:set(self.excess_key, excess)
    dict:set(self.last_key, now)
    return excess / rate
end

return exports
