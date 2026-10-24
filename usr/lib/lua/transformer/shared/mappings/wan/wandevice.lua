local require = require

local M = {}

local uci_helper = require 'transformer.mapper.ucihelper'
local activedevice = require 'transformer.shared.models.igd.activedevice'

local ethernet_binding = { config = "ethernet", sectionname = "port" }
local xdsl_binding = { config = "xdsl", sectionname = "xdsl" }
local gponl3_binding = { config = "gponl3", sectionname = "interface" }
local mobiled_binding = { config = "network", sectionname = "interface" }
local foreach_on_uci = uci_helper.foreach_on_uci

function M.entries()
  local WANDevices = {}
  -- DSL Entries
  foreach_on_uci(xdsl_binding, function(s)
    WANDevices[#WANDevices + 1] = "DSL|" .. s['.name']
  end)
  -- Ethernet Entries
  foreach_on_uci(ethernet_binding, function(s)
    if s['wan'] == '1' then
      WANDevices[#WANDevices + 1] = "ETH|" .. s['.name']
    end
  end)
  -- GPON Entries
  local veip = {}
  foreach_on_uci(gponl3_binding, function(s)
    -- iterate over all Ethernet ports and check the 'wan' option
    if s["l3dev"] and not veip[s["l3dev"]] then
      veip[s["l3dev"]] = true
      WANDevices[#WANDevices + 1] = "ETH|" .. s["l3dev"]
    end
  end)
  -- Mobiled Entries
  foreach_on_uci(mobiled_binding, function(s)
    if s.proto == "mobiled" then
        WANDevices[#WANDevices + 1] = "MOB|" .. s['.name']
    end
  end)
  -- WANConfig Entries
  for _, intf in pairs(activedevice.getActiveDevices()) do
    WANDevices[#WANDevices+1] = "ACTIVE|" ..intf
  end
  return WANDevices
end

return M
