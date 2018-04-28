
local function alphabetInRandomOrder()
    local t = {}
    local used = {}
    for i = 1,26 do
        repeat
            letter = string.char(math.floor(math.random() * 26) + 97)
        until not used[letter]
        used[letter] = true
        t[letter .. letter .. letter .. letter .. letter] = letter .. letter
    end
    return t
end

local x = alphabetInRandomOrder()
local y = alphabetInRandomOrder()

local pi = require "pi"

for k, v in pairs(x) do
    print(k, v)
end

print()
print()
print()


for k, v in pairs(y) do 
    print(k, v)
end
--pi("x=", x)
--pi("y=", y)

for kx, vx, ky, vy in pairs(x), pairs(y) do
    print(kx, vx, ky, vy)
end

print(table.getn(x), table.getn(y))
