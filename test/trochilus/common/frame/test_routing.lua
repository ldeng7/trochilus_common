require("test.common").boot()

require("trochilus.common.util.luaunit.luaunit").mock_loaded_packages({
    ["xyz.controller.a1"] = {get = function(_) return 1 end},
    ["xyz.controller.api.v1.a2"] = {get = function(_) return 2 end},
    ["xyz.controller.api.v1.a3.set_i"] = {get = function(_) return 3 end},
    ["xyz.controller.a4"] = {get = function(_) return 4 end}
})

ngx.exit = function(status) return "exit " .. status end
ngx.req = {}
ngx.req.get_method = function() return "GET" end

local routing = require "trochilus.common.frame.routing"
local luaunit = require "ext.github.bluebird75.luaunit.luaunit"


test_route = function()
    local routes = {
        "/a1",
        "/api/v1/a2",
        "/api/v1/a3/:id/set_i/:i",
        "/:x/a4"
    }
    routing.on_init_worker(routes, "xyz")

    ngx.var, ngx.ctx = {}, {}
    ngx.var.uri = "/a1"
    luaunit.assertEquals(routing.route(ngx), 1)

    ngx.var.uri = "/api/v1/a2"
    luaunit.assertEquals(routing.route(ngx), 2)

    ngx.var.uri = "/api/v1/a3/7/set_i/8"
    luaunit.assertEquals(routing.route(ngx), 3)
    luaunit.assertEquals(ngx.ctx[routing.CTX_KEY_ROUTING_ARGS].id, "7")
    luaunit.assertEquals(ngx.ctx[routing.CTX_KEY_ROUTING_ARGS].i, "8")

    ngx.var.uri = "/_b1_/a4"
    luaunit.assertEquals(routing.route(ngx), 4)
    luaunit.assertEquals(ngx.ctx[routing.CTX_KEY_ROUTING_ARGS].x, "_b1_")

    ngx.var.uri = "/none"
    luaunit.assertEquals(routing.route(ngx), "exit 404")
end

luaunit.LuaUnit.run()
