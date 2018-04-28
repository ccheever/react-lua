local assign = require "assign"
local pi = require "pi"

local object1 = {
    a = 1,
    b = 2,
    c = 3
}

local object2 = assign({c = 4, d = 5}, object1)
pi(object2.c, object2.d)

local x = assign({}, {a = 1, b = 2, c = 3}, {"a", "b", "c"}, {b = 4, c = 5, d = 6})
pi(x)