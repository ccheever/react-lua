do
  local invariant = require('invariant')
  local __DEV__ = __DEV__ or false


  -- Exports ReactDOM.createRoot
  local enableUserTimingAPI = __DEV__

  -- Mutating mode (React DOM, React ART, React Native)
  local enableMutatingReconciler = true

  -- Experimental noop mode (currently unused)
  local enableNoopReconciler = false

  -- Experimental persistent mode (Fabric)
  local enablePersistentReconciler = false

  -- Experimental error-boundary API that can recover from
  -- errors within a single render phase
  local enableGetDerivedStateFromCatch = false

  -- Helps identify side effects in begin-phase lifecycle hooks and setState reducers
  local debugRenderPhaseSideEffects = false

  -- In some cases, StrictMode should also double-render lifecycles.
  -- This can be confusing for tests though, and it can be bad for
  -- performance in production. This feature can be used to control
  -- the behavior
  local debugRenderPhaseSideEffectsForStrictMode = __DEV__

  -- To preserve the "Pause on caught exceptions" behavior of the debugger,
  -- we replay the begin phase of a failed component inside invokeGuardedCallback.
  local replayFailedUnitOfWorkWithInvokeGuardedCallback = __DEV__

  -- Warn about deprecated, async-unsafe lifecycles; relates to RFC #6
  local warnAboutDeprecatedLifecycles = false

  local alwaysUseRequestIdleCallbackPolyfill = false

  -- Only used in www builds
  local function addUserTimingListener()
    invariant(false, 'Not implemented')
  end

  return {
    enableUserTimingAPI = enableUserTimingAPI,
    enableMutatingReconciler = enableMutatingReconciler,
    enableNoopReconciler = enableNoopReconciler,
    enablePersistentReconciler = enablePersistentReconciler,
    enableGetDerivedStateFromCatch = enableGetDerivedStateFromCatch,
    debugRenderPhaseSideEffects = debugRenderPhaseSideEffects,
    debugRenderPhaseSideEffectsForStrictMode = debugRenderPhaseSideEffectsForStrictMode,
    replayFailedUnitOfWorkWithInvokeGuardedCallback = replayFailedUnitOfWorkWithInvokeGuardedCallback,
    warnAboutDeprecatedLifecycles = warnAboutDeprecatedLifecycles,
    alwaysUseRequestIdleCallbackPolyfill = alwaysUseRequestIdleCallbackPolyfill
  }
end
