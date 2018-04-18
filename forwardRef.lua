local warning = require "warning"

local function forwardRef(render)
    if __DEV__ then
        warning(type(render) == "function", "forwardRef requires a render function but was given " .. type(render))
    end

    return {
        ["$$typeof"] = "REACT_FORWARD_REF_TYPE",
        render = render
    }

end

return forwardRef