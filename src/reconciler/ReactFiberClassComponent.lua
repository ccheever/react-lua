local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Update = ReactTypeOfSideEffect.Update
local Snapshot = ReactTypeOfSideEffect.Snapshot

local ReactFeatureFlags = require "ReactFeatureFlags"
local enableGetDerivedStateFromCatch = ReactFeatureFlags.enableGetDerivedStateFromCatch
local debugRenderPhaseSideEffects = ReactFeatureFlags.debugRenderPhaseSideEffects
local debugRenderPhaseSideEffectsForStrictMode = ReactFeatureFlags.debugRenderPhaseSideEffectsForStrictMode
local warnAboutDeprecatedLifecycles = ReactFeatureFlags.warnAboutDeprecatedLifecycles

local ReactStrictModeWarnings = require "ReactStrictModeWarnings"
local reflection = require "reflection"
local isMounted = reflection.isMounted
local ReactInstanceMap = require "ReactInstanceMap"
local emptyObject = require "emptyObject"
local getComponentName = require "getComponentName"
local shallowEqual = require "shallowEqual"
local invariant = require "invariant"
local warning = require "warning"

local ReactDebugFiberPerf = require "ReactDebugFiberPerf"
local startPhaseTimer = ReactDebugFiberPerf.startPhaseTimer
local stopPhaseTimer = ReactDebugFiberPerf.stopPhaseTimer
local ReactTypeOfMode = require "ReactTypeOfMode"
local StrictMode = ReactTypeOfMode.StrictMode
local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local insertUpdateIntoFiber = ReactFiberUpdateQueue.insertUpdateIntoFiber
local processUpdateQueue = ReactFiberUpdateQueue.processUpdateQueue

local fakeInternalInstance = {}
local array = require "array"
local isArray = array.isArray

local assign = require "assign"

local didWarnAboutStateAssignmentForComponent;
local didWarnAboutUndefinedDerivedState;
local didWarnAboutUninitializedState;
local didWarnAboutGetSnapshotBeforeUpdateWithoutDidUpdate;
local didWarnAboutLegacyLifecyclesAndDerivedState;
local warnOnInvalidCallback;

if __DEV__ then
    -- TODO(ccheever): Some __DEV__ stuff here that I commented out
    -- because it looked gnarly and super-JavaScript-specific-y
end

local function callGetDerivedStateFromCatch(ctor, capturedValues)
    local resultState = {}
    for i, capturedValue in ipairs(capturedValues) do
        local error = capturedValue.value
        local partialState = ctor.getDerivedStateFromCatch(null, error)
        if partialState ~= nil then
            assign(resultState, partialState)
        end
    end

    return resultState
end

