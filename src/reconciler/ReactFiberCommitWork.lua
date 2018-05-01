local ReactFeatureFlags = require "ReactFeatureFlags"
local enableMutatingReconciler = ReactFeatureFlags.enableMutatingReconciler
local enableNoopReconciler = ReactFeatureFlags.enableNoopReconciler
local enablePersistentReconciler = ReactFeatureFlags.enablePersistentReconciler

local ReactTypeOfWork = require "ReactTypeOfWork"
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local CallComponent = ReactTypeOfWork.CallComponent

local ReactErrorUtils = require "ReactErrorUtils"
local invokeGuardedCallback = ReactErrorUtils.invokeGuardedCallback
local hasCaughtError = ReactErrorUtils.hasCaughtError
local clearCaughtError = ReactErrorUtils.clearCaughtError

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Placement = ReactTypeOfSideEffect.Placement
local Update = ReactTypeOfSideEffect.Update
local ContentReset = ReactTypeOfSideEffect.ContentReset
local Snapshot = ReactTypeOfSideEffect.Snapshot

local invariant = require "invariant"
local warning = require "warning"

local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local commitCallbacks = ReactFiberUpdateQueue.commitCallbacks
local ReactFiberDevToolsHook = require "ReactFiberDevToolsHook"
local onCommitUnmount = ReactFiberDevToolsHook.onCommitUnmount
local ReactDebugFiberPerf = require "ReactDebugFiberPerf"
local startPhaseTimer = ReactDebugFiberPerf.startPhaseTimer
local stopPhaseTimer = ReactDebugFiberPerf.stopPhaseTimer
local ReactFiberErrorLogger = require "ReactFiberErrorLogger"
local logCapturedError = ReactFiberErrorLogger.logCapturedError
local getComponentName = require "getComponentName"
local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber

local bit = require "bit"

local didWarnAboutUndefinedSnapshotBeforeUpdate = nil
if __DEV__ then
    didWarnAboutUndefinedSnapshotBeforeUpdate = {}
end

local function logError(boundary, errorInfo)
    local source = errorInfo.source
    local stack = errorInfo.stack
    if stack == nil then
        stack = getStackAddendumByWorkInProgressFiber(source)
    end

    local capturedError = {
        componentName = source ~= nil and getComponentName(source) or nil,
        componentStack = stack ~= nil and stack or "",
        error = errorInfo.value,
        errorBoundary = nil,
        errorBoundaryName = nil,
        errorBoundaryFound = false,
        willRetry = false
    }

    if boundary ~= nil and boundary.tag == ClassComponent then
        capturedError.errorBoundary = boundary.stateNode
        capturedError.errorBoundaryName = getComponentName(boundary)
        capturedError.errorBoundaryFound = true
        capturedError.willRetry = true
    end

    local ok, resultOrError = pcall(logCapturedError, capturedError)
    if not ok then
        -- Prevent cycle if logCapturedError() throws.
        -- A cycle may still occur if logCapturedError renders a component that throws.
        local e = resultOrError
        local suppressLogging = e and type(e) == "table" and e.suppressReactErrorLogging
        if not suppressLogging then
            io.stderr:write(e)
        end
    end
end

