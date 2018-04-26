local bit = require "bit"

local getComponentName = require "getComponentName"
local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Placement = ReactTypeOfSideEffect.Placement
local Deletion = ReactTypeOfSideEffect.Deletion

local ReactSymbols = require "ReactSymbols"
local getIteratorFn = ReactSymbols.getIteratorFn
local REACT_ELEMENT_TYPE = ReactSymbols.REACT_ELEMENT_TYPE
local REACT_FRAGMENT_TYPE = ReactSymbols.REACT_FRAGMENT_TYPE
local REACT_PORTAL_TYPE = ReactSymbols.REACT_PORTAL_TYPE

local ReactTypeOfWork = require "ReactTypeOfWork"
local FunctionalComponent = ReactTypeOfWork.FunctionalComponent
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local Fragment = ReactTypeOfWork.Fragment

local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber

local emptyObject = require "emptyObject"
local invariant = require "invariant"
local warning = require "warning"
local array = require "array"

local ReactFiber = require "ReactFiber"
local createWorkInProgress = ReactFiber.createWorkInProgress
local createFiberFromElement = ReactFiber.createFiberFromElement
local createFiberFromFragment = ReactFiber.createFiberFromFragment
local createFiberFromText = ReactFiber.createFiberFromText
local createFiberFromPortal = ReactFiber.createFiberFromPortal

local ReactDebugCurrentFiber = require "ReactDebugCurrentFiber"

local ReactTypeOfMode = require "ReactTypeOfMode"
local StrictMode = ReactTypeOfMode.StrictMode

local ReactDebugCurrentFiber = require "ReactDebugCurrentFiber"
local getCurrentFiberStackAddendum = ReactDebugCurrentFiber.getCurrentFiberStackAddendum

local didWarnAboutMaps
local didWarnAboutStringRefInStrictMode
local ownerHasKeyUseWarning
local ownerHasFunctionTypeWarning
local function warnForMissingKey(child)
    return {}
end


if __DEV__ then
    didWarnAboutMaps = false
    didWarnAboutStringRefInStrictMode = {}

    -- Warn if there's no key explicitly set on dynamic arrays of children
    -- or object keys are not valid. This allows us to keep track of children
    -- between updates
    ownerHasKeyUseWarning = {}
    ownerHasFunctionTypeWarning = {}

    warnForMissingKey = function(child)
        if child == nil then
            return
        end

        if (not child._store or child._store.validated or child.key ~= nil) then
            return
        end

        invariant(type(child._store) == "table", 
            "React Component in warnForMissingKey should have a _store. This error is likely caused by a bug in React or react-lua. Please file an issue.")

        child._store.validated = true

        local currentComponentErrorInfo = "Each child in an array or iterator should have a unique `key` prop. See https://fb.me/react-warning-keys for more info" .. (getCurrentFiberStackAddendum() or "")
        if ownerHasKeyUseWarning[currentComponentErrorInfo] then
            return
        end
        ownerHasKeyUseWarning[currentComponentErrorInfo] = true

        warning(false, "each child in an array or iterator should have a unique `key` prop. See https://fb.me/react-warning-keys for more info. " .. getCurrentFiberStackAddendum())
    end
end

local isArray = array.isArray

