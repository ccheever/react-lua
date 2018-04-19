local ReactChildren = require "ReactChildren"
local ReactElement = require "ReactElement"
local pi = require "pi"
print(ReactChildren.escape("hello"))
print(ReactChildren.escape("hi=24:there.asd====1ad"))


print(ReactChildren.escapeUserProvidedKey("something"))
print(ReactChildren.escapeUserProvidedKey("som///eth/in/g"))

-- TODO: test all the React Children methods and stuff
local child1 = ReactElement.createElement("image", {source="img1"})
pi(child1)
local child2 = ReactElement.createElement("image", {source="img2"})
local child3 = ReactElement.createElement("image", {source="img3"})
local instance = ReactElement.createElement("div", {a=1}, child1, child2, child3)
local context = {}
ReactChildren.forEach(instance.props.children, function (child, i) print(child) end, context)
