Object = require 'classic'

invariant = require 'invariant'
warning = require 'warning'

ReactNoopUpdateQueue = require 'ReactNoopUpdateQueue'

do
  -- Base class helpers for the updating state of a component
  local Component = Object:extend()
  function Component:new(props, context, updater)
    self.props = props
    self.context = context
    self.refs = {} -- TODO: Make sure this doesn't need to be emptyObject
    self.updater = updater or ReactNoopUpdateQueue
  end

  Component.isReactComponent = true

  -- Sets a subset of the state. Always use this to mutate
  -- state. You should treat `this.state` as immutable.
  --
  -- Thre is no guarantee that `this.state` will be immediately
  -- updated, so accessing `this.state` after calling this
  -- method may return the old value.
  --
  -- There is no guarantee that calls to `setState` will run
  -- synchronously, as they may eventually be batched
  -- together. You can provide an optional callback that will
  -- be executed when the call to setState is actually completed.
  --
  -- When a function is provided to setState, it will be called
  -- at some point in the future (not synchronously). It will
  -- be called with the up-to-date component arguments
  -- (state, props, context). These values can be different from
  -- this.* because your function may be called after
  -- receiveProps but before shouldComponentUPdate, and this
  -- new state, props, and context will not yet be assigned to
  -- this.
  --
  -- @param {table|function} partialState Next partial state or function to produce next parital state to be merged with current state.
  -- @param {?function} callback Called after state is updated.
  function Component:setState(partialState, callback)
    invariant(
      ((type(partialState) == 'table') or (type(partialState) == 'function') or (not partialState)),
      'setState(...): takes a table of state variable to update or a function which returns a table of state variables.'
    )
    self.updater:enqueueSetState(self, partialState, callback, 'setState')
  end

  -- Forces an update. This should only be invoked when it is known with
  -- certainty that we are **not** in a DOM transaction.
  --
  -- You may want to call this when you know that some deeper aspect of the
  -- component's state has changed but `setState` was not called.
  --
  -- This will not invoke `shouldComponentUpdate`, but it will invoke
  -- `componentWillUpdate` and `componentDidUpdate`.
  --
  -- * @param {?function} callback Called after update is complete.
  function Component:forceUpdate(callback)
    self.updater:enqueueForceUpdate(self, callback, 'forceUpdate')
  end

  local PureComponent = Component:extend()
  function PureComponent:new(props, context, updater)
    self.props = props
    self.context = context
    self.refs = {} -- TODO: Make sure this doesn't need to be emptyObject
    self.updater = updater or ReactNoopUpdateQueue
  end

  PureComponent.isPureReactComponent = true

  return {
    Component = Component,
    PureComponent = PureComponent
  }
end
