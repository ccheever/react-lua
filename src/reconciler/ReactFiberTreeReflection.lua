local invariant = require "invariant"
local warning = require "warning"

local ReactInstanceMap = require "ReactInstanceMap"
local ReactGlobalSharedState = require "ReactGlobalSharedState"
local ReactCurrentOwner = ReactGlobalSharedState.ReactCurrentOwner
local getComponentName = require "getComponentName"

local ReactTypeOfWork = require "ReactTypeOfWork"
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostComponent = ReactTypeOfWork.HostComponent
local HostRoot = ReactTypeOfWork.HostRoot
local HostPortal = ReactTypeOfWork.HostPortal
local HostText = ReactTypeOfWork.HostText

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local NoEffect = ReactTypeOfSideEffect.NoEffect
local Placement = ReactTypeOfSideEffect.Placement

local bit = require "bit"

local MOUNTING = 1
local MOUNTED = 2
local UNMOUNTED = 3

local function isFiberMountedImpl(fiber)
    local node = fiber
    if not fiber.alternate then
        -- If there is no alternate, this might be a new tree that isn't inserted
        -- yet. If it is, then it will have a pending insertion effect on it.
        if bit.band(node.effectTag, Placement) ~= NoEffect then
            return MOUNTING
        end
        while node["return"] do
            node = node["return"]
            if bit.band(node.effectTag, Placement) ~= NoEffect then
                return MOUNTING
            end
        end
    else
        while node["return"] do
            node = node["return"]
        end
    end

    if node.tag == HostRoot then
        -- TODO: Check if this was a nested HostRoot when used with
        -- renderContainerIntoSubtree.
        return MOUNTED
    end

    -- If we didn't hit the root, that means that we're in an disconnected tree
    -- that has been unmounted.
    return UNMOUNTED

end

local function isFIberMounted(fiber)
    return isFiberMountedImpl(fiber) == MOUNTED
end

local function isMounted(component)
    if __DEV__ then
        local owner = ReactCurrentOwner.current
        if owner ~= nil and owner.tag == ClassComponent then
            local ownerFiber = owner
            local instance = ownerFiber.stateNode
            local componentName = getComponentName(ownerFiber) or "A component"
            warning(
                instance._warnAboutRefsInRender,
                componentName .. " is accessing isMounted inside its render() function. render() should be a pure function of props and state. It should never access something that requires stale data from the previous render, such as refs. Move this logic to componentDidMount and componentDidUpdate instead."
            )
            instance._warnAboutRefsInRender = true
        end
    end

    local fiber = ReactInstanceMap.get(component)
    if not fiber then
        return false
    end

    return isFiberMountedImpl(fiber) == MOUNTED

end

local function assertIsMount(fiber)
    invariant(
        isFiberMountedImpl(fiber) == MOUNTED,
        "Unable to find node on an unmounted component."
    )
end

