local warning = require "warning"
local __REACT_DEVTOOLS_GLOBAL_HOOK__

local onCommitFiberRoot = nil
local onCommitFiberUnmount = nil
local hasLoggedError = false

local function catchErrors(fn)
    return function (arg) 
        local ok, resultOrError = pcall(fn, arg)
        if ok then
            return resultOrError
        else
            if __DEV__ and not hasLoggedError then
                hasLoggedError = true
                warning(false, "React DevTools encountered an error: " .. resultOrError)
            end
        end
    end
end

local function injectInternals(internals)
    if __REACT_DEVTOOLS_GLOBAL_HOOK__ == nil then
        -- No DevTools
        return false
    end

    local hook = __REACT_DEVTOOLS_GLOBAL_HOOK__
    if hook.isDisabled then
        -- This isn't a real property on the hook, but it can be set to opt out
        -- of DevTools integration and associated warnings and logs.
        -- https://github.com/facebook/react/issues/3877
        return true
    end

    if not hook.supportsFiber then
        if __DEV__ then
            warning(
                false,
                "The installed version of React DevTools is too old and will not work with the current version of React. Please update React DevTools. https://fb.me/react-devtools"
            )
        end
        -- DevTools exists, even though it doesn't support Fiber.
        return true
    end

    local ok, resultOrError = pcall(function () 
        local rendererID = hook.inject(internals)
        -- We have successfully injected, so now it is safe to set up hooks.
        onCommitFiberRoot = catchErrors(function (root)
            hook.onCommitFiberRoot(rendererID, root)
        end)
        onCommitFiberUnmount = catchErrors(function (fiber)
            hook.onCommitFiberUnmount(rendererID, fiber)
        end)
    end)

    if not ok then
        -- Catch all errors because it is unsafe to throw during initialization.
        if __DEV__ then
            warning(false, "React DevTools encountered an error: " .. resultOrError)
        end
    end

    -- DevTools exists
    return true
end

local function onCommitRoot(root)
    if type(onCommitFiberRoot) == "function" then
        onCommitFiberRoot(root)
    end
end

local function onCommitUnmount(fiber)
    if type(onCommitFiberUnmount) == "function" then
        onCommitFiberUnmount(fiber)
    end
end

return {
    injectInternals = injectInternals,
    onCommitRoot = onCommitRoot,
    onCommitUnmount = onCommitUnmount
}