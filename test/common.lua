return {
    boot = function()
        package.path = "./src/?.lua;./?.lua;"
        package.cpath = ""
        ngx = require "trochilus.common.util.luaunit.mock.ngx.ngx"
    end
}
