local invariant = require "invariant"
local invokeGuardedCallback = require "invokeGuardedCallback"

local ReactErrorUtils = {
  -- Used by Fiber to simulate a try-catch.
  _caughtError = nil,
  _hasCaughtError = false,

  -- // Used by event system to capture/rethrow the first error.
  _rethrowError = nil,
  _hasRethrowError = false,

  -- Call a function while guarding against errors that happens within it.
  -- Returns an error if it throws, otherwise null.
  --
  -- In production, this is implemented using a try-catch. The reason we don't
  -- use a try-catch directly is so that we can swap out a different
  -- implementation in DEV mode.
  -- 
  -- @param {String} name of the guard to use for logging or debugging
  -- @param {Function} func The function to invoke
  -- @param {*} context The context to use when calling the function
  -- @param {...*} args Arguments for function
  invokeGuardedCallback = function (...)
    invokeGuardedCallback(ReactErrorUtils, ...)
  end,

  -- Same as invokeGuardedCallback, but instead of returning an error, it stores
  -- it in a global so it can be rethrown by `rethrowCaughtError` later.
  -- TODO: See if _caughtError and _rethrowError can be unified.
  -- 
  -- @param {String} name of the guard to use for logging or debugging
  -- @param {Function} func The function to invoke
  -- @param {*} context The context to use when calling the function
  -- @param {...*} args Arguments for function
  invokeGuardedCallbackAndCatchFirstError = function (...)
    ReactErrorUtils.invokeGuardedCallback(...)
    if ReactErrorUtils.hasCaughtError() then
      local error_ = ReactErrorUtils.clearCaughtError()
      if not ReactErrorUtils._hasRethrowError then
        ReactErrorUtils._hasRethrowError = true
        ReactErrorUtils._rethrowError = error_
      end
    end
  end,

  -- During execution of guarded functions we will capture the first error which
  -- we will rethrow to be handled by the top level error handler.
  rethrowCaughtError = function (...)
    return rethrowCaughtError(ReactErrorUtils, ...)
  end,

  hasCaughtError = function ()
    return ReactErrorUtils._hasCaughtError
  end,

  clearCaughtError = function ()
    if ReactErrorUtils._hasCaughtError then
      local error_ = ReactErrorUtils._caughtError
      ReactErrorUtils._caughtError = nil
      ReactErrorUtils._hasCaughtError = false
      return error_
    else
      invariant(
        false,
        "clearCaughtError was called but no error was captured. This error is likely caused by a bug in React. Please file an issue."
      )
    end
  end

}

local function rethrowCaughtError()
  if ReactErrorUtils._hasRethrowError then
    local error_ = ReactErrorUtils._rethrowError
    ReactErrorUtils._rethrowError = nil
    ReactErrorUtils._hasRethrowError = false
    error(error_)
  end
end

return ReactErrorUtils