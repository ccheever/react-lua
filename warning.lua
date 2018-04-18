-- Similar to invariant but only logs a warning if the condition is not met.
-- This can be used to log issues in development environments in critical paths.
-- Removing the logging code for production environments will keep the same logic
-- and follow the same code paths.

do
  local warning = function()
  end
  if __DEV__ then
    function warning(condition, format, ...)
      if not format then
        error('`warning(condition, format, ..)` requires a warning message argument')
      end
      if not condition then
        io.stderr:write('Warning: ' .. string.format(format, ...) .. "\n")
        io.stderr:flush()
      end
    end
  end
  return warning
end
