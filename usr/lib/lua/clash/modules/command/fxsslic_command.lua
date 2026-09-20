--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2020 - 2020  -  Technicolor Delivery Technologies, SAS **
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
-- @module modules.command.fxsslic_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")
local cmdAssist = require("helper.command")

local cmdName = "fxs_slic_test"
local usageMsg = [[
  Runs and displays the results of slic tests of FXS devices connected to the board.
  <device> (string) FXS device name
  <test>   (string) Slic test to be performed
]]

local function isValidDevice(device)
  local fxsDevicesList = {}
  local result = proxy.get("uci.mmpbxbrcmfxsdev.device.")
  if result then
    for _, entries in ipairs(result) do
      local path = tostring(entries.path)
      local fxsDevice = path:match("@(%a+_%a+_%d+)")
      if not fxsDevicesList[fxsDevice] then
        fxsDevicesList[fxsDevice] = true
      end
    end
  end
  if not fxsDevicesList[device] then
    return false
  end
  return true
end

local function verifyArgs(args)
  if not args then
    return false
  end

  local validSlicTests = {
    ["voltage"] = true,
    ["impedance"] = true,
    ["off-hook"] = true,
    ["ren"] = true,
  }
  -- Check if device name and slic test is valid
  if not args.device or not isValidDevice(args.device) or not args.test or not validSlicTests[string.lower(args.test)] then
    return false
  end

  return true
end

local function fxsSlicTest(args)
  args = cmdAssist.rename_args(usageMsg, args)

  -- Verification of args
  if not verifyArgs(args) then
    return nil, "Invalid arguments"
  end

  local ok, errMsg = cmdAssist.launch_command(cmdName, args)
  if not ok then
    print(errMsg)
  end
end

-- Table representation of the fxs_slic_test command module
local command = {
  name = cmdName,
  usage_msg = usageMsg,
  action = fxsSlicTest,
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

M.init = function()
  register(command)
end

M.destroy = function()
  unregister(command)
end

return M
