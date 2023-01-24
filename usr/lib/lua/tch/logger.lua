--[[
Copyright (c) 2016-2017 Technicolor Delivery Technologies, SAS

The source code form of this lua-tch component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- Logging module.
--
-- Intended way of using:
--
-- - Load it using require():
--     local logger = require("tch.logger")
-- - Initialize using `logger.init`. Pass the name of your module,
--   the desired global log level (1 to 6), syslog options of interest
--   and default syslog facility.
--     local posix = require("tch.posix")
--     logger.init("mymodule", 3, posix.LOG_PID + posix.LOG_CONS, posix.LOG_USER)
-- - Create zero or more logging objects for different parts of your application
--   where each object can optionally have its own name and log level. On that
--   object you have a log function for each log level and a function to change
--   the log level. You can also clear the specific log level and fall back to
--   the global log level.
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
-- @module tch.logger
-- @see tch.posix

local setmetatable = setmetatable
local format = string.format

local posix = require("tch.posix")

-- Our logger module has 6 log levels, ranging from 1 to 6.
-- To each level corresponds a syslog priority.
local syslog_priorities = {
  posix.LOG_CRIT,
  posix.LOG_ERR,
  posix.LOG_WARNING,
  posix.LOG_NOTICE,
  posix.LOG_INFO,
  posix.LOG_DEBUG,
}

-- module table with default global log level
local M = { log_level = 3 }

-- metatable for logger instances
local logger = {}
logger.__index = logger

--- Create a new logger object with its own log level and optionally a name.
-- @string modname Optional name of the module using the logger. It will
--   be added to each log message, if present. This name is in addition
--   to the global name set in `init`.
-- @int log_level The initial log level. If not given then the
--   global log level will be used.
-- @treturn logger The newly created logger instance.
function M.new(modname, log_level)
  local self = {
    modname = modname,
    log_level = log_level
  }
  setmetatable(self, logger)
  return self
end

--- Initialize the logger module.
-- This isn't strictly necessary but it allows you configure a name
--   that is prepended to every log message, a different default log level,
--   additional syslog options or a different default syslog facility.
--   The function may be called multiple times.
-- @string name This name will be prepended to every log message,
--   including those generated using logger objects created with `new`.
-- @int log_level The global log level as a number from 1 to 6.
--   1 is the most important level, 6 the least. A level outside
--   this range will be ignored and the default level (3) will be used.
-- @int[opt=0] syslog_options Bitwise OR of syslog option constants.
-- @int[opt=tch.posix.LOG_DAEMON] syslog_facility Syslog facility to use.
-- @see openlog(3)

function M.init(name, log_level, syslog_options, syslog_facility)
  posix.openlog(name, syslog_options or 0, syslog_facility or posix.LOG_DAEMON)
  M:set_log_level(log_level)
end

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
    posix.syslog(syslog_priorities[log_level], msg)
  end
end

--- Logger methods.
-- @type logger

--- Log a critical message.
-- @string fmt Format of the log message of critical severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:critical(fmt, ...)
  log(self, 1, fmt, ...)
end

--- Log an error message.
-- @string fmt Format of the log message of error severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:error(fmt, ...)
  log(self, 2, fmt, ...)
end

--- Log a warning message.
-- @string fmt Format of the log message of warning severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:warning(fmt, ...)
  log(self, 3, fmt, ...)
end

--- Log a notice message.
-- @string fmt Format of the log message of notice severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:notice(fmt, ...)
  log(self, 4, fmt, ...)
end

--- Log an informational message.
-- @string fmt Format of the log message of info severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:info(fmt, ...)
  log(self, 5, fmt, ...)
end

--- Log a debug message.
-- @string fmt Format of the log message of debug severity.
-- @param[opt] ... Arguments of the format string, if any.
-- @see string.format
function logger:debug(fmt, ...)
  log(self, 6, fmt, ...)
end

--- Change or clear the log level of this logger.
-- @int log_level The new log level. It must be a number from 1 to 6.
--   A level outside this range will be ignored.
--   Pass `nil` to clear this logger's specific log level
--   and use the global log level.
function logger:set_log_level(log_level)
  if log_level == nil then
    if self ~= M then
      self.log_level = nil
    end
  elseif log_level >= 0 and log_level <= 6 then
    self.log_level = log_level
  end
end

-- turn the module itself in a global logger object
setmetatable(M, logger)

return M