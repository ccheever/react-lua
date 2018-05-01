local ReactCapturedValue = require "ReactCapturedValue"
local createCapturedValue = ReactCapturedValue.createCapturedValue
local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local ensureUpdateQueues = ReactFiberUpdateQueue.ensureUpdateQueues

local ReactTypeOfWork = require "ReactTypeOfWork"
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostPortal = ReactTypeOfWork.HostPortal
local ContextProvider = ReactTypeOfWork.ContextProvider

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local NoEffect = ReactTypeOfSideEffect.NoEffect
local DidCapture = ReactTypeOfSideEffect.DidCapture
local ShouldCapture = ReactTypeOfSideEffect.ShouldCapture

local ReactFeatureFlags = require "ReactFeatureFlags"
local enableGetDerivedStateFromCatch = ReactFeatureFlags.enableGetDerivedStateFromCatch

local bit = require "bit"

local function ReactFiberUnwindWork(
    hostContext,
    legacyContext,
    newContext,
    scheduleWork,
    isAlreadyFailedLegacyErrorBoundary
)
    local popHostContainer = hostContext.popHostContainer
    local popHostContext = hostContext.popHostContext

    local  popLegacyContextProvider = legacyContext.popContextProvider
    local  popTopLevelLegacyContextObject = legacyContext.popTopLevelContextObject

    local popProvider = newContext.popProvider

    local function throwException(
        returnFiber,
        sourceFiber,
        rawValue
    )
        -- The source fiber did not complete.
        sourceFiber.effectTag = bit.bor(sourceFiber.effectTag, Incomplete)
        -- Its effect list is no longer valid.
        sourceFiber.firstEffect = nil
        sourceFiber.lastEffect = nil

        local value = createCapturedValue(rawValue, sourceFiber)

        local workInProgress = returnFiber
        repeat
            for __switch = 1, 1 do
                local tag = workInProgress.tag
                if tag == HostRoot then
                    -- Uncaught error
                    local errorInfo = value
                    ensureUpdateQueues(workInProgress)
                    local updateQueue = workInProgress.updateQueue
                    updateQueue.capturedValues = {errorInfo}
                    workInProgress.effectTag = bit.bor(workInProgress.effectTag, ShouldCapture)
                    return
                elseif tag == ClassComponent then
                    -- Capture and retry
                    local ctor = workInProgress.type
                    local instance = workInProgress.stateNode
                    if (
                        bit.band(workInProgress.effectTag, DidCapture) == NoEffect and
                        (type(ctor.getDerivedStateFromCatch) == "function" and 
                            enableGetDerivedStateFromCatch) or 
                            (
                                instance ~= nil and
                                type(instance.componentDidCatch) == "function" and
                                not isAlreadyFailedLegacyErrorBoundary(instance)
                            )
                    ) then
                        ensureUpdateQueues(workInProgress)
                        local updateQueue = workInProgress.updateQueue
                        local capturedValues = updateQueue.capturedValues
                        if capturedValues == nil then
                            updateQueue.capturedValues = {value}
                        else
                            table.insert(capturedValues, value)
                        end
                        workInProgress.effectTag = bit.bor(workInProgress.effectTag, ShouldCapture)
                        return
                    end
                end
            end
            workInProgress = workInProgress["return"]
        until workInProgress == nil
    end

    local function unwindWork(workInProgress)

        local tag = workInProgress.tag
        if tag == ClassComponent then
            popLegacyContextProvider(workInProgress)
            local effectTag = workInProgress.effectTag
            if bit.band(effectTag, ShouldCapture) > 0 then
                workInProgress.effectTag = bit.bor(bit.band(effectTag, bit.bnot(ShouldCapture)), DidCapture)
                return workInProgress
            end
            return nil
        elseif tag == HostRoot then
            popHostContainer(workInProgress)
            popTopLevelContextObject(workInProgress)
            local effectTag = workInProgress.effectTag
            if bit.band(effectTag, ShouldCapture) > 0 then
                workInProgress.effectTag = bit.bor(bit.band(effectTag, bit.bnot(ShouldCapture)), DidCapture)
                return workInProgress
            end
            return nil
        elseif tag == HostComponent then
            popHostContext(workInProgress)
            return nil
        elseif tag == HostPortal then
            popHostContainer(workInProgress)
            return nil
        elseif tag == ContextProvider then
            popProvider(workInProgress)
            return nil
        else
            return nil
        end
    end

    local function unwindInterruptedWork(interruptedWork)
        for __switch = 1, 1 do
            local tag = interruptedWork.tag
            if tag == ClassComponent then
                popLegacyContextProvider(interruptedWork)
                break
            elseif tag == HostRoot then
                popHostContainer(interruptedWork)
                popTopLevelLegacyContextObject(interruptedWork)
                break
            elseif tag == HostComponent then
                popHostContainer(interruptedWork)
                break
            elseif tag == HostPortal then
                popHostContainer(interruptedWork)
                break
            elseif tag == ContextProvider then
                popProvider(interruptedWork)
                break
            else
                break
            end
        end
    end

    return {
        throwException = throwException,
        unwindWork = unwindWork,
        unwindInterruptedWork = unwindInterruptedWork
    }

end

return ReactFiberUnwindWork