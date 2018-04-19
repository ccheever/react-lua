ReactElement = require "ReactElement"
invariant = require "invariant"

local multipleChildren = ReactElement.createElement("div", {a=2, b=3}, "a", "b", "c")
local oneChild = ReactElement.createElement("div", {a=2, b=3}, "a")
local noChildren = ReactElement.createElement("div", {a=2, b=3})
