do
  local function invariant(condition, message)
    if not condition then
      error(message)
    end
  end
  return invariant
end
