local ReactFiberErrorDialog = require "ReactFiberErrorDialog"
local showErrorDialog = ReactFiberErrorDialog.showErrorDialog

local function logCapturedError(capturedError)
    local logError = showErrorDialog(capturedError)

    -- Allow injected showErrorDialog() to prevent default console.error logging.
    -- This enables renderers like ReactNative to better manage redbox behavior.
    if logError == false then
        return
    end

    local error_ = capturedError.error
    local suppressLogging = error_ and error_.suppressReactErrorLogging
    if suppressLogging then
        return
    end

    if __DEV__ then
        -- lots of dev stuff
    else
        io.stderr:write(error_ .. "\n")
        io.stderr:flush()
    end

end

return {
    logCapturedError = logCapturedError
}
