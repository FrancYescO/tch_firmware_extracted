--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 -          Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

-- Each operation takes care of taking the package through the various
-- states to complete the requested operation.
-- The function can be called in two ways: with or without data.
-- * If called without data this means the next step of the operation is
--   to be initiated. The package should be in a stable state (states
--   with solid lines in the state machine diagram) and the function
--   transitions it to a transient state (states with dotted lines).
--   In this case the operation function is invoked in a child process
--   of lcmd so time consuming operations are not a problem. The function
--   can do one of two things:
--   * Return the result of the operation step as 'true` or `nil` + error.
--   * Execv() another executable. This executable should write the result
--     to stdout/stderr.
--   In both cases the result will be sent to the master lcmd process and
--   stored there until the child process stops. This data is then fed back
--   to the operation function for further processing.
--   TODO: which parts of lcmd can be accessed from within this child
--   process? How to properly quit the child process? E.g. if we ever
--   have persistency using a database what about pending queries?
-- * If called with data (possibly empty string) this means one step of
--   the operation completed. The package was in a transient state and
--   the function transitions it to a stable state. The operation function
--   should now inspect the data and decide what's next:
--   * If the operation is completed the function should return false.
--   * If the operation is not completed yet the function should return
--     the next (transient) state. The core will update the package's state
--     and invoke the operation for the next step.
--   Note that in this case the function is called in the context of the
--   main lcmd process and thus should return quickly.
--   When an operation is started the first invocation will be with empty
--   data so the operation can inspect the current state and return the
--   next state.

local posix = require("tch.posix")
local execv = posix.execv
local logger = require("tch.logger").new("operations")
local execenv = require("lcm.execenv")
local db = require("lcm.db")
local rm = os.remove

local s_pkg_states = require("lcm.package").states
local s_errorcodes = require("lcm.errorcodes")

local M = {}

---------------------------------------------------------------------

-- TODO: refactor so there's one implementation for each transition

