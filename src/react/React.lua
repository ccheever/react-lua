local ReactVersion = require "ReactVersion"

local ReactBaseClasses = require "ReactBaseClasses"
local Component = ReactBaseClasses.Component
local PureComponent = ReactBaseClasses.PureComponent
local createRef = require "ReactCreateRef"
local ReactChildren = require "ReactChildren"
local forEach = ReactChildren.forEach
local map = ReactChildren.map
local count = ReactChildren.count
local toArray = ReactChildren.toArray
local only = ReactChildren.only
local ReactCurrentOwner = require "ReactCurrentOwner"
local ReactElement = require "ReactElement"
local createElement = ReactElement.createElement
local createFactory = ReactElement.createFactory
local cloneElement = ReactElement.cloneElement
local isValidElement = ReactElement.isValidElement
local ReactContext = require "ReactContext"
local createContext = ReactContext.createContext
local forwardRef = require "forwardRef"
local ReactElementValidator = require "ReactElementValidator"
local createElementWithValidation = ReactElementValidator.createElementWithValidation
local createFactoryWithValidation = ReactElementValidator.createFactoryWithValidation
local cloneElementWithValidation = ReactElementValidator.cloneElementWithValidation
local ReactDebugCurrentFrame = require "ReactDebugCurrentFrame"

local React = {
    Children = {
        map = map,
        forEach = forEach,
        count = count,
        toArray = toArray,
        only = only,
    },

    createRef = createRef,
    Component = Component,
    PureComponent = PureComponent,

    createContext = createContext,
    forwardRef = forwardRef,

    Framgent = "REACT_FRAGMENT_TYPE",
    StrictMode = "REACT_STRICT_MODE_TYPE",
    unstable_AsyncMode = "REACT_ASYNC_MODE_TYPE",

    createElement = __DEV__ and createElementWithValidation or createElement,
    cloneElement = __DEV__ and cloneElementWithValidation or cloneElement,
    createFactory = __DEV__ and createFactoryWithValidation or createFactory,
    isValidElement = isValidElement,

    __SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED = {
        ReactCurrentOwner = ReactCurrentOwner
    }

}

-- TODO: Add some stuff if __DEV__

return React