local function ReactFiberCommitWork(
    config,
    captureError,
    scheduleWork,
    computeExpirationForFiber,
    markLegacyErrorBoundaryAsFailed,
    recalculateCurrentTime
)
    local getPublicInstance = config.getPublicInstance
    local mutation = config.mutation
    local persistence = config.persistence

    local function callComponentWillUnmountWithTimer(current, instance)
        startPhaseTimer(current, "componentWillUnmount")
        instance.props = current.memoizedProps
        instance.state = current.memoizedState
        instance:componentWillUnmount()
        stopPhaseTimer()
    end

    -- Capture errors so they don't interrupt unmounting.
    local function safelyCallComponentWillUnmount(current, instance)
        if __DEV__ then
            -- dev stuff
        else
            local ok, unmountError = pcall(callComponentWillUnmountWithTimer, current, instance)
            if not ok then
                captureError(current, unmountError)
            end
        end
    end


    local function safelyDetachRef(current)
        local ref = current.ref
        if ref ~= nil then
            if type(ref) == "function" then
                if __DEV__ then
                    -- dev stuff
                else
                    local ok, refError = pcall(ref, nil)
                    if not ok then
                        captureError(current, refError)
                    end
                end
            else
                ref.current = nil
            end
        end
    end

    local function commitBeforeMutationLifeCycles(current, finishedWork)
        for __switch = 1, 1 do
            local tag = finishedWork.tag
            if tag == ClassComponent then
                if bit.band(finishedWork.effectTag, Snapshot) > 0 then
                    if current ~= nil then
                        local prevProps = current.memoizedProps
                        local prevState = current.memoizedState
                        startPhaseTimer(finishedWork, "getSnapshotBeforeUpdate")
                        local instance = finishedWork.stateNode
                        instance.props = finishedWork.stateNode
                        instance.props = finishedWork.memoizedProps
                        instance.state = finishedWork.memoizedState
                        local snapshot = instance.getSnapshotBeforeUpdate(
                            prevProps,
                            prevState
                        )
                        if __DEV__ then
                            -- TODO(ccheever): some warning stuff
                        end
                        instance.__reactInternalSnapshotBeforeUpdate = snapshot
                        stopPhaseTimer()
                    end
                end
                return
            elseif tag == HostRoot or
                    tag == HostComponent or 
                    tag == HostText or 
                    tag == HostPortal then
                return
            else
                invariant(
                    false,
                    "This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
                )
            end
        end
    end

    local function commitLifeCycles(
        finishedRoot,
        current,
        finishedWork,
        currentTime,
        committedExpirationTime
    )
        for __switch = 1, 1 do
            local tag = finishedWork.tag
            if tag == ClassComponent then
                local instance = finishedWork.stateNode
                if bit.band(finishedWork.effectTag, Update) > 0 then
                    if current == nil then
                        startPhaseTimer(finishedWork, "componentDidMount")
                        instance.props = finishedWork.memoizedProps
                        instance.state = finishedWork.memoizedState
                        instance:componentDidMount();
                        stopPhaseTimer()
                    else
                        local prevProps = current.memoizedProps
                        local prevState = current.memoizedState
                        startPhaseTimer(finishedWork, 'componentDidUpdate')
                        instance.props = finishedWork.memoizedProps
                        instance.state = finishedWork.memoizedState
                        instance:componentDidUpdate(
                          prevProps,
                          prevState,
                          instance.__reactInternalSnapshotBeforeUpdate
                        )
                        stopPhaseTimer()
                    end
                end
                local updateQueue = finishedWork.updateQueue
                if updateQueue ~= nil then
                    commitCallbacks(updateQueue, instance)
                end
                return
            elseif tag == HostRoot then
                local updateQueue = finishedWork.updateQueue
                if updateQueue ~= nil then
                    local instance = nil
                    if finishedWork.child ~= nil then
                        if finishedWork.child.tag == HostComponent then
                            instance = getPublicInstance(finishedWork.child.stateNode)
                        elseif finishedWork.child.tag == ClassComponent then
                            instance = finishedWork.child.stateNode
                        end
                    end
                    commitCallbacks(updateQueue, instance)
                end
                return
            elseif tag == HostComponent then
                local instance = finishedWork.stateNode
                -- Renderers may schedule work to be done after host components are mounted
                -- (eg DOM renderer may schedule auto-focus for inputs and form controls).
                -- These effects should only be committed when components are first mounted,
                -- aka when there is no current/alternate.
                if current == nil and bit.band(finishedWork.effectTag, Update) > 0 then
                    local type_ = finishedWork.type
                    local props = finishedWork.memoizedProps
                    commitMount(instance, type_, props, finishedWork)
                end

                return

            elseif tag == HostText then
                -- We have no life-cycles associated with text
                return
            elseif tag == HostPortal then
                -- We have no life-cycles associated with portals
                return
            else
                invariant(
                    false,
                    "This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
                )
            end
        end
    end

    local function commitErrorLogging(
        finishedWork,
        onUncaughtError
    )
        for __switch = 1, 1 do
            local tag = finishedWork.tag
            if tag == ClassComponent then
                local ctor = finishedWork.type
                local isntance = finishedWork.stateNode
                local updateQueue = finishedWork.updateQueue
                invariant(
                    updateQueue ~= nil and updateQueue.capturedValues ~= nil,
                    "An error logging effect should not have been scheduled if no errors were captured. This error is likely caused by a bug in React. Please file an issue."
                )
                local capturedErrors = updateQueue.capturedValues
                updateQueue.capturedValues = nil

                if type(ctor.getDerivedStateFromCatch) ~= "function" then
                    -- To preserve the preexisting retry behavior of error boundaries,
                    -- we keep track of which ones already failed during this batch.
                    -- This gets reset before we yield back to the browser.
                    -- TODO: Warn in strict mode if getDerivedStateFromCatch is
                    -- not defined.
                    markLegacyErrorBoundaryAsFailed(instance)
                end

                instance.props = finishedWork.memoizedProps
                instance.state = finishedWork.memoizedState
                for i, errorInfo in ipairs(capturedErrors) do
                    local error_ = errorInfo.value
                    local stack = errorInfo.stack
                    logError(finishedWork, errorInfo)
                    instance:componentDidCatch(error_, {
                        componentStack = stack ~= nil and stack or ""
                    })
                end
            elseif tag == HostRoot then
                local updateQueue = finishedWork.updateQueue
                invariant(
                    updateQueue ~= nil and updateQueue.capturedValues ~= nil,
                    "An error logging effect should not have been scheduled if no errors were captured. This error is likely caused by a bug in React. Please file an issue."
                )
                local capturedErrors = updateQueue.capturedValues
                updateQueue.capturedValues = nil
                for i, errorInfo in ipairs(capturedErrors) do
                    logError(finishedWork, errorInfo)
                    onUncaughtError(errorInfo.value)
                end
            else
                invariant(
                    false,
                    "This unit of work tag cannot capture errors.  This error is likely caused by a bug in React. Please file an issue."
                )
            end

        end
    end

    local function commitAttachRef(finishedWork)
        local ref = finishedWork.ref
        if ref ~= nil then
            local instance = finishedWork.stateNode
            local instanceToUse
            if finishedWork.tag == HostComponent then
                instanceToUse = getPublicInstance(instance)
            else
                instanceToUse = instance
            end
            if type(ref) == "function" then
                ref(instanceToUse)
            else
                if __DEV__ then
                    -- TODO(ccheever): Some warning stuff
                end
                ref.current = instanceToUse
            end
        end
    end

    local function commitDetachRef(current)
        local currentRef = current.ref
        if currentRef ~= nil then
            if type(currentRef) == "function" then
                currentRef(nil)
            else
                currentRef.current = nil
            end
        end
    end

    -- User-originating errors (lifecycles and refs) should not interrupt
    -- deletion, so don't let them throw. Host-originating errors should
    -- interrupt deletion, so it's okay
    local function commitUnmount(current) 
        if type(onCommitUnmount) == "function" then
            onCommitUnmount(current)
        end

        for __switch = 1, 1 do 
            local tag = current.tag
            if tag == ClassComponent then
                safelyDetachRef(current)
                local instance = current.stateNode
                if type(instance.componentWillUnmount) == "function" then
                    safelyCallComponentWillUnmount(current, instance)
                end
                return
            elseif tag == HostComponent then
                safelyDetachRef(current)
                return
            elseif tag == CallComponent then
                commitNestedUnmounts(current.stateNode)
                return
            elseif tag == HostPortal then
                -- TODO: this is recursive.
                -- We are also not using this parent because
                -- the portal will get pushed immediately.
                if bit.band(enableMutatingReconciler, mutation) > 0 then
                    unmountHostComponents(current)
                elseif bit.band(enablePersistentReconciler, persistence) > 0 then
                    emptyPortalContainer(current)
                end
                return
            end
        end
    end

    local function commitNestedUnmounts(root)
        -- While we're inside a removed host node we don't want to call
        -- removeChild on the inner nodes because they're removed by the top
        -- call anyway. We also want to call componentWillUnmount on all
        -- composites before this host node is removed from the tree. Therefore
        -- we do an inner loop while we're still inside the host node.
        local node = root
        while true do
            for __continue = 1, 1 do
                commitUnmount(node)
                -- Visit children because they may contain more composite or host nodes.
                -- Skip portals because commitUnmount() currently visits them recursively.
                if (
                    node.child ~= nil and 
                    -- If we use mutation we drill down into portals using commitUnmount above.
                    -- If we don't use mutation we drill down into portals here instead.
                    (not mutation or node.tag ~= HostPortal)
                ) then
                    node.child["return"] = node
                    node = node.child
                    break
                end
                if node == root then
                    return
                end
                while node.sibling == nil do
                    if node["return"] == nil or node["return"] == root then
                        return
                    end
                    node = node["return"]
                end
                node.sibling["return"] = node["return"]
                node = node.sibling
            end
        end
    end

    local function detachFiber(current)
        -- Cut off the return pointers to disconnect it from the tree. Ideally, we
        -- should clear the child pointer of the parent alternate to let this
        -- get GC:ed but we don't know which for sure which parent is the current
        -- one so we'll settle for GC:ing the subtree of this child. This child
        -- itself will be GC:ed when the parent updates the next time.
        current.child = nil
        if current.alternate then
          current.alternate.child = nil
          current.alternate["return"] = nil
        end
    end

        local emptyPortalContainer

        if not mutation then
            local commitContainer
            if persistence then
                local replaceContainerChildren = persistence.replaceContainerChildren
                local createContainerChildSet = persistence.createContainerChildSet
                emptyPortalContainer = function(current)
                    local portal = current.stateNode
                    local containerInfo = portal.containerInfo
                    local emptyChildSet = createContainerChildSet(containerInfo)
                    replaceContainerChildren(containerInfo, emptyChildSet)
                end
                commitContainer = function(finishedWork)
                    local tag = finishedWork.tag
                    for __switch = 1, 1 do
                        if tag == ClassComponent then
                            return 
                        elseif tag == HostComponent then
                            return
                        elseif tag == HostText then
                            return
                        elseif tag == HostRoot or tag == HostPortal then
                            local portalRoot = finishedWork.stateNode
                            local containerInfo = portalOrRoot.containerInfo
                            local pendingChildren = portalOrRoot.pendingChildren
                            replaceContainerChildren(containerInfo, pendingChildren)
                            return
                        else
                            invariant(
                                false,
                                "This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
                            )
                        end
                    end
                end

            else
                commitContainer = function(finishedWork)
                    -- Noop
                end
            end

            if enablePersistentReconciler or enableNoopReconciler then
                return {
                    commitResetTextContext = function (finishedWork) end,
                    commitPlacement = function (finishedWork) end,
                    commitDeletion = function (current)
                        -- Detach refs and call componentWillUnmount() on the whole subtree.
                        commitNestedUnmounts(current)
                        detachFiber(current)
                    end,
                    commitWork = function (current, finishedWork)
                        commitContainer(finishedWork)
                    end,
                    commitLifeCycles = commitLifeCycles,
                    commitBeforeMutationLifeCycles = commitBeforeMutationLifeCycles,
                    commitErrorLogging = commitErrorLogging,
                    commitAttachRef = commitAttachRef,
                    commitDetachRef = commitDetachRef
                }
            elseif persistence then
                invariant(
                    false,
                    "Persistent reconciler is disaibled."
                )
            else
                invariant(false, "Noop reconciler is disabled")
            end
        end
    end

    local commitMount = mutation.commitMount
    local commitUpdate = mutation.commitUpdate
    local resetTextContent = mutation.resetTextContent
    local commitTextUpdate = mutation.commitTextUpdate
    local appendChild = mutation.appendChild
    local appendChildToContainer = mutation.appendChildToContainer
    local insertBefore = mutation.insertBefore
    local insertInContainerBefore = mutation.insertInContainerBefore
    local removeChild = mutation.removeChild
    local removeChildFromContainer = mutation.removeChildFromContainer
    local insertInContainerBefore = mutation.insertInContainerBefore

    local function getHostParentFiber(fiber)
        -- TODO(ccheever): start from here
    end

end