local function coerceRef(returnFiber, current, element)
    local mixedRef = element.ref
    if (mixedRef ~= nil and type(mixedRef) ~= "function" and type(mixedRef) ~= "table") then
        if __DEV__ then
            if bit.band(returnFiber.mode, StrictMode) > 0 then
                local componentName = getComponentName(returnFiber) or "Component"
                if not didWarnAboutStringRefInStrictMode[componentName] then
                    warning(false, "A string ref " .. mixedRef .. " has been found within a strict mode tree. String refs are a source of potential bugs and should be avoided. We recommend using createRef() instead.\n" .. getStackAddendumByWorkInProgressFiber(returnFiber) .. "\n\nLearn more about using refs safely here: https://fb.me/react-strict-mode-string-ref")

                end

                didWarnAboutStringRefInStrictMode[componentName] = true

             end
        end

        if element._owner then
            local owner = element._owner
            local inst
            if owner then
                local ownerFiber = owner
                invariant(ownerFiber.tag == ClassComponent, "Stateless function components cannot have refs.")
                inst = ownerFiber.stateNode
            end
            invariant(inst, "Missing owner for string ref " .. mixedRef .. ". This error is likely caused by a bug in React or react-lua. Please file an issue.")

            local stringRef = "" .. mixedRef
            -- Check if previous string ref matches new string ref

            if current ~= nil and current.ref ~= nil and current.ref._stringRef == stringRef then
                return current.ref
            end

            local ref = function(value) 
                if inst.refs == emptyObject then
                    inst.refs = {}
                end
                local refs = inst.refs
                if value == nil then
                    refs[stringRef] = nil
                else
                    refs[stringRef] = value
                end
            end

            ref._stringRef = stringRef
            return ref
        else
            invariant(type(mixedRef) == "string", "Expected ref to be a function or a string.")
            invariant(element._owner, 
                "Element ref was specified as a string (" .. mixedRef") but no owner was set. This could happen for one of the following reasons:\n1. You may be adding a ref to a functional component\n2. You may be adding a ref to a component that was not created inside a component's render method\n3. You have multiple copies of React loaded\nSee https://fb.me/react-refs-must-have-owner for more information.",
                mixedRef
            )
        end
    end
    
    return mixedRef

end

local function throwOnInvalidObjectType(returnFiber, newChild)
    if returnFiber.type ~= "textarea" then
        local addendum = "";
        if __DEV__ then
            addendum = "If you meant to render a collection of children, use an array instead. " .. (getCurrentFiberStackAddendum() or "")
        end
        invariant(false, "Objects are not valid as a React child. " .. addendum)
    end
end
            

local function warnOnFunctionType()
    local currentComponentErrorInfo = 
        "Functions are not valid as a React child. This may happen if you return a Component instead of <Component /> from render. Or maybe you meant to call this function rather than return it. " .. (getCurrentFiberStackAddendum() or "")
end

