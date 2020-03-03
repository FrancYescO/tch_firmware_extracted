#!/usr/bin/env lua

local args = {...}
local cronHandler = require('vendorextensions.cron_handler')
if args[1] and args[2] then
  cronHandler.generateAndSetRandomTime(args[2], args[1])
end
