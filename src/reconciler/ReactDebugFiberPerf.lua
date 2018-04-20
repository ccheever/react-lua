local ReactFeatureFlags = require "ReactFeatureFlags"
local enableUserTimingAPI = ReactFeatureFlags.enableUserTimingAPI

local getComponentName = require "getComponentName"
local ReactTypeOfWork = require "ReactTypeOfWork"
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local CallComponent = ReactTypeOfWork.CallComponent
local ReturnComponent = ReactTypeOfWork.ReturnComponent
local Fragment = ReactTypeOfWork.Fragment
local ContextProvider = ReactTypeOfWork.ContextProvider
local ContextConsumer = ReactTypeOfWork.ContextConsumer
local Mode = ReactTypeOfWork.Mode

local reactEmoji = "⚛"
local warningEmoji = "⛔"

local supportsUserTiming = false

-- Keep track of the current fiber so that we know the path to unwind on pause.
-- TODO: this looks the same as nextUnitOfWork in scheduler. Can we unify?
local currentFiber = nil

-- If we're in the middle of user code, which fiber and method is it?
-- Reusing `currentFiber` would be confusing for this because user code fiber
-- can change during commit phase too, but we don't need to unwind it( since
-- lifecycles in the commit phase don't resemble a tree).
local currentPhase = nil
local currentPhaseFiber = nil

-- Did lifecycle hook schedule an updater? This is often a performance problem,
-- so we will keep track of it, and include it in the report.
-- Track commits caused by cascading updates
local isComitting = false
local hasScheduledUpdateInCurrentCommit = false
local hasScheduledUpdateInCurrentPhase = false
local commitCountInCurrentWorkLoop = 0
local effectCountInCurrentCommit = 0
local isWaitingForCallback = false

-- During commits, we only show a measurement once per method name
-- to avoid stretching the commit phase with measurement overhead
local labelsInCurrentcommit = {}

local function formatMarkName(markName)
    return reactEmoji .. " " .. markName
end

local function formatLabel(label, warning)
    local prefix = (warning and warningEmoji or reactEmoji) .. " "
    local suffix = warning and (" Warning: " .. warning) or ""
    return prefix .. label .. suffix
end

local function beginMark(markName) 
    -- performance.mark(formatMarkName(markName))
end

local function clearMark(markName)
    -- performance.clearMarks(formatMarkName(markName))
end

local function endMark(label, markName, warning)
    local formattedMarkName = formatMarkName(markName)
    local formattedLabel = formatLabel(label, warning)

    -- performance stuff ...
end

local function getFiberMarkName(label, debugID)
    return label .. " (#" .. debugID .. ")"
end

local function getFiberLabel(componentName, isMounted, phase)
    if phase == nil then
        -- These are composite component total time measurements
        return componentName .. " [" .. (isMounted and "updated" or "mount") .. "]"
    else
        -- Composite component methods
        return componentName .. "." .. phase
    end
end

local function beginFiberMark(fiber, phase)
    local componentName = getComponentName(fiber) or "Unknown"
    local debugID = fiber._debugID
    local isMounted = fiber.alternate ~= nil
    local label = getFiberLabel(componentName, isMounted, phase)

    if (isComitting and labelsInCurrentcommit[label] ~= nil) then
        -- During the commit phase, we don't show duplicate labels
        -- because there is a fixed overhead for every measurement,
        -- and we don't want to stretch the commit phase beyond
        -- necessary
        return false
    end

    labelsInCurrentcommit[label] = true

    local markName = getFiberMarkName(label, debugID)
    beginMark(markName)
    return true

end

local function clearFiberMark(fiber, phase, warning)
    local componentName = getComponentName(fiber) or "Unknown"
    local debugID = fiber._debugID
    local isMounted = fiber.alternate ~= nil
    local label = getFiberLabel(componentName, isMounted, phase)
    local markName = getFiberMarkName(label, debugID)
    clearMark(label, markName, warning)
end

local function endFiberMark(fiber, phase, warning)
    local componentName = getComponentName(fiber) or "Unknown"
    local debugID = fiber._debugID
    local isMounted = fiber.alternate ~= nil
    local label = getFiberLabel(componentName, isMounted, phase)
    local markName = getFiberMarkName(label, debugID)
    endMark(label, markName, warning)
end


-- TODO: Maybe finish this file or maybe don't. We can't really use it in Lua