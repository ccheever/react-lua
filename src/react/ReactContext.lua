local warning = require "warning"

local function createContext(defaultValue, calculateChangedBits)
    if __DEV__ then
        warning(calculateChangedBits == nil or type(calculateChangedBits) == "function", "createContext: Expected the optional second argument to be a function but instead got " .. type(calculateChangedBits))
    end

    local context = {
        ["$$typeof"] = "REACT_CONTEXT_TYPE",
        _calculateChangedBits = calculateChangedBits,
        _defaultValue = defaultValue,
        _currentValue = defaultValue,
        Provider = nil,
        Consumer = nil
    }

    context.Provider = {
        ["$$typeof"] = "REACT_PROVIDER_TYPE",
        _context = context
    }

    context.Consumer = context

    if __DEV__ then
        context._currentRenderer = nil
    end

    return context
end

return {
    createContext = createContext
}