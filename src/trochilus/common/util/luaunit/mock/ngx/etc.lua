local exports = {}

exports.mixin = function(ngx)
    ngx.config = {}
    ngx.config.ngx_lua_version = 99999

    ngx.time = os.time
    ngx.now = os.time
    ngx.null = require("cjson.safe").null

    ngx.worker = {}
    ngx.worker.id = function() return 1 end
    ngx.sleep = function() return end
    ngx.timer = {}
    ngx.timer.at = function(...) return true end
end

return exports
