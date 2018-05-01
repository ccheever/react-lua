-- This module is forked in different environments.
-- By default, return `true` to log errors to the console.
-- Forks can return `false` if this isn't desirable.
return {
    showErrorDialog = function(capturedError)
        return true
    end
}
