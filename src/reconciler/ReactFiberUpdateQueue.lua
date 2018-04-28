local ReactFeatureFlags = require "ReactFeatureFlags"
local debugRenderPhaseSideEffects = ReactFeatureFlags.debugRenderPhaseSideEffects
local debugRenderPhaseSideEffectsForStrictMode = ReactFeatureFlags.debugRenderPhaseSideEffectsForStrictMode
local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local CallbackEFfect = ReactTypeOfSideEffect.Callback
local ReactTypeOfWork = require "ReactTypeOfWork"
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostRoot = ReactTypeOfWork.HostRoot
local invariant = require "invariant"
local warning = require "warning"
local ReactTypeOfMode = require "ReactTypeOfMode"
local StrictMode = ReactTypeOfMode.StrictMode

local ReactFiberExpirationTime = require "ReactFiberExpirationTime"
local NoWork = ReactFiberExpirationTime.NoWork

local bit = require "bit"
local assign = require "assign"

local didWarnInsideUpdate

if __DEV__ then
    didWarnInsideUpdate = false
end

local function createUpdateQueue(baseState)
    local queue = {
        baseState = baseState,
        expirationTime = NoWork,
        first = nil,
        last = nil,
        callbackList = nil,
        hasForceUpdate = false,
        isInitialized = false,
        capturedValues = nil
    }
    if __DEV__ then
        queue.isProcessing = false
    end
    return queue
end

local function insertUpdateIntoQueue(
    queue,
    update
)
    -- Append the update to the end of the list
    if queue.last == nil then
        -- Queue is empty
        queue.last = update
        queue.first = queue.last
    else
        queue.last.next = update
        queue.last = update
    end
    if queue.expirationTime == NoWork or queue.expirationTime > update.expirationTime then
        queue.expirationTime = update.expirationTime
    end
end

local q1
local q2
local function ensureUpdateQueues(fiber)
    q1 = nil
    q2 = nil

    -- We'll have at least one and at most two distinct update queues
    local alternateFiber = fiber.alternate
    local queue1 = fiber.updateQueue
    if queue1 == nil then
        -- TODO: We don't know what the base state will be until we begin work.
        -- It depends on which fiber is the next current. Initialize with an empty
        -- base state, then set to the memoizedState when rendering. Not super
        -- happy with this approach.
        fiber.updateQueue = createUpdateQueue(nil)
        queue1 = fiber.updateQueue
    end

    local queue2
    if alternateFiber ~= nil then
        queue2 = alternateFiber.updateQueue
        if queue2 == nil then
            alternateFiber.updateQueue = createUpdateQueue(nil)
            queue2 = alternateFiber.updateQueue
        end
    else
        queue2 = nil
    end
    queue2 = queue2 ~= queue1 and queue2 or nil

    -- Use module variables instead of returning a tuple
    q1 = queue1
    q2 = queue2
end


local function insertUpdateIntoFiber(fiber, update)
    ensureUpdateQueues(fiber)
    local queue1 = q1
    local queue2 = q2

    -- Warn if an update is scheduled from inside an updater
    if __DEV__ then
        if ((queue1.isProcessing or (queue2 ~= nil and queue2.isProcessing)) and not didWarnInsideUpdate) then
            warning(
                false,
                "An update (setState, replaceState, or forceUpdate) was scheduled from inside an update function. Update functions should be pure, with zero side-effects. Consider using componentDidUpdate or a callback."
            )
            didWarnInsideUpdate = true
        end
    end

    -- If there's only one queue, add the update to that queue and exit
    if queue2 == nil then
        insertUpdateIntoQueue(queue1, update)
    end

    -- If either queue is empty, we need to add to both queues
    if queue1.last == nil or queue2.last == nil then
        insertUpdateIntoQueue(queue1, update)
        insertUpdateIntoQueue(queue2, update)
        return
    end

    -- If both lists are not empty, the last update is the same for both lists
    -- because of structural sharing. So, we should only append to one of the lists
    insertUpdateIntoQueue(queue1, update)
    -- But we still need to update the `last` pointer of queue2
    queue2.last = update
end

local function getUpdateExpirationTime(fiber)
    local t = fiber.tag
    if t == HostRoot or t == ClassComponent then
        local updateQueue = fiber.updateQueue
        if updateQueue == nil then
            return NoWork
        end
        return updateQueue.expirationTime
    else
        return NoWork
    end
end

local function getStateFromUpdate(update, instance, prevState, props)
    local partialState = update.partialState
    if type(partialState) == "function" then
        return partialState(instance, prevState, props)
    else
        return partialState
    end
end

