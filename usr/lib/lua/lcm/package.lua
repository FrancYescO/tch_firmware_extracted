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

local send_event = require("lcm.ubus").send_event
local state_machine = require("lcm.state_machine")
local s_errorcodes = require("lcm.errorcodes")
local db = require("lcm.db")
local logger = require("tch.logger").new("package")
local json = require ("dkjson")
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local open = io.open
local real_remove = os.remove
local format = string.format
local tremove = table.remove
local s_stable_states = state_machine.s_stable_states
local is_transient_state = state_machine.is_transient_state
local is_persistent_state = state_machine.is_persistent_state
local is_valid_state = state_machine.is_valid_state
local get_success_transition = state_machine.get_success_transition
local get_failure_transition = state_machine.get_failure_transition
local find_next_state = state_machine.find_next_state

local s_readonly_properties = {
  execenv = true,
  state = true,
  ID = true,
  version = true,
  name = true,
  _persistent_state = true,
}

---------------------------------------------------------------------
local Package = {}
Package.__index = Package

function Package:can_have_end_state(state)
  return is_valid_state(state) and not is_transient_state(state)
end

function Package:is_in_transient_state()
  return is_transient_state(self.state)
end

local function save_package(pkg)
  if pkg.state ~= s_stable_states.GONE then
    db.save(pkg)
  end
end

function Package:modify(properties)
  for name, value in pairs(properties) do
    if s_readonly_properties[name] then
      logger:warning("ignoring modification attempt for %s:%s to %s", self.ID, name, value)
    else
      -- empty string value unsets the property
      if value == "" then
        value = nil
      end
      self[name] = value
    end
  end
  save_package(self)
  return true
end

function Package:clear_error()
  self.errorcode = nil
  self.errormsg = nil
end

local function pkgUpdateState(pkg, state)
  local changed = state ~= pkg.state
  pkg.state = state
  if changed and is_persistent_state(state) then
    pkg._persistent_state = state
  end
  return changed
end

local function pkgUpdateError(pkg, errorcode, errormsg_fmt, ...)
  local changed = errorcode ~= pkg.errorcode
  pkg.errorcode = errorcode

  if errormsg_fmt then
    local errormsg = format(errormsg_fmt, ...)
    if errormsg ~= pkg.errormsg then
      pkg.errormsg = errormsg
      changed = true
    end
  end
  return changed
end

local function pkgWasUpdated(stateChanged, errorChanged)
  return stateChanged or errorChanged
end

local StateChangeEvent = {}
StateChangeEvent.__index = StateChangeEvent

function StateChangeEvent:send()
  local pkg = self.pkg
  local event = {
    ID = pkg.ID,
    operationID = self.operationID,
    execenv = pkg.execenv,
    name = pkg.name,
    vendor = pkg.vendor,
    state = pkg.state,
    old_state = self.old_state,
    errorcode = pkg.errorcode,
    errormsg = pkg.errormsg
  }
  send_event("pkg.statechange", event)
  logger:notice("state change of package %s: state=%s, old_state=%s, errorcode=%s, errormsg=%s",
                  pkg.ID, pkg.state, self.old_state, tostring(pkg.errorcode), tostring(pkg.errormsg))
end

local function newStateChangeEvent(pkg, operationID)
  return setmetatable({
    pkg = pkg,
    operationID = operationID,
    old_state = pkg.state
  }, StateChangeEvent)
end

local function pkgIsSane(pkg)
  if not pkg.errormsg then
    return true
  end
  return nil, pkg.errormsg
end

-- Change the state of a package and optionally also set
-- an error code and error message.
-- The error message can be a format string.
-- It's allowed to set the state to the current state.
-- An event will be sent out if either the state changes
-- or error information is added.
function Package:set_state(state, operationID, errorcode, errormsg_fmt, ...)
  if not is_valid_state(state) then
    logger:error("attempt to set unknown state '%s' for pkg %s:%s (cur_state=%s)",
                 tostring(state), tostring(self.execenv), tostring(self.URL), tostring(self.state))
    return nil, "Attempt to set unknown state"
  end
  local changeEvent = newStateChangeEvent(self, operationID)
  local changed = pkgWasUpdated(
    pkgUpdateState(self, state),
    pkgUpdateError(self, errorcode, errormsg_fmt, ...)
  )
  if changed then
    save_package(self)
    changeEvent:send()
  end
  return pkgIsSane(self)
end

local function download(package)
  package.downloadfile = "/tmp/lcm_" .. package.execenv .. "/" .. package.ID
end

local function remove(package)
  if package.downloadfile then
    local fd = open(package.downloadfile, "r")
    if fd then
      fd:close()
      real_remove(package.downloadfile)
    end
    package.downloadfile = nil
  end
end

function Package:remove()
  return db.remove(self.ID)
end

local function pending_actions(pkg)
  local pending = pkg._pending_actions
  if not pending then
    pending = {}
    pkg._pending_actions = pending
  end
  return pending
end

function Package:add_pending_action(seqnr, operationID, desired_end_state)
  local pending = pending_actions(self)
  pending[#pending+1] = {
    sequence = seqnr,
    operationID = operationID,
    desired_end_state = desired_end_state
  }
  save_package(self)
end

function Package:pending_actions(actions)
  actions = actions or {}
  local pending = pending_actions(self)
  for _, action in ipairs(pending) do
    actions[#actions+1] = {
      package = self,
      sequence = action.sequence,
      desired_end_state = action.desired_end_state,
      operation_ID = action.operationID,
    }
  end
  return actions
end

