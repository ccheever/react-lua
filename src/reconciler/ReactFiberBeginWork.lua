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
local cancelWorkTimer = ReactDebugFiberPerf.cancelWorkTimer

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

local bit = require "bit"
local assign = require "assign"

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

    local _rfcc = ReactFiberClassComponent(legacyContext, scheduleWork, computeExpirationForFiber, memoizeProps, memoizeState)
    local adoptClassInstance = _rfcc.adoptClassInstance
    local callGetDerivedStateFromProps = _rfcc.callGetDerivedStateFromProps
    local constructClassInstance = _rfcc.constructClassInstance
    local mountClassInstance = _rfcc.mountClassInstance
    local resumeMountClassInstance = _rfcc.resumeMountClassInstance
    local updateClassInstance = _rfcc.updateClassInstance

    -- TODO: Remove this and use reconcileChildrenAtExpirationTime directly.
    local function reconcileChildren(current, workInProgress, nextChildren)
        reconcileChildrenAtExpirationTime(
            current,
            workInProgress,
            nextChildren,
            workInProgress.expirationTime
        )
    end

    local function reconcileChildrenAtExpirationTime(
        current,
        workInProgress,
        nextChildren,
        renderExpirationTime
    )
        if current == nil then
            -- If this is a fresh new component that hasn't been rendered yet, we
            -- won't update its child set by applying minimal side-effects. Instead,
            -- we will add them all to the child before it gets rendered. That means
            -- we can optimize this reconciliation pass by not tracking side-effects.
            workInProgress.child = mountChildFibers(
                workInProgress,
                nil,
                nextChildren,
                renderExpirationTime
            )
        else
            -- If the current child is the same as the work in progress, it means that
            -- we haven't yet started any work on these children. Therefore, we use
            -- the clone algorithm to create a copy of all the current children.
      
            -- If we had any progressed work already, that is invalid at this point so
            -- let's throw it out.
            workInProgress.child = reconcileChildFibers(
                workInProgress,
                current.child,
                nextChildren,
                renderExpirationTime
            )
        end
    end

    local function updateForwardRef(current, workInProgress)
        local render = workInProgress.type.render
        local nextChildren = render(
            workInProgress.pendingProps,
            workInProgress.ref
        )
        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextChildren)
        return workInProgress.child
    end

    local function updateFragment(current, workInProgress)
        local nextChildren = workInProgress.pendingProps
        if hasLegacyContextChanged() then
            -- Normally we can bail out on props equality but if context has changed
            -- we don't do the bailout and we have to reuse existing props instead.
        elseif workInProgress.memoizedProps == nextChildren then
            return bailoutOnAlreadyFinishedWork(current, workInProgress)
        end

        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextChildren)
        return workInProgress.child

    end

    local function updateMode(current, workInProgress) 
        local nextChildren = workInProgress.pendingProps.children
        if hasLegacyContextChanged() then
            -- Normally we can bail out on props equality but if context has changed
            -- we don't do the bailout and we have to reuse existing props instead.
        elseif (
            nextChildren == nil or 
            workInProgress.memoizedProps == nextChildren
        ) then
            return bailoutOnAlreadyFinishedWork(current, workInProgress)
        end
        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextChildren)
        return workInProgress.child
    end

    local function markRef(current, workInProgress)
        local ref = workInProgress.ref
        if (
            (current == nil and ref ~= nil) or
            (current ~= nil and current.ref ~= ref)
        ) then

            -- Schedule a Ref effect
            workInProgress.effectTag = bit.bor(workInProgress.effectTag , Ref)

        end
    end

    local function updateFunctionalComponent(current, workInProgress)
        local fn = workInProgress.type
        local nextProps = workInProgress.pendingProps

        if hasLegacyContextChanged() then
            -- Normally we can bail out on props equality but if context has changed
            -- we don't do the bailout and we have to reuse existing props instead.
        else 
            if workInProgress.memoizedProps == nextProps then
                return bailoutOnAlreadyFinishedWork(current, workInProgress)
            end
            -- TODO: consider bringing fn.shouldComponentUpdate() back.
            -- It used to be here.
        end

        local unmaskedContext = getUnmaskedContext(workInProgress)
        local context = getMaskedContext(workInProgress, unmaskedContext)

        local nextChildren

        if __DEV__ then
            ReactCurrentOwner.current = workInProgress
            ReactDebugCurrentFiber.setCurrentPhase("render")
            nextChildren = fn(nextProps, context)
            ReactDebugCurrentFiber.setCurrentPhase(nil)
        else
            nextChildren = fn(nextProps, context)
        end

        -- React DevTools reads this flag.
        workInProgress.effectTag = bit.bor(workInProgress.effectTag, PerformedWork)
        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextProps)
        return workInProgress.child

    end

    local function updateClassComponent(
        current,
        workInProgress,
        renderExpirationTime
    -- )
        -- Push context providers early to prevent context stack mismatches.
        -- During mounting we don't know the child context yet as the instance doesn't exist.
        -- We will invalidate the child context in finishClassComponent() right after rendering.
        local hasContext = pushLegacyContextProvider(workInProgress)
        local shouldUpdate
        if current == nil then
            if workInProgress.stateNode == nil then
                -- In the initial pass we might need to construct the instance.
                constructClassInstance(workInProgress, workInProgress.pendingProps)
                mountClassInstance(workInProgress, renderExpirationTime)
                shouldUpdate = true
            else
                -- In a resume, we'll already have an instance we can reuse.
                shouldUpdate = resumeMountClassInstance(
                    workInProgress,
                    renderExpirationTime
                )
            end

        else
            shouldUpdate = updateClassInstance(
                current,
                workInProgress,
                renderExpirationTime
            )
        end

        -- We processed the update queue inside updateClassInstance. It may have
        -- included some errors that were dispatched during the commit phase.
        -- TODO: Refactor class components so this is less awkward.
        local didCaptureError = false
        local updateQueue = workInProgress.updateQueue
        if updateQueue ~= nil and updateQueue.capturedValues ~= nil then
            shouldUpdate = true
            didCaptureError = true
        end

        return finishClassComponent(
            current,
            workInProgress,
            shouldUpdate,
            hasContext,
            didCaptureError,
            renderExpirationTime
        )

    end

    local function finishClassComponent(
        current,
        workInProgress,
        shouldUpdate,
        hasContext,
        didCaptureError,
        renderExpirationTime
    )
        -- Refs should update even if shouldComponentUpdate returns false
        markRef(current, workInProgress)

        if (not shouldUpdate) and (not didCaptureError) then
            -- Context providers should defer to sCU for rendering
            if hasContext then
                invalidateContextProvider(workInProgress, false)
            end

            return bailoutOnAlreadyFinishedWork(current, workInProgress)
        end

        local ctor = workInProgress.type
        local instance = workInProgress.stateNode

        -- Rerender
        ReactCurrentOwner.current = workInProgress
        local nextChildren
        if (
            didCaptureError and
            (not enableGetDerivedStateFromCatch or type(ctor.getDerivedStateFromCatch) ~= "function")
        ) then
            -- If we captured an error, but getDerivedStateFrom catch is not defined,
            -- unmount all the children. componentDidCatch will schedule an update to
            -- re-render a fallback. This is temporary until we migrate everyone to
            -- the new API.
            -- TODO: Warn in a future release.
            nextChildren = nil
        else
            if __DEV__ then
                ReactDebugCurrentFiber.setCurrentPhase("render")
                nextChildren = instance.render()
                if (
                    debugRenderPhaseSideEffects or 
                    (debugRenderPhaseSideEffectsForStrictMode and bit.band(workInProgress.mode, StrictMode) > 0)
                ) then
                    instance.render()
                end
                ReactDebugCurrentFiber.setCurrentPhase(nil)
            else
                if (
                    debugRenderPhaseSideEffects or 
                    (debugRenderPhaseSideEffectsForStrictMode and bit.band(workInProgress.mode, StrictMode) > 0)
                ) then      
                    instance.render()
                end
                nextChildren = instance.render()
            end
        end

        -- React DevTools reads this flag.
        workInProgress.effectTag = bit.bor(workInProgress.effectTag, PerformedWork)

        if didCaptureError then
            -- If we're recovering from an error, reconcile twice: first to delete
            -- all the existing children.
            reconcileChildrenAtExpirationTime(
                current,
                workInProgress,
                nil,
                renderExpirationTime
            )
            workInProgress.child = nil
            -- Now we can continue reconciling like normal. This has the effect of
            -- remounting all children regardless of whether their their
            -- identity matches.
        end

        reconcileChildrenAtExpirationTime(
            current,
            workInProgress,
            nextChildren,
            renderExpirationTime
        )

        -- Memoize props and state using the values we just used to render.
        -- TODO: Restructure so we never read values from the instance.
        memoizeState(workInProgress, instance.state)
        memoizeProps(workInProgress, instance.props)

        -- The context might have changed so we need to recalculate it.
        if hasContext then
            invalidateContextProvider(workInProgress, true)
        end

        return workInProgress.child
    end

    local function pushRootContext(workInProgress)
        local root = workInProgress.stateNode
        if root.pendingContext then
            pushTopLevelContextObject(
                workInProgress,
                root.pendingContext,
                root.pendingContext ~= root.context
            )
        elseif root.context then
            -- Should always be set
            pushTopLevelContextObject(workInProgress, root.context, false)
        end
        pushHostContainer(workInProgress, root.containerInfo)
    end

    local function updateHostRoot(current, workInProgress, renderExpirationTime)
        pushHostRootContext(workInProgress)
        local updateQueue = workInProgress.updateQueue
        if updateQueue ~= nil then
            local prevState = workInProgress.memoizedState
            local state = processUpdateQueue(
                current,
                workInProgress,
                updateQueue,
                nil,
                nil,
                renderExpirationTime
            )
            memoizeState(workInProgress, state)
            updateQueue = workInProgress.updateQueue

            local element
            if updateQueue ~= nil and updateQueue.capturedValues ~= nil then
                -- There's an uncaught error. Unmount the whole root.
                element = nil
            elseif prevState == state then
                -- If the state is the same as before, that's a bailout because we had
                -- no work that expires at this time.
                resetHydrationState()
                return bailoutOnAlreadyFinishedWork(current, workInProgress)
            else 
                element = state.element
            end

            local root = workInProgress.stateNode

            if (
                (current == nil or current.child == nil) and
                root.hydrate and
                enterHydrationState(workInProgress)
            ) then
                -- If we don't have any current children this might be the first pass.
                -- We always try to hydrate. If this isn't a hydration pass there won't
                -- be any children to hydrate which is effectively the same thing as
                -- not hydrating.
        
                -- This is a bit of a hack. We track the host root as a placement to
                -- know that we're currently in a mounting state. That way isMounted
                -- works as expected. We must reset this before committing.
                -- TODO: Delete this when we delete isMounted and findDOMNode.
                workInProgress.effectTag = bit.bor(workInProgress.effectTag, Placement)

                -- Ensure that children mount into this root without tracking
                -- side-effects. This ensures that we don't store Placement effects on
                -- nodes that will be hydrated.
                workInProgress.child = mountChildFibers(
                    workInProgress,
                    nil,
                    element,
                    renderExpirationTime
                )
            else
                -- Otherwise reset hydration state in case we aborted and resumed another
                -- root.
                resetHydrationState()
                reconcileChildren(current, workInProgress, element)
            end
            memoizeState(workInProgress, state)
            return workInProgress.child
        end

        resetHydrationState()

        -- If there is no update queue, that's a bailout because the root has no props.
        return bailoutOnAlreadyFinishedWork(current, workInProgress)

    end

    local function updateHostComponent(current, workInProgress, renderExpirationTime)
        pushHostContext(workInProgress)

        if current == nil then
            tryToClaimNextHydratableInstance(workInProgress)
        end

        local ty = workInProgress.type
        local memoizedProps = workInProgress.memoizedProps
        local nextProps = workInProgress.pendingProps
        local prevProps = current ~= nil and current.memoizedProps or nil

        if hasLegacyContextChanged() then
            -- Normally we can bail out on props equality but if context has changed
            -- we don't do the bailout and we have to reuse existing props instead.
        elseif memoizedProps == nextProps then
            local isHidden = 
                bit.band(workInProgress.mode, AsyncMode) > 0 and
                shouldDeprioritizeSubtree(ty, nextProps)
            if isHidden then
                -- Before bailing out, make sure we've deprioritized a hidden component.
                workInProgress.expirationTime = Never
            end

            if not isHidden or renderExpirationTime ~= Never then
                return bailoutOnAlreadyFinishedWork(current, workInProgress)
            end

            -- If we're rendering a hidden node at hidden priority, don't bailout. The
            -- parent is complete, but the children may not be.
        end

        local nextChildren = nextProps.children
        local isDirectTextChild = shouldSetTextContent(ty, nextProps)

        if isDirectTextChild then
            -- We special case a direct text child of a host node. This is a common
            -- case. We won't handle it as a reified child. We will instead handle
            -- this in the host environment that also have access to this prop. That
            -- avoids allocating another HostText fiber and traversing it.
            nextChildren = nil
        elseif prevProps and shouldSetTextContent(ty, prevProps) then
            workInProgress.effectTag = bit.bor(workInProgress.effectTag, ContentReset)
        end

        markRef(current, workInProgress)

        -- Check the host config to see if the children are offscreen/hidden.
        if (
            renderExpirationTime ~= Never and
            bit.band(workInProgress.mode, AsyncMode) and
            shouldDeprioritizeSubtree(ty, nextProps)
        ) then
            -- Down-prioritize the children.
            workInProgress.expirationTime = Never
            -- Bailout and come back to this fiber later.
            workInProgress.memoizedProps = nextProps
            return nil
        end

        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextProps)
        return workInProgress.child

    end

    local function updateHostText(current, workInProgress)
        if current == nil then
            tryToClaimNextHydratableInstance(workInProgress)
        end

        local nextProps = workInProgress.pendingProps
        memoizedProps(workInProgress, nextProps)

        -- Nothing to do here. This is terminal. We'll do the completion step
        -- immediately after.
        return nil
    end

    local function mountIndeterminateComponent(
        current,
        workInProgress,
        renderExpirationTime
    )
        invariant(
            current == nil,
            "An indeterminate component should never have mounted. This error is likely caused by a bug in React. Please file an issue."
        )
    end

    local fn = workInProgress.type
    local props = workInProgress.pendingProps
    local unmaskedContext = getUnmaskedContext(workInProgress)
    local context = getMaskedContext(workInProgress, unmaskedContext)

    local value
    
    if __DEV__ then
        -- TODO(ccheever): Translate this
        value = fn(props, context)
    else
        value = fn(props, context)
    end

    -- React DevTools reads this flag.
    workInProgress.effectTag = bit.bor(workInProgress.effectTag, PerformedWork)

    if (
        type(value) == "table" and 
        value ~= nil and
        type(value.render) == "function" and
        value["$$typeof"] == nil
    ) then
        local Component = workInProgress.type

        -- Proceed under the assumption that this is a class instance
        workInProgress.tag = ClassComponent

        workInProgress.memoizedState = value.state ~= nil and value.state or nil

        if type(Component.getDerivedStateFromProps) == "function" then
            local partialState = callGetDerivedStateFromProps(
                workInProgress,
                value,
                props,
                workInProgress.memoizedState
            )

            if partialState ~= nil then
                workInProgress.memoizedState = assign(
                    {},
                    workInProgress.memoizedState,
                    partialState
                )
            end
        end

        -- Push context providers early to prevent context stack mismatches.
        -- During mounting we don't know the child context yet as the instance doesn't exist.
        -- We will invalidate the child context in finishClassComponent() right after rendering.
        local hasContext = pushLegacyContextProvider(workInProgress)
        adoptClassInstance(workInProgress, value)
        mountClassInstance(workInProgress, renderExpirationTime)
        return finishClassComponent(
            current,
            workInProgress,
            true,
            hasContext,
            false,
            renderExpiration
        )
    else
        -- Proceed under the assumption that this is a functional component
        workInProgress.tag = FunctionalComponent
        if __DEV__ then
            -- TODO(ccheever): Do a bunch of this stuff
        end

        reconcileChildren(current, workInProgress, value)
        memoizeProps(workInProgress, props)
        return workInProgress.child
    end

