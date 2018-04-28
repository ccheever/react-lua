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
local isCommitting = false
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

    if (isCommitting and labelsInCurrentcommit[label] ~= nil) then
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

local function shouldIgnoreFiber(fiber)
    -- Host components should be skipped in the timeline
    -- We could check typeof fiber.type, but does this work with RN?
    local t = fiber.tag
    if t == HostRoot or
            t == HostComponent or
            t == HostText or
            t == HostPortal or
            t == CallComponent or
            t == ReturnComponent or
            t == Fragment or 
            t == ContextProvider or
            t == ContextConsumer or 
            t == Mode then
        return true
    else
        return false
    end
end

local function clearPendingPhaseMeasurement()
    if currentPhase ~= nil and currentPhaseFiber ~= nil then
        clearFiberMark(currentPhaseFiber, currentPhase)
    end
    currentPhaseFiber = nil
    currentPhase = nil
    hasScheduledUpdateInCurrentPhase = false
end

local function pauseTimers()
    -- Stops all currently active measurements so that they can be resumed
    -- if we continue in a later deferred loop from the same unit of work.
    local fiber = currentFiber

    while fiber do
        if fiber._debugIsCurrentlyTiming then
            endFiberMark(fiber, nil, nil)
        end
        fiber = fiber["return"]
    end
end

local function resumeTimersRecursively(fiber)
    if fiber["return"] ~= nil then
        resumeTimersRecursively(fiber["return"])
    end
    if fiber._debugIsCurrentlyTiming then
        beginFiberMark(fiber, nil)
    end
end

local function resumeTimers()
    -- Resumes all measurements that were active during the last deferred loop
    if currentFiber ~= nil then
        resumeTimersRecursively(currentFiber)
    end
end

local function recordEffect()
    if enableUserTimingAPI then
        effectCountInCurrentCommit = effectCountInCurrentCommit + 1
    end
end

local function recordScheduleUpdate()
    if enableUserTimingAPI then
        if isCommitting then
            hasScheduledUpdateInCurrentCommit = true
        end
        if (
            currentPhase ~= nil and
            currentPhase ~= "componentWillMount" and
            currentPhase ~= "componentWillReceiveProps"
        ) then
            hasScheduledUpdateInCurrentPhase = true
        end
    end
end

local function startRequestCallbackTimer()
    if enableUserTimingAPI then
        if supportsUserTiming and not isWaitingForCallback then
            isWaitingForCallback = true
            beginMark("(Waiting for async callback...)")
        end
    end
end

local function stopRequestCallbackTimer(didExpire, expirationTime)
    if enableUserTimingAPI then
        if supportsUserTiming then
            isWaitingForCallback = false
            local warning = didExpire and "React was blocked by main thread" or nil
            endMark(
                "(Waiting for async callback... will force flush in " .. expirationTime .. "ms)",
                "(Waiting for async callback...)",
                warning
            )
        end
    end
end

local function startWorkTimer(fiber)
    if enableUserTimingAPI then
        if (not supportsUserTiming) or shouldIgnoreFiber(fiber) then
            return
        end
        -- If we pause, this is the fiber to unwind from
        currentFiber = fiber
        if not beginFiberMark(fiber, nil) then
            return
        end
        fiber._debugIsCurrentlyTiming = true
    end
end


local function cancelWorkTimer(fiber)
    if enableUserTimingAPI then
        if (not supportsUserTiming) or shouldIgnoreFiber(fiber) then
            return
        end
        -- Remember we shouldn't complete measurement for this fiber.
        -- Otherwise flamechart will be deep even for small updates
        fiber._debugIsCurrentlyTiming = false
        clearFiberMark(fiber, nil)
    end
end

local function stopWorkTimer(fiber)
    if enableUserTimingAPI then
        if (not supportsUserTiming) or shouldIgnoreFiber(fiber) then
            return
        end
        -- If we pause, its parent is the fiber to unwind from
        currentFiber = fiber["return"]
        if not fiber._debugIsCurrentlyTiming then
            return
        end
        fiber._debugIsCurrentlyTiming = false
        endFiberMark(fiber, nil, nil)
    end
end

local function stopFailedWorkTimer(fiber)
    if enableUserTimingAPI then
        if (not supportsUserTiming) or shouldIgnoreFiber(fiber) then
            return
        end

        -- If we pause, its parent is the fiber to unwind from
        currentFiber = fiber["return"]
        if not fiber._debugIsCurrentlyTiming then
            return
        end
        fiber._debugIsCurrentlyTiming = false
        local warning = "An error was thrown inside this error boundary"
        endFiberMark(fiber, nil, warning)
    end
end

local function startPhaseTimer(fiber, phase)
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        clearPendingPhaseMeasurement()
        if not beginFiberMark(fiber, phase) then
            return
        end
        currentPhaseFiber = fiber
        currentPhase = phase
    end
end

