--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- Logging module.
-- 
-- Intended way of using:
-- - Load it using require():
--     local logger = require("transformer.logger")
-- - Initialize using logger.init(). Pass the desired global log level (1 to 6)
--   and whether you want logs to also be sent to stderr (next to syslog).
-- - Create a logging object that has optionally a name and optionally a
--   specific log level. On that object you have a log function for each log
--   level and a function to change the log level. You can also clear the
--   specific log level and fall back to the global log level.
--     local log = logger.new("mymodule", 2)
--     log:critical("%s:%d", "oops", 42)
--     log:error(....)
--     log:warning(....)
--     log:notice(....)
--     log:info(....)
--     log:debug(....)
--     log:set_log_level(4)
-- - Use the methods on the global logging object to send log output. The
--   global logging object is the module itself.
--     logger:critical(....)
--     logger:error(....)
--     ...

local setmetatable = setmetatable
local format = string.format

local syslog = require("syslog")

-- Our logger module has 6 log levels, ranging from 1 to 6.
-- To each level corresponds a syslog logging function.
local syslog_functions = {
  syslog.critical,
  syslog.error,
  syslog.warning,
  syslog.notice,
  syslog.info,
  syslog.debug
}

-- module table with default global log level
local M = { log_level = 3 }

-- metatable for logger instances
local logger = {}
logger.__index = logger

-- actually log the message but only if log level says so
local function log(logger, log_level, fmt, ...)
  if log_level <= (logger.log_level or M.log_level) then
    local msg
    local modname = logger.modname
    if modname then
      msg = format("[%s] " .. fmt, modname, ...)
    else
      msg = format(fmt, ...)
    end
    syslog_functions[log_level](msg)
  end
end

--- Log a critical message.
function logger:critical(fmt, ...)
  log(self, 1, fmt, ...)
end

--- Log an error message.
function logger:error(fmt, ...)
  log(self, 2, fmt, ...) 
end

--- Log a warning message.
function logger:warning(fmt, ...)
  log(self, 3, fmt, ...) 
end

--- Log a notice message.
function logger:notice(fmt, ...)
  log(self, 4, fmt, ...) 
end

--- Log an informational message.
function logger:info(fmt, ...)
  log(self, 5, fmt, ...) 
end

--- Log a debug message.
function logger:debug(fmt, ...)
  log(self, 6, fmt, ...) 
end

--- Change or clear the log level of this logger.
-- @param log_level The new log level. It must be a number from 1 to 6.
--                  A level outside this range will be ignored.
--                  Pass nil to clear this logger's specific log level
--                  and use the global log level.
function logger:set_log_level(log_level)
  if log_level == nil then
    if self ~= M then
      self.log_level = nil
    end
  elseif log_level >= 0 and log_level <= 6 then
    self.log_level = log_level
  end
end


--- Create a named (optional) logger with its own log level.
-- @param modname Optional name of the module using the logger. It will
--                be added to each log message, if present.
-- @param log_level the initial log level. If not given then the
--                  global log level will be used.
-- @return a logger instance
function M.new(modname, log_level)
  local self = {
    modname = modname,
    log_level = log_level
  }
  setmetatable(self, logger)
  return self
end

-- turn the module itself in a global logger object
setmetatable(M, logger)

--- Initialize the logger module.
-- This isn't strictly necessary but it's the only way to set a different
-- global log level and enable logging to stderr.
-- The function may be called multiple times.
-- @param log_level The global log level as a number from 1 to 6.
--                  1 is the most important level, 6 the least.
--                  A level outside this range will be ignored and
--                  the default level will be used.
-- @param log_stderr Boolean indicating whether to also log to stderr.
function M.init(log_level, log_stderr)
  syslog.openlog("transformer", log_stderr and syslog.options.LOG_PERROR or 0,
                 syslog.facilities.LOG_DAEMON)
  M:set_log_level(log_level)
end

return M
