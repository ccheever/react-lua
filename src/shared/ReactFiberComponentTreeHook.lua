local describeComponentFrame = require "describeComponentFrame"
local getComponentName = require "getComponentName"

local function describeFiber(fiber)
    local tag = fiber.tag
    if tag == "IndeterminateComponent" or tag == "FunctionalComponent" or tag == "ClassComponent" or tag == "HostComponent" then
        local owner = fiber._debugOwner
        local source = fiber._debugSource
        local name = getComponentName(fiber)
        local ownerName = nil
        if owner then
            ownerName = getComponentName(owner)
        end
        return describeComponentFrame(name, source, ownerName)
    else
        return ""
    end
end

-- This function can only be called with a work-in-progress fiber and
-- only during begin or complete phase. Do not call it under any other
-- circumstances.
local function getStackAddendumByWorkInProgressFiber(workInProgress)
    local info = ""
    local node = workInProgress
    repeat
        info = info .. describeFiber(node)
        -- Otherwise this return pointer might point to the wrong tree
        node = node["return"]
    until not node
    return info
end

return {
    describeFiber = describeFiber,
    getStackAddendumByWorkInProgressFiber = getStackAddendumByWorkInProgressFiber
}