local ReactGlobalSharedState = require "ReactGlobalSharedState"
local ReactDebugCurrentFrame = ReactGlobalSharedState.ReactDebugCurrentFrame

local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber
local getComponentName = require "getComponentName"

local function getCurrentFiberOwnerName() 
    if __DEV__ then
        local fiber = ReactDebugCurrentFiber.current
        if fiber == nil then
            return nil
        end
        local owner = fiber._debugOwner
        if owner ~= nil then
            return getComponentName(owner)
        end
        return nil
    end
end

local function getCurrentFiberStackAddendum()
    if __DEV__ then
        local fiber = ReactDebugCurrentFiber.current
        if fiber == nil then
            return nil
        end

        -- Safe because if current fiber exists, we are reconciling,
        -- and it is guaranteed to be the work-in-progress version.
        return getStackAddendumByWorkInProgressFiber(fiber)
    end
    return nil
end

local function resetCurrentFiber()
    ReactDebugCurrentFrame.getCurrentStack = nil
    ReactDebugCurrentFiber.current = nil
    ReactDebugCurrentFiber.phase = nil
end

local function setCurrentFiber(fiber)
    ReactDebugCurrentFrame.getCurrentStack = getCurrentFiberStackAddendum
    ReactDebugCurrentFiber.current = fiber
    ReactDebugCurrentFiber.phase = nil
end

local function setCurrentPhase(phase)
    ReactDebugCurrentFiber.phase = phase
end

local ReactDebugCurrentFiber = {
    current = nil,
    phase = nil,
    resetCurrentFiber = resetCurrentFiber,
    setCurrentFiber = setCurrentFiber,
    setCurrentPhase = setCurrentPhase,
    getCurrentFiberOwnerName = getCurrentFiberOwnerName,
    getCurrentFiberStackAddendum = getCurrentFiberStackAddendum
}

return ReactDebugCurrentFiber