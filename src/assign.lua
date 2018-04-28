-- Object.assign from JavaScript
-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign

local function assign(target, ...)
    local sources = {...}

    for _, s in ipairs(sources) do
        for k, v in pairs(s) do
            target[k] = v
        end
    end

    return target

end

return assign