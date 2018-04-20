local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber

function createCapturedValue(value, source)
    -- If the value is an error, call this function immediately after it is 
    -- throw so the stack is accurate
    return {
        value = value,
        source = source,
        stack = getStackAddendumByWorkInProgressFiber(source)
    }
end

return {
    createCapturedValue = createCapturedValue
}