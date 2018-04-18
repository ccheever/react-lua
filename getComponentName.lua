local function getComponentName(fiber)
  local t = fiber.type
  if type(t) == "function" then
    return "ReactFunctionComponent"
  end
  if type(t) == "string" then
    return t
  end
  if t == "REACT_FRAGMENT_TYPE" then
    return "ReactFragment"
  else if t == "REACT_PORTAL_TYPE" then
    return "ReactPortal"
  else if t == "REACT_CALL_TYPE" then
    return "ReactCall"
  else if t == "REACT_RETURN_TYPE" then
    return "ReactReturn"
  end

  if type(t) == "table" and t["$$typeof"] == "ForwardRef" then
    return "ForwardRef"
  end

  return nil
  
end

return getComponentName