invariant = require("invariant")

do
  invariant(true, "`invariant` errored when it should not")
  local ranWithoutError, returnValue = pcall(invariant, false, "Not OK")
  if ranWithoutError then
    error("`invariant` did not error when it should have")
  end
end