-- this function runs in a child process
local function download(pkg)
  -- TODO: if we switch to using libcurl we should only require() the
  -- binding and library here in the function. That way only the child process
  -- will load it and the master process can remain smaller.
  logger:notice("starting download of %s:%s", pkg.execenv, pkg.URL)
  local args = {
    "-o", pkg.downloadfile,
    "-s", "-S",
--    "--limit-rate", "256",  -- for testing
  }
  if pkg.username then
    args[#args + 1] = "--anyauth"
    args[#args + 1] = "-u"
    -- TODO: username cannot contain a ":"; we should check for this
    -- and return an error (or perhaps this is not an issue if we
    -- talk directly to libcurl instead of via the tool?)
    args[#args + 1] = pkg.username .. ":" .. pkg.password
  end
  args[#args + 1] = pkg.URL
  local rc, errmsg = execv("/usr/bin/curl", args)
  if not rc then
    return nil, "failed to invoke curl: " .. (errmsg or "(no error message)")
  end
end

-- this function runs in a child process
local function install(pkg)
  logger:notice("starting install of %s:%s", pkg.execenv, pkg.URL)
  local ee = execenv.query(pkg.execenv)
  return ee.install(pkg)
end

-- this function runs in the master process
local function dl_and_install_check_complete(operationID, pkg, data)
  local cur_state = pkg.state
  local next_state
  if cur_state == s_pkg_states.NEW or cur_state == s_pkg_states.RETIRED then
    next_state = s_pkg_states.DOWNLOADING  -- 'download'/'redownload' transition
    pkg.downloadfile = "/tmp/lcm_" .. pkg.ID
  elseif cur_state == s_pkg_states.DOWNLOADING then
    if data == "" then
      -- TODO: ideally we can collect here more details of the
      -- downloaded file so we can add it to the pkg database
      pkg:set_state(s_pkg_states.DOWNLOADED, operationID)  -- 'download_complete' transition
      next_state = s_pkg_states.INSTALLING  -- 'install' transition
    else
      -- 'download_fail' transition
      pkg:set_state(s_pkg_states.RETIRED, operationID, s_errorcodes.DOWNLOAD_FAILED, "%s", data)
    end
  elseif cur_state == s_pkg_states.INSTALLING then
    if data == "" then
      rm(pkg.downloadfile)
      pkg.downloadfile = nil
      -- TODO: ugly way to figure out name and vendor of newly installed package;
      -- once we have a library to inspect an .ipk we should be able to get rid of this.
      -- TODO: if we are given a package to install that is already present opkg
      -- will happily report success. When we try to fill in the name and version
      -- we won't be able to find an opkg pkg that doesn't exist in our db (based
      -- on the pkg name) and the entry in our db will not get a name and version.
      -- In general: how to detect an installation of a package that already exists?
      -- (This should be the responsibility of the EE) And how to report it?
      local ee = execenv.query(pkg.execenv)
      local ee_list = ee.list()
      local db_list = db.query({execenv=pkg.execenv})
      local found_in_db = false
      for _, ee_pkg in ipairs(ee_list) do
        local name = ee_pkg.name
        found_in_db = false
        for _, db_pkg in ipairs(db_list) do
          if db_pkg.name == name then
            found_in_db = true
            break
          end
        end
        if not found_in_db then
          ee_pkg.state = nil  -- don't overwrite state because then pkg:set_state() won't send an event
          for property, value in pairs(ee_pkg) do
            pkg[property] = value
          end
          break
        end
      end
      if found_in_db then
        -- Everything was found in the database, we're dealing with a duplicate
        pkg:set_state(s_pkg_states.RETIRED, operationID, s_errorcodes.DUPLICATE_PKG, "duplicate package")
      else
        pkg:set_state(s_pkg_states.INSTALLED, operationID)  -- 'install_complete' transition
      end
    else
      -- 'install_fail' transition
      pkg:set_state(s_pkg_states.DOWNLOADED, operationID, s_errorcodes.INSTALL_FAILED, "%s", data)
    end
  else
    pkg:set_state(cur_state, operationID, s_errorcodes.WRONG_STATE, "%s: pkg in wrong state '%s'",
                  "download_and_install", cur_state)
  end
  return next_state
end

function M.download_and_install(operationID, pkg, data)
  if data then
    -- operation starting or a step of the operation finished; process outcome
    return dl_and_install_check_complete(operationID, pkg, data)
  end
  -- start a step of the operation; we're running in
  -- a child process of lcmd
  local cur_state = pkg.state
  if cur_state == s_pkg_states.DOWNLOADING then
    return download(pkg)
  end
  if cur_state == s_pkg_states.INSTALLING then
    return install(pkg)
  end
  return nil, "pkg in unexpected state " .. cur_state
end

---------------------------------------------------------------------

-- TODO: for start/stop we should rely on the EE to decide if it's actually running.
-- E.g. for the native EE a start just invokes an init script that in turn just tells
-- procd to start (an) instance(s). The current implementation considers the successful
-- invocation of the init script as meaning the package is started while this only
-- means the ubus message to procd was successfully sent. If procd could not start
-- the service or the service crashes (immediately or later) we are not aware of this.
-- To solve this the native EE should subscribe for notifications from the "service"
-- object in ubus. I found several shortcomings in the current codebase of procd/ubus:
-- - The ubus Lua binding seems to have a memoryleak: when subscribing the code
--   (ubus_lua_do_subscribe()) uses malloc() to allocate a struct to keep some state
--   but the pointer to this struct is never stored and consequently can never be freed.
--   Fixing this is not trivial because it requires some refactoring of that code.
--   Because our code would not subscribe and unsubscribe all the time this memory leak
--   would not be an immediate problem.
-- - The callback we register to invoke when a notification is received only gets the
--   notification data but not the notification name which in this case indicates whether
--   a service is started, stopped, respawned or failed. Without this information it's
--   not possible to properly track a service state. To get this information we will
--   need to update the ubus Lua binding.
-- - If an instance exits procd does not keep information on the exit status. It has
--   the exit code (see procd/service/instance.c:instance_exit()) but it does not use
--   it, except for debug logging. If we ever need more detailed info on why the
--   service stopped (e.g. status info in the data model) we will have to extend procd.

local function start_check_complete(operationID, pkg, data)
  local cur_state = pkg.state
  local next_state
  if cur_state == s_pkg_states.INSTALLED then
    next_state = s_pkg_states.STARTING  -- 'start' transition
  elseif cur_state == s_pkg_states.RUNNING then -- luacheck: ignore 542
    -- nothing to do
  elseif cur_state == s_pkg_states.STARTING then
    if data == "" then
      pkg:set_state(s_pkg_states.RUNNING, operationID)  -- 'start_complete' transition
    else
      -- 'start_fail' transition
      pkg:set_state(s_pkg_states.INSTALLED, operationID, s_errorcodes.START_FAILED, "%s", data)
    end
  else
    pkg:set_state(cur_state, operationID, s_errorcodes.WRONG_STATE, "%s: pkg in wrong state '%s'",
                  "start", cur_state)
  end
  return next_state
end

function M.start(operationID, pkg, data)
  if data then
    return start_check_complete(operationID, pkg, data)
  end
  -- start a step of the operation; we're running in
  -- a child process of lcmd
  local cur_state = pkg.state
  if cur_state == s_pkg_states.STARTING then
    local ee = execenv.query(pkg.execenv)
    return ee.start(pkg)
  end
  return nil, "pkg in unexpected state " .. cur_state
end

---------------------------------------------------------------------

local function stop_check_complete(operationID, pkg, data)
  local cur_state = pkg.state
  local next_state
  if cur_state == s_pkg_states.RUNNING then
    next_state = s_pkg_states.STOPPING  -- 'stop' transition
  elseif cur_state == s_pkg_states.INSTALLED then -- luacheck: ignore 542
    -- nothing to do
  elseif cur_state == s_pkg_states.STOPPING then
    if data == "" then
      pkg:set_state(s_pkg_states.INSTALLED, operationID)  -- 'stop_complete' transition
    else
      pkg:set_state(s_pkg_states.RUNNING, operationID, s_errorcodes.STOP_FAILED, "%s", data)  -- 'stop_fail' transition
    end
  else
    pkg:set_state(cur_state, operationID, s_errorcodes.WRONG_STATE, "%s: pkg in wrong state '%s'", "stop", cur_state)
  end
  return next_state
end

function M.stop(operationID, pkg, data)
  if data then
    return stop_check_complete(operationID, pkg, data)
  end
  -- start a step of the operation; we're running in
  -- a child process of lcmd
  local cur_state = pkg.state
  if cur_state == s_pkg_states.STOPPING then
    local ee = execenv.query(pkg.execenv)
    return ee.stop(pkg)
  end
  return nil, "pkg in unexpected state " .. cur_state
end

---------------------------------------------------------------------

local function uninstall_check_complete(operationID, pkg, data)
  local cur_state = pkg.state
  local next_state
  if cur_state == s_pkg_states.INSTALLED then
    next_state = s_pkg_states.UNINSTALLING  -- 'uninstall' transition
  elseif cur_state == s_pkg_states.DOWNLOADED then
    rm(pkg.downloadfile)
    pkg:set_state(s_pkg_states.RETIRED, operationID)  -- 'remove' transition
  elseif cur_state == s_pkg_states.RETIRED then
    db.remove(pkg.ID)
    pkg:set_state(s_pkg_states.GONE, operationID)  -- 'purge' transition
  elseif cur_state == s_pkg_states.RUNNING then
    next_state = s_pkg_states.STOPPING  -- 'stop' transition
  elseif cur_state == s_pkg_states.STOPPING then
    if data == "" then
      pkg:set_state(s_pkg_states.INSTALLED, operationID)  -- 'stop_complete' transition
      next_state = s_pkg_states.UNINSTALLING  -- 'uninstall' transition
    else
      pkg:set_state(s_pkg_states.RUNNING, operationID, s_errorcodes.STOP_FAILED, "%s", data)  -- 'stop_fail' transition
    end
  elseif cur_state == s_pkg_states.UNINSTALLING then
    if data == "" then
      pkg:set_state(s_pkg_states.RETIRED, operationID)  -- 'uninstall_complete' transition
    else
      -- 'stop_fail' transition
      pkg:set_state(s_pkg_states.INSTALLED, operationID, s_errorcodes.UNINSTALL_FAILED, "%s", data)
    end
  else
    pkg:set_state(cur_state, operationID, s_errorcodes.WRONG_STATE, "%s: pkg in wrong state '%s'",
                  "uninstall", cur_state)
  end
  return next_state
end

function M.uninstall(operationID, pkg, data)
  if data then
    return uninstall_check_complete(operationID, pkg,data)
  end
  -- start a step of the operation; we're running in
  -- a child process of lcmd
  local cur_state = pkg.state
  local ee = execenv.query(pkg.execenv)
  if cur_state == s_pkg_states.UNINSTALLING then
    return ee.uninstall(pkg)
  end
  if cur_state == s_pkg_states.STOPPING then
    return ee.stop(pkg)
  end
  return nil, "pkg in unexpected state " .. cur_state
end

---------------------------------------------------------------------

return M