-- This wrapper function exists because I expect to clone the code in each path
-- to be able to optimize each path individually by branching early. This needs
-- a compiler or we can do it manually. Helpers that don't need this branching
-- live outside of this function.
local function ChildReconciler(shouldTrackSideEffects)
    local function deleteChild(returnFiber, childToDelete)
        if not shouldTrackSideEffects then
            -- Noop
            return
        end

        -- Deletions are added in reversed order so we add it to the front.
        -- At this point, the return fiber's effect list is empty except for
        -- deletions, so we can just append the deletion to the list. The remaining
        -- effects aren't added until the complete phase. Once we implement
        -- resuming, this may not be true.
        local last = returnFiber.lastEffect
        if last ~= nil then
            last.nextEffect = childToDelete
            returnFiber.lastEffect = childToDelete
        else
            returnFiber.lastEffect = childToDelete
            returnFiber.firstEffect = childToDelete
        end
        childToDelete.nextEffect = nil
        childToDelete.effectTag = Deletion
    end

    local function deleteRemainingChildren(returnFiber, currentFirstChild)
        if not shouldTrackSideEffects then
            -- Noop
            return nil
        end

        -- TODO: For the shouldClone case, this could be micro-optimized a bit by
        -- assuming that after the first child we've already added everything.
        local childToDelete = currentFirstChild
        while childToDelete ~= nil do
            deleteChild(returnFiber, childToDelete)
            childToDelete = childToDelete.sibling
        end
        return nil
    end

    local function mapRemainingChildren(returnFiber, currentFirstChild)
        -- Add the remaining children to a temporary map so that we can find them by
        -- keys quickly. Implicit (null) keys get added to this set with their index
        -- instead.
        local existingChildren = {}

        local existingChild = currentFirstChild
        while existingChild ~= nil do
            if existingChild.key ~= nil then
                existingChildren[existingChild.key] = existingChild
            else 
                existingChildren[existingChild.index] = existingChild
            end
            existingChild = existingChild.sibling
        end
        return existingChildren
    end

    local function useFiber(fiber, pendingProps, expirationTime)
        -- We currently set sibling to null and index to 0 here because it is easy
        -- to forget to do before returning it. E.g. for the single child case.
        local clone = createWorkInProgress(fiber, pendingProps, expirationTime)
        clone.index = 0
        clone.sibling = nil
        return clone
    end

    local function placeChild(newFiber, lastPlacedIndex, newIndex)
        newFiber.index = newIndex
        if not shouldTrackSideEffects then
            -- Noop
            return lastPlacedIndex
        end
        local current = newFiber.alternate
        if current ~= nil then
            local oldIndex = current.index
            if oldIndex < lastPlacedIndex then
                -- This is a move
                newFiber.effectTag = Placement
                return lastPlacedIndex
            else
                -- This item can stay in place
                return oldIndex
            end
        else
            -- This is an insertion
            newFiber.effectTag = Placement
            return lastPlacedIndex
        end
    end

    local function placeSingleChild(newFiber)
        -- This is simpler for the single child case. We only need to do a
        -- placement for inserting new children.
        if shouldTrackSideEffects and newFiber.alternate == nil then
            newFiber.effectTag = Placement
        end
        return newFiber
    end

    local function updateTextNode(returnFiber, current, textContent, expirationTime)
        if current == nil or current.tag ~= HostText then
            -- Insert
            local created = createFiberFromText(textContent, returnFiber.mode, expirationTime)
            created["return"] = returnFiber
        else
            -- Update
            local existing = useFiber(current, textContent, expirationTime)
            existing["return"] = returnFiber
            return existing
        end
    end

    local function updateElement(returnFiber, current, element, expirationTime)
        if current ~= nil and current.type == element.type then
            -- Move based on index
            local existing = useFiber(current, element.props, expirationTime)
            existing.ref = coerceRef(returnFiber, current, element)
            existing["return"] = returnFiber
            if __DEV__ then
                existing._debugSource = element._source
                existing._debugOwner = element._owner
            end
            return existing
        else
            -- Insert
            local created = createFiberFromElement(
                element,
                returnFiber.mode,
                expirationTime
            )
            created.ref = coerceRef(returnFiber, current, element)
            created["return"] = returnFiber
            return created
        end
    end

    local function updatePortal(returnFiber, current, portal, expirationTime)
        if (
            current == nil or
            current.tag ~= HostPortal or
            current.stateNode.containerInfo ~= portal.containerInfo or
            current.stateNode.implementation ~= portal.implementation
        ) then
            -- Insert
            local created = createFiberFromPortal(
                portal, returnFiber.mode, expirationTime
            )

            created["return"] = returnFiber
            return created
        else
            -- Update
            local existing = useFiber(current, portal.children or {}, expirationTime)
            existing["return"] = returnFiber
            return existing
        end
    end

    local function updateFragment(
        returnFiber, current, fragment, expirationTime, key
    )
        if current == nil or current.tag ~= Fragment then
            -- Insert
            local created = createFiberFromFragment(
                fragment, returnFiber.mode, expirationTime, key
            )
            created["return"] = returnFiber
            return created
        else
            -- Update
            local existing = useFiber(current, fragment, expirationTime)
            existing["return"] = returnFiber
            return existing
        end
    end

    local function createChild(
        returnFiber, newChild, expirationTime
    )
        if type(newChild) == "string" or type(newChild) == "number" then
            -- Text nodes don't have keys. If the previous node is implicitly keyed
            -- we can continue to replace it without aborting even if it is 
            -- not a text node.
            local created = createFiberFromText("" .. newChild, returnFiber.mode, expirationTime)
            created["return"] = returnFiber
            return created
        end

        if type(newChild) == "table" and newChild ~= nil then
            local typeof = newChild["$$typeof"]
            if typeof == REACT_ELEMENT_TYPE then
                local created = createFiberFromElement(newChild, returnFiber.mode, expirationTime)
                created.ref = coerceRef(returnFiber, nil, newChild)
                created["return"] = returnFiber
            elseif typeof == REACT_PORTAL_TYPE then
                local created = createFiberFromPortal(newChild, returnFiber.mode, expirationTime)
                created["return"] = returnFiber
                return created
            end

            if isArray(newChild) or getIteratorFn(newChild) then
                local created = createFiberFromFragment(newChild, returnFiber.mode, expirationTime, nil)
                created["return"] = returnFiber
                return created
            end

            throwOnInvalidObjectType(returnFiber, newChild)
        end

        if __DEV__ then
            if type(newChild) == "function" then
                warnOnFunctionType()
            end
        end

        return nil

    end

    local function updateSlot(returnFiber, oldFiber, newChild, expirationTime)
        -- Update the fiber if the keys match, otherwise return null.

        local key = nil
        if oldFiber ~= nil then
            key = oldFiber.key
        end

        if type(newChild) == "string" or type(newChild) == "number" then
            -- Text nodes don't have keys. If the previous node is implicitly keyed
            -- we can continue to replace it without aborting even if it 
            -- is not a text node.
            if key ~= nil then
                return nil
            end
            return updateTextNode(
                returnFiber,
                oldFiber,
                "" .. newChild,
                expirationTime
            )
        end

        if type(newChild) == "table" and newChild ~= nil then
            local typeof = newChild["$$typeof"]
            if typeof == REACT_ELEMENT_TYPE then
                if newChild.key == key then
                    if newChild.type == REACT_FRAGMENT_TYPE then
                        return updateFragment(
                            returnFiber,
                            oldFiber,
                            newChild.props.children,
                            expirationTime,
                            key
                        )
                    end
                    return updateElement(
                        returnFiber,
                        oldFiber,
                        newChild,
                        expirationTime
                    )
                else
                    return nil
                end
            elseif typeof == REACT_PORTAL_TYPE then
                if newChild.key == key then
                    return updatePortal(
                        returnFiber,
                        oldFiber,
                        newChild,
                        expirationTime
                    )
                else
                    return nil
                end
            end

            if isArray(newChild) or getIteratorFn(newChild) then
                if key ~= nil then
                    return nil
                end
                return updateFragment(
                    returnFiber,
                    oldFiber,
                    newChild,
                    expirationTime,
                    nil
                )
            end

            throwOnInvalidObjectType(returnFiber, newChild)

        end

        if __DEV__ then
            if type(newChild) == "function" then
                warnOnFunctionType()
            end
        end
    
        return nil

    end

    local function updateFromMap(
        existingChildren,
        returnFiber, 
        newIdx,
        newChild,
        expirationTime
    )
        if type(newChild) == "string" or type(newChild) == "number" then
            --  Text nodes don't have keys, so we neither have to check the old nor
            --  new node for the key. If both are text nodes, they match.
            local matchedFiber = existingChildren[newIdx] or nil
            return updateTextNode(
                returnFiber, matchedFiber, "" .. newChild, expirationTime
            )

        end

        if type(newChild) == "table" and newChild ~= nil then
            local typeof = newChild["$$typeof"]
            if typeof == REACT_ELEMENT_TYPE then
                local matchedFiber = existingChildren[newChild.key == nil and newIdx or newChild.key] or nil
                if newChild.type == REACT_FRAGMENT_TYPE then
                    return updateFragment(returnFiber, matchedFiber, newChild.props.children, expirationTime, newChild.key)
                end
                return updateElement(returnFiber, matchedFiber, newChild, expirationTime)
            elseif typeof == REACT_PORTAL_TYPE then
                local matchedFiber = existingChildren[newChild.key == nil and newIdx or newChild.key] or nil
                return updatePortal(returnFiber, matchedFiber, newChild, expirationTime)
            end

            if isArray(newChild) or getIteratorFn(newChild) then
                local matchedFiber = existingChildren[newIdx or nil]
                return updateFragment(returnFiber, matchedFiber, newChild, expirationTime, nil)
            end

            throwOnInvalidObjectType(returnFiber, newChild)
        end

        if __DEV__ then
            if type(newChild) == "function" then
                warnOnFunctionType()
            end
        end

        return nil

    end

    -- Warns if there is a duplicate or missing key
    local function warnOnInvalidKey(child, knownKeys)
        if __DEV__ then
            if type(child) == "table" or child == nil then
                return knownKeys
            end

            local typeof = child["$$typeof"]
            for __switch = 1,1 do
                if typeof == REACT_ELEMENT_TYPE or typeof == REACT_PORTAL_TYPE then
                    warnForMissingKey(child)
                    local key = child.key
                    if type(key) ~= "string" then
                        break
                    end
                    if knownKeys == nil then
                        knownKeys = {}
                        knownKeys[key] = true
                        break
                    end

                    if not knownKeys[key] then
                        knownKeys[key] = true
                        break
                    end

                    warning(false, "Encountered two childen with the same key `" .. key .. "` Keys should be unique so that components maintain their identity across updates. Non-unique keys may cause children to be duplicated and/or omitted — the behavior is unsupported and could change in a future version." .. getCurrentFiberStackAddendum())
                    break

                end
            end
        end
        return knownKeys
    end

    local function reconcileChildrenArray() 

        -- This algorithm can't optimize by searching from boths ends since we
        -- don't have backpointers on fibers. I'm trying to see how far we can get
        -- with that model. If it ends up not being worth the tradeoffs, we can
        -- add it later.

        -- Even with a two ended optimization, we'd want to optimize for the case
        -- where there are few changes and brute force the comparison instead of
        -- going for the Map. It'd like to explore hitting that path first in
        -- forward-only mode and only go for the Map once we notice that we need
        -- lots of look ahead. This doesn't handle reversal as well as two ended
        -- search but that's unusual. Besides, for the two ended optimization to
        -- work on Iterables, we'd need to copy the whole set.

        -- In this first iteration, we'll just live with hitting the bad case
        -- (adding everything to a Map) in for every insert/move.

        -- If you change this code, also update reconcileChildrenIterator() which
        -- uses the same algorithm.

        if __DEV__ then
            -- First, validate keys
            local knownKeys = nil
            for i, child in ipairs(newChildren) do
                knownKeys = warnOnInvalidKey(child, knownKeys)
            end
        end

        local resultingFirstChild
        local previousNewFiber

        local oldFiber = currentFirstChild
        local lastPlacedIndex = 1
        local newIdx = 1
        local nextOldFiber = nil
        while oldFiber ~= nil and newIdx <= #newChildren do
            if oldFiber.index > newIdx then
                nextOldFiber = oldFiber
                oldFiber = nil
            else
                nextOldFiber = oldFiber.sibling
            end

            local newFiber = updateSlot(
                returnFiber,
                oldFiber,
                newChild[newIdx],
                expirationTime
            )
            if newFiber == nil then
                -- TODO: This breaks on empty slots like null children. That's
                -- unfortunate because it triggers the slow path all the time. We need
                -- a better way to communicate whether this was a miss or null,
                -- boolean, undefined, etc.
                if oldFiber == nil then
                    oldFiber = nextOldFiber
                end
                break
            end

            if shouldTrackSideEffects then
                if oldFiber and newFiber.alternate == nil then
                    -- We matched the slot, but we didn't reuse the existing fiber, so we
                    -- need to delete the existing child.
                    deleteChild(returnFiber, oldFiber)
                end
            end
            lastPlacedIndex = placeChild(newFiber, lastPlacedIndex, newIdx)
            if previousNewFiber == nil then
                -- TODO: Move out of the loop. This only happens for the first run.
                resultingFirstChild = newFiber
            else
                -- TODO: Defer siblings if we're not at the right index for this slot.
                -- I.e. if we had null values before, then we want to defer this
                -- for each null value. However, we also don't want to call updateSlot
                -- with the previous one.
                previousNewFiber.sibling = newFiber
            end
            previousNewFiber = newFiber
            oldFiber = nextOldFiber

            newIdx = newIdx + 1
        end

        if step.done then
            -- We've reached the end of the new children. We can delete the rest.
            deleteRemainingChildren(returnFiber, oldFiber)
            return resultingFirstChild
        end

        if oldFiber == nil then
            -- If we don't have any more existing children we can choose a fast path
            -- since the rest will all be insertions.
            while not step.done do
                for __continue = 1,1 do

                    local newFiber = createChild(returnFiber, step.value, expirationTime)

                    if newFiber == nil then
                        break
                    end

                    lastPlacedIndex = placeChild(newFiber, lastPlacedIndex, newIdx)
                    if previousNewFiber == nil then
                        -- TODO: Move out of the loop. This only happens on the first run
                        resultingFirstChild = newFiber
                    else
                        previousNewFiber.sibling = newFiber
                    end

                    previousNewFiber = newFiber

                end

                newIdx = newIdx + 1
                step = newChildren:next()

            end

            return resultingFirstChild

        end


        -- Add all children to a key map for quick lookups
        local existingChildren = mapRemainingChildren(returnFiber, oldFiber)

        -- Keep scanning and use the map to restore deleted items as moves.
        while not step.done do

            local newFiber = updateFromMap(existingChildren, returnFiber, newIdx, step.value, expirationTime)

            if newFiber ~= nil then
                if shouldTrackSideEffects then
                    if newFiber.alternate ~= nil then
                        -- The new fiber is a work in progress, but if there exists a
                        -- current, that means that we reused the fiber. We need to delete
                        -- it from the child list so that we don't add it to the deletion
                        -- list.
                        existingChildren.delete(
                            newFiber.key == nil and newIdx or newFiber.key
                        )
                    end
                end
                lastPlacedIndex = placeChild(newFiber, lastPlacedIndex, newIdx)
                if previousNewFiber == nil then
                    resultingFirstChild = newFiber
                else
                    previousNewFiber.sibling = newFiber
                end
                previousNewFiber = newFiber
            end
        end

        if shouldTrackSideEffects then
            -- Any existing children that weren't consumed above were deleted. We need
            -- to add them to the deletion list.
            for _i, child in ipairs(existingChildren) do
                deleteChild(returnFiber, child)
            end
        end

        return resultingFirstChild
    end


    local function reconcileSingleTextNode(
        returnFiber,
        currentFirstChild,
        textContent,
        expirationTime
    )
        -- There's no need to check for keys on text nodes since we don't have a
        -- way to define them.
        if currentFirstChild ~= nil and currentFirstChild.tag == HostText then
            -- We already have an existing node so let's just update it and delete
            -- the rest.
            deleteRemainingChildren(returnFiber, currentFirstChild.sibling)
            local existing = useFiber(currentFirstChild, textContent, expirationTime)
            existing["return"] = returnFiber
            return existing
        end

        -- The existing first child is not a text node so we need to create one
        -- and delete the existing ones.
        deleteRemainingChildren(returnFiber, currentFirstChild)
        local created = createFiberFromElement(
            textContent,
            returnFiber.mode,
            expirationTime
        )
        created["return"] = returnFiber
        return created
    end

    local function reconcileSingleElement(
        returnFiber,
        currentFirstChild,
        element,
        expirationTime
    )
        local key = element.key
        local child = currentFirstChild
        while child ~= nil do
            -- TODO: If key === null and child.key === null, then this only applies to
            -- the first item in the list.
            if child.key == key then
                if (child.tag == Fragment and (element.type == REACT_FRAGMENT_TYPE) or (child.type == element.type)) then
                    deleteRemainingChildren(returnFiber, child.sibling)
                    local existing = useFiber(
                        child,
                        element.type == REACT_FRAGMENT_TYPE and element.props.children or element.props,
                        expirationTime
                    )
                    existing.ref = coerceRef(returnFiber, child, element)
                    existing["return"] = returnFiber
                    if __DEV__ then
                        existing._debugSource = element._source
                        existing._debugOwner = element._owner
                    end
                    return existing
                else
                    deleteRemainingChildren(returnFiber, child)
                    break
                end
            else
                deleteChild(returnFiber, child)
            end
            child = child.sibling
        end

        if element.type == REACT_FRAGMENT_TYPE then
            local created = createFiberFromFragment(
                element.props.children,
                returnFiber.mode,
                expirationTime,
                element.key
            )
            created["return"] = returnFiber
            return created
        else
            local created = createFiberFromElement(
                element,
                returnFiber.mode,
                expirationTime
            )
            created.ref = coerceRef(returnFiber, currentFirstChild, element)
            created["return"] = returnFiber
            return created
        end

    end

    local function reconcileSinglePortal(
        returnFiber,
        currentFirstChild,
        portal,
        expirationTime
    )
        local key = portal.key
        local child = currentFirstChild
        while child ~= nil do
            -- TODO: If key === null and child.key === null, then this only applies to
            -- the first item in the list.
            if child.key == key then
                if (child.tag == HostPortal and
                    child.stateNode.containerInfo == portal.containerInfo and
                    child.stateNode.implementation == portal.implementation
                ) then
                    deleteRemainingChildren(returnFiber, child.sibling)
                    local existing = useFiber(child, portal.children or {}, expirationTime)
                    existing["return"] = returnFiber
                    return existing
                else
                    deleteRemainingChildren(returnFiber, child)
                    break
                end

            else
                deleteChild(returnFiber, child)
            end

            child = child.sibling

        end

        local created = createFiberFromPortal(
            portal,
            returnFiber.mode,
            expirationTime
        )
        created["return"] = returnFiber
        return created

    end

    -- This API will tag the children with the side-effect of the reconciliation
    -- itself. They will be added to the side-effect list as we pass through the
    -- children and the parent.
    local function reconcileChildFibers(
        returnFiber,
        currentFirstChild,
        newChild,
        expirationTime
    )
        -- This function is not recursive.
        -- If the top level item is an array, we treat it as a set of children,
        -- not as a fragment. Nested arrays on the other hand will be treated as
        -- fragment nodes. Recursion happens at the normal flow.
    
        -- Handle top level unkeyed fragments as if they were arrays.
        -- This leads to an ambiguity between <>{[...]}</> and <>...</>.
        -- We treat the ambiguous cases above the same.
        if (
            type(newChild) == "table" and
            newChild ~= nil and
            newChild.type == REACT_FRAGMENT_TYPE and
            newChild.key == nil
        ) then
            newChild = newChild.props.children
        end

        -- Handle object types
        local isObject = type(newChild) == "table" and newChild ~= nil and not isArray(newChild)

        if isObject then
            local t = newChild["$$typeof"]
            if t == REACT_ELEMENT_TYPE then
                return placeSingleChild(
                    reconcileSingleElement(
                        returnFiber,
                        currentFirstChild,
                        newChild,
                        expirationTime
                    )
                )
            elseif t == REACT_PORTAL_TYPE then
                return placeSingleChild(
                    reconcileSinglePotal(
                        returnFiber,
                        currentFirstChild,
                        newChild,
                        expirationTime
                    )
                )
            end
        end

        if type(newChild) == "string" or type(newChild) == "number" then
            return placeSingleChild(
                reconcileSingleTextNode(
                    returnFiber,
                    currentFirstChild,
                    '' .. newChild,
                    expirationTime
                )
            )
        end

        if isArray(newChild) then
            return reconcileChildrenArray(
                returnFiber,
                currentFirstChild,
                newChild,
                expirationTime
            )
        end

        if getIteratorFn(newChild) then
            return reconcileChildrenIterator(
                returnFiber,
                currentFirstChild,
                newChild,
                expirationTime
            )
        end

        if isObject then
            throwOnInvalidObjectType(returnFiber, newChild)
        end

        if __DEV__ then
            if type(newChild) == "function" then
                warnOnFunctionType()
            end
        end

        if newChild == nil then
            -- If the new child is undefined, and the return fiber is a composite
            -- component, throw an error. If Fiber return types are disabled,
            -- we already threw above.
            for __switch = 1,1 do
                local tag = returnFiber.tag
                if tag == ClassComponent then
                    if __DEV__ then
                        local instance = returnFiber.stateNode
                        if instance.render._isMockFunction then
                            -- We allow auto-mocks to proceed as if they're returning null.
                            break
                        end
                    end
                end

                -- Intentionally fall through to the next case, which handles both
                -- functions and classes
                -- eslint-disable-next-lined no-fallthrough
                if tag == ClassComponent or tag == FunctionalComponent then
                    local Component = returnFiber.type
                    local display = Component.displayName or Component.name or "Component"
                    invariant(false, display .. "(...): Nothing was returned from render. This usually means a return statement is missing. Or, to render nothing, return null.")
                end
            end
        end

        -- Remaining cases are all treated as empty
        return deleteRemainingChildren(returnFiber, currentFirstChild)

    end

    return reconcileChildFibers

end

local reconcileChildFibers = ChildReconciler(true)
local mountChildFibers = ChildReconciler(false)

local function cloneChildFibers(current, workInProgress)
    invariant(current == nil or workInProgress.child == current.child, "Resuming work not yet implemented.")

    if workInProgress.child == nil then
        return
    end

    local currentChild = workInProgress.child
    local newChild = createWorkInProgress(
        currentChild,
        currentChild.pendingProps,
        currentChild.expirationTime
    )
    workInProgress.child = newChild

    newChild["return"] = workInProgress
    while currentChild.sibling ~= nil do
        currentChild = currentChild.sibling
        newChild.sibling = createWorkInProgress(
            currentChild,
            currentChild.pendingProps,
            currentChild.expirationTime
        )
        newChild = newChild.sibling

        newChild["return"] = workInProgress
    end
    newChild.sibling = nil
end

return {
    reconcileChildFibers = reconcileChildFibers,
    mountChildFibers = mountChildFibers,
    cloneChildFibers = cloneChildFibers
}