local function pending_action_index(pkg, seqnr)
  local pending = pending_actions(pkg)
  for i, action in ipairs(pending) do
    if action.sequence == seqnr then
      return i
    end
  end
end

function Package:remove_pending_action(seqnr)
  local idx = pending_action_index(self, seqnr)
  if idx then
    tremove(pending_actions(self), idx)
    save_package(self)
  end
end

local function purge(package)
  package:remove()
end

local function download_complete(package)
  -- Double check. The download should have succeeded if we get here, this is a sanity check
  local fd = open(package.downloadfile, "r")
  if not fd then
    return nil, "download_fail", "There was no file downloaded, unable to proceed."
  end
  fd:close()
end

local edge_actions = {
  download = download,
  remove = remove,
  redownload = download,
  purge = purge,
  download_complete = download_complete,
  install_complete = remove,
}

local edge_errorcodes = {
  download_fail = s_errorcodes.DOWNLOAD_FAILED,
  install_fail = s_errorcodes.INSTALL_FAILED,
  start_fail = s_errorcodes.START_FAILED,
  stop_fail = s_errorcodes.STOP_FAILED,
  uninstall_fail = s_errorcodes.UNINSTALL_FAILED,
}

function Package:advance_state(operation_ID, desired_state, return_value)
  logger:debug("Entered advance_state with ID %s, desired state %s and return_value %s", operation_ID, desired_state, tostring(return_value))
  if self.state == s_stable_states.GONE then
    -- Can't advance from this state, stop here
    return self:set_state(self.state, operation_ID, s_errorcodes.WRONG_STATE, "Unable to progress out of gone state")
  end
  if desired_state and is_transient_state(desired_state) then
    return self:set_state(self.state, operation_ID, s_errorcodes.WRONG_STATE, "Unable to end in a transient state")
  end
  if return_value == "" then
    return_value = nil
  end
  local decoded_value
  if return_value then
    -- We still have a return value, it can be an encoded result or an error message.
    -- Try to decode it.
    decoded_value = json.decode(return_value)
    if decoded_value then
      -- If we were able to decode the return value, it's not an error message. Clear it.
      return_value = nil
    end
  end
  local next_state, edge
  if is_transient_state(self.state) then
    -- Currently we only have transient states with two possible outcomes (success or failure)
    -- If this ever changes, we need to distinguish here between the cases.
    if decoded_value then
      -- The external process returned metadata for the package, add it.
      for key, value in pairs(decoded_value) do
        if not self[key] then
          -- We don't allow overriding existing values. This functionality is purely to populate the
          -- properties for the first time.
          self[key] = value
        end
      end
    end
    if not return_value then
      next_state, edge = get_success_transition(self.state)
    else
      next_state, edge = get_failure_transition(self.state)
    end
  else
    next_state, edge = find_next_state(self.state, desired_state)
    return_value = nil
  end
  if not next_state then
    return self:set_state(self.state, operation_ID, s_errorcodes.WRONG_STATE, "Unable to progress from %s to %s", self.state, desired_state or "<unknown>")
  end
  if edge_actions[edge] then
    -- We need to perform an internal action during this state transition. Perform it first.
    local ok, new_edge, errmsg = edge_actions[edge](self)
    if not ok and new_edge and errmsg then
      next_state = self.state
      edge = new_edge
      return_value = errmsg
    end
  end
  return self:set_state(next_state, operation_ID, edge_errorcodes[edge], return_value)
end

local M = {}

local function make_package(pkg)
  setmetatable(pkg, Package)
  db.add(pkg)
  return pkg
end

function M.new(info)
  if type(info) ~= "table" then
    return nil, "Invalid package info provided"
  end
  if not info.execenv then
    return nil, "No execution environment specified"
  end
  if not info.URL then
    return nil, "No URL specified"
  end
  if not info.ID then
    info.ID = db.generateID()
  end
  info.state = s_stable_states.NEW
  return make_package(info)
end

local function find_existing_package(info)
  -- we currently assume we can find the package based on the EE name,
  -- package name and version.
  -- This assumption may be incorrect and the actual method of locating
  -- an existing package in the db based on the given info might depend on
  -- the EE. So at some point we might delegate this to the EE, if the
  -- EE indicates it can and wants to do that.
  -- For now we keep it simple.
  -- TODO: assess the above
  local pkgs = db.query({
    execenv = info.execenv,
    name = info.name,
    version = info.version,
  })
  if not pkgs or #pkgs ~= 1 then
    -- no or multiple packages found
    -- failed to find a unique match
    return
  end
  return pkgs[1]
end

function M.load(info)
  if type(info) ~= "table" then
    return nil, "Invalid package info provided"
  end
  if not info.execenv then
    return nil, "No execution environment specified"
  end
  local package = find_existing_package(info)
  if not package then
    info.ID = db.generateID()
    info.URL = "file:///default.installed"
    info.state = s_stable_states.INSTALLED
    package = make_package(info)
  end
  return package
end

function M.query(params)
  return db.query(params)
end

local function restore_package(pkg_info)
  --TODO: if the just loaded state is RUNNING we should check if the process
  -- is still running or not.
  -- If it runs the package can stay in the running state.
  -- If not we have to decide whether to start it or not.
  if not is_persistent_state(pkg_info.state) then
    pkg_info.state = pkg_info._persistent_state or s_stable_states.NEW
  end
  return make_package(pkg_info)
end

function M.init(config)
  db.init(config.db_type, config.db_location)
  db.restore_contents(function(pkg_info)
    return restore_package(pkg_info)
  end)
end

return M
