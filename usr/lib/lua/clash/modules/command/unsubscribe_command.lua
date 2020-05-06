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
-- A module that implements the unsubscribe command.
--
-- @module modules.command.unsubscribe_command
--
local require = require

---- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

local function do_unsubscribe(args)
  if not args.subscr_id then
    return nil, "Missing subscription ID"
  end
  local res, errmsg = proxy.unsubscribe(args.subscr_id)
  if not res then
    print("ERROR: %s", errmsg)
  else
    print("Removed subscription %d", args.subscr_id)
  end
end

local usage_msg = [[
  Unsubscribe to a previous datamodel subscription.
    <subscr_id> (number) The subscription ID to unsubscribe from.
]]

-- Table representation of the unsubscribe command module
local command = {
  name = "unsubscribe",
  usage_msg = usage_msg,
  action = do_unsubscribe,
}

local M = {}

M.name = command.name

--- Function to initialize the unsubscribe command module.
-- This will register the unsubscribe command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the unsubscribe command module.
-- This will unregister the unsubscribe command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M