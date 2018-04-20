local ReactFeatureFlags = require "ReactFeatureFlags"
local enableUserTimingAPI = ReactFeatureFlags.enableUserTimingAPI

local getComponentName = require "getComponentName"
local ReactTypeOfWork = require "ReactTypeOfWork"
local HostRoot = ReactTypeOfWork.HostRoot
local HostComponent = ReactTypeOfWork.HostComponent
local HostText = ReactTypeOfWork.HostText
local HostPortal = ReactTypeOfWork.HostPortal
local CallComponent = ReactTypeOfWork.CallComponent
local ReturnComponent = ReactTypeOfWork.ReturnComponent
local Fragment = ReactTypeOfWork.Fragment
local ContextProvider = ReactTypeOfWork.ContextProvider
local ContextConsumer = ReactTypeOfWork.ContextConsumer
local Mode = ReactTypeOfWork.Mode

local reactEmoji = "⚛"
local warningEmoji = "⛔"

local supportsUserTiming = false

-- 