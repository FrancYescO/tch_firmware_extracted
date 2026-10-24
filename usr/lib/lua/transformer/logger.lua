--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- Dummy to redirect to the new location of logger

local logger = require("tch.logger")
local posix = require("tch.posix")

local logger_init = logger.init
logger.init = function(log_level, log_stderr)
  logger_init("", log_level, posix.LOG_PID + (log_stderr and posix.LOG_PERROR or 0))
  logger:warning("use tch.logger")
end

return logger
