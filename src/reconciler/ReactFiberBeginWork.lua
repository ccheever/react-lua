local ReactTypeOfWork = require "ReactTypeOfWork"

local IndeterminateComponent = ReactTypeOfWork.IndeterminateComponent
local FunctionalComponent = ReactTypeOfWork.FunctionalComponent
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local CallComponent = ReactTypeOfWork.CallComponent
local CallHandlerPhase = ReactTypeOfWork.CallHandlerPhase
local ReturnComponent = ReactTypeOfWork.ReturnComponent
local ForwardRef = ReactTypeOfWork.ForwardRef
local Fragment = ReactTypeOfWork.Fragment
local Mode = ReactTypeOfWork.Mode
local ContextProvider = ReactTypeOfWork.ContextProvider
local ContextConsumer = ReactTypeOfWork.ContextConsumer

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local PerformedWork = ReactTypeOfSideEffect.PerformedWork
local ContentReset = ReactTypeOfSideEffect.ContentReset
local Ref = ReactTypeOfSideEffect.Ref

local ReactGlobalSharedState = require "ReactGlobalSharedState"
local ReactCurrentOwner = ReactGlobalSharedState.ReactCurrentOwner

local ReactFeatureFlags = require "ReactFeatureFlags"
local enableGetDerivedStateFromCatch = ReactFeatureFlags.enableGetDerivedStateFromCatch
local debugRenderPhaseSideEffects = ReactFeatureFlags.debugRenderPhaseSideEffects
local debugRenderPhaseSideEffectsForStrictMode = ReactFeatureFlags.debugRenderPhaseSideEffectsForStrictMode

local invariant = require "invariant"
local warning = require "warning"

local getComponentName = require "getComponentName"

local ReactDebugCurrentFiber = require "ReactDebugCurrentFiber"
local ReactDebugFiberPerf = require "ReactDebugFiberPerf"
--local cancelWorkTimer = ReactDebugFiberPerf.cancelWorkTimer

local ReactFiberClassComponent = require "ReactFiberClassComponent"

local ReactChildFiber = require "ReactChildFiber"
local mountChildFibers = ReactChildFiber.mountChildFibers
local reconcileChildFibers = ReactChildFiber.reconcileChildFibers
local cloneChildFibers = ReactChildFiber.cloneChildFibers

local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local processUpdateQueue = ReactFiberUpdateQueue.processUpdateQueue

local ReactFiberExpirationTime = require "ReactFiberExpirationTime"
local NoWork = ReactFiberExpirationTime.NoWork
local Never = ReactFiberExpirationTime.Never
local ReactTypeOfMode = require "ReactTypeOfMode"
local AsyncMode = ReactTypeOfMode.AsyncMode
local StrictMode = ReactTypeOfMode.StrictMode

local MAX_SIGNED_31_BIT_INT = require "maxSigned31BitInt"

local didWarnAboutBadClass
local didWarnAboutGetDerivedStateOnFunctionalComponent
local didWarnAboutStatelessRefs

if __DEV__ then
    didWarnAboutBadClass = {}
    didWarnAboutGetDerivedStateOnFunctionalComponent = {}
    didWarnAboutStatelessRefs = {}
end

local function reactFiberBeginWork(config, hostContext, legacyContext, newContext, hudrationContext, scheduleWork, computeExpirationForFiber)
    local shouldSetTextContent = config.shouldSetTextContent
    local shouldDeprioritizeSubtree = config.shouldDeprioritizeSubtree

    local pushHostContext = hostContext.pushHostContext
    local pushHostContainer = hostContext.pushHostContainer

    local pushProvider = newContext.pushProvider

    local getMaskedContext = legacyContext.getMaskedContext
    local getUnmaskedContext = legacyContext.getUnmaskedContext
    local hasLegacyContextChanged = legacyContext.hasContextChanged
    local pushLegacyContextProvider = legacyContext.pushContextProvider
    local pushTopLevelContextObject = legacyContext.pushTopLevelContextObject
    local invalidateContextProvider = legacyContext.invalidateContextProvider

    local enterHydrationState = hydrationContext.enterHydrationState
    local resetHydrationState = hydrationContext.resetHydrationState
    local tryToClaimNextHydratableInstance = hydrationContext.tryToClaimNextHydratableInstance

    --local _rfcc = ReactFiberClassComponent(legacyContext, scheduleWork, computeExpirationForFiber, memoizeProps, memoizeState)

    -- TODO: Continue this after ReactFiberClassComponent is ported

end

return reactFiberBeginWork