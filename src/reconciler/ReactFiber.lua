local Object = require "classic"

local invariant = require "invariant"

local bit = require "bit"
local ReactTypeOfMode = require "ReactTypeOfMode"


local getComponentName = require "getComponentName"
local ReactFiberExpirationTime = require "ReactFiberExpirationTime"

local hasBadMapPolyfill

if __DEV__ then
    hasBadMapPolyfill = true
end

local debugCounter

if __DEV__ then
    debugCounter = 1
end

local FiberNode = Object:extend()

function FiberNode:new(tag, pendingProps, key, mode)

    -- Instance
    self.tag = tag
    self.key = key
    self.type = nil
    self.stateNode = nil

    -- Fiber
    self["return"] = nil
    self.child = nil
    self.sibling = nil
    self.index = 0

    self.ref = nil
    self.pendingProps = pendingProps
    self.memoizedProps = nil
    self.updateQueue = nil
    self.memoizedState = nil

    self.mode = mode

    -- Effects
    self.effectTag = NoEffect
    self.nextEffect = nil


    self.firstEffect = nil
    self.lastEffect = nil

    self.expirationTime = "NoWork"

    self.alternate = nil

    if __DEV__ then
        self._debugId = debugCounter
        debugCounter = debugCounter + 1
        self._debugOwner = nil
        self._debugIsCurrentlyTiming = false
    end

end

-- This is a constructor function, rather than a POJO constructor, still
-- please ensure we do the following:
-- 1) Nobody should add any instance methods on this. Instance methods can be
--    more difficult to predict when they get optimized and they are almost
--    never inlined properly in static compilers.
-- 2) Nobody should rely on `instanceof Fiber` for type testing. We should
--    always know when it is a fiber.
-- 3) We might want to experiment with using numeric keys since they are easier
--    to optimize in a non-JIT environment.
-- 4) We can easily go from a constructor to a createFiber object literal if that
--    is faster.
-- 5) It should be easy to port this to a C struct and keep a C implementation
--    compatible.
local createFiber = function(tag, pendingProps, key, mode)
    return FiberNode(tag, pendingProps, key, mode)
end

local function shouldConstruct(Component)
    return type(Component) == "table" and Component.isReactComponent
end

local function createWorkInProgress(
    current,
    pendingProps,
    expirationTime)
    local workInProgress = current.alternate
    if workInProgress == nil then
        -- We use a double buffering pooling technique because we know that we'll
        -- only ever need at most two versions of a tree. We pool the "other" unused
        -- node that we're free to reuse. This is lazily created to avoid allocating
        -- extra objects for things that are never updated. It also allow us to
        -- reclaim the extra memory if needed.
        workInProgress = createFiber(
            current.tag,
            pendingProps,
            current.key,
            current.mode
        )
        workInProgress.type = current.type
        workInProgress.stateNode = current.stateNode

        if __DEV__ then
            workInProgress._debugId = current._debugId
            workInProgress._debugSource = current._debugSource
            workInProgress._debugOwner = current._debugOwner
        end

        workInProgress.alternate = current
        current.alternate = workInProgress
    else
        workInProgress.pendingProps = pendingProps

        -- We already have an alternate
        -- Reset the effect tag
        workInProgress.effectTag = "NoEffect"

        -- The effect list is no longer valid
        workInProgress.nextEffect = nil
        workInProgress.firstEffect = nil
        workInProgress.lastEffect = nil

    end

    workInProgress.expirationTime = expirationTime

    workInProgress.child = current.child
    workInProgress.memoizedProps = current.memoizedProps
    workInProgress.memoizedState = current.memoizedState
    workInProgress.updateQueue = current.updateQueue

    -- These will be overridden during the parent's reconciliation
    workInProgress.sibling = current.sibling
    workInProgress.index = current.index
    workInProgress.ref = current.ref
    
    return workInProgress
end

local function createHostRootFiber(isAsync)
    local mode
    if isAsync then
        mode = bit.bor(ReactTypeOfMode.AsyncMode, ReactTypeOfMode.StrictMode)
    else
        mode = ReactTypeOfMode.NoContext
    end
    return createFiber("HostRoot", nil, nil, mode)
end

