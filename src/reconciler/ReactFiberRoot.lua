local ReactFiber = require "ReactFiber"
local createHostFiber = ReactFiber.createHostFiber
local ReactFiberExpirationTime = require "ReactFiberExpirationTime"
local NoWork = ReactFiberExpirationTime.NoWork

local function createFiberRoot(
    containerInfo,
    isAsync,
    hydrate
)
    -- Cyclic construction. This cheats the type system right now because
    -- stateNode is any.
    local uninitializedFiber = createHostRootFiber(isAsync)
    local root = {
        current = uninitializedFiber,
        containerInfo = containerInfo,
        pendingChildren = nil,
        pendingCommitExpirationTime = NoWork,
        finishedWork = nil,
        context = nil,
        hydrate = hydrate,
        remainingExpirationTime = NoWork,
        firstBatch = nil,
        nextScheduledRoot = nil
    }
    uninitializedFiber.stateNode = root
    return root
end

return {
    createFiberRoot = createFiberRoot
}