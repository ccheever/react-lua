local invariant = require "invariant"

local function invokeGuardedCallback(self, name, func, ...)
    self._hasCaughtError = false
    self._caughtError = nil
    local ok, resultOrError = pcall(func, ...)
    if not ok then
        this._caughtError = resultOrError
        this._hasCaughtError = true
    end
end

if __DEV__ then
    -- TODO(ccheever): Some wacky tricky stuff that would be hard to translate
end

return invokeGuardedCallback