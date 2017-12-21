local unpack = unpack
local shared, ngx_time = ngx.shared, ngx.time
local log, ERR = ngx.log, ngx.ERR
local lock = require "resty.lock"
local LOCK_OPTS = {
    exptime = 0.05,
    timeout = 0.04
}


local exports = {}

local STATE_NORMAL  = 0
local STATE_FLOP    = 1
local STATE_RECOVER = 2
exports.STATE_NORMAL  = STATE_NORMAL
exports.STATE_FLOP    = STATE_FLOP
exports.STATE_RECOVER = STATE_RECOVER

exports.new = function(shm_key, key, hit_intl, hit_thres, flop_intl, rc_thres, rc_thres_suc)
    local dict = shared[shm_key]
    if not dict then
        log(ERR, "shm not found, key: ", shm_key)
        return nil
    end
    return {
        shm_key = shm_key,
        dict = dict,
        lock_key = "baffle:l:" .. key,
        state_key = "baffle:s:" .. key,

        tick_key = "baffle:t:" .. key,
        hit_key = "baffle:h:" .. key,
        hit_intl = hit_intl,
        hit_thres = hit_thres,
        flop_intl = flop_intl,
        rc_rest_key = "baffle:rr:" .. key,
        rc_hit_key = "baffle:rh:" .. key,
        rc_suc_key = "baffle:rs:" .. key,
        rc_thres = rc_thres,
        rc_thres_suc = rc_thres_suc
    }
end

local locked_method = function(self, method, args)
    local lck = lock.new(nil, self.shm_key, LOCK_OPTS)
    lock.lock(lck, self.lock_key)
    local res = {method(self, args)}
    lock.unlock(lck)
    return unpack(res)
end

local check_in = function(self, _)
    local now = ngx_time()
    local dict = self.dict
    local allowed = true
    local state, state_new = dict:get(self.state_key), nil

    if STATE_FLOP == state then
        allowed = false
        local tick = dict:get(self.tick_key)
        if now >= tick then
            allowed = true
            if self.rc_thres then
                state_new = STATE_RECOVER
                dict:set(self.rc_rest_key, self.rc_thres)
                dict:set(self.rc_hit_key, 0)
                dict:set(self.rc_suc_key, 0)
            else
                state_new = STATE_NORMAL
            end
            dict:delete(self.tick_key)
        end

    elseif STATE_RECOVER == state then
        local rc_rest = dict:get(self.rc_rest_key)
        if rc_rest > 0 then
            dict:incr(self.rc_rest_key, -1)
        else
            allowed = false
        end

    elseif not state then
        state, state_new = STATE_NORMAL, STATE_NORMAL
    end

    if state_new then
        dict:set(self.state_key, state_new)
    end
    return allowed, state_new or state, state
end

exports.check_in = function(self)
    return locked_method(self, check_in, nil)
end

local check_out = function(self, args)
    local now = ngx_time()
    local suc, state_in = args[1], args[2]
    local dict = self.dict
    local state, state_new = dict:get(self.state_key), nil
    if state_in ~= state then return state_in, state_in end

    if STATE_NORMAL == state then
        if not suc then
            local hit
            local ok = dict:add(self.hit_key, 1, self.hit_intl)
            if ok then
                hit = 1
            else
                hit = dict:incr(self.hit_key, 1)
            end

            if hit >= self.hit_thres then
                state_new = STATE_FLOP
                dict:set(self.tick_key, now + self.flop_intl)
                dict:delete(self.hit_key)
            end
        end

    elseif STATE_RECOVER == state then
        local rc_hit = dict:incr(self.rc_hit_key, 1)
        if suc then dict:incr(self.rc_suc_key, 1) end

        if self.rc_thres == rc_hit then
            local rc_suc = dict:get(self.rc_suc_key)
            if (rc_suc or 0) >= self.rc_thres_suc then
                state_new = STATE_NORMAL
            else
                state_new = STATE_FLOP
                dict:set(self.tick_key, now + self.flop_intl)
            end
        end
    end

    if state_new then
        dict:set(self.state_key, state_new)
    end
    return state_new or state, state
end

exports.check_out = function(self, suc, state)
    return locked_method(self, check_out, {suc, state})
end

return exports
