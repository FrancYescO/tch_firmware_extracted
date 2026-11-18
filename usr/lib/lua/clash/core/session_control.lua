--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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
---
-- Handles all CLI session logic. Exposes logic to start a new session or destroy
-- an existing session.
--
-- @module core.session_control

local setmetatable, require, ipairs = setmetatable, require, ipairs
local gsub = string.gsub
local proxy = require("datamodel-bck")
local tch_uuid = require("tch.uuid")

local session_tp = "Command.Session."

--- @type CliSession
local CliSession = {}
CliSession.__index = CliSession

function CliSession:start()
  local uuid = self.uuid
  local ok, errmsg = proxy.getPN(uuid, self.session_op, true)
  if not ok then
    -- Session doesn't exist yet.
    ok, errmsg = proxy.add(uuid, session_tp, uuid)
    if not ok then
      self.logger:critical("Can't create session %s in datamodel: %s", uuid, errmsg)
      return nil, errmsg
    end
  end
  return true
end

function CliSession:stop()
  local uuid = self.uuid
  local ok, errmsg = proxy.del(uuid, self.session_op)
  if not ok then
    self.logger:critical("Couldn't delete session %s in datamodel: %s", uuid, errmsg)
    return nil, errmsg
  end
  return true
end

function CliSession:check_active()
  local uuid = self.uuid
  local result, errmsg = proxy.get(uuid, self.session_op.."Running.")
  if result then
    for _, param in ipairs(result) do
      if param.param == "pid" then
        return true
      end
    end
  end
  return false
end

function CliSession:get_uuid()
  return self.uuid
end

---
-- @section end
local M = {}

--- Initializes a new session control.
-- @param logger An initialized syslog logger object.
-- @treturn CliSession A new CLI session control.
M.new = function(logger)
  local uuid = tch_uuid.uuid_generate() or "ad81aa1c49d54108b4594ad53a65b20d"
  uuid = gsub(uuid,"-","")
  local self = {
    logger = logger,
    uuid = uuid,
    session_op = session_tp.."@"..uuid..".",
  }
  local session = setmetatable(self, CliSession)
  return session
end

return M