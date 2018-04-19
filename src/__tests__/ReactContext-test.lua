ReactContext = require "ReactContext"
pi = require "pi"

pi(ReactContext.createContext("d.v."))
pi(ReactContext.createContext("d.v2", function (x) return x + x end))

