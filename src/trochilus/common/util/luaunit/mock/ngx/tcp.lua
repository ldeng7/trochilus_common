local socket = require("trochilus.common.util.luaunit.mock.ext.github.diegonehab.luasocket.socket")

local vt = {}

vt.connect = function(self, host, port, _)
    local conn = socket.connect4(host, port)
    self._conn = conn
    return (conn and 1) or nil
end

vt.send = function(self, data)
    local sock = self._conn
    if "table" == type(data) then
        data = table.concat(data)
    end
    local n = sock:send(data)
    return (n >= 0 and n) or nil
end

vt.receive = function(self, size)
    local sock = self._conn
    local data = sock:receive(size)
    return data
end

vt.getreusedtimes = function(self)
    return 0
end

vt.settimeout = function(self, time)
    return true
end

vt.setkeepalive = function(self, ...)
    local conn = self._conn
    conn:close()
    self._conn = nil
    return true
end

vt.close = function(self)
    local conn = self._conn
    conn:close()
    self._conn = nil
    return true
end

local tcp = function()
    return setmetatable({}, {__index = vt})
end

local exports = {}

exports.mixin = function(ngx)
    if not ngx.socket then ngx.socket = {} end
    ngx.socket.tcp = tcp
end

return exports
