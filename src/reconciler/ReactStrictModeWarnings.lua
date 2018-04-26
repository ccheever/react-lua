local getComponentName = require "getComponentName"
local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber
local ReactTypeOfMode = require "ReactTypeOfMode"
local StrictMode = ReactTypeOfMode.StrictMode
local lowPriorityWarning = require "lowPriorityWarning"
local warning = require "warning"

local ReactStrictModeWarnings = {
    discardPendingWarnings = function () end,
    flushPendingDeprecationWarnings = function () end,
    flushPendingUnsafeLifecycleWarnings = function () end,
    recordDeprecationWarnings = function(fiber, instance) end,
    recordUnsafeLifecycleWarnings = function (fiber, instance) end
}

if __DEV__ then
    -- TODO: Implement these things
end

return ReactStrictModeWarnings
