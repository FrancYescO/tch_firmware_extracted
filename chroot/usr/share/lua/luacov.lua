-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2010 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************

--[[
 This module, when loaded, starts measuring coverage as code is being executed by
 the VM. The resulting data can then be further processed with the accompanying
 'luacov_report' script to give you a readable view on how much code was covered
 at runtime.
 By default the data is written to one or more <random prefix>luacov_stats.out
 files in the current directory (one for each Lua state used in your process).
 In case the current directory is not suitable you can specify an environment
 variable LUACOV_STATSFILE_PREFIX whose content will be prefixed to each stats
 file name.

 IMPORTANT: to implement this coverage logging a debug hook is used.
 However, this hook is NOT inherited when new threads/coroutines are created.
 To get all the coverage measurements the debug hook must be installed before the
 actual coroutine body starts running.
 One way to achieve this is by providing a suitable definition of
 luai_userstatethread() in Lua's config header file. However, this requires a
 rebuild of liblua, which is a hassle or simply not feasible.
 Another way, and that's what luacov is doing, is to overload coroutine.wrap()
 and coroutine.create() to set the debug hook before running the actual
 coroutine body.
 Note that this overloading only happens the moment you call sethook() and not
 when luacov is loaded. This means that if your code stores a local reference
 to wrap() or create() those will not be overloaded and the coroutines created
 via those functions will not show up in the coverage measurements. In other
 words: you should do
   require("luacov").sethook(filter)
 before *any* of your code is executed.
 Also note that this doesn't change anything for coroutines/threads created via
 Lua's C API. Those will still remain unrecorded.
--]]

local dbg_sethook, getinfo = debug.sethook, debug.getinfo
local assert, type = assert, type
local create, wrap = coroutine.create, coroutine.wrap

-- File that logs each line being executed in this Lua state.
-- Note that we have to generate a random name so each Lua state gets
-- its own stats file. You don't want multiple Lua states running
-- in separate threads all writing to the same file.
local f = assert(io.open("/dev/urandom", "r"))
local prefix_length = 5
local bytes = f:read(prefix_length)
local prefix = ("%02x"):rep(prefix_length):format(bytes:byte(1, prefix_length))
f:close()
local env_prefix = os.getenv("LUACOV_STATSFILE_PREFIX") or ""

f = assert(io.open(env_prefix .. prefix .. "luacov_stats.out", "w"))
f:setvbuf("no")  -- no output buffering

-- Filter function optionally provided by caller to only log coverage
-- for relevant files.
local file_filter
-- If the optional file filter is given, cache the results so we don't have
-- to call the function for each trace.
local file_filter_cache
-- Keep track of the previous file we traced coverage for. In the log
-- file only output the filename if it's changed from the previous
-- entry. This significantly reduces the log size.
local previous_filename
-- The actual hook function
local function hook(what, line_nr)
  local info = getinfo(2, "S")
  -- for now we don't trace code not defined in files
  if info.source:sub(1,1) ~= "@" then
    return
  end
  local filename = info.source:sub(2)  -- strip leading '@'
  -- filter out our own file
  if filename:match("luacov.lua$") then
    return
  end
  -- if a filter was given then only record data for files that
  -- match the filter
  if file_filter then
    if file_filter_cache[filename] == nil then
      file_filter_cache[filename] = file_filter(filename)
    end
    if not file_filter_cache[filename] then
      return
    end
  end
  if previous_filename == filename then
    f:write(line_nr, "\n")
  else
    f:write(line_nr, " ", filename, "\n")
    previous_filename = filename
  end
  f:flush()
end

-- Replacement for coroutine.wrap() that enables coverage
-- recording before starting the actual coroutine body.
local function coro_wrap(f)
  return wrap(function(...)
    dbg_sethook(hook, "l")
    return f(...)
  end)
end

-- Replacement for coroutine.create() that enables coverage
-- recording before starting the actual coroutine body.
local function coro_create(f)
  return create(function(...)
    dbg_sethook(hook, "l")
    return f(...)
  end)
end

local M = {}

-- Install the hook function; from then on we're tracing coverage.
-- Optional argument: either a string or a function that will be used with
-- every data point to decide whether to record it or not.
--  - The string should be a pattern that will be used in string.match()
--    on the filename. Only data coming from files that match the filter
--    will be recorded.
-- - The function will be called with the filename as argument. It should
--   return true if data from that file should be recorded and false otherwise.
function M.sethook(filter)
  local ftype = type(filter)
  if ftype == "string" then
    file_filter = function(filename)
      return filename:match(filter) ~= nil
    end
    file_filter_cache = {}
  elseif ftype == "function" then
    file_filter = filter
    file_filter_cache = {}
  end
  coroutine.wrap = coro_wrap
  coroutine.create = coro_create
  dbg_sethook(hook, "l")
end

return M
