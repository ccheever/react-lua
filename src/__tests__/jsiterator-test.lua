local JSIterator = require "jsiterator"
local pi = require "pi"

local li = ipairs({"a", "b", "C"})
local it = JSIterator(li)

for i, v in it do
    print(i, v)
end


