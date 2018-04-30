local objectIs = require "objectIs"
local invariant = require "invariant"

invariant(
    objectIs(0/0, -1*0/0) == true,
    "nan is nan"
)

invariant(
    objectIs(1/0, -1/0) == false,
    "-0 is not +0"
)

invariant(
    objectIs("hello", "hello") == true,
    "string = -> true"
)

invariant(
    objectIs("abc", "def") == false,
    "string ~= -> false"
)

invariant(
    objectIs(5, "x") == false,
    "mismatched types -> false"
)

invariant(
    objectIs({}, {}) == false,
    "diff tables -> false"
)

invariant(
    objectIs(invariant, invariant) == true,
    "same objects -> true"
)