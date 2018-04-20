local MAX_SIGNED_31_BIT_INT = require "maxSigned31BitInt"

local NoWork = 0
local Sync = 1
local Never = MAX_SIGNED_31_BIT_INT

local UNIT_SIZE = 10
local MAGIC_NUMBER_OFFSET = 2

-- 1 unit of expiration time represents 10ms
local function msToExpirationTime(ms)
    -- Always add an offset so that we don't clash with the magic number for NoWork
    return (math.floor(ms / UNIT_SIZE) + MAGIC_NUMBER_OFFSET)
end

local function expirationTimeToMs(expirationTime)
    return (expirationTime - MAGIC_NUMBER_OFFSET) * UNIT_SIZE
end

local function ceiling(num, precision)
    return math.ceil(num / precision) * precision
end

local function computeExpirationBucket(
    currentTime,
    expirationInMs,
    bucketSizeMs
)
    return ceiling(
        currentTime + expirationInMs / UNIT_SIZE,
        bucketSizeMs / UNIT_SIZE
    )

end

return {
    msToExpirationTime = msToExpirationTime,
    expirationTimeToMs = expirationTimeToMs,
    ceiling = ceiling,
    computeExpirationBucket = computeExpirationBucket
}



