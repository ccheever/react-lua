Object = require './classic'

do
  local Component = Object:extend()
  local emptyObject = {}
  local __DEV__ = true

  -- ReactNoopUpdateQueue
  local didWarnStateUpdateForUnmountedComponent = {}

  local function warnNoop(publicInstance, callerName)
    if __DEV__ then
      print("Warning: Can't call " .. callerName .. ' on a component that is not yet mounted.')
    end
  end

  local ReactNoopUpdateQueue = Object:extend()

  -- Checks whether or not this composite component is mounted.
  -- @param {ReactClass} publicInstance The instance we want to test.
  -- @return {boolean} True if mounted, false otherwise.
  function ReactNoopUpdateQueue:isMounted(publicInstance)
    return false
  end

  -- Forces an update. This should only be invoked when it is known with
  -- certainty that we are **not** in a DOM transaction
  --
  -- You may want to call this when you know that some deeper aspect of
  -- the component's state has changed but `setState` was not called.
  --
  -- This will not invoke `shouldCopmonentUpdate` but it will invoke
  -- `componentWillUpdate` and `componentDidUpdate`
  --
  -- @param {ReactClass} piublicInstance The instance that should render
  -- @param {?function} callback Called after component is updated
  -- @param {?string} callerName name of the calling function in the public API
  function ReactNoopUpdateQueue:enqueueForceUpdate(publicInstance, callback, callerName)
    warnNoop(publicInstance, 'forceUpdate')
  end

  -- Replaces all of the state. ALways use this or `setState` to mutate state.
  -- You should treat `this.state` as immutable.
  --
  -- There is no guarantee that `this.state` will be immeditaely updated, so
  -- accessing `this.state` after calling this method may return the old value.
  --
  -- @param {ReactClass} publicInstance The instance that should rerender
  -- @param {object} completeState Next state.
  -- @param {?function} callback Called after component is updated.
  -- @param {?string} callerName name of the calling function in the public API.
  function ReactNoopUpdateQueue:enqueueReplaceState(publicInstance, completeState, callback, callerName)
    warnNoop(publicInstance, 'replaceState')
  end

  -- Sets a subset of the state. This only exists because _pendingState is
  -- internal. This provides a merging strategy that is not available to
  -- deep properties which is confusing. TODO: expose pendingState or don't
  -- use it during the merge.
  --
  -- @param {ReactClass} publicInstance The instance that should rerender.
  -- @param {object} partialState Next partial state to be merged with state.
  -- @param {?function} callback Called after component is updated.
  -- @param {?string} callerName name of the calling function in the public API
  function ReactNoopUpdateQueue:enqueueSetState(publicInstance, partialState, callback, callerName)
    warnNoop(publicInstance, 'setState')
  end

  function Component:new(props, context, updater)
    self.props = props
    self.context = context
    self.refs = {}
    -- We initialize the default update but the real one gets injected by the renderer
    self.updater = updater or ReactNoopUpdateQueue
  end

  Component.isReactComponent = true

  -- Sets a subset of the state. Always use this to mutate
  -- state. You should treat `this.state` as immutable.
  --
  -- There is no guarantee that `this.state` will be immediately updated, so
  -- accessing `this.state` after calling this method may return the old value.
  --
  -- There is no gaurantee that calls to `setState` will run synchronously,
  -- as they may eventually be batched together. You can provide an optional
  -- callback that will be executed when the call to setState is actually
  -- completed.
  --
  -- When a function is provided to setState, it will be called at some point
  -- in the future (not synchronously). It will be called with the up-to-date
  -- component arguments (state, props, context). These values can be different
  -- from this.* because your function may be called after receiveProps but before
  -- shouldComponentUpdte, and this new state, props, and context will not yet be
  -- assigned to this.
  --
  -- @param {object|function} partialState Next partial state or function to
  --        produce next partial state to be merged with current state
  -- @param {?function} callback Called after state is updated
  function Component:setState(partialState, callback)
    if not ((type(partialState) == 'object') or (type(partialState) == 'function') or (type(partialState) == nil)) then
      print(
        'setState(...): takes an object of state variables to update or a function which returns an object of state variables.'
      )
    end

    self.updater:enqueueSetState(self, partialState, callback, 'setState')
  end

  -- Forces an update. This should only be invoked when it is known with
  -- certainty that we are *not* in a DOM transaction.
  --
  -- You may want to call this when you know that some deeper aspect of the
  -- component's state has changed but `setState` was not called.
  --
  -- This will not invoke `shouldComponentUpdate`, but it will invoke
  -- `componentWillUpdate` and `componentDidUpdate`.
  --
  -- @param {?funcftion} callback Called after update is complete.
  function Component:forceUpdate(callback)
    self.updater:enqueueForceUpdate(self, callback, 'forceUpdate')
  end

  local ComponentDummy = Component:extend()
  local PureComponent = ComponentDummy:extend()
  function PureComponent:new(props, context, updater)
    this.props = props
    this.context = context
    this.refs = emptyObject
    this.updater = updater or ReactNoopUpdateQueue
  end

  PureComponent.isPureReactComponent = true

  -- TODO: Some optimizations probably possible. Possibly can skip a metatable
  -- lookup if we do something differently here
  -- See ReactBaseClasses.js lines 120 - 138
  local function createRef()
    return {
      current = nil
    }
  end

  local ReactCurrentOwner = nil
  local RESERVED_PROPS = {
    key = true,
    ref = true,
    __self = true,
    __source = true
  }

  local specialPropKeyWarningShown, specialPropRefWarningShown

  local function hasValidRef(config)
    if __DEV__ then
    --     if (hasOwnProperty.call(config, 'ref')) {
    --       const getter = Object.getOwnPropertyDescriptor(config, 'ref').get;
    --       if (getter && getter.isReactWarning) {
    --         return false;
    --       }
    --     }
    end
    return config.ref ~= nil
  end

  local function hasValidKey(config)
    if __DEV__ then
    --     if (hasOwnProperty.call(config, 'key')) {
    --       const getter = Object.getOwnPropertyDescriptor(config, 'key').get;
    --       if (getter && getter.isReactWarning) {
    --         return false;
    --       }
    end
    return config.key ~= nil
  end

  local function defineKeyPropWarningGetter(props, displayName)
    -- TODO: Add something to the metatable that warns about access
    local function warnAboutAccessingKey()
      if not specialPropKeyWarningShown then
        specialPropKeyWarningShown = true
        print(
          '`key` is not a prop. Trying to access it will result in `nil` being returned. If you need to access the same value within a child component, you should pass it as a different prop.'
        )
      end
    end
  end

  local function defineRefPropWarningGetter(props, displayName)
    -- TODO: Add something to the metatable that warns about access
    local function warnAboutAccessingRef()
      if not specialPropRefWarningShown then
        specialPropRefWarningShown = true
        print(
          '`ref` is not a prop. Trying to access it will result in `nil` being returned. If you need to access the same value within a child component, you should pass it as a different prop.'
        )
      end
    end
  end

  -- TODO: Rewrite comment so that it makes sense in Lua
  -- Factory method to create a new React element. This no longer adheres to the
  -- class pattern, so do not use new to call it. Alas, no instanceof check
  -- will work. Instead test $$typeof field against Symbol.for('react.element') to
  -- check if something is a React Element.
  -- @param {*} type
  -- @param {*} key
  -- @param {string|object} ref
  -- @param {*} self A *temporary* helper to detect places where `this` is
  --        different from the `owner` when React.createElement is called, so
  --        that we can warn. We want to get rid of owner and replace the string
  --        `ref`s with arrow functions, and as long as `this` and owner are the
  --        same, tehere will be no change in behavior.
  -- @param {*} source AN annotation object (added by a transpiler or otherwise)
  --        indicating filename, line number, and/or other information
  -- @param {*} owner
  -- @param {*} props
  local function ReactElement(type, key, ref, self, source, owner, props)
    local element = {
      -- This tag allows us to uniquely identify this as a React Element
      __typeof = 'REACT_ELEMENT_TYPE',
      -- Built-in properties that belong on the element
      type = type,
      key = key,
      ref = ref,
      props = props,
      -- Record the component responsible for creating this element
      _owner = owner
    }

    -- TODO: Some __DEV__ stuff
    return element
  end

  -- Create and return a new ReactElement of the given type
  local function createElement(type, config, ...)
    local propName

    -- Reserved names are extracted
    local props = {}

    local key = nil
    local ref = nil
    local self = nil
    local source = nil

    if (config ~= nil) then
      if (hasValidRef(config)) then
        ref = config.ref
      end
      if (hasValidKey(config)) then
        key = '' .. config.key
      end

      self = config.__self
      source = config.__source

      for propName, v in pairs(config) do
        if not RESERVED_PROPS[propName] then
          props[propName] = config[propName]
        end
      end
    end

    local children = {...}
    local childrenLength = #children
    props.children = children

    if type and type.defaultProps then
      local defaultProps = type.defaultProps
      for propName, defaultValue in pairs(defaultProps) do
        if props[propName] == nil then
          props[propName] = defaultValue
        end
      end
    end

    if __DEV__ then
    -- TODO: Some stuff with keys and refs and display etc.
    end

    return ReactElement(type, key, ref, self, source, ReactCurrentOwner.current, props)
  end

  -- Returns a function that produces ReactElements of a given type
  local function createFactory(type)
    local function factory(...)
      return createElement(type, ...)
    end
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
  end

-- CLone and return a new ReactElement using element as the starting point.
function cloneElement(element, config, children)
  if (element == nil) then
    error("React.cloneElement(...): The argument must be a React element but you passed nil")
  end

  local propName

  -- Original props are copied
  local props = {table.unpack(element.props or {})}

  -- Reserved names are extracted
  local key = element.key
  local ref = element.ref
  -- self is preserved since the owner is preserved.
  local self = element._self
  -- Source is preserved since cloneElement is unlikely to be targeted
  -- by a transpiler, and the original source is probably a 
  -- better indicator the true owner.
  local source = element._source

  -- Owner will be preserved, unless ref is overridden
  local owner = element._owner

  if (config ~= nil) then
    if hasValidRef(config) then
      -- Silently steal the ref from the parent
      ref = config.ref
      owner = ReactCurrentOwner.current
    end
    if hasValidKey(config) then
      key = '' .. config.key
    end

    -- Remaining properties override existing props
    local defaultProps
    -- CDC: This might behave weird if we expect 0 or '' to be be false
    if (element.type and element.type.defaultProps) then
      defaultProps = element.type.defaultProps
    end

    for propName in pairs(config) do
      if (config[propName] and (not RESERVED_PROPS[propName])) then
        if 
      end
    end

  end

end


--   /**
--  * Clone and return a new ReactElement using element as the starting point.
--  * See https://reactjs.org/docs/react-api.html#cloneelement
--  */
-- export function cloneElement(element, config, children) {
--   invariant(
--     !(element === null || element === undefined),
--     'React.cloneElement(...): The argument must be a React element, but you passed %s.',
--     element,
--   );

--   let propName;

--   // Original props are copied
--   const props = Object.assign({}, element.props);

--   // Reserved names are extracted
--   let key = element.key;
--   let ref = element.ref;
--   // Self is preserved since the owner is preserved.
--   const self = element._self;
--   // Source is preserved since cloneElement is unlikely to be targeted by a
--   // transpiler, and the original source is probably a better indicator of the
--   // true owner.
--   const source = element._source;

--   // Owner will be preserved, unless ref is overridden
--   let owner = element._owner;

--   if (config != null) {
--     if (hasValidRef(config)) {
--       // Silently steal the ref from the parent.
--       ref = config.ref;
--       owner = ReactCurrentOwner.current;
--     }
--     if (hasValidKey(config)) {
--       key = '' + config.key;
--     }

--     // Remaining properties override existing props
--     let defaultProps;
--     if (element.type && element.type.defaultProps) {
--       defaultProps = element.type.defaultProps;
--     }
--     for (propName in config) {
--       if (
--         hasOwnProperty.call(config, propName) &&
--         !RESERVED_PROPS.hasOwnProperty(propName)
--       ) {
--         if (config[propName] === undefined && defaultProps !== undefined) {
--           // Resolve default props
--           props[propName] = defaultProps[propName];
--         } else {
--           props[propName] = config[propName];
--         }
--       }
--     }
--   }

--   // Children can be more than one argument, and those are transferred onto
--   // the newly allocated props object.
--   const childrenLength = arguments.length - 2;
--   if (childrenLength === 1) {
--     props.children = children;
--   } else if (childrenLength > 1) {
--     const childArray = Array(childrenLength);
--     for (let i = 0; i < childrenLength; i++) {
--       childArray[i] = arguments[i + 2];
--     }
--     props.children = childArray;
--   }

--   return ReactElement(element.type, key, ref, self, source, owner, props);
-- }

-- /**
--  * Verifies the object is a ReactElement.
--  * See https://reactjs.org/docs/react-api.html#isvalidelement
--  * @param {?object} object
--  * @return {boolean} True if `object` is a valid component.
--  * @final
--  */
-- export function isValidElement(object) {
--   return (
--     typeof object === 'object' &&
--     object !== null &&
--     object.$$typeof === REACT_ELEMENT_TYPE
--   );
-- }

  local React = {
    reactVersion = '16.3.1',
    Children = {},
    Fragment = 'FRAGMENT',
    StrictMode = 'STRICT_MODE',
    AsyncMode = 'ASYNC_MODE',
    createElement = createElement,
    cloneElement = cloneElement,
    createFactory = createFactory,
    isValidElement = isValidElement,
    createRef = createRef,
    Component = Component,
    PureComponent = PureComponent,
    createContext = createContext,
    forwardRef = forwardRef
  }
  return React
end
