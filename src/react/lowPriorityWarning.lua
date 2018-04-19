local function lowPriorityWarning()
  if __DEV__ then
    function lowPriorityWarning(condition, format, ...)
      if not format then
        error("`lowPriorityWarning(condition, format, ...) requires a warning message argument")
      end
      if not condition then
        io.stderr:write("Low-pri Warning: " .. string.format(format, ...) .. "\n")
        io.stderr:flush()
      end
    end
  end
end
return lowPriorityWarning
