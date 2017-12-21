package.path = os.getenv("OPRROOT") .. "/lualib/?.lua;" .. (package.path or "")
package.cpath = os.getenv("OPRROOT") .. "/lualib/?.so;" .. (package.cpath or "")

local ngx = {}

local p = "trochilus.common.util.luaunit.mock.ngx."
for _, pp in ipairs({"etc", "lmn", "log", "tcp", "re"}) do
    require(p .. pp).mixin(ngx)
end

return ngx
