local inspect = require "inspect"
local function pi(...)
    local t = {...}
    local it = {}
    local m = 0
    for i, _ in pairs(t) do
        if i > m then 
            m = i
        end
    end
    for i = 1, m do
        local x = t[i]
        it[i] = inspect.inspect(x)
    end
    print(unpack(it))
end
return pi