local function stopPhaseTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        if currentPhase ~= nil and currentPhaseFiber ~= nil then
            local warning = hasScheduledUpdateInCurrentPhase and "Schedule a cascading update" or nil
            endFiberMark(currentPhaseFiber, currentPhase, warning)
        end
        currentPhase = nil
        currentPhaseFiber = nil
    end
end

local function startWorkLoopTimer(nextUnitOfWork)
    if enableUserTimingAPI then
        currentFiber = nextUnitOfWork
        if not supportsUserTiming then
            return
        end
        commitCountInCurrentWorkLoop = 0
        -- This is a top level call.
        -- Any other measurements are performed within
        beginMark("(React Tree Reconciliation)")
        -- Resume any measurements that were in progress during the last loop
        resumeTimers()
    end
end

local function stopWorkLoopTimer(interruptedBy, didCompleteRoot) 
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        local warning = nil
        if interruptedBy ~= nil then
            if interruptedBy.tag == HostRoot then
                warning = "A top-level update interrupted the previous render"
            else
                local componentName = getComponentName(interruptedBy) or "Unknown"
                warning = "An update to " .. componentName .. " interrupted the previous render"
            end
        elseif commitCountInCurrentWorkLoop > 1 then
            warning = "There were cascading updates"
        end
        commitCountInCurrentWorkLoop = 0
        local label = didCompleteRoot and "(React Tree Recocniliation: Completed Root)" or "(React Tree Reconciliation: Yielded)"
        -- Pause any measurements until the next loop.
        pauseTimers()
        endMark(label, "(React Tree Reconciliation)", warning)
    end
end

local function startCommitTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return 
        end
        isCommitting = true
        hasScheduledUpdateInCurrentCommit = false
        labelsInCurrentcommit = {} -- Set.clear()
        beginMark("(Committing changes)")
    end
end

local function stopCommitTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end

        local warning = nil
        if hasScheduledUpdateInCurrentCommit then
            warning = "Lifecycle hook scheduled a cascading update"
        elseif commitCountInCurrentWorkLoop > 0 then
            warning = "Caused by a cascading update in earlier commit"
        end
        hasScheduledUpdateInCurrentCommit = false
        commitCountInCurrentWorkLoop = commitCountInCurrentWorkLoop + 1
        isCommitting = false
        labelsInCurrentcommit = {} -- Set.clear()

        endMark("(Committing Changes)", "(Committing Changes)", warning)
    end
end

local function startCommitSnapshotEffectsTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        effectCountInCurrentCommit = 0
        beginMark("(Committing Snapshot Effects)")
    end
end

local function stopCommitSnapshotEffectsTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        local count = effectCountInCurrentCommit
        effectCountInCurrentCommit = 0
        endMark(
            "(Committing Snapshot Effects: " .. count .. " Total)",
            "(COmmitting Snapshot Effects)",
            nil
        )
    end
end

local function startCommitHostEffectsTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return 
        end
        effectCountInCurrentCommit = 0
        beginMark("(Committing Host Effects)")
    end
end

local function stopCommitHostEffectsTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        local count = effectCountInCurrentCommit
        effectCountInCurrentCommit = 0
        endMark(
            "(Comitting Host Effects: " .. count .. " Total)",
            "(Committing Host Effects)",
            nil
        )
    end
end

local function startcommitLifeCyclesTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        effectCountInCurrentCommit = 0
        beginMark("(Calling Lifecycle Methods")
    end
end

local function stopCommitLifeCyclesTimer()
    if enableUserTimingAPI then
        if not supportsUserTiming then
            return
        end
        local count = effectCountInCurrentCommit
        effectCountInCurrentCommit = 0
        endMark(
            "(Calling Lifecycle Methods: " .. count .. " Total)",
            "(Calling Lifecycle Methods)",
            nil
        )
    end
end

return {
    recordEffect = recordEffect,
    recordScheduleUpdate = recordScheduleUpdate,
    startRequestCallbackTimer = startRequestCallbackTimer,
    stopRequestCallbackTimer = stopRequestCallbackTimer,
    startWorkTimer = startWorkTimer,
    cancelWorkTimer = cancelWorkTimer,
    stopWorkTimer = stopWorkTimer,
    stopFailedWorkTimer = stopFailedWorkTimer,
    startPhaseTimer = startPhaseTimer,
    stopPhaseTimer = stopPhaseTimer,
    startWorkLoopTimer = startWorkLoopTimer,
    stopWorkLoopTimer = stopWorkLoopTimer,
    startCommitTimer = startCommitTimer,
    stopCommitTimer = stopCommitTimer,
    startCommitSnapshotEffectsTimer = startCommitSnapshotEffectsTimer,
    stopCommitSnapshotEffectsTimer = stopCommitSnapshotEffectsTimer,
    startCommitHostEffectsTimer = startCommitHostEffectsTimer,
    stopCommitHostEffectsTimer = stopCommitHostEffectsTimer,
    startcommitLifeCyclesTimer = startcommitLifeCyclesTimer,
    stopCommitLifeCyclesTimer = stopCommitLifeCyclesTimer
}
