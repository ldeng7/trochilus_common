Name
====

trochilus_common

Synopsis
========

```lua
-- test/conf.lua

local exports = {}

exports.redis = {
    host = "127.0.0.1",
    port = 6379,
    index = 2
}

exports.mysql = {
    host = "127.0.0.1",
    port = 3306,
    user = "root",
    password = "abcabc",
    database = "test"
}

return exports
```
