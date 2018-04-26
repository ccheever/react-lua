local Object = require "classic"
local pi = require "pi"

local JSIterator = Object:extend()

function JSIterator:__tostring()
    return "JSIterator"
end

function JSIterator:new(iter)
    self._iter = iter
    self._i = 0
end

function JSIterator:next()
    local value = self._iter(self, self._i)
    self._i = self._i + 1
    local done = (value == nil)
    return {
        value = value,
        done = done
    }
end

function JSIterator:__call(...)
    local x = self:next()
    return x.value
end

it = JSIterator(ipairs{"a","b","c"})
pi(it:next())
pi(it:next())
pi(it:next())
pi(it:next())


return JSIterator
