ReactCurrentOwner = require "ReactCurrentOwner"

do

  print(ReactCurrentOwner.current)
  ReactCurrentOwner.current = "Fiber"
  print(ReactCurrentOwner.current)
  ReactCurrentOwner = require "ReactCurrentOwner"
  print(ReactCurrentOwner.current)

end