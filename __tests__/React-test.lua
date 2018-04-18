local React = require "React"
local pi = require "pi"

local re = React.createElement(
  "div",
  { className = "shopping-list" },
  React.createElement(
    "h1",
    nil,
    "Shopping List for ",
    "Zorro"
  ),
  React.createElement(
    "ul",
    nil,
    React.createElement(
      "li",
      nil,
      "Instagram"
    ),
    React.createElement(
      "li",
      nil,
      "WhatsApp"
    ),
    React.createElement(
      "li",
      nil,
      "Oculus"
    )
  )
)

pi(re)