end

local function updateCallComponent(current, workInProgress, renderExpirationTime)
    local nextProps = workInProgress.pendingProps
    if hasLegacyContextChanged() then
        -- Normally we can bail out on props equality but if context has changed
        -- we don't do the bailout and we have to reuse existing props instead.
    elseif workInProgress.memoizedProps == nextProps then
        nextProps = workInProgress.memoizedProps
        -- TODO: When bailing out, we might need to return the stateNode instead
        -- of the child. To check it for work.
        -- return bailoutOnAlreadyFinishedWork(current, workInProgress);
    end

    local nextChildren = nextProps.children

    -- The following is a fork of reconcileChildrenAtExpirationTime but using
    -- stateNode to store the child.
    if current == nil then
        workInProgress.stateNode = mountChildFiber(
            workInProgress,
            workInProgress.stateNode,
            nextChildren,
            renderExpiration
        )
    else 
        workInProgress.stateNode = reconcileChildFibers(
            workInProgress,
            current.stateNode,
            nextChildren,
            renderExpirationTime
        )
    end

    memoizeProps(workInProgress, nextProps)
    -- This doesn't take arbitrary time so we could synchronously just begin
    -- eagerly do the work of workInProgress.child as an optimization.
    return workInProgress.stateNode
end

local function updatePortalComponent(
    current,
    workInProgress,
    renderExpirationTime
)
    pushHostContainer(workInProgress, workInProgress.stateNode.containerInfo)
    local nextChildren = workInProgress.pendingProps
    if hasLegacyContextChanged() then
        -- Normally we can bail out on props equality but if context has changed
        -- we don't do the bailout and we have to reuse existing props instead.
    elseif workInProgress.memoizedProps == nextChildren then
        return bailoutOnAlreadyFinishedWork(current, workInProgress)
    end

    if current == nil then
        -- Portals are special because we don't append the children during mount
        -- but at commit. Therefore we need to track insertions which the normal
        -- flow doesn't do during mount. This doesn't happen at the root because
        -- the root always starts with a "current" with a null child.
        -- TODO: Consider unifying this with how the root works.
        workInProgress.child = reconcileChildFibers(
            workInProgress,
            nil,
            nextChildren,
            renderExpirationTime
        )
        memoizeProps(workInProgress, nextChildren)
    else
        reconcileChildren(current, workInProgress, nextChildren)
        memoizeProps(workInProgress, nextChildren)
    end
    return workInProgress.child
end

local function propagateContextChange(
    workInProgress,
    context,
    changedBits,
    renderExpirationTime,
)
end

return reactFiberBeginWork