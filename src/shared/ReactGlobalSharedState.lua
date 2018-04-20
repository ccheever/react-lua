local React = require "React"

local ReactInternals = React.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED

local ReactCurrentOwner = ReactInternals.ReactCurrentOwner
local ReactDebugCurrentFrame
if __DEV__ then
    ReactDebugCurrentFrame = ReactInternals.ReactDebugCurrentFrame
else
    ReactDebugCurrentFrame = nil
end

return {
    ReactCurrentOwner = ReactCurrentOwner,
    ReactDebugCurrentFrame = ReactDebugCurrentFrame
}