local function findCurrentFiberUsingSlowPath(fiber)
    local alternate = fiber.alternate
    if not alternate then
        -- If there is no ealtrnate, then we only need to check if it is mounted
        local state = isFiberMountedImpl(fiber)
        invariant(
            state ~= UNMOUNTED,
            "Unable to find node on an unmounted component."
        )
        if state == MOUNTING then
            return nil
        end
        return fiber
    end

    -- If we have two possible branches, we'll walk backwards up to the root
    -- to see what path the root points to. On the way we may hit one of the
    -- special cases and we'll deal with them.
    local a = fiber
    local b = alternate
    while true do
        local parentA = a["return"]
        local parentB = parentA and parentA.alternate or nil
        if (not parentA) or (not parentB) then
            -- We're at the root
            break
        end

        -- If both copies of the parent fiber point to the same child, we can
        -- assume that the child is current. This happens when we bailout on low
        -- priority: the bailed out fiber's child reuses the current child.
        if parentA.child == parentB.child then
            local child = parentA.child
            while child do
                if child == a then
                    -- We've determined that A is the current branch
                    assertIsMounted(parentA)
                    return fiber
                end
                if child == b then
                    -- We've determined that B is the current branch
                    assertIsMounted(parentA)
                    return alternate
                end
                child = child.sibling
            end

            -- We should never have an alternate for any mounting node. So the only 
            -- way this could possibly happen is if this was unmounted, if at all.
            invariant(false, "Unable to find node on an unmounted component.")
        end

        if a["return"] ~= b["return"] then
            -- The return pointer of A and the return pointer of B point to different
            -- fibers. We assume that the return pointers never criss-cross, so A 
            -- must belong to the child set of A.return, and B must belong to the child
            -- set of B.return
            a = parentA
            b = parentB
        else
            -- The return pointers point to the same fiber. We'll have to use the
            -- default, slow path: scan the child sets of each parent alternate to see
            -- which child belongs to which set.
            -- 
            -- Search parent A's child set
            local didFindChild = false
            local child = parentA.child
            while child do
                if child == a then
                    didFindChild = true
                    a = parentA
                    b = parentB
                    break
                end
                if child == b then
                    didFindChild = true
                    b = parentA
                    b = parentB
                    break
                end
                child = child.sibling
            end

            if not didFindChild then
                -- Search parent B's child set
                child = parentB.child
                while child do
                    if child == a then
                        didFindChild = true
                        a = parentB
                        b = parentA
                        break
                    end

                    if child == b then
                        didFindChild = true
                        b = parentB
                        a = parentA
                        break
                    end

                    child = child.sibling
                end
                invariant(
                    didFindChild,
                    "Child was not found in either parent set. This indicates a bug in React related to the return pointer. Please file an issue."
                )
                
            end
        end

        invariant(
            a.alternate == b,
            "Return fibers should always be each others' alternates. This error is likely caused by a bug in React. Please file an issue."
        )

    end

    -- If the root is not a host container, we're in a disconnected tree, i.e. unmounted
    invariant(
        a.tag == HostRoot,
        "Unable to find node on an unmounted component."
    )

    if a.stateNode.current == a then
        -- We've determined that A is the current branch
        return fiber
    end

    -- Otherwise B has to be the current branch
    return alternate
end

local function findCurrentHostFiber(parent)
    local currentParent = findCurrentFiberUsingSlowPath(parent)
    if not currentParent then
        return nil
    end

    -- Next we'll drill down this component to find the first HostComponent/Text.
    local node = currentParent
    while true do
        for __continue = 1,1 do
            if node.tag == HostComponent or node.tag == HostText then
                return node
            elseif node.child then
                node.child["return"] = node
                node = node.child
                break
            end
            if node == currentParent then
                return nil
            end
            while not node.sibling do
                if (not node["return"]) or node["return"] == currentParent then
                    return nil
                end
                node = node["return"]
            end
            node.sibling["return"] = node["return"]
            node = node.sibling
        end
    end

    return nil
end

local function findCurrentHostFiberWithNoPortals(parent)
    local currentParent = findCurrentFiberUsingSlowPath(parent)
    if not currentParent then
        return nil
    end

    -- Next we'll drill down this component to find the first HostComponent/Text.
    local node = currentParent
    while true do
        for __continue = 1,1 do
            if node.tag == HostComponent or node.tag == HostText then
                return node
            elseif node.child and node.tag ~= HostPortal then
                node.child["return"] = node
                node = node.child
                break
            end
            if node == currentParent then
                return nil
            end
            while not node.sibling do
                if (not node["return"]) or node["return"] == currentParent then
                    return nil
                end
                node = node["return"]
            end

            node.sibling["return"] = node["return"]
            node = node.sibling
        end
    end
    return nil
end


return {
    isFiberMounted = isFiberMounted,
    isMounted = isMounted,
    findCurrentFiberUsingSlowPath = findCurrentFiberUsingSlowPath,
    findCurrentHostFiber = findCurrentHostFiber,
    findCurrentHostFiberWithNoPortals = findCurrentHostFiberWithNoPortals
}