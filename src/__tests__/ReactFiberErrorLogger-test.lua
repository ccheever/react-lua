local ReactFiberErrorLogger = require "ReactFiberErrorLogger"
local pi = require "pi"

pi(ReactFiberErrorLogger)

ReactFiberErrorLogger.logCapturedError({
    error = "An error"
})