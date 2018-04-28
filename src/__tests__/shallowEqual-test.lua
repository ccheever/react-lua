local shallowEqual = require "shallowEqual"
local invariant = require "invariant"

invariant(
    shallowEqual(nil, {}) == false,
    "Returns false if either argument is nil"
)

invariant(
    shallowEqual({}, nil) == false,
    "Returns false if either argument is nil"
)

invariant(
    shallowEqual(nil, nil) == true,
    "Returns true if both nil"
)

invariant(
    shallowEqual(1, 1) == true,
    "Returns true if arguments are not tables and are equal"
)

invariant(
    shallowEqual({a=1, b=2, c=3}, {a=1, b=2, c=3}) == true,
    "Returns true if arugments are shallow equal"
)

local nan = 1 / 0 * 0
invariant(
    shallowEqual({a=1, b=2, c=3, d=nan}, {a=1, b=2, c=3, d=nan}) == true,
    "Returns true when comparing nan"
)
-- invariant(
--     shallowEqual({a=1, b=2, c=3, d=nan}, {a=1, b=2, c=3, d=nan}) == false,
--     "Returns false when comparing nan"
-- )



invariant(
    shallowEqual(1, 2) == false,
    "Returns false if arguments are not tables and not equal"
)

invariant(
    shallowEqual(1, {}) == false,
    "Returns false if only one argument is not a table"
)

invariant(
    shallowEqual({}, 1) == false,
    "Returns false if only one argument is not a table"
)

invariant(
    shallowEqual({a=1, b=2, c=3}, {a=1, b=2}) == false,
    "Returns false if first argument has too many keys"
)

invariant(
    shallowEqual({a=1, b=2}, {a=1, b=2, c=3}) == false,
    "Returns false if second argument has too many keys"
)

invariant(
    shallowEqual({a=1, b=2, c={}}, {a=1, b=2, c={}}) == false,
    "Returns false if arguments not are shallow equal"
)

invariant(
    shallowEqual({"a", "b", "c"}, {"a", "b", "c"}) == true,
    "Returns true for arrays that are shallow equal"
)