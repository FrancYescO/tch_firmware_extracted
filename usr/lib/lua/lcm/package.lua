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
local logger = require("tch.logger").new("package")
local pairs, setmetatable, tostring = pairs, setmetatable, tostring
local format = string.format

-- see package_states.dot for the state machine
local s_states = {
  NEW          = "new",          -- stable
  DOWNLOADING  = "downloading",  -- transient
  DOWNLOADED   = "downloaded",   -- stable
  INSTALLING   = "installing",   -- transient
  INSTALLED    = "installed",    -- stable
  UNINSTALLING = "uninstalling", -- transient
  RETIRED      = "retired",      -- stable
  STARTING     = "starting",     -- transient
  RUNNING      = "running",      -- stable
  STOPPING     = "stopping",     -- transient
  GONE         = "gone"          -- stable
}

local s_valid_states = {}
for _, state in pairs(s_states) do
  s_valid_states[state] = true
end

local s_readonly_properties = {
  execenv = true,
  state = true,
  ID = true,
  version = true,
  name = true
}

---------------------------------------------------------------------
local Package = {}
Package.__index = Package

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
  return true
end

function Package:clear_error()
  self.errorcode = nil
  self.errormsg = nil
end

-- Change the state of a package and optionally also set
-- an error code and error message.
-- The error message can be a format string.
-- It's allowed to set the state to the current state.
-- An event will be sent out if either the state changes
-- or error information is added.
function Package:set_state(state, operationID, errorcode, errormsg_fmt, ...)
  if not s_valid_states[state] then
    logger:error("attempt to set unknown state '%s' for pkg %s:%s (cur_state=%s)",
                 tostring(state), self.execenv, self.URL, self.state)
    return
  end
  local old_state = self.state
  self.state = state
  -- send event if state changes ...
  local changed = (old_state ~= state)
  -- ... or send event if error code is given and it's different from current
  if errorcode and (errorcode ~= self.errorcode) then
    self.errorcode = errorcode
    changed = true
  end
  -- ... or send event if error message is given and it's different from current
  local errormsg
  if errormsg_fmt then
    errormsg = format(errormsg_fmt, ...)
  end
  if errormsg and (errormsg ~= self.errormsg) then
    self.errormsg = errormsg
    changed = true
  end
  if changed then
    send_event("pkg.statechange", { ID = self.ID, operationID = operationID, execenv = self.execenv,
               name = self.name, vendor = self.vendor, state = state, old_state = old_state,
               errorcode = self.errorcode, errormsg = self.errormsg })
    logger:notice("state change of package %s: state=%s, old_state=%s, errorcode=%s, errormsg=%s",
                  self.ID, state, old_state, tostring(self.errorcode), tostring(self.errormsg))
  end
end

---------------------------------------------------------------------
local M = { states = s_states }

function M.new(info)
  if not info.execenv then
    return nil, "no execenv specified"
  end
  if not info.state then
    return nil, "no state specified"
  end
  return setmetatable(info, Package)
end

return M
