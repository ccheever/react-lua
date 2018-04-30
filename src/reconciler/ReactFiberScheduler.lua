local ReactErrorUtils = require "ReactErrorUtils"

local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber
local ReactGlobalSharedState = require "ReactGlobalSharedState"
local ReactCurrentOwner = ReactGlobalSharedState.ReactCurrentOwner
local ReactStrictModeWarnings = require "ReactStrictModeWarnings"
local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"

local NoEffect = ReactTypeOfSideEffect.NoEffect
local PerformedWork = ReactTypeOfSideEffect.PerformedWork
local Placement = ReactTypeOfSideEffect.Placement
local Update = ReactTypeOfSideEffect.Update
local Snapshot = ReactTypeOfSideEffect.Snapshot
local PlacementAndUpdate = ReactTypeOfSideEffect.PlacementAndUpdate
local Deletion = ReactTypeOfSideEffect.Deletion
local ContentReset = ReactTypeOfSideEffect.ContentReset
local Callback = ReactTypeOfSideEffect.Callback
local DidCapture = ReactTypeOfSideEffect.DidCapture
local Ref = ReactTypeOfSideEffect.Ref
local Incomplete = ReactTypeOfSideEffect.Incomplete
local HostEffectMask = ReactTypeOfSideEffect.HostEffectMask
local ErrLog = ReactTypeOfSideEffect.ErrLog

local ReactTypeOfWork = require "ReactTypeOfWork"
local HostRoot = ReactTypeOfWork.HostRoot
local ClassComponent = ReactTypeOfWork.ClassComponent
local HostComponent = ReactTypeOfWork.HostComponent
local ContextProvider = ReactTypeOfWork.ContextProvider
local HostPortal = ReactTypeOfWork.HostPortal

local ReactFeatureFlags = require "ReactFeatureFlags"
local enableUserTimingAPI = ReactFeatureFlags.enableUserTimingAPI
local warnAboutDeprecatedLifecycles = ReactFeatureFlags.warnAboutDeprecatedLifecycles
local replayFailedUnitOfWorkWithInvokeGuardedCallback = ReactFeatureFlags.replayFailedUnitOfWorkWithInvokeGuardedCallback

local getComponentName = require "getComponentName"
local invariant = require "invariant"
local warning = require "warning"

local ReactFiberBeginWork = require "ReactFiberBeginWork"
local ReactFiberCompleteWork = require "ReactFiberCompleteWork"
local ReactFiberUnwindWork = require "ReactFiberUnwindWork"