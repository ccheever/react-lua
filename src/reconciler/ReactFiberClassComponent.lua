local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Update = ReactTypeOfSideEffect.Update
local Snapshot = ReactTypeOfSideEffect.Snapshot

local ReactFeatureFlags = require "ReactFeatureFlags"
local enableGetDerivedStateFromCatch = ReactFeatureFlags.enableGetDerivedStateFromCatch
local debugRenderPhaseSideEffects = ReactFeatureFlags.debugRenderPhaseSideEffects
local debugRenderPhaseSideEffectsForStrictMode = ReactFeatureFlags.debugRenderPhaseSideEffectsForStrictMode
local warnAboutDeprecatedLifecycles = ReactFeatureFlags.warnAboutDeprecatedLifecycles

local ReactStrictModeWarnings = require "ReactStrictModeWarnings"
local reflection = require "reflection"
local isMounted = reflection.isMounted
local ReactInstanceMap = require "ReactInstanceMap"
local emptyObject = require "emptyObject"
local getComponentName = require "getComponentName"
local shallowEqual = require "shallowEqual"
local invariant = require "invariant"
local warning = require "warning"

local ReactDebugFiberPerf = require "ReactDebugFiberPerf"
local startPhaseTimer = ReactDebugFiberPerf.startPhaseTimer
local stopPhaseTimer = ReactDebugFiberPerf.stopPhaseTimer
local ReactTypeOfMode = require "ReactTypeOfMode"
local StrictMode = ReactTypeOfMode.StrictMode
local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local insertUpdateIntoFiber = ReactFiberUpdateQueue.insertUpdateIntoFiber
local processUpdateQueue = ReactFiberUpdateQueue.processUpdateQueue

-- TODO(ccheever): Continue after ReactFiberUpdateQueue is implemented