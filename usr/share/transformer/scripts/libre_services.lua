#!/usr/bin/env lua
local process = require("tch.process")
local match = string.match
local feature = arg[1]
if feature then
  local featureNumber, featureValue = feature:match("(%S+)_(%S+)$")
  featureNumber = feature:match("web") and "1" or "2"
  featureValue = string.upper(featureValue)
  process.execute("libre_luci", {"--server", "172.16.234.2", "--port",  "7778", "--command", "universal", "--command", "45", "--type", "2", "--data", ''..featureNumber..':'..featureValue..''})
  if featureNumber == "1" then
    process.execute("libre_luci", {"--server", "172.16.234.2", "--port", "7778", "--command", "reboot"})
  end
end
