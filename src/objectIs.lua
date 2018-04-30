local function objectIs(x, y)
    if x == y then
        if x == 0 then
            -- test for -0 vs +0
            return 1 / x == 1 / y
        else
            return true
        end
    else
        -- test for nan
        if type(x) == "number" and type(y) == "number" and x ~= x and y ~= y then
            return true
        end
    end

    return false

end

return objectIs