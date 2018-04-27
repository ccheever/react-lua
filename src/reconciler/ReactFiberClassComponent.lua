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