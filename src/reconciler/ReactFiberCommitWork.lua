local ReactFeatureFlags = require "ReactFeatureFlags"
local enableMutatingReconciler = ReactFeatureFlags.enableMutatingReconciler
local enableNoopReconciler = ReactFeatureFlags.enableNoopReconciler
local enablePersistentReconciler = ReactFeatureFlags.enablePersistentReconciler

local ReactTypeOfWork = require "ReactTypeOfWork"
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local CallComponent = ReactTypeOfWork.CallComponent

local ReactErrorUtils = require "ReactErrorUtils"
local invokeGuardedCallback = ReactErrorUtils.invokeGuardedCallback
local hasCaughtError = ReactErrorUtils.hasCaughtError
local clearCaughtError = ReactErrorUtils.clearCaughtError

local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Placement = ReactTypeOfSideEffect.Placement
local Update = ReactTypeOfSideEffect.Update
local ContentReset = ReactTypeOfSideEffect.ContentReset
local Snapshot = ReactTypeOfSideEffect.Snapshot

local invariant = require "invariant"
local warning = require "warning"

local ReactFiberUpdateQueue = require "ReactFiberUpdateQueue"
local commitCallbacks = ReactFiberUpdateQueue.commitCallbacks
local ReactFiberDevToolsHook = require "ReactFiberDevToolsHook"
local onCommitUnmount = ReactFiberDevToolsHook.onCommitUnmount
local ReactDebugFiberPerf = require "ReactDebugFiberPerf"
local startPhaseTimer = ReactDebugFiberPerf.startPhaseTimer
local stopPhaseTimer = ReactDebugFiberPerf.stopPhaseTimer
local ReactFiberErrorLogger = require "ReactFiberErrorLogger"
local logCapturedError = ReactFiberErrorLogger.logCapturedError
local getComponentName = require "getComponentName"
local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber


