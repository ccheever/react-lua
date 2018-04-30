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
                


            end

        end

             
    end
end


return ReactFiberCompleteWork


