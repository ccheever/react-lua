local function isNan(x)
    return type(x) == "number" and x ~= x
end

local function shallowEqual(objA, objB)

    if objA == objB then
        return true
    end

    if type(objA) ~= "table" or type(objB) ~= "table" then
        -- This `shallowEqual` function is supposed to say
        -- that nan == nan even though the language says they aren't
        if isNan(objA) and isNan(objB) then
            return true
        end
        return false
    end


    -- In Lua, there's no way to get all the keys of a table
    -- except to enumerate them all
    local countA = 0
    for k, v in pairs(objA) do

        -- N.B.: If these have subtables then if they aren't
        -- literally the same table object, this will return false
        if v ~= objB[k] then
            if not (isNan(v) and isNan(objB[k])) then
                return false
            end
        end
        countA = countA + 1
    end

    local countB = 0
    for k, v in pairs(objB) do
        countB = countB + 1
    end
    if countB ~= countA then
        return false
    end

    return true

end

return shallowEqual