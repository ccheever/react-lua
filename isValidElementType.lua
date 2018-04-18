local function isValidElementType(t)
  return (
    type(t) == "string" or
    (type(t) == "table" and (
      t["$$typeof"] == "REACT_PROVIDER_TYPE" or
    t["$$typeof"] == "REACT_CONTEXT_TYPE" or
    t["$$typeof"] == "REACT_FORWARD_REF_TYPE"
    )
  ))
end
return isValidElementType