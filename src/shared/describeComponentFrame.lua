local function describeComponentFrame(name, source, ownerName)
    return (
        '\n    in ' ..
        (name or "Unknown") ..
        (source and (" (at " .. source.fileName .. ":" .. source.lineNumber .. ")") or
ownerName and (" (created by " .. ownerName .. ")") or "")
    )
end

return describeComponentFrame