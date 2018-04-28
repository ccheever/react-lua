local invariant = require "invariant"

local NO_CONTEXT = {}

local function ReactFiberHostContext(config, stack)
    local getChildHostContext = child.getChildHostContext
    local getRootHostContext = config.getRootHostContext
    local createCursor = stack.createCursor
    local push = stack.push
    local pop = stack.pop

    local contextStackCursor = createCursor(NO_CONTEXT)
    local contextStackCursor = createCursor(NO_CONTEXT)
    local rootInstanceStackCursor = createCursor(NO_CONTEXT)

    local function requiredContext(c)
        invariant(
            c ~= NO_CONTEXT,
            "Expected host context to exist. This error is likely caused by a bug in React. Please file an issue."
        )
        return c
    end

    local function pushHostContainer(fiber, nextRootInstance)
        -- Push current root instance onto the stack;
        -- This allows us to reset root when portals are popped.
        push(rootInstanceStackCursor, nextRootInstance, fiber)

        -- Track the context and the Fiber that provided it.
        -- This enables us to pop only Fibers that provide unique contexts.
        push(contextFiberStackCursor, fiber, fiber)

        -- Finally, we need to push the host context to the stack.
        -- However, we can't just call getRootHostContext() and push it because
        -- we'd have a different number of entries on the stack depending on
        -- whether getRootHostContext() throws somewhere in renderer code or not.
        -- So we push an empty value first. This lets us safely unwind on errors.
        push(contextStackCursor, NO_CONTEXT, fiber)
        local nextRootContext = getRootHostContext(nextRootInstance)

        -- Now that we know this function doesn't throw, replace it.
        pop(contextStackCursor, fiber)
        push(contextStackCursor, nextRootContext, fiber)
    end

    local function popHostContainer(fiber)
        pop(contextStackCursor, fiber)
        pop(contextFiberStackCursor, fiber)
        pop(rootInstanceStackCursor, fiber)
    end

    local function getHostContext()
        local context = requiredContext(contextStackCursor.current)
        return context
    end

    local function pushHostContext(fiber)
        local rootInstance = requiredContext(rootInstanceStackCursor.current)
        local context = requiredContext(contextStackCursor.current)
        local nextContext = getChildHostContext(context, fiber.type, rootInstance)

        -- Don't push this Fiber's context unless it's unique
        if context == nextContext then
            return
        end

        -- Track the context and the Fiber that provided it.
        -- This enables us to pop only Fibers that provide unique contexts.
        push(contextFiberStackCursor, fiber, fiber)
        push(contextStackCursor, nextContext, fiber)
    end

    local function popHostContext(fiber)
        -- Do not pop unless this Fiber provided the current context.
        -- pushHostContext() only pushes Fibers that provide unique contexts.
        if contextFiberStackCursor.current ~= fiber then
            return
        end

        pop(contextStackCursor, fiber)
        pop(contextFiberStackCursor, fiber)
    end

    return {
        getHostContext = getHostContext,
        getRootHostContainer = getRootHostContainer,
        popHostContainer = popHostContainer,
        popHostContext = popHostContext,
        pushHostContainer = pushHostContainer,
        pushHostContext = pushHostContext
    }

end

return ReactFiberHostContext