local warning = require "warning"
local isValidElementType = require "isValidElementType"

-- 
-- ReactElementValidator provides a wrapper around a element factory
-- which validates the props passed to the element. This is intended to be
-- used only in DEV and could be replaced by a static type checker for languages
-- that support it.
-- 

local lowPriorityWarning = require "lowPriorityWarning"
local isValidElementType = require "isValidElementType"
local getComponentName = require "getComponentName"

-- TODO: Implement this part of the port
-- For now, we'll just use the ones without validation

local ReactElement = require "ReactElement"
return {
    createElementWithValidation = ReactElement.createElement,
    createFactoryWithValidation = ReactElement.createFactory,
    cloneElementWithValidation = ReactElement.cloneElement
}
