local invariant = require 'invariant'
local warning = require 'warning'
-- local pi = require "pi"

local ReactSymbols = require 'ReactSymbols'
local getIteratorFn = ReactSymbols.getIteratorFn
local function emptyFunctionThatReturnsArgument(x)
  return x
end

local function emptyFunctionThatReturnsNil()
  return nil
end

local SEPARATOR = '.'
local SUBSEPARATOR = ':'

local getComponentKey

-- Escape and wrap a key so it is safe to use as a reactid
--
-- @param {string} key to be escaped
-- @param {string} the escaped key
local function escape(key)
  return ('$' .. key):gsub('=', '=0'):gsub(':', '=2')
end

-- TODO: Test that a single child and an array with one
-- item have the same key pattern

local didWarnAboutMaps = false

local function escapeUserProvidedKey(text)
  return ('' .. text):gsub(
    '/+',
    function(s)
      return s .. '/'
    end
  )
end

local POOL_SIZE = 10
local traverseContextPool = {}

function getPooledTraverseContext(mapResult, keyPrefix, mapFunction, mapContext)

  -- pi("getPooledTraverseContext:", mapResult, keyPrefix, mapFunction, mapContext)
  if #traverseContextPool > 0 then
    local traverseContext = table.remove(traverseContextPool)
    traverseContext.result = mapResult
    traverseContext.keyPrefix = keyPrefix
    traverseContext.func = mapFunction
    traverseContext.context = mapContext
    traverseContext.count = 0
    -- pi("returning Reused traverseContext", traverseContext)
    return traverseContext
  else
    local tc = {
      result = mapResult,
      keyPrefix = keyPrefix,
      func = mapFunction,
      context = mapContext,
      count = 0
    }
    -- pi("returning new traverseContext", tc)
    return tc
  end
end

local function releaseTraverseContext(traverseContext)
  -- pi("releaseTraverseContext")
  traverseContext.result = nil
  traverseContext.keyPrefix = nil
  traverseContext.func = nil
  traverseContext.context = nil
  traverseContext.count = 0
  if #traverseContextPool < POOL_SIZE then
    table.insert(traverseContextPool, traverseContext)
  end
end

-- @param {?*} children Children tree container.
-- @param {!string} nameSoFar Name of the key path so far.
-- @param {!function} callback Callback to invoke with each child found.
-- @param {?*} traverseContext Used to pass information throughout the traversal
-- process.
-- @return {!number} The number of children in this subtree.
local function traverseAllChildrenImpl(children, nameSoFar, callback, traverseContext)
  local t = type(children)

  if t == 'boolean' then
    -- All of the above are perceived as nil
    children = nil
  end

  local invokeCallback = false

  if children == nil then
    print("#taci:", 10, "children==nil")
    invokeCallback = true
  else
    if t == 'string' or t == 'number' then
      print("#taci:", 20, "t=string or number")
      invokeCallback = true
    else
      if t == 'table' then
        local typeof = children['$$typeof']
        if typeof == 'REACT_ELEMENT_TYPE' or typeof == 'REACT_PORTAL_TYPE' then
          print("#taci:", 30, "t=element or portal")
          invokeCallback = true
        end
      end
    end
  end

  print("#taci", 40, "invokeCallback=", invokeCallback)
  if invokeCallback then
    callback(
      traverseContext,
      chlidren,
      -- If it's the only child, treat the name as if it was
      -- wrapped in an array so that it's consistent if the
      -- number of children grows.
      (nameSoFar == '') and SEPARATOR .. getComponentKey(children, 0) or nameSoFar
    )
    return 1
  end

  local child
  local nextName
  local subtreeCount = 0 -- Count of children found in the current subtree
  local nextNamePrefix = nameSoFar == '' and SEPARATOR or nameSoFar .. SUBSEPARATOR

  if type(children) == 'table' then
    --for i, child in ipairs(children) do
    for i = 1, #children do
      local child = children[i]
    
      -- WATCH_FOR_INDEXING
      nextName = nextNamePrefix .. getComponentKey(child, i)
      print("subtreeCount=", subtreeCount, "callback=", callback, "child=", child, "nextName=", nextName)
      subtreeCount = subtreeCount + traverseAllChildrenImpl(child, nextName, callback, traverseContext)
    end
  else
    local iteratorFn = getIteratorFn(children)
    if type(iteratorFn) == 'function' then
      if __DEV__ then
        -- Warn about using Maps as children
        if iteratorFn == children.entries then
          warning(
            didWarnAboutMaps,
            'Using Maps as children is unsupported and will likely yield unexpected results. Convert it to a table of keyed ReactElements instead.'
          )
          didWarnAboutMaps = true
        end
      end

      local itetator = iteratorFn(children)
      local step
      local ii = 0
      for child in iterator do
        nextName = nextNamePrefix + getComponentKey(child, ii)
        ii = ii + 1
        subtreeCount = subtreeCount + traverseAllChildrenImpl(child, nextName, callback, traverseContext)
      end
    elseif type == 'table' then
    -- We won't actually hit this, since we handle
    -- tables and just assume they are lists, but
    -- in JS, we would warn here
    end
  end

  return subtreeCount
end

