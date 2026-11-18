--[[
Copyright (c) 2017 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]


---
-- Common validation functions.
--
-- @module tch.validation

local M = {}

--- Check if the given time is in ISO 8601 format for combined date
-- and UTC time representation ("2016-12-29T10:24:00Z")
-- and potentially if the time is in the future.
-- @string time The time to check.
-- @bool[opt=false] futureTime If true also check if the given time is in the future.
-- @treturn boolean True if given time is valid time and, if requested, in the future.
-- @error Error message.
function M.validateTime(time, futureTime)
  local date = {}
  if type(time) == "string" then
    date.year, date.month, date.day, date.hour, date.min, date.sec = time:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
  end
  if not date.year then
    return nil, "Invalid format"
  end
  if not futureTime then
    return true
  end
  -- Converting the given "local time in UTC format" to "epoch value"
  local givenTime = os.time(date)
  -- Get the current time in epoch value
  local curTime = os.time()
  -- Compare both epoch values
  local timeDiff = givenTime - curTime
  if timeDiff < 0 then
    return nil, "Invalid future date"
  end
  return true
end

return M
