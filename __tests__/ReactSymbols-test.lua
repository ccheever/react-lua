ReactSymbols = require "ReactSymbols"

getIteratorFn = ReactSymbols.getIteratorFn

print(getIteratorFn(nil))
print(getIteratorFn({}))
t = {}
t["Symbol.iterator"] = function () end
print(getIteratorFn(t))