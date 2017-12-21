local type, pairs, ipairs, setmetatable = type, pairs, ipairs, setmetatable
local log, ERR, DEBUG = ngx.log, ngx.ERR, ngx.DEBUG
local quote_sql_str = ngx.quote_sql_str
local string_format, string_gsub, table_concat = string.format, string.gsub, table.concat

local mysql = require "resty.mysql"
local mysql_new, mysql_set_timeout, mysql_connect = mysql.new, mysql.set_timeout, mysql.connect
local mysql_get_reused_times, mysql_set_keepalive = mysql.get_reused_times, mysql.set_keepalive
local mysql_query = mysql.query
local cjson = require "cjson.safe"
local json_encode = cjson.encode

local do_log_query = os.getenv("MYSQL_LOG_QUERY") == "true"

local exports = {}

local new = function(conf)
    local conn, err = mysql_new()
    if not conn then
        log(ERR, "resty.mysql.new failed: ", err)
        return nil, err
    end
    mysql_set_timeout(conn, conf.timeout or 1000)

    local ok, err, errno = mysql_connect(conn, conf)
    if not ok then
        log(ERR, "resty.mysql.connect failed: ", err, ": ", errno)
        return nil, err
    end

    local n, err = mysql_get_reused_times(conn)
    if not n then
        log(ERR, "resty.mysql.get_reused_times failed: ", err)
        n = 0
    end
    if 0 == n then
        local res, err = mysql_query(conn, "SET NAMES " .. (conf.encoding or "utf8"))
        if not res then
            log(ERR, "resty.mysql.query SET NAMES failed: ", err)
            return nil, err
        end
    end

    conn.pool_ttl = conf.pool_ttl or 10000
    conn.pool_size = conf.pool_size or 100
    return conn
end
exports.new = new

local set_keepalive = function(conn)
    local res, err = mysql_set_keepalive(conn, conn.pool_ttl, conn.pool_size)
    if err then
        log(ERR, "resty.mysql.set_keepalive failed: ", err)
    end
    return res
end
exports.set_keepalive = set_keepalive

local query = function(conn, ka, sql)
    local res, err, errno = mysql_query(conn, sql)
    if not res then
        log(ERR, "resty.mysql.query failed: ", err, ": ", errno, ": ", sql)
        return nil, err
    end
    if do_log_query then
        log(DEBUG, "[sql]: ", sql, " [res]: ", json_encode(res))
    end
    if ka then
        set_keepalive(conn)
    end
    return res, err
end
exports.query = query

local obj_set_keepalive = function(self)
    if self.tx then return nil, "in transaction" end
    return set_keepalive(self.conn)
end

local obj_query = function(self, ka, sql)
    local conn = self.conn
    if not self.tx then
        return query(conn, ka, sql)
    end

    if self.tx_err then return nil, "tx error before" end
    local res, err = query(conn, false, sql)
    if not res then
        self.tx_err = err or "tx error"
    end
    return res, err
end

local obj_transaction_inner = function(self, f, arg, ka)
    local conn = self.conn
    local err = f(self, arg) or self.tx_err
    if err then
        query(conn, false, "ROLLBACK;")
        return nil, err
    end

    local res, err = query(conn, ka, "COMMIT;")
    if not res then
        query(conn, false, "ROLLBACK;")
        return nil, err
    end
    return true
end

local obj_transaction = function(self, f, arg, ka)
    local conn = self.conn
    local res, err = query(conn, false, "START TRANSACTION;")
    if not res then return nil, err end

    self.tx = true
    res, err = obj_transaction_inner(self, f, arg, ka)
    self.tx, self.tx_err = false, nil
    return res, err
end

local obj_mt = {__index = {
    set_keepalive = obj_set_keepalive,
    query = obj_query,
    transaction = obj_transaction,
}}

exports.new_obj = function(conf)
    local conn, err = new(conf)
    if not conn then return nil, err end
    return setmetatable({conn = conn}, obj_mt)
end

-- sql("#{a}", {a = 7})
-- => 7
-- sql("#{a}", {a = { 7 }})
-- => '7'
-- sql("INSERT INTO t(#{as})", {as = { typ = "/", {"a", "b"} }})
-- => INSERT INTO t(a, b)
-- sql("VALUES (#{s})", {s = { typ = ",", {7, 8} }})
-- => VALUES ('7', '8')
-- sql("UPDATE t SET #{m}", {m = { typ = ":", {a = 7, b = 8} }})
-- => UPDATE t SET a = '7', b = '8'
-- sql("UPDATE t SET #{avs}", {avs = { typ = "=", {"a", "b"}, {7, 8} }})
-- => UPDATE t SET a = '7', b = '8'
-- sql("VALUES #{s}", {s = { typ = "(", {{7, 8}, {17, 18}} }})
-- => VALUES ('7', 8), ('17', 18)
exports.sql = function(s, args)
    for k, v in pairs(args) do
        if "table" == type(v) then
            local v1, typ = v[1], v.typ
            local vn
            if not typ then
                vn = quote_sql_str(v1)
            elseif "/" == typ then
                vn = table_concat(v1, ", ")
            elseif "," == typ then
                vn = {}
                for i, e in ipairs(v1) do
                    vn[i] = quote_sql_str(e)
                end
                vn = table_concat(vn, ", ")
            elseif ":" == typ then
                vn = {}
                local i = 1
                for k, e in pairs(v1) do
                    vn[i] = string_format("%s = %s", k, quote_sql_str(e))
                    i = i + 1
                end
                vn = table_concat(vn, ", ")
            elseif "=" == typ then
                vn = {}
                local v2 = v[2]
                for i, e in ipairs(v2) do
                    vn[i] = string_format("%s = %s", v1[i], quote_sql_str(e))
                end
                vn = table_concat(vn, ", ")
            elseif "(" == typ then
                vn = {}
                for i, e in ipairs(v1) do
                    local en = {}
                    for ie, ee in ipairs(e) do
                        en[ie] = quote_sql_str(ee)
                    end
                    vn[i] = table_concat(en, ", ")
                end
                vn = string_format("(%s)", table_concat(vn, "), ("))
            else
                vn = v1
            end
            args[k] = vn
        end
    end
    local out = string_gsub(s, "#%{([%w_]+)%}", args)
    return out
end

exports.null_to_nil = function(t)
    for k, v in pairs(t) do
        if "userdata" == type(v) then t[k] = nil end
    end
end

return exports
