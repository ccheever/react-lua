local ReactFeatureFlags = require "ReactFeatureFlags"
local enableMutatingReconciler = ReactFeatureFlags.enableMutatingReconciler
local enablePersistentReconciler = ReactFeatureFlags.enablePersistentReconciler
local enableNoopReconciler = ReactFeatureFlags.enableNoopReconciler
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
local ContextProvider = ReactTypeOfWork.ContextProvider
local ContextConsumer = ReactTypeOfWork.ContextConsumer
local ForwardRef = ReactTypeOfWork.ForwardRef
local Fragment = ReactTypeOfWork.Fragment
local Mode = ReactTypeOfWork.Mode

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Placement = ReactTypeOfSideEffect.Placement
local Ref = ReactTypeOfSideEffect.Ref
local Update = ReactTypeOfSideEffect.Update
local ErrLog = ReactTypeOfSideEffect.ErrLog
local DidCapture = ReactTypeOfSideEffect.DidCapture

local invariant = require "invariant"

local ReactChildFiber = require "ReactChildFiber"
local reconcileChildFibers = ReactChildFiber.reconcileChildFibers

local bit = require "bit"

local function ReactFiberCompleteWork(
    config,
    hostContext,
    legacyContext,
    newContext,
    hydrationContext
)
    local createInstance = config.createInstance
    local createTextInstance = config.createTextInstance
    local appendInitialChild = config.appendInitialChild
    local finalizeInitialChildren = config.finalizeInitialChildren
    local prepareUpdate = config.prepareUpdate
    local mutation = config.mutation
    local persistence = config.persistence

    local getRootHostContainer = hostContext.getRootHostContainer
    local popHostContext = hostContext.popHostContext
    local getHostContext = hostContext.getHostContext
    local popHostContainer = hostContext.popHostContainer

    local popContextProvider = legacyContext.popLegacyContextProvider
    local popTopLevelContextObject = legacyContext.popTopLevelLegacyContextObject
    
    local popProvider = newContext.popProvider

    local prepareToHydrateHostInstance = hydrationContext.prepareToHydrateHostInstance
    local prepareToHydrateHostTextInstance = hydrationContext.prepareToHydrateHostTextInstance
    local popHydrationState = hydrationContext.popHydrationState

    local function markUpdate(workInProgress)
        -- Tag the fiber with an update effect. This turns a Placement into
        -- a PlacementAndUpdate.
        workInProgress.effectTag = bit.bor(workInProgress.effectTag, Update)
    end

    local function markRef(workInProgress)
        workInProgress.effectTag = bit.bor(workInProgress.effectTag, Ref)
    end

    local function appendAllReturns(returns, workInProgress)
        local node = workInProgress.stateNode
        if node then
            node["return"] = workInProgress
        end
        while node ~= nil do
            for __continue = 1, 1 do
                if (
                    node.tag == HostComponent or 
                    node.tag == HostText or 
                    node.tag == HostPortal
                ) then
                    invariant(false, "A call cannot have host component children")
                elseif node.tag == ReturnComponent then
                    table.insert(returns, node.pendingProps.value)
                elseif node.child ~= nil then
                    node.child["return"] = node
                    node = node.child
                    break
                end
                while node.sibling == nil do
                    if node["return"] == nil or node["return"] == workInProgress then
                        return
                    end
                    node = node["return"]
                end
            end
        end
    end

    local function moveCallToHandlerPhase(
        current,
        workInProgress,
        renderExpirationTime
    )
        local props = workInProgress.memoizedProps
        invariant(
            props,
            "Should be resolved by now. This error is likely caused by a bug in React. Please file an issue."
        )

        -- First step of the call has completed. Now we need to do the second.
        -- TODO: It would be nice to have a multi stage call represented by a
        -- single component, or at least tail call optimize nested ones. Currently
        -- that requires additional fields that we don't want to add to the fiber.
        -- So this requires nested handlers.
        -- Note: This doesn't mutate the alternate node. I don't think it needs to
        -- since this stage is reset for every pass.
        workInProgress.tag = CallHandlerPhase

        -- Build up the returns.
        -- TODO: Compare this to a generator or opaque helpers like Children.
        local returns = {}
        appendAllReturns(returns, workInProgress)
        local fn = props.handler
        local childProps = props.props
        local nextChildren = fn(childProps, returns)

        local currentFirstChild = current ~= nil and current.child or nil

        workInProgress.child = reconcileChildFibers(
            workInProgress,
            currentFirstChild,
            nextChildren,
            renderExpirationTime
        )
        return workInProgress.child
    end

    local function appendAllchildren(parent, workInProgress)
        -- We only have the top Fiber that was created but we need recurse down its
        --  children to find all the terminal nodes.
        local node = workInProgress.child
        while node ~= nil do
            for __continue = 1, 1 do
                if node.tag == HostComponent or node.tag == HostText then
                    appendInitialChild(parent, node.stateNode)
                elseif node.tag == HostPortal then
                    -- If we have a portal child, then we don't want to traverse
                    -- down its children. Instead, we'll get insertions from each child in
                    -- the portal directly.
                elseif node.child ~= nil then
                    node.child["return"] = node
                    node = node.child
                    break
                end
                if node == workInProgress then
                    return
                end
                while node.sibling == nil do
                    if node["return"] == nil or node["return"] == workInProgress then
                        return
                    end
                    node = node["return"]
                end
                node.sibling["return"] = node["return"]
                node = node.sibling
            end
        end
    end

    local updateHostContainer
    local updateHostComponent
    local updateHostText
    if mutation then
        if enableMutatingReconciler then
            -- Mutation mode
            updateHostContainer = function(workInProgress)
                -- Noop
            end

            updateHostComponent = function(
                current,
                workInProgress,
                updatePayload,
                type_,
                oldProps,
                newProps,
                rootContainerInstance,
                currentHostContext
            )
                -- TODO: Type this specific to this type of component.
                workInProgress.updateQueue = updatePayload

                --If the update payload indicates that there is a change or if there
                -- is a new ref we mark this as an update. All the work is done in commitWork.
                if updatePayload then
                    markUpdate(workInProgress)
                end
            end

            updateHostText = function(
                current,
                workInProgress,
                oldText,
                newText
            )
                -- If the text differs, mark it as an update. All the work in done in commitWork.
                if oldText ~= newText then
                    markUpdate(workInProgress)
                end
            end

        else
            invariant(false, "Mutating reconciler is disabled.")
        end
    elseif persistence then
        if enablePersistentReconciler then
            -- Persistent host tree mode
            local cloneInstance = persistence.cloneInstance
            local createContainerChildSet = persistence.createContainerChildSet
            local appendChildToContainerChildSet = persistence.appendChildToContainerChildSet
            local finalizeContainerChildren = persistence.finalizeContainerChildren

            -- An unfortunate fork of appendAllChildren because we have two different parent types.
            local function appendAllChildrenToContainer(
                containerChildSet,
                workInProgress
            )
                -- We only have the top Fiber that was created but we need recurse down its
                -- children to find all the terminal nodes.
                local node = workInProgress.child
                while node ~= nil do
                    for __continue = 1, 1 do
                        if node.tag == HostComponent or node.tag == HostText then
                            appendChildToContainerChildSet(containerChildSet, node.stateNode)
                        elseif node.tag == HostPortal then
                            -- If we have a portal child, then we don't want to traverse
                            -- down its children. Instead, we'll get insertions from each child in
                            -- the portal directly.
                        elseif node.child ~= nil then
                            node.child["return"] = node
                            node = node.child
                            break
                        end
                        if node == workInProgress then
                            return
                        end
                        while node.sibling == nil do
                            if node["return"] == nil or node["return"] == workInProgress then
                                return
                            end
                            node = node["return"]
                        end
                        node.sibling["return"] = node["return"]
                        node = node.sibling
                    end
                end
            end

            local function updateHostContainer(workInProgress)
                local portalOrRoot = workInProgress.stateNode
                local childrenUnchanged = workInProgress.firstEffect == nil
                if childrenUnchanged then
                    -- No changes, just reuse the existing instance
                else
                    local container = portalOrRoot.containerInfo
                    local newChildSet = createContainerChildSet(container)
                    -- If children might have changed, we have to add them all to the set.
                    appendAllChildrenToContainer(newChildSet, workInProgress)
                    portalOrRoot.pendingChildren = newChildSet
                    -- Schedule an update on the container to swap out the container.
                    markUpdate(workInProgress)
                    finalizeContainerChildren(container, newChildSet)
                end
            end

            local function updateHostComponent(
                current,
                workInProgress,
                updatePayload,
                type_,
                oldProps,
                newProps,
                rootContainerInstance,
                currentHostContext
            )
                -- If there are no effects associated with this node, then none of our children had any updates.
                -- This guarantees that we can reuse all of them.
                local childrenUnchanged = workInProgress.firstEffect == nil
                local currentInstance = current.stateNode
                if childrenUnchanged and updatePayload == nil then
                    -- No changes, just reuse the existing instance.
                    -- Note that this might release a previous clone.
                    workInProgress.stateNode = currentInstance
                else
                    local recyclableInstance = workInProgress.stateNode
                    local newInstance = cloneInstance(
                      currentInstance,
                      updatePayload,
                      type,
                      oldProps,
                      newProps,
                      workInProgress,
                      childrenUnchanged,
                      recyclableInstance
                    )
                    if (
                        finalizeInitialChildren(
                            newInstance,
                            type,
                            newProps,
                            rootContainerInstance,
                            currentHostContext
                        )
                    ) then
                        markUpdate(workInProgress)
                    end
                    workInProgress.stateNode = newInstance
                    if childrenUnchanged then
                        -- If there are no other effects in this tree, we need to flag this node as having one.
                        -- Even though we're not going to use it for anything.
                        -- Otherwise parents won't know that there are new children to propagate upwards.
                        markUpdate(workInProgress)
                    else
                        -- If children might have changed, we have to add them all to the set.
                        appendAllChildren(newInstance, workInProgress)
                    end
                end
            end

            local function updateHostText(
                current,
                workInProgress,
                oldText,
                newText
            )
                if oldText ~= newText then
                    -- If the text content differs, we'll create a new text instance for it.
                    local rootContainerInstance = getRootHostContainer()
                    local currentHostContext = getHostContext()
                    workInProgress.stateNode = createTextInstance(
                        newText,
                        rootContainerInstance,
                        currentHostContext,
                        workInProgress
                      )
                    -- We'll have to mark it as having an effect, even though we won't use the effect for anything.
                    -- This lets the parents know that at least one of their children has changed.
                    markUpdate(workInProgress)
                end
            end

        else
            invariant(false, "Persistent reconciler is disabled.")
        end

    else
        if enableNoopReconciler then
            -- No host operations
            local function updateHostContainer(workInProgress)
              -- Noop
            end

            local function updateHostComponent(
                current,
                workInProgress,
                updatePayload,
                type_,
                oldProps,
                newProps,
                rootContainerInstance,
                currentHostContext
            )
                -- Noop
            end

            local function updateHostText(
                current,
                workInProgress,
                oldText,
                newText
            )
                -- Noop
            end
        else
            invariant(false, "Noop reconciler is disabled")
        end

    end

    local function completeWork(
        current,
        workInProgress,
        renderExpirationTime
    )
        local newProps = workInProgress.pendingProps
        for __switch = 1, 1 do
            local tag = workInProgress.tag
            if tag == FunctionalComponent then
                return nil
            elseif tag == ClassComponent then
                -- We are leaving this subtree so pop context if any
                popLegacyContextProvider(workInProgress)

                -- If this component caught an error, schedule an error log effect.
                local instance = workInProgress.stateNode
                local updateQueue = workInProgress.updateQueue
                if updateQueue ~= nil and updateQueue.capturedValues ~= nil then
                    workInProgress.effectTag = bit.band(workInProgress.effectTag, bit.bnot(DidCapture))
                    if type(instance.componentDidCatch) == "function" then
                        workInProgress.effectTag = bit.bor(workInProgress.effectTag, ErrLog)
                    else
                        -- Normally we clear this in the commit phase, but since we did not
                        -- schedule an effect, we need to reset it here.
                        updateQueue.capturedValues = nil
                    end
                end
                return nil
            elseif tag == HostRoot then
                popHostContainer(workInProgress)
                popTopLevelContextObject(workInProgress)
                local fiberRoot = workInProgress.stateNode
                if fiberRoot.pendingContext then
                    fiberRoot.context = fiberRoot.pendingContext
                    fiberRoot.pendingContext = nil
                end
                if current == nil or current.child == nil then
                    -- If we hydrated, pop so that we can delete any remaining children
                    -- that weren't hydrated.
                    popHydrationState(workInProgress)
                    -- This resets the hacky state to fix isMounted before committing.
                    -- TODO: Delete this when we delete isMounted and findDOMNode.
                    workInProgress.effectTag = bit.band(workInProgress.effectTag, bit.bnot(Placement))
                end
                updateHostContainer(workInProgress)

                local updateQueue = workInProgress.updateQueue
                if updateQueue ~= nil and updateQueue.capturedValues ~= nil then
                    workInProgress.effectTag = bit.bor(workInProgress.effectTag, ErrLog)
                end
                return nil
            elseif tag == HostComponent then
                popHostContext(workInProgress)
                local rootContainerInstance = getRootHostContainer()
                local type_ = workInProgress.type
                if current ~= nil and workInProgress.stateNode ~= nil then
                    -- If we have an alternate, that means this is an update and we need to
                    -- schedule a side-effect to do the updates.
                    local oldProps = current.memoizedProps
                    -- If we get updated because one of our children updated, we don't
                    -- have newProps so we'll have to reuse them.
                    -- TODO: Split the update API as separate for the props vs. children.
                    -- Even better would be if children weren't special cased at all tho.
                    local instance = workInProgress.stateNode
                    local currentHostContext = getHostContext()
                    -- TODO: Experiencing an error where oldProps is null. Suggests a host
                    -- component is hitting the resume path. Figure out why. Possibly
                    -- related to `hidden`.
                    local updatePayload = prepareUpdate(
                        instance,
                        type_,
                        oldProps,
                        newProps,
                        rootContainerInstance,
                        currentHostContext
                    )

                    updateHostComponent(
                        current,
                        workInProgress,
                        updatePayload,
                        type_,
                        oldProps,
                        newProps,
                        rootContainerInstance,
                        currentHostContext
                    )

                    if current.ref ~= workInProgress.ref then
                        markRef(workInProgress)
                    end
                else
                    if not newProps then
                        invariant(
                            workInProgress.stateNode ~= nil,
                            "We must have new props for new mounts. This error is likely caused by a bug in React. Please file an issue."
                        )
                        -- This can happen when we abort work
                        return nil
                    end

                    local currentHostContext = getHostContext()
                    -- TODO: Move createInstance to beginWork and keep it on a context
                    -- "stack" as the parent. Then append children as we go in beginWork
                    -- or completeWork depending on we want to add then top->down or
                    -- bottom->up. Top->down is faster in IE11.
                    local wasHydrated = popHydrationState(workInProgress)
                    if wasHydrated then
                        -- TODO: Move this and createInstance step into the beginPhase
                        -- to consolidate.
                        if (
                            prepareToHydrateHostInstance(
                                workInProgress,
                                rootContainerInstance,
                                currentHostContext
                            )
                        ) then
                            -- If changes to the hydrated node needs to be applied at the
                            -- commit-phase we mark this as such.
                            markUpdate(workInProgress)
                        end
                    else
                        local instance = createInstance(
                            type_,
                            newProps,
                            rootContainerInstance,
                            currentHostContext,
                            workInProgress
                        )

                        appendAllChildren(instance, workInProgress)

                        -- Certain renderers require commit-time effects for initial mount.
                        -- (eg DOM renderer supports auto-focus for certain elements).
                        -- Make sure such renderers get scheduled for later work.
                        if (
                            finalizeInitialChildren(
                                instance,
                                type_,
                                newProps,
                                rootContainerInstance,
                                currentHostContext
                            )
                        ) then
                            markUpdate(workInProgress)
                        end
                        workInProgress.stateNode = instance
                    end

                    if workInProgress.ref ~= nil then
                        -- If there is a ref on a host node we need to schedule a callback
                        markRef(workInProgress)
                    end
                end

                return nil
            elseif tag == HostText then
                local newText = newProps
                if current and workInProgress.stateNode ~= nil then
                    local oldText = current.memoizedProps
                    -- If we have an alternate, that means this is an update and we need
                    -- to schedule a side-effect to do the updates.
                    updateHostText(current, workInProgress, oldText, newText)
                else
                    if type(newText) ~= "string" then
                        invariant(
                            workInProgress.stateNode ~= nil,
                            "We must have new props for new mounts. This error is likely caused by a bug in React. Please file an issue."
                        )
                        -- This can happen when we abort work
                        return nil
                    end

                    local rootContainerInstance = getRootHostContainer()
                    local currentHostContext = getHostContext()
                    local wasHydrated = popHydrationState(workInProgress)
                    if wasHydrated then
                        if prepareToHydrateHostInstance(workInProgress) then
                            markUpdate(workInProgress)
                        end
                    else
                        workInProgress.stateNode = createTextInstance(
                            newText,
                            rootContainerInstance,
                            currentHostContext,
                            workInProgress
                        )
                    end
                end
                return nil
            elseif tag == CallComponent then
                return moveCallToHandlerPhase(
                    current,
                    workInProgress,
                    renderExpirationTime
                )
            elseif tag == CallHandlerPhase then
                -- Reset the tag to now be a first phase call.
                workInProgress.tag = CallComponent
                return nil
            elseif tag == ReturnComponent then
                -- Does nothing.
                return nil
            elseif tag == ForwardRef then
                return nil
            elseif tag == Fragment then
                return nil
            elseif tag == Mode then
                return nil
            elseif tag == HostPortal then
                popHostContainer(workInProgress)
                updateHostContainer(workInProgress)
                return nil
            elseif tag == ContextProvider then
                -- Pop provider fiber
                popProvider(workInProgress)
                return nil
            elseif tag == ContextConsumer then
                return nil
            -- Error cases
            elseif tag == IndeterminateComponent then
                invariant(
                    false,
                    "An indeterminate component should have become determinate before completing. This error is likely caused by a bug in React. Please file an issue."
                )
                return nil
            else
                invariant(
                    false,
                    "Unknown unit of work tag. This error is likely caused by a bug in React. Please file an issue."
                )
                return nil
            end
        end
    end

    return {
        completeWork = completeWork
    }
end

return ReactFiberCompleteWork
