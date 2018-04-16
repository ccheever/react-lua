do
  local warning = require 'warning'
  local Object = require 'classic'

  local didWarnStateUpdateForUnmountedComponent = {}

  local function warnNoop(publicInstance, callerName)
    if __DEV__ then
      local componentName = 'ReactClass' -- We don't have Component names in React Lua right now!
      local warningKey = componentName .. '.' .. callerName
      if didWarnStateUpdateForUnmountedComponent[warningKey] then
        return
      end
      warning(
        false,
        "Can't call %s on a component that is not yet mounted. This call is a no-op, but it might indiciate a bug in your application. Instead, assign to `this.state` directly or define a `state = {}` class property with the desired state in the %s component.",
        callerName,
        componentName
      )
      didWarnStateUpdateForUnmountedComponent[warningKey] = true
    end
  end

  -- This is the abstract API for an update queue
  local ReactNoopUpdateQueue = Object:extend()

  -- Checks whether or not this composite component is mounted.
  -- @param {ReactClass} publicInstance The instance we want to test
  -- @return {boolean} true if mounted, false if otherwise.
  function ReactNoopUpdateQueue:isMounted(publicInstance)
    return false
  end

  -- Forces an update. This should only be invoked when
  -- it is known with certainty that we are **not** in
  -- a DOM transaction.
  --
  -- You may want to call this when you know that some
  -- deeper aspect of the component's state has changed
  -- but `setState` was not called.
  --
  -- This will not invoke `shouldComponentUpdate` but
  -- it will invoke `componentWillUpdate` and
  -- `componentDidUpdate`.
  --
  -- @param {ReactClass} publicInstance The instance that should rerender
  -- @param {?function} callback Called after component is updated.
  -- @param {?string} callerName name of the calling function in the public API
  function ReactNoopUpdateQueue:enqueueForceUpdate(publicInstance, callback, callerName)
    warnNoop(publicInstance, 'forceUpdate')
  end

  -- Replaces all of the state. Always use this or `setState` to mutate state
  -- You should treat `this.state` as immutable.
  --
  -- There is no guarantee that `this.state` will be immediately updated, so
  -- accessing `this.state` after calling this method
  -- may return the old value.
  --
  -- @param {ReactClass} publicInstance The instance that should rerender.
  -- @param {object} completeState Next state
  -- @param {?function} callback Called after component is updated
  -- @param {?string} callerName name of the calling function in the public API
  function ReactNoopUpdateQueue:enqueueReplaceState(publicInstance, completeState, callback, callerName)
    warnNoop(publicInstance, 'replaceState')
  end

  -- Sets a subset of the state.
  --
  -- @param {ReactClass} publicInstance THe instance that should rerender.
  -- @param {object} partialState Next parital state to be merged with state.
  -- @param {?function} callback Called after component is updated.
  -- @param {?string} Name of the calling function in the public API.
  function ReactNoopUpdateQueue:enqueueSetState(publicInstance, partialState, callback, callerName)
    warnNoop(publicInstance, 'setState')
  end

  return ReactNoopUpdateQueue
end
