invariant = require 'invariant'
warning = require 'warning'

ReactCurrentOwner = require 'ReactCurrentOwner'

local REACT_ELEMENT_TYPE = 'REACT_ELEMENT_TYPE'
local RESERVED_PROPS = {
  key = true,
  ref = true,
  __self = true,
  __source = true
}

local specialPropKeyWarningShown, specialPropRefWarningShown

local function hasValidRef(config)
  return not (not config.ref)
end

local function hasValidKey(config)
  return not (not config.key)
end

-- TODO: Implement warnings for key and ref prop accessors
-- See: `defineKeyPropWarningGetter` and
-- `defineRefPropWarningGetter` in the original React source

-- Factory method to create a new React element. This no longer adheres to
-- the class pattern, so do not use new to call it. Also, no instanceof check
-- will work. Instead test $$typeof field against Symbol.for('react.element') to check
-- if something is a React Element.
-- TODO: Figure out some other way to mark this as a React Element
--
-- @param {*} type
-- @param {*} key
-- @param {string|object} ref
-- @param {*} self A *temporary* helper to detect places where `this` is
-- different from the `owner` when React.createElement is called, so that we
-- can warn. We want to get rid of owner and replace string `ref`s with arrow
-- functions, and as long as `this` and owner are the same, there will be no
-- change in behavior.
-- @param {*} source An annotation object (added by a transpiler or otherwise)
-- indicating filename, line number, and/or other information.
-- @param {*} owner
-- @param {*} props
local ReactElement =
  function(type, key, ref, self, source, owner, props)
  local element = {
    -- Build-in properties that belong on the element
    type = type,
    key = key,
    ref = ref,
    props = props,
    -- Record the component responsible for creating this element
    _owner = owner
  }
  -- This tag allows us to uniquely identify this as a React Element
  element['$$typeof'] = REACT_ELEMENT_TYPE

  if __DEV__ then
    -- The validation flag is currently mutative. We put it on
    -- an external backing store so we can freeze the whole
    -- table
    element._store = {}

  -- TODO: Add in a bunch of __DEV__ only stuff for testing
  -- See original React source
  end

  return element
end

-- Create and return a new ReactElement of the given type
-- See https://reactjs.org/docs/react-api.html#createelement
local function createElement(type, config, children, ...)
  local additionalChildren = {...}
  local propName

  -- Reserved names are extracted
  local props = {}
  local key = nil
  local ref = nil
  local self = nil
  local source = nil

  if config then
    if hasValidRef(config) then
      ref = config.ref
    end
    if hasValidKey(config) then
      key = '' .. config.key
    end

    self = config.__self
    source = config.__source

    -- Reamining properties are added to a new props object
    for propName, val in pairs(config) do
      if not RESERVED_PROPS[propName] then
        props[propName] = config[propName]
      end
    end
  end

  if #additionalChildren == 0 then
    props.children = children
  else
    props.children = {children}
    for i, child in ipairs(additionalChildren) do
      table.insert(props.children, child)
    end
  end

  -- Resolve default props
  if type and type.defaultProps then
    local defaultProps = type.defaultProps
    for _, propName in ipairs(defaultProps) do
      if props[propName] == nil then
        props[propName] = defaultProps[propName]
      end
    end
  end

  -- TODO; Some more __DEV__ stuff, see React source

  return ReactElement(type, key, ref, self, source, ReactCurrentOwner.current, props)
end

-- Return a function that produces ReactElements of a given type
--See https://reactjs.org/docs/react-api.html#createfactory
local function createFactory(type)
  local factory = function(...)
    return createElement(type, ...)
  end
  -- TODO: Do something about the fact that React wants
  -- to set factory.type but it's a function here in Lua
  -- and you can't just set stuff

  return factory
end

local function cloneAndReplaceKey(oldElement, newKey)
  local newElement =
    ReactElement(
    oldElement.type,
    newKey,
    oldElement.ref,
    oldElement._self,
    oldElement._source,
    oldElement._owner,
    oldElement.props
  )
  return newElement
end

-- Clone and return a new ReactElement using element as
-- the starting point
local function cloneElement(element, config, ...)
  local children = {...}
  invariant((not (element == nil)), 'React.cloneELement(...): The argument must be a React element, but you passed %s')

  local propName

  -- Original props are copied
  local props = {}
  for prop, val in pairs(element.props) do
    props[prop] = val
  end

  -- Reserved names are extracted
  local key = element.key
  local ref = element.ref

  -- Self is preserved since the owner is preserved
  local self = element._self
  -- Source is presreved since cloneElement is unlikely
  -- to be targeted by a transpiler, and the original
  -- source is probably a better indicator of the true owner
  local source = element._source

  -- Owner will be preserved, unless ref is overridden
  local owner = element._owner

  if config ~= nil then
    if hasValidRef(config) then
      -- Silently steal the ref from the parent
      ref = config.ref
      owner = ReactCurrentOwner.current
    end
    if hasValidKey(config) then
      key = '' .. config.key
    end
  end

  -- Remaining properties override existing props
  local defaultProps
  if (element.type and element.type.defaultProps) then
    defaultProps = element.type.defaultProps
  end

  for propsName, val in pairs(config) do
    if (config[propName] and not RESERVED_PROPS[propName]) then
      if (config[propName] == nil and defaultProps ~= nil) then
        props[propName] = defaultProps[propName]
      else
        props[propName] = config[propName]
      end
    end
  end

  -- Children can be more than one argument, and those
  -- are transferred on to the newly allocated props table
  if #children == 1 then
    props.children = children[1]
  else
    props.children = children
  end

  return ReactElement(element.type, key, ref, self, source, owner, props)
end

-- Verifies the object is a ReactElement
-- See https://reactjs.org/docs/react-api.html#isvalidelement
-- @param {?object} object
-- @return {boolean} True if `object` is a valid component
local function isValidElement(object)
  return (type(object) == 'table' and object['$$typeof'] == REACT_ELEMENT_TYPE)
end

return {
  createElement = createElement,
  createFactory = createFactory,
  cloneAndReplaceKey = cloneAndReplaceKey,
  cloneElement = cloneElement,
  isValidElement = isValidElement
}
