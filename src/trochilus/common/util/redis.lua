local pairs, rawget, tostring, setmetatable = pairs, rawget, tostring, setmetatable
local string_byte, string_format = string.byte, string.format
local os_clock = os.clock
local log, ERR, NOTICE, DEBUG = ngx.log, ngx.ERR, ngx.NOTICE, ngx.DEBUG

local redis = require "resty.redis"
local redis_new, redis_set_timeout, redis_connect = redis.new, redis.set_timeout, redis.connect
local redis_get_reused_times, redis_set_keepalive = redis.get_reused_times, redis.set_keepalive
local redis_select, redis_auth = redis.select, redis.auth
local cjson = require "cjson.safe"
local json_encode = cjson.encode

local do_log_query = os.getenv("REDIS_LOG_QUERY") == "true"

local exports = {}

local new = function(conf)
    local conn, err = redis_new()
    if not conn then
        log(ERR, "resty.redis.new failed: ", err)
        return nil, err
    end
    redis_set_timeout(conn, conf.timeout or 1000)

    local host, port, password, index = conf.host, conf.port, conf.password, conf.index or 0
    local ok, err = redis_connect(conn, host, port, {pool = host .. ":" .. port .. ":" .. index})
    if not ok then
        log(ERR, "resty.redis.connect failed: ", err)
        return nil, err
    end

    local n, err = redis_get_reused_times(conn)
    if not n then
        log(ERR, "resty.redis.get_reused_times failed: ", err)
        n = 0
    end
    if 0 == n then
        if password then
            local res, err = redis_auth(conn, password)
            if not res then
                log(ERR, "resty.redis.auth failed: ", err)
                return nil, err
            end
        end
        if 0 ~= index then
            local res, err = redis_select(conn, index)
            if not res then
                log(ERR, "resty.redis.select failed: ", err)
                return nil, err
            end
        end
    end

    conn.pool_ttl = conf.pool_ttl or 10000
    conn.pool_size = conf.pool_size or 100
    return conn
end
exports.new = new

local set_keepalive = function(conn)
    local res, err = redis_set_keepalive(conn, conn.pool_ttl, conn.pool_size)
    if err then
        log(ERR, "resty.redis.set_keepalive failed: ", err)
    end
    return res
end
exports.set_keepalive = set_keepalive

local query = function(conn, ka, com, ...)
    local f = conn[com]
    if not f then
        return nil, "invalid redis command"
    end
    local res, err = f(conn, ...)
    if not res then
        log(ERR, "resty.redis.query failed: ", err, ": ", com)
        return nil, err
    end
    if do_log_query then
        log(DEBUG, "[com]: ", com, " [res]: ", json_encode(res))
    end
    if ka then
        set_keepalive(conn)
    end
    return res, err
end
exports.query = query

local obj_set_keepalive = function(self)
    return set_keepalive(self.conn)
end

local obj_query = function(self, ka, com, ...)
    return query(self.conn, ka, com, ...)
end

local obj_mt = {__index = {
    set_keepalive = obj_set_keepalive,
    query = obj_query,
}}

exports.new_obj = function(conf)
    local conn, err = new(conf)
    if not conn then return nil, err end
    return setmetatable({conn = conn}, obj_mt)
end

local gen_cmd_from_map = function(cmd, key, map)
    local t, i, n = {0}, 2, 2
    for k, v in pairs(map) do
        k, v = tostring(k), tostring(v)
        t[i] = "$"
        t[i + 1] = #k
        t[i + 2] = "\r\n"
        t[i + 3] = k
        t[i + 4] = "\r\n"
        t[i + 5] = "$"
        t[i + 6] = #v
        t[i + 7] = "\r\n"
        t[i + 8] = v
        t[i + 9] = "\r\n"
        i = i + 10
        n = n + 2
    end
    t[1] = string_format("*%s\r\n$%s\r\n%s\r\n$%s\r\n%s\r\n", n, #cmd, cmd, #key, key)
    return t, n
end

exports.hmset_heavy = function(conn, key, map)
    local c = os_clock()
    local sock = rawget(conn, "_sock")
    if not sock then return nil, "sock is nil from red" end

    local t, narg = gen_cmd_from_map("hmset", key, map)
    if narg <= 2 then return true end
    log(NOTICE, "key: ", key, ", nvalue: ", (narg - 2) / 2)
    local res, err = sock:send(t)
    if not res then return nil, err end

    res, err = sock:receive()
    if not res then return nil, err end
    log(NOTICE, "dur: ", os_clock() - c)
    if string_byte(res, 1) ~= 43 then return nil, "recv not OK" end -- '+'
    return true
end

return exports