local function ReactFiberClassComponent(
    legacyContext,
    scheduleWork,
    computeExpirationForFiber,
    memoizeProps,
    memoizeState
)
    local cacheContext = legacyContext.cacheContext
    local getMaskedContext = legacyContext.getMaskedContext
    local getUnmaskedContext = legacyContext.getUnmaskedContext
    local isContextConsumer = legacyContext.isContextConsumer
    local hasContextChanged = legacyContext.hasContextChanged

    -- Class component state updater
    local updater = {
        isMounted = isMounted,
        enqueueSetState = function (self, instance, partialState, callback)
            local fiber = ReactInstanceMap.get(instance)
            callback = callback == nil and nil or callback
            if __DEV__ then
                warnOnInvalidCallback(callback, "setState")
            end
            local expirationTime = computeExpirationForFiber(fiber)
            local update = {
                expirationTime = expirationTime,
                partialState = partialState,
                callback = callback,
                isReplace = false,
                isForced = false,
                capturedValue = nil,
                next = nil
            }
            insertUpdateIntoFiber(fiber, update)
            scheduleWork(fiber, expirationTime)
        end,

        enqueueReplaceState = function (self, instance, state, callback)
            local fiber = ReactInstanceMap.get(instance)
            callback = callback == nil and nil or callback
            if __DEV__ then
                warnOnInvalidCallback(callback, "replaceState")
            end
            local expirationTime = computeExpirationForFiber(fiber)
            local update = {
                expirationTime = expirationTime,
                partialState = state,
                callback = callback,
                isReplace = true,
                isForced = false,
                capturedValue = nil,
                next = nil
            }
            insertUpdateIntoFiber(fiber, update)
            scheduleWork(fiber, expirationTime)
        end,

        enqueueForceUpdate = function (self, instance, callback)
            local fiber = ReactInstanceMap.get(instance)
            callback = callback == nil and nil or callback
            if __DEV__ then
                warnOnInvalidCallback(callback, "forceUpdate")
            end
            local expirationTime = computeExpirationForFiber(fiber)
            local update = {
                expirationTime = expirationTime,
                partialState = nil,
                callback = callback,
                isReplace = false,
                isForced = true,
                capturedValue = nil,
                next = nil
            }
            insertUpdateIntoFiber(fiber, update)
            scheduleWork(fiber, expirationTime)
        end
    }

    local function checkShouldComponentUpdate(
        workInProgress,
        oldProps,
        newProps,
        oldState,
        newState,
        newContext
    )
        if (oldProps == nil or (workInProgress.updateQueue ~= nil and workInProgress.updateQueue.hasForceUpdate)) then
            -- If the workInProgress already has an Update effect, return true
            return true
        end

        local instance = workInProgress.stateNode
        local ctor = workInProgress.type
        if type(instance.shouldComponentUpdate) == "function" then
            startPhaseTimer(workInProgress, "shouldComponentUpdate")
            local shouldUpdate = instance:shouldComponentUpdate(
                newProps, newState, newContext
            )
            stopPhaseTimer()

            if __DEV__ then
                local cn = getComponentName(workInProgress) or "Component"
                warning(
                    shouldUpdate ~= nil,
                    cn .. ".shouldComponentUpdate(): Returned undefined instead of a boolean value. Make sure to return true or false."
                )
            end
            return shouldUpdate
        end

        if ctor.isPureReactComponent then
            return not shallowEqual(oldProps, newProps) or not shallowEqual(oldState, newState)
        end

        return true

    end


    local function checkClassInstance(workInProgress)
        local instance = workInProgress.stateNode
        local ty = workInProgress.type
        if __DEV__ then
            local name = getComponentName(workInProgress) or "Component"
            local renderPresent = instance.render

            if not renderPresent then
                warning(
                    false,
                    name .. '(...): No `render` method found on the returned component instance: you may have forgotten to define `render`.'
                )
            end

            -- TODO(ccheever): A bunch of checks

        end

    end

    local function resetInputPointers(workInProgress, instance)
        instance.props = workInProgress.memoizeProps
        instance.state = workInProgress.memoizeState
    end

    local function adoptClassInstance(workInProgress, instance)
        instance.updater = updater
        workInProgress.stateNode = instance
        -- The instance needs access to the fiber so that it can schedule updates
        ReactInstanceMap.set(instance, workInProgress)
        if __DEV__ then
            instance._reactInternalInstance = fakeInternalInstance
        end
    end

    local function constructClassInstance(workInProgress)
        local ctor = workInProgress.type
        local unmaskedContext = getUnmaskedContext(workInProgress)
        local needsContext = isContextConsumer(workInProgress)
        local context = needsContext and getMaskedContext(workInProgress, unmaskedContext) or emptyObject

        -- Instantiate twice to help detect side-effects
        if (debugRenderPhaseSideEffects or (debugRenderPhaseSideEffectsForStrictMode and bit.band(workInProgress.mode, StrictMode) > 0)) then
            ctor(props, context)
        end

        local instance = ctor(props, context)
        local state = instance.state ~= nil and instance.state or nil
        adoptClassInstance(workInProgress, instance)

        if __DEV__ then
            -- TODO(ccheever): A bunch of stuff
        end

        workInProgress.memoizeState = state

        local partialState = callGetDerivedStateFromProps(
            workInProgress,
            instance,
            props,
            state
        )

        if partialState ~= nil and partialState ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            workInProgress.memoizedState = assign(
                {},
                workInProgress.memoizedState,
                partialState
            )
        end

        -- Cache unmasked context so we can avoid recreating masked context unless necessary.
        -- ReactFiberContext usually updates this cache but can't for newly-created instances.
        if needsContext then
            cacheContext(workInProgress, unmaskedContext, context)
        end

        return instance
    end

    local function callComponentWillMount(workInProgress, instance)
        startPhaseTimer(workInProgress, "componentWillMount")
        local oldState = instance.state

        if type(instance.componentWillMount) == "function" then
            instance:componentWillMount()
        end

        if type(instance.UNSAFE_componentWillMount == "function") then
            instance:UNSAFE_componentWillMount()
        end

        stopPhaseTimer()

        if oldState ~= instance.state then
            if __DEV__ then
                local cn = getComponentName(workInProgress) or "Component"
                warning(
                    false,
                    cn .. ":componentWillMount(): Assigning directly to this.state is deprecated (except inside a component's constructor). Use setState instead."
                    )
            end
            updater:enqueueReplaceState(instance, instance.state, nil)
        end
    end

    local function callComponentWillReceiveProps(
        workInProgress,
        instance,
        newProps,
        newContext
    )
        local oldState = instance.state
        startPhaseTimer(workInProgress, "componentWillReceiveProps")
        if type(instance.componentWillReceiveProps) == "function" then
            instance:componentWillReceiveProps(newProps, newContext)
        end

        if type(instance.UNSAFE_componentWillReceiveprops) == "function" then
            instance:UNSAFE_componentWillReceiveProps(newProps, newContext)
        end

        stopPhaseTimer()

        if instance.state ~= oldState then
            if __DEV__ then
                local componentName = getComponentName(workInProgress) or 'Component'
                if not didWarnAboutStateAssignmentForComponent[componentName] then
                    didWarnAboutStateAssignmentForComponent[componentName] = true
                    warning(
                    false,
                    componentName .. ":componentWillReceiveProps(): Assigning directly to this.state is deprecated (except inside a component's constructor). Use setState instead."
                    )
                end
            end

            updater:enqueueReplaceState(instance, instance.state, nil)
        end

    end

    local function callGetDerivedStateFromProps(
        workInProgress,
        instance,
        nextProps,
        prevState
    )
        local ty = workInProgress

        if type(ty.getDerivedStateFromProps) == "function" then
            if (debugRenderPhaseSideEffects or (debugRenderPhaseSideEffectsForStrictMode and bit.band(workInProgress.mode, StrictMode) > 0)) then
                -- Invoke method an extra time to help detect side-effects.
                ty.getDerivedStateFromProps(nextProps, prevState)
            end

            local partialState = ty.getDerivedStateFromProps(nextProps, prevState)

            if __DEV__ then
                if partialState == nil then
                    local componentName = getComponentName(workInProgress) or "Component"
                    if not didWarnAboutUndefinedDerivedState[componentName] then
                        didWarnAboutUndefinedDerivedState[componentName] = true
                        warning(
                            false,
                            componentName .. '.getDerivedStateFromProps(): A valid state object (or null) must be returned. You have returned undefined.'
                        )
                    end
                end
            end

            return partialState

        end
    end

    -- Invokes the mount life-cycles on a previously never rendered instance
    local function mountClassInstance(
        workInProgress,
        renderExpirationTime
    )
        local ctor = workInProgress.type
        local current = workInProgress.alternate

        if __DEV__ then
            checkClassInstance(workInProgress)
        end

        local instance = workInProgress.stateNode
        local props = workInProgress.pendingProps
        local unmaskedContent = getUnmaskedContext(workInProgress)

        instance.props = props
        instance.state = workInProgress.memoizedState
        instance.refs = emptyObject
        instance.context = getMaskedContext(workInProgress, unmaskedContent)

        if __DEV__ then
            if bit.band(workInProgress.mode, StrictMode) > 0 then
                ReactStrictModeWarnings.recordUnsafeLifecycleWarnings(
                    workInProgress,
                    instance
                )
            end

            if warnAboutDeprecatedLifecycles then
                ReactStrictModeWarnings.recordDeprecationWarnings(
                    workInProgress,
                    instance
                )
            end
        end


        -- In order to support react-lifecycles-compat polyfilled components,
        -- Unsafe lifecycles should not be invoked for components using the new APIs.
        if (
            type(ctor.getDerivedStateFromProps) ~= "function" and
            type(instance.getSnapshotBeforeUpdate) ~= "function" and
            (type(instance.UNSAFE_componentWillMount) == "function" or type(instance.componentWillMount) == "function")
        ) then
            callComponentWillMount(workInProgress, instance)
            -- If we had additional state updates during this life-cycle, let's
            -- process them now.
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                instance.state = processUpdateQueue(
                    current,
                    workInProgress,
                    updateQueue,
                    instance,
                    props,
                    renderExpirationTime
                )
            end
        end

        if type(instance.componentDidMount) == "function" then
            workInProgress.effectTag = bit.band(workInProgress.effectTag, Update)
        end

    end

    local function resumeMountClassInstance(
        workInProgress,
        renderExpirationTime
    )
        local ctor = workInProgress.type
        local instance = workInProgress.stateNode
        resetInputPointers(workInProgress, instance)

        local oldProps = workInProgress.memoizedProps
        local newProps = workInProgress.pendingProps
        local oldContext = instance.context
        local newUnmaskedContext = getUnmaskedContext(workInProgress)
        local newContext = getMaskedContext(workInProgress, newUnmaskedContext)

        local hasNewLifecycles = (
            type(ctor.getDerivedStateFromProps) == "function" or 
            type(instance.getSnapshotBeforeUpdate) == "function"
        )

        -- Note: During these life-cycles, instance.props/instance.state are what
        -- ever the previously attempted to render - not the "current". However,
        -- during componentDidUpdate we pass the "current" props.
    
        -- In order to support react-lifecycles-compat polyfilled components,
        -- Unsafe lifecycles should not be invoked for components using the new APIs.
        if (not hasNewLifecycles) and (type(instance.UNSAFE_componentWillReceiveProps) or type(instance.componentWillReceiveProps) == "function") then
            if oldProps ~= newProps or oldContext ~= newContext then
                callComponentWillReceiveProps(
                    workInProgress,
                    instance,
                    newProps,
                    newContext
                )
            end
        end

        -- Compute the enxt state using the memoized state and the update queue.
        local oldState = workInProgress.memoizedState

        -- TODO: Previous state can be nil
        local newState
        local derivedStateFromCatch
        if workInProgress.updateQueue ~= nil then
            newState = processUpdateQueue(
                nil,
                workInProgress,
                workInProgress.updateQueue,
                instance,
                newProps,
                renderExpirationTime
            )

            local updateQueue = workInProgress.updateQueue
            if (
                updateQueue ~= nil and 
                updateQueue.capturedValues ~= nil and
                (endableGetDerivedStateFromCatch and type(ctor.getDerivedStateFromCatch) == "function")
            ) then
                local capturedValues = updateQueue.capturedValues
                -- Don't remove these from the update queue yet. We need them in
                -- finishClassComponent. Do the reset there.
                -- TODO: This is awkward. Refactor class components.
                -- updateQueue.capturedValues = null;
                derivedStateFromCatch = callGetDerivedStateFromCatch(
                    ctor,
                    capturedValues
                )
            end
        else
            newState = oldState
        end

        local derivedStateFromProps
        if oldProps ~= newProps then
            -- The prevState parameter should be the partially updated state.
            -- Otherwise, spreading state in return values could override updates.
            derivedStateFromProps = callGetDerivedStateFromProps(
                workInProgress,
                instance,
                newProps,
                newState
            )
        end

        if derivedStateFromProps ~= nil and derivedStateFromProps ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derivedStateFromProps or assign({}, newState, derivedStateFromProps)

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromProps
                )
            end
        end

        if derivedStateFromCatch ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derviedStateFromCatch or assign({}, newState, derivedStateFromCatch)

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue

            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromCatch
                )
            end
        end

        if (
            oldProps == newProps and
            oldState == newState and
            not hasContextChanged() and
            not (
                workInProgress.updateQueue ~= nil and
                workInProgress.updateQueue.hasForceUpdate
            )
        ) then
            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
            end
            return false
        end

        local shouldUpdate = checkShouldComponentUpdate(
            workInProgress,
            oldProps,
            newProps,
            oldState,
            newState,
            newContext
        )

        if shouldUpdate then
            -- In order to support react-lifecycles-compat polyfilled components,
            -- Unsafe lifecycles should not be invoked for components using the new APIs.
            if (
                not hasNewLifecycles and 
                (type(instance.UNSAFE_componentWillMount) == "function" or 
                type(instance.componentWillMount) == "function")
            ) then
                startPhaseTimer(workInProgress, "componentWillMount")
                if type(instance.componentWillMount) == "function" then
                    instance:componentWillMount()
                end

                if type(instance.UNSAFE_componentWillMount) == "function" then
                    instance:UNSAFE_componentWillMount()
                end

                stopPhaseTimer()
            end

            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress, Update)
            end

        else
            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress, Update)
            end

            -- If shouldComponentUpdate returned false, we should still update the
            -- memoized props/state to indicate that this work can be reused.
            memoizeProps(workInProgress, newProps)
            memoizeState(workInProgress, newState)

        end

        -- Update the existing instance's state, props, and context pointers even
        -- if shouldComponentUpdate returns false.
        instance.props = newProps
        instance.state = newState
        instance.context = newContext

        return shouldUpdate
    end

    -- Invokes the update life-cycles and returns false if it shouldn't rerender.
    local function updateClassInstance(
        current,
        workInProgress,
        renderExpirationTime
    )
        local ctor = workInProgress.type
        local instance = workInProgress.stateNode
        resetInputPointers(workInProgress, instance)

        local oldProps = workInProgress.memoizedProps
        local newProps = workInProgress.pendingProps
        local oldContext = instance.context
        local newUnmaskedContext = getUnmaskedContext(workInProgress)
        local newContext = getMaskedContext(workInProgress, newUnmaskedContext)

        local hasNewLifecycles = type(ctor.getDerivedStateFromProps) == "function" or type(instance.getSnapshotBeforeUpdate) == "function"
        -- Note: During these life-cycles, instance.props/instance.state are what
        -- ever the previously attempted to render - not the "current". However,
        -- during componentDidUpdate we pass the "current" props.

        -- In order to support react-lifecycles-compat polyfilled components,
        -- Unsafe lifecycles should not be invoked for components using the new APIs.
        if (
            not hasNewLifecycles and
            (type(instance.UNSAFE_componentWillReceiveProps) == "function" or 
            type(instance.componentWillReceiveProps) == "function")
        ) then
            if oldProps ~= newProps or oldContext ~= newContext then
                callComponentWillReceiveProps(
                    workInProgress,
                    instance,
                    newProps,
                    newContext
                )
            end
        end

        -- Compute the next state using the memoized state and the update queue.
        local oldState = workInProgress.memoizedState

        -- TODO: Previous state can be nil
        local newState 
        local derivedStateFromCatch

        if workInProgress.updateQueue ~= nil then
            newState = processUpdateQueue(
                current,
                workInProgress,
                workInProgress.updateQueue,
                instance,
                newProps,
                renderExpirationTime
            )

            local updateQueue = workInProgress.updateQueue
            if (
                updateQueue ~= nil and 
                updateQueue.capturedValues ~= nil and
                (
                    enableGetDerivedStateFromCatch and 
                    type(ctor.getDerivedStateFromCatch) == "function"
                )
            ) then
                local capturedValues = updateQueue.capturedValues
                -- Don't remove these from the update queue yet. We need them in
                -- finishClassComponent. Do the reset there.
                -- TODO: This is awkward. Refactor class components.
                -- updateQueue.capturedValues = null;
                derivedStateFromCatch = callGetDerivedStateFromCatch(
                    ctor,
                    capturedValues
                )
            end
        else
            newState = oldState
        end

        local derivedStateFromProps
        if oldProps ~= newProps then
            -- The prevState parameter should be the partially updated state.
            -- Otherwise, spreading state in return values could override updates.
            derivedStateFromProps = callGetDerivedStateFromProps(
                workInProgress,
                instance,
                newProps,
                newState
            )
        end

        if derivedStateFromProps ~= nil and derivedStateFromProps ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derviedStateFromProps or assign({}, newState, derivedStateFromProps)

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromProps
                )
            end
        end

        if derivedStateFromCatch ~= nil and derivedStateFromCatch ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derivedStateFromCatch or assign(
                {}, newState, derviedStateFromCatch
            )

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromCatch
                )
            end
        end

        if (
            oldProps == newProps and
            oldState == newState and
            not hasContextChanged() and
            not (
                workInProgress.updateQueue ~= nil and
                workInProgress.updateQueue.hasForceUpdate
            )
        ) then
            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
            end
            return false
        end

        local shouldUpdate = checkComponentShouldUpdate(
            workInProgress,
            oldProps,
            newProps,
            oldState,
            newState,
            newContext
        )

        if shouldUpdate then
            -- In order to support react-lifecycles-compat polyfilled components,
            -- Unsafe lifecycles should not be invoked for components using the new APIs.
            if (
                not hasNewLifecycles and
                (
                    type(instance.UNSAFE_componentWillMount) == "function" or
                    type(instance.componentWillMount) == "function"
                )
            ) then
                startPhaseTimer(workInProgress, "componentWillMount")
                if type(instance.componentWillMount) == "function" then
                    instance:componentWillMount()
                end
                if type(instance.UNSAFE_componentWillMount) == "function" then
                    instance:UNSAFE_componentWillMount()
                end
                stopPhaseTimer()
            end

            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
            end

        else 
            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidMount) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
            end

            -- If shouldComponentUpdate returned false, we should still update the
            -- memoized props/state to indicate that this work can be reused.
            memoizeProps(workInProgress, newProps)
            memoizeState(workInProgress, newState)

        end

        -- Update the existing instance's state, props, and context pointers even
        -- if shouldComponentUpdate returns false.
        instance.props = newProps
        instance.state = newState
        instance.context = newContext

        return shouldUpdate
    end

    -- Invokes the update life-cycles and returns false if it shouldn't rerender.
    local function updateClassInstance(
        current,
        workInProgress,
        renderExpirationTime
    )
        local ctor = workInProgress.type
        local instance = workInProgress.stateNode
        resetInputPointers(workInProgress, instance)

        local oldProps = workInProgress.memoizedProps
        local newProps = workInProgress.pendingProps
        local oldContext = instance.context
        local newUnmaskedContext = getUnmaskedContext(workInProgress)
        local newContext = getMaskedContext(workInProgress, newUnmaskedContext)

        local hasNewLifecycles = 
            type(ctor.getDerivedStateFromProps) == "function" or
            type(instance.getSnapshotBeforeUpdate) == "function"
    

        -- Note: During these life-cycles, instance.props/instance.state are what
        -- ever the previously attempted to render - not the "current". However,
        -- during componentDidUpdate we pass the "current" props.
    
        -- In order to support react-lifecycles-compat polyfilled components,
        -- Unsafe lifecycles should not be invoked for components using the new APIs.
        if (
            not hasNewLifecycles and
            (
                type(instance.UNSAFE_componentWillReceiveProps) == "function" or
                type(instance.componentWillReceiveProps) == "function"
            )
        ) then
            if oldProps ~= newProps or oldContext ~= newContext then
                callComponentWillReceiveProps(
                    workInProgress,
                    instance,
                    newProps,
                    newContext
                )
            end
        end

        -- Compute the next state using the memoized state and the update queue.
        local oldState = workInProgress.memoizedState
        -- TODO: Previous state can be nil
        local newState
        local derivedStateFromCatch

        if workInProgress.updateQueue ~= nil then
            newState = processUpdateQueue(
                current,
                workInProgress,
                workInProgress.updateQueue,
                instance,
                newProps,
                renderExpirationTime
            )

            local updateQueue = workInProgress.updateQueue
            if (
                updateQueue ~= nil and
                updateQueue.capturedValues ~= nil and
                (
                    enableGetDerivedStateFromCatch and
                    type(ctor.getDerivedStateFromCatch) == "function"
                )
            ) then
                local capturedValues = updateQueue.capturedValues
                -- Don't remove these from the update queue yet. We need them in
                -- finishClassComponent. Do the reset there.
                -- TODO: This is awkward. Refactor class components.
                -- updateQueue.capturedValues = null;
                derivedStateFromCatch = callGetDerivedStateFromCatch(
                    ctor,
                    capturedValues
                )
            end
        else
            newState = oldState
        end

        local derivedStateFromProps
        if oldProps ~= newProps then
            -- The prevState parameter should be the partially updated state.
            -- Otherwise, spreading state in return values could override updates.
            derivedStateFromProps = callGetDerivedStateFromProps(
                workInProgress,
                instance,
                newProps,
                newState
            )
        end

        if derivedStateFromProps ~= nil then 
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derivedStateFromProps or assign(
                {}, newState, derivedStateFromProps
            )

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromProps
                )
            end
        end

        if derivedStateFromCatch ~= nil then
            -- Render-phase updates (like this) should not be added to the update queue,
            -- So that multiple render passes do not enqueue multiple updates.
            -- Instead, just synchronously merge the returned state into the instance.
            newState = newState == nil and derivedStateFromCatch or assign(
                {}, newState, derivedStateFromCatch
            )

            -- Update the base state of the update queue.
            -- FIXME: This is getting ridiculous. Refactor plz!
            local updateQueue = workInProgress.updateQueue
            if updateQueue ~= nil then
                updateQueue.baseState = assign(
                    {},
                    updateQueue.baseState,
                    derivedStateFromCatch
                )
            end
        end

        if (
            oldProps == newProps and
            oldState == newState and
            not hasContextChanged() and
            not (
                workInProgress.updateQueue ~= nil and
                workInProgress.updateQueue.hasForceUpdate
            )
        ) then

            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidUpdate) == "function" then
                if (
                    oldProps ~= current.memoizedProps or
                    oldState ~= current.memoizedState
                ) then
                    workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
                end
            end

            if type(instance.getSnapshotBeforeUpdate) == "function" then
                if (
                    oldProps ~= current.memoizedProps or
                    oldState ~= current.memoizedState
                ) then
                    workInProgress.effectTag = bit.bor(workInProgress.effectTag, Snapshot)
                end
            end

            return false

        end

        local shouldUpdate = checkShouldComponentUpdate(
            workInProgress,
            oldProps,
            newProps,
            oldState,
            newState,
            newContext
        )

        if shouldUpdate then
            -- In order to support react-lifecycles-compat polyfilled components,
            -- Unsafe lifecycles should not be invoked for components using the new APIs.
            if (
                not hasNewLifecycles and
                (
                    type(instance.UNSAFE_componentWillUpdate) == "function" or
                    type(instance.componentWillUpdate) == "function"
                )
            ) then
                startPhaseTimer(workInProgress, "componentWillUpdate")
                if type(instance.componentWillUpdate) == "function" then
                    instance:componentWillUpdate(newProps, newState, newContext)
                end
                if type(instance.UNSAFE_componentWillUpdate) == "function" then
                    instance:UNSAFE_componentWillUpdate(newProps, newState, newContext)
                end
                stopPhaseTimer()
            end

            if type(instance.componentDidUpdate) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
            end

            if type(instance.getSnapshotBeforeUpdate) == "function" then
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Snapshot)
            end

        else
            -- If an update was already in progress, we should schedule an Update
            -- effect even though we're bailing out, so that cWU/cDU are called.
            if type(instance.componentDidUpdate) == "function" then
                if (
                    oldProps ~= current.memoizedProps or
                    oldState ~= current.memoizedState
                ) then
                    workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
                end
            end

            -- If shouldComponentUpdate returned false, we should still update the
            -- memoized props/state to indicate that this work can be reused.
            memoizeProps(workInProgress, newProps)
            memoizeState(workInProgress, newState)
        end

        -- Update the existing instance's state, props, and context pointers even
        -- if shouldComponentUpdate returns false.
        instance.props = newProps
        instance.state = newState
        instance.context = newContext

        return shouldUpdate
    end

    return {
        adoptClassInstance = adoptClassInstance,
        callGetDerivedStateFromProps = callGetDerivedStateFromProps,
        constructClassInstance = constructClassInstance,
        mountClassInstance = mountClassInstance,
        resumeMountClassInstance = resumeMountClassInstance,
        updateClassInstance = updateClassInstance
    }

end

return ReactFiberClassComponent