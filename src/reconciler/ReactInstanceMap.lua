-- `ReactInstanceMap` maintains a mapping from a public facing stateful
-- instance (key) and the internal representation (value). This allows public
-- methods to accept the user facing instance as an argument and map them back
-- to internal methods.
-- 
-- Note that this module is currently shared and assumed to be stateless.
-- If this becomes an actual Map, that will break.


-- This API should be called `delete` but we'd have to make sure to always
-- transform these to strings for IE support. When this transform is fully
-- supported we can rename it.
local function remove(key)
    key._reactInternalFiber = nil
end

local function get(key)
    return key._reactInternalFiber
end

local function has(key)
    return key._reactInternalFiber ~= nil
end

local function set(key, value)
    key._reactInternalFiber = value
end

return {
    remove = remove,
    get = get,
    has = has,
    set = set
}