local function createRef()
    local refObject = {
        current = nil
    }
    if __DEV__ then
        -- Maybe do something with metatables so that you can't mutate anything except `current`?
        -- TODO: Can do this later
    end
    return refObject
end

return {
    createRef = createRef
}