local function createFiberFromElement(
    element, mode, expirationTime
)
    local owner = nil
    if __DEV__ then
        owner = element._owner
    end

    local fiber
    local ty = element.type
    local key = element.key
    local pendingProps = element.props

    local fiberTag
    if type(ty) == "function" then
        fiberTag = shouldConstruct(ty) and "ClassComponent" or "IndeterminateComponent"
    elseif type(ty) == "string" then
        fiberTag = "HostComponent"
    else
        if ty == "REACT_FRAGMENT_TYPE" then
            return createFiberFromFragment(
                pendingProps.children,
                mode, 
                expirationTime,
                key
            )
        elseif ty == "REACT_ASYNC_MODE_TYPE" then
            fiberTag = "Mode"
            mode = bit.bor(mode, ReactTypeOfMode.AsyncMode, ReactTypeOfMode.StrictMode)
        elseif ty == "REACT_STRICT_MODE_TYPE" then
            fiberTag = "Mode"
            mode = bit.bor(mode, ReactTypeOfMode.StrictMode)
        elseif ty == "REACT_CALL_TYPE" then
            fiberTag = "CallComponent"
        elseif ty == "REACT_RETURN_TYPE" then
            fiberTag = "ReturnComponent"
        else
            if type(ty) == "table" then
                local typeof = ty["$$typeof"]
                if typeof == "REACT_PROVIDER_TYPE" then
                    fiberTag = "ContextProvider"
                elseif typeof == "REACT_CONTEXT_TYPE" then
                    -- This is a consumer
                    fiberTag = "ContextConsumer"
                elseif typeof == "REACT_FORWARD_REF_TYPE" then
                    fiberTag = "ForwardRef"
                else
                    if type(ty.tag) == "string" then
                        -- Currently assumed to be a continuation and therefore is a
                        -- fiber already.
                        -- TODO: The yield system is currently broken for updates in
                        -- some cases. The reified yield stores a fiber, but we don't
                        -- know which fiber that is; the current or a workInProgress?
                        -- When the continuation gets rendered here we don't know if we
                        -- can reuse that fiber or if we need to clone it. There is
                        -- probably a clever way to restructure this.
                        fiber = ty
                        fiber.pendingProps = pendingProps
                        fiber.expirationTime = expirationTime
                        return fiber
                    else
                        throwOnInvalidElementType(ty, owner)
                    end
                end
            else
                throwOnInvalidElementType(ty, owner)
            end
        end
    end

    fiber = createFiber(fiberTag, pendingProps, key, mode)
    fiber.type = ty
    fiber.expirationTime = expirationTime

    if __DEV__ then
        fiber._debugSource = element._source
        fiber._debugOwner = element._owner
    end
    
    return fiber

end

local function throwOnInvalidElementType(t, owner)
    local info = ""
    if __DEV__ then
        if t == nil or (type(t) == "table" and #t == 0) then
            info = info .. " You likely forgot to export your component from the file it's defined in or something like that."
        end
        local ownerName = owner and getComponentName(owner) or nil
        if ownerName then
            info = info .. "\n\nCheck the render method of `" .. ownerName .. "`."
        end
    end

    invariant(false, "Element type is invalid: expected a string (for built-in components) or a class/function (for composite components) but got " .. t .. "." .. info)

end

local function createFiberFromFragment(elements, mode, expirationTime, key)
    local fiber = createFiber("Fragment", elements, key, mode)
    fiber.expirationTime = expirationTime
    return fiber
end

local function createFiberFromText(content, mode, expirationTime)
    local fiber = createFiber("HostText", content, nil, mode)
    fiber.expirationTime = expirationTime
    return fiber
end

local function createFiberFromHostInstanceForDeletion()
    local fiber = createFiber("HostComponent", null, null, ReactTypeOfMode.NoContext)
    fiber.type = "DELETED"
    return fiber
end

local function createFiberFromPortal(portal, mode, expirationTime)
    local pendingProps = portal.children ~= nil and portal.children or {}
    local fiber = createFiber("HostPortal", pendingProps, portal.key, mode)
    fiber.expirationTime = expirationTime
    fiber.stateNode = {
        containerInfo = portal.containerInfo,
        pendingChildren = nil, -- Used by persistent updates
        implementation = portal.implementation
    }
    return fiber
end

-- Used for stashing WIP properties to replay failed work in DEV
local function assignFiberPropertiesInDEV(target, source)
    if target == nil then
        -- This Fiber's initial properites will always be overwritten
        -- We only use a Fiber to ensure the same hidden class so DEV isn't slow
        target = createFiber("IndeterminateComponent", nil, nil, ReactTypeOfMode.NoContext)
    end

    target.tag = source.tag
    target.key = source.key
    target.type = source.type
    target.stateNode = source.stateNode
    target["return"] = source["return"]
    target.child = source.child
    target.sibling = source.sibling
    target.index = source.index
    target.ref = source.ref
    target.pendingProps = source.pendingProps
    target.memoizedProps = source.memoizedProps
    target.updateQueue = source.updateQueue
    target.memoizedState = source.memoizedState
    target.mode = source.mode
    target.effectTag = source.effectTag
    target.nextEffect = source.nextEffect
    target.firstEffect = source.firstEffect
    target.lastEffect = source.lastEffect
    target.expirationTime = source.expirationTime
    target.alternate = source.alternate
    target._debugID = source._debugID
    target._debugSource = source._debugSource
    target._debugOwner = source._debugOwner
    target._debugIsCurrentlyTiming = source._debugIsCurrentlyTiming
    return target

end

return {
    createWorkInProgress = createWorkInProgress,
    createHostRootFiber = createHostRootFiber,
    createFiberFromElement = createFiberFromElement,
    createFiberFromFragment = createFiberFromFragment,
    createFiberFromText = createFiberFromText,
    createFiberFromHostInstanceForDeletion = createFiberFromHostInstanceForDeletion,
    createFiberFromPortal = createFiberFromPortal,
    assignFiberPropertiesInDEV = assignFiberPropertiesInDEV
}