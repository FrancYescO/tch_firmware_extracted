
local M = {}

local bridged = require("bridgedmode_helper")

local bridge_limit_list = {
  ["gateway.lp"] = true,
  ["broadband.lp"] = true,
  ["wireless.lp"] = true,
  ["LAN.lp"] = true,
  ["usermgr.lp"] = true,
}

function M.get_limit_info()
  return {bridged=bridged.isBridgedMode()}
end

function M.card_limited(info, cardname)
  if info.bridged then
    return not bridge_limit_list[cardname]
  end
  return false
end

return M
