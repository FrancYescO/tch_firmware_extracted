
local require = require
local setmetatable = setmetatable
local floor = math.floor

local posix = require 'tch.posix'
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC
local clock_gettime = posix.clock_gettime

local Chrono = {}
Chrono.__index = Chrono

local function newChrono()
  return setmetatable({}, Chrono)
end

function Chrono:ticks_per_second()
  return 1000
end

function Chrono:ticks()
  local seconds, nanoseconds = clock_gettime(CLOCK_MONOTONIC)
  return (seconds*1000) + floor(nanoseconds / 1000000)
end

return {
  new = newChrono,
}