local function processUpdateQueue(
    current,
    workInProgress,
    queue,
    instance,
    props,
    renderExpirationTime
)
    if current ~= nil and current.updateQueue == queue then
        -- We need to create a work-in-progress queue, by cloining the current queue
        local currentQueue = queue
        workInProgress.updateQueue = {
            baseState = currentQueue.baseState,
            expirationTime = currentQueue.expirationTime,
            first = currentQueue.first,
            last = currentQueue.last,
            isInitialized = currentQueue.isInitialized,
            capturedValues = currentQueue.capturedValues,
            -- These fields are no longer valid because they were already committed
            -- Reset them.
            callbackList = nil,
            hasForceUpdate = false
        }
        queue = workInProgress.updateQueue
    end

    if __DEV__ then
        -- Set this flag so we can warn if setState is called inside the update
        -- function of another setState
        queue.isProcessing = true
    end

    -- Reset the remaining expiration time. If we skip over any updates, we'll
    -- increase this accordingly
    queue.expirationTime = NoWork

    -- TODO: We don't know what the base state will be until we begin work.
    -- It depends on which fiber is the next current. Initialize with an empty
    -- base state, then set to the memoizedState when rendering. Not super
    -- happy with this approach.
    local state 
    if queue.isInitialized then
        state = queue.baseState
    else
        queue.baseState = workInProgress.memoizedState
        state = queue.baseState
        queue.isInitialized = true
    end
    local dontMutatePrevState = true
    local update = queue.first
    local didSkip = false
    while update ~= nil do
        for __continue = 1,1 do
            local updateExpirationTime = update.expirationTime
            if updateExpirationTime > renderExpirationTime then
                -- This update does not have sufficient priority
                local remainingExpirationTime = queue.expirationTime
                if (
                    remainingExpirationTime == NoWork or remainingExpirationTime > updateExpirationTime
                ) then
                    -- Update the remaining expiration time
                    queue.expirationTime = updateExpirationTime
                end
                if not didSkip then
                    didSkip = true
                    queue.baseState = state
                end
                -- Continue to the next update
                update = update.next
                break
            end

            -- This update does have sufficient priority

            -- If no previous updates were skipped, drop this update from the queue
            -- by advancing the head of the list
            if not didSkip then
                queue.first = update.next
                if queue.first == nil then
                    queue.last = nil
                end
            end

            -- Invoke setState callback an extra time to help detect side-effects
            -- Ignore the return value in this case
            if (debugRenderPhaseSideEffects or (debugRenderPhaseSideEffectsForStrictMode and bit.band(workInProgress.mode, StrictMode) > 0)) then
                getStateFromUpdate(update, instance, state, props)
            end

            -- Process the update
            local partialState
            if update.isReplace then
                state = getStateFromUpdate(update, instance, state, props)
                dontMutatePrevState = true
            else
                partialState = getStateFromUpdate(update, instance, state, props)
                if partialState then
                    if dontMutatePrevState then
                        state = assign({}, state, partialState)
                    else
                        state = assign(state, partialState)
                    end
                    dontMutatePrevState = false
                end

            end

            if update.isForced then
                queue.hasForceUpdate = true
            end

            if update.callback ~= nil then
                -- Append to list of callbacks
                local callbackList = queue.callbackList
                if callbackList == nil then
                    queue.callbackList = {}
                    callbackList = queue.callbackList
                end
                table.insert(callbackList, update)
            end

            if update.capturedValue ~= nil then
                local capturedValues = queue.capturedValues
                if capturedValues == nil then
                    queue.capturedValues = {update.capturedValue}
                else
                    table.insert(capturedValues, update.capturedValue)
                end
            end
            update = update.next
        end -- continue
    end

    if queue.callbackList ~= nil then
        workInProgress.effectTag = bit.bor(workInProgress.effectTag, CallbackEFfect)
    elseif (
        queue.first == nil and
        (not queue.hasForceUpdate) and
        queue.capturedValues == nil
    ) then
        -- The queue is empty. We can reset it.
        workInProgress.updateQueue = nil
    end

    if not didSkip then
        didSkip = true
        queue.baseState = state
    end

    if __DEV__ then
        -- No longer processing
        queue.isProcessing = false
    end

    return state
end

local function commitCallbacks(queue, context)
    local callbackList = queue.callbackList
    if callbackList == nil then
        return
    end

    -- Set the list to nil to make sure they don't get called more than once
    queue.callbackList = nil
    for i, update in ipairs(callbackList) do
        local callback = update.callback
        -- This update might be processed again. Clear the callback so it's only
        -- called once.
        update.callback = nil
        invariant(
            type(callback) == "function",
            "Invalid argument passed as callback. Expected a function. Instead received: " .. callback
        )
        callback(context)
    end
end

return {
    insertUpdateIntoQueue = insertUpdateIntoQueue,
    ensureUpdateQueues = ensureUpdateQueues,
    insertUpdateIntoFiber = insertUpdateIntoFiber,
    getUpdateExpirationTime = getUpdateExpirationTime,
    processUpdateQueue = processUpdateQueue,
    commitCallbacks = commitCallbacks
}