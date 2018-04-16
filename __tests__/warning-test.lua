-- __DEV__ has to be true when warning is required for it to do anything
__DEV__ = true

warning = require("warning")

do
  warning(true, "This warning *should not* be displayed")
  warning(false, "This warning should be displayed")
  warning(false, "This warning should have a number %d and a string %s", 5, "test")
end