-- Traverses children that are typically specified as `props.children`, but
-- might also be specified through attributes:
--
-- - `traverseAllChildren(this.props.children, ...)`
-- - `traverseAllChildren(this.props.leftPanelChildren, ...)`
--
-- The `traverseContext` is an optional argument that is passed through the
-- entire traversal. It can be used to store accumulations or anything else that
-- the callback might find relevant.
--
-- @param {?*} children Children tree object.
-- @param {!function} callback To invoke upon traversing each child.
-- @param {?*} traverseContext Context for traversal.
-- @return {!number} The number of children in this subtree.
local function traverseAllChildren(children, callback, traverseContext)
  if children == nil then
    return 0
  end
  -- pi("traverseAllChildren", children, callback, traverseContext)
  return traverseAllChildrenImpl(children, '', callback, traverseContext)
end

-- Generate a key string that identifies a component within a set.
--
-- @param {*} component A component that could contain a manual key.
-- @param {number} index Index that is used if a manual key is not provided.
-- @return {string}
function getComponentKey(component, index)
  -- Do some typechecking here
  if type(component) == 'table' and component.key ~= nil then
    return escape(component.key)
  end
  -- Impicit key determined by the index in the set
  return '' .. index
end

local function forEachSingleChild(bookKeeping, child, name)
  -- pi("bookKeeping", bookKeeping)
  local func = bookKeeping.func
  local context = bookKeeping.context
  func(context, child, bookKeeping.count)
  bookKeeping.count = bookKeeping.count + 1
end

-- Iterates through children that are typically specified as `props.children`.
--
-- See https://reactjs.org/docs/react-api.html#react.children.foreach
--
-- The provided forEachFunc(child, index) will be called for each
-- leaf child.
--
-- @param {?*} children Children tree container.
-- @param {function(*, int)} forEachFunc
-- @param {*} forEachContext Context for forEachContext.
local function forEachChildren(children, forEachFunc, forEachContext)
  if children == nil then
    return children
  end

  local traverseContext = getPooledTraverseContext(nil, nil, forEachFunc, forEachContext)

  traverseAllChildren(children, forEachSingleChild, traverseContext)
  releaseTraverseContext(traverseContext)
end

local function mapSingleChildIntoContext(bookKeeping, child, childKey)
  local result = bookKeeping.result
  local keyPrefix = bookKeeping.keyPrefix
  local func = bookKeeping.func
  local context = bookKeeping.context

  local mappedChild = func(context, child, bookKeeping.count)
  bookKeeping.count = bookKeeping.count + 1
  if type(mappedChild) == 'table' and #mappedChild > 0 then
    mapIntoWithKeyPrefixInternal(mappedChild, result, childKey, emptyFunctionThatReturnsArgument)
  elseif mappedChild ~= nil then
    if isValidElement(mappedChild) then
      mappedChild =
        cloneAndReplaceKey(
        mappedChild,
        -- Keep both the (mapped) and old keys if they differ,
        -- just as `traverseAllchildren` used to do for objects
        -- as children
        keyPrefix +
          ((mappedChild.key and (not child or child.key ~= mappedChild.key)) and
            (escapeUserProvidedKey(mappedChild.key) + '/') or
            '') +
          childKey
      )
    end
    table.insert(result, mappedChild)
  end
end

local function mapIntoWithKeyPrefixInternal(children, array, prefix, func, context)
  local escapedPrefix = ''
  if prefix ~= nil then
    escapedPrefix = escapeUserProvidedKey(prefix) + '/'
  end
  local traverseContext = getPooledTraverseContext(array, escapedPrefix, func, context)
  traverseAllChildren(children, mapSingleChildIntoContext, traverseContext)
  releaseTraverseContext(traverseContext)
end

-- Maps children that are typically specified as `props.children`.
--
-- See https://reactjs.org/docs/react-api.html#react.children.map
--
-- The provided mapFunction(child, key, index) will be called for each
-- leaf child.
--
-- @param {?*} children Children tree container.
-- @param {function(*, int)} func The map function.
-- @param {*} context Context for mapFunction.
-- @return {table} Object containing the ordered map of results.
local function mapChildren(children, func, context)
  if children == nil then
    return children
  end
  local result = {}
  mapIntoWithKeyPrefixInternal(childrenm, result, nil, func, context)
  return result
end

-- Count the number of children that are typically
-- specified as `props.children`
--
-- See https://reactjs.org/docs/react-api.html#react.children.count
--
-- @param {?*} children Children tree container
-- @return {number} The number of children
local function countChildren(children, context)
  return traverseAllChildren(children, emptyFunctionThatReturnsNil, nil)
end

-- Flatten a children object (typically specified as `props.children`) and
-- return an array with appropriately re-keyed children.
--
-- See https://reactjs.org/docs/react-api.html#react.children.toarray
local function toArray(children)
  local result = {}
  mapIntoWithKeyPrefixInternal(children, result, nil, emptyFunctionThatReturnsArgument)
  return result
end

-- Returns the first child in a collection of children and
-- verifies that there is only one child in the collection.
--
-- See https://reactjs.org/docs/react-api.html#react.children.only
-- The current implementation of this function assumes that a single child gets
-- passed without a wrapper, but the purpose of this helper function is to
-- abstract away the particular structure of children.
--
-- @param {?object} children Child collection structure.
-- @return {ReactElement} The first and only `ReactElement` contained in the structure.
local function onlyChild(children)
  invariant(isValidElement(children), 'React.Children.only expected to receive a single React element child.')
  return children
end

return {
  -- Internal (just for testing)
  escape = escape,
  escapeUserProvidedKey = escapeUserProvidedKey,
  -- External
  forEach = forEachChildren,
  count = countChildren,
  only = onlyChild,
  toArray = toArray
}