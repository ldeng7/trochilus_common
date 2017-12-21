local io_open = io.open
local ngx_prefix = ngx.config.prefix
local ffi = require "ffi"
ffi.cdef[[
    int getpid();
    int gethostname(char *s, size_t len);
    int kill(int pid, int sig);
]]

local exports = {}

exports.master_pid = function()
    local f = io_open(ngx_prefix() .. "/logs/nginx.pid", "r")
    if not f then return nil end
    local id = f:read("*n")
    f:close()
    return id
end

exports.pid = function()
    return ffi.C.getpid()
end

exports.hostname = function()
    local s = ffi.new("char[128]")
    if -1 == ffi.C.gethostname(s, 128) then
        return nil
    end
    return ffi.string(s)
end

exports.send_hup = function(pid)
    ffi.C.kill(pid, 1)
end

exports.send_quit = function(pid)
    ffi.C.kill(pid, 3)
end

return exports
