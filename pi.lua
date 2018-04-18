local inspect = require "inspect"
local function pi(...)
    print(inspect.inspect(...))
end
return pi
