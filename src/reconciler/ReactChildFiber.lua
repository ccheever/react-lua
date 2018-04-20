local getComponentName = require "getComponentName"
local ReactTypeOfSideEffect = require "ReactTypeOfSideEffect"
local Placement = ReactTypeOfSideEffect.Placement
local Deletion = ReactTypeOfSideEffect.Deletion

local ReactSymbols = require "ReactSymbols"
local getIteratorFn = ReactSymbols.getIteratorFn

local ReactFiberComponentTreeHook = require "ReactFiberComponentTreeHook"
local getStackAddendumByWorkInProgressFiber = ReactFiberComponentTreeHook.getStackAddendumByWorkInProgressFiber

local emptyObject = require "emptyObject"
local invariant = require "invariant"
local warning = require "warning"

local ReactFiber = require "ReactFiber"
local createWorkInProgress = ReactFiber.createWorkInProgress
local createFiberFromElement = ReactFiber.createFiberFromElement
local createFiberFromFragment = ReactFiber.createFiberFromFragment
local createFiberFromText = ReactFiber.createFiberFromText
local createFiberFromPortal = ReactFiber.createFiberFromPortal

local ReactDebugCurrentFiber = require "ReactDebugCurrentFiber"
