
local t = {"a", "b", "c"}

local x = false

setmetatable(t, {
    __call = function (t, a, i)
        --print("called with ", t, a, i)
        i = i or 0
        if i < #t then
            return i + 1, t[i + 1]
        else
            return nil
        end
    end
})

for i, x in t do
    print(i, x)
end

return t
