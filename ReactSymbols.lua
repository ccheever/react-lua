-- For now, we don't use symbols or numbers or anything
-- String comparison are close to as fast as number comparisons in Lua 
-- as far as I can tell. See compare.lua.

-- We do include the `getIteratorFn` function though

return {
  getIteratorFn = function(maybeIterable)
    local MAYBE_ITERATOR_SYMBOL = "Symbol.iterator"
    if maybeIterable == nil then
      return nil
    end
    local maybeIterator = (MAYBE_ITERATOR_SYMBOL and type(maybeIterable) == "table" and maybeIterable[MAYBE_ITERATOR_SYMBOL])
    if type(maybeIterator) == "function" then
      return maybeIterator
    end
    return nil
  end
}
