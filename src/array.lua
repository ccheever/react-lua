local function isArray(x)
    return x[1] ~= nil
end

local function isMaybeArray(x)
    return x[1] ~= nil or next(x) == nil
end

local function isObject(x)
    return x[1] == nil
end

local function isEmpty(x)
    return next(x) == nil
end

return {
    isArray = isArray,
    isMaybeArray = isMaybeArray,
    isObject = isObject,
    isEmpty = isEmpty
}