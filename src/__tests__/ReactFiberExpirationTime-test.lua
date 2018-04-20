local ReactFiberExpirationTime = require "ReactFiberExpirationTime"
local msToExpirationTime = ReactFiberExpirationTime.msToExpirationTime
local expirationTimeToMs = ReactFiberExpirationTime.expirationTimeToMs
local ceiling = ReactFiberExpirationTime.ceiling
local computeExpirationBucket = ReactFiberExpirationTime.computeExpirationBucket

local pi = require "pi"

pi(ceiling(2.5, 1), 3)
pi(ceiling(2.123456, 0.001), 2.124)
pi(msToExpirationTime(12),expirationTimeToMs(3))
pi(msToExpirationTime(400), expirationTimeToMs(42))
pi(msToExpirationTime(2),expirationTimeToMs(2))
pi(msToExpirationTime(10),expirationTimeToMs(3))
pi(computeExpirationBucket(1524170411214, 14, 16))

