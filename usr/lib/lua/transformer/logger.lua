--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- Dummy to redirect to the new location of logger

local debug = debug

local logger = require("tch.logger")
local posix = require("tch.posix")

local function get_call_location(level)
  local info = debug.getinfo(level+1, "lS")
  local source = info.source
  local line = info.currentline
  if source and line then
    return source:gsub("^@", "") .. ":" .. line
  end
end

local logger_init = logger.init
logger.init = function(log_level, log_stderr)
  logger_init("", log_level, posix.LOG_PID + (log_stderr and posix.LOG_PERROR or 0))

  local location = get_call_location(2)
  if location then
    logger:warning("Use tch.logger in "..location)
  else
    logger:warning("use tch.logger")
  end
end

return logger
