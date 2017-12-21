local ffi = require "ffi"
ffi.cdef[[
unsigned int sleep(unsigned int seconds);
]]

local exports = {}

exports.mock_loaded_packages = function(packages)
    local cb = function(name)
        return packages[name]
    end
    local f = function(name)
        if packages[name] then return cb end
        return nil
    end
    table.insert(package.loaders, 1, f)
end

exports.sleep = function(sec)
    ffi.C.sleep(sec)
end

return exports
