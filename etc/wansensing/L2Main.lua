---
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
-- Module L2 Main.
-- Module Specifies the check functions of a wansensing state
-- @module modulename
local M = {}
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_1(=idle)/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_device_eth4_up',
    'network_device_eth5_down',
    'network_device_eth5_up',
    'network_interface_wan_ifup',
    'network_interface_wan_ifdown' ,
}
local xdslctl = require('transformer.shared.xdslctl')
local optical = require('transformer.shared.optical')
local match = string.match
local process = require("tch.process")
local popen = io.popen


local function crossbarHandling(logger)

	  logger:debug("eth4 down and eth5 up, switch crossbar endpoints!!")
          -- get current end point for eth4
          local eth4ep
          local f = popen('ethctl eth4 phy-crossbar')
          if not f then return files end
          for line in f:lines() do
             eth4ep = line:match(":%s(%S+)%s*$")
          end
          f:close()
          logger:notice("eth4 mapped to endpoint " .. eth4ep)

          --turn off phy power
          process.execute("ethctl", {"eth4", "phy-power", "down"})
          process.execute("ethctl", {"eth5", "phy-power", "down"})
          process.execute("sleep", {"1"})
          --bing netdev down
          process.execute("ifconfig", {"eth4", "down"})
          process.execute("ifconfig", {"eth5", "down"})
          process.execute("ethswctl", {"-c", "wan", "-i", "eth4", "-o", "disable"})
          if( eth4ep == "9") then
              logger:debug("Switch WAN to Ethernet")
              process.execute("ethctl", {"eth5", "phy-crossbar", "port", "9"})
              process.execute("ethctl", {"eth4", "phy-crossbar", "port", "10"})
          elseif ( eth4ep == "10") then
              logger:debug("Switch WAN to SFP")
              process.execute("ethctl", {"eth5", "phy-crossbar", "port", "10"})
              process.execute("ethctl", {"eth4", "phy-crossbar", "port", "9"})
          end

          process.execute("sleep", {"1"})
          -- bring phy-power up
          process.execute("ethctl", {"eth4", "phy-power", "up"})
          process.execute("ethctl", {"eth5", "phy-power", "up"})
          -- enable wan mode on eth4
          logger:notice("Enable WAN mode on eth4")
          process.execute("ethswctl", {"-c", "wan", "-i", "eth4", "-o", "enable"})
          process.execute("sleep", {"1"})
          --bring up netdev
          logger:debug("Bring up netdev ifconfig up")
          process.execute("ifconfig", {"eth4", "up"})
          process.execute("ifconfig", {"eth5", "up"})
end

function M.check(runtime, event)
  local scripthelpers = runtime.scripth
  local conn = runtime.ubus
  local logger = runtime.logger
  local uci = runtime.uci
  local mode = xdslctl.infoValue("tpstc")
  local x = uci.cursor()
  local hw_version = x:get("env", "var", "hardware_version")
  local s_variant = (hw_version == "VBNT-S" or hw_version == "VCNT-3")  and true or false
  local board_mnemonic = x:get("env.rip.board_mnemonic")
  if not uci then
    return false
  end
  -- check if xDSL is up
  if s_variant and mode then
    if match(mode, "ATM") then
      return "L3Sense", "ADSL"
    elseif match(mode, "PTM") then
      return "L3Sense", "VDSL"
    end
  end

  if (board_mnemonic == "VCNT-D" and event:match("network_device_eth")) then
       -- get eth4, eth5 state from ubus
       local eth5state , eth4state
       local handle = popen("ubus call network.link status")
       local json = require("dkjson")

       local interface_data = handle:read("*a")
       ubus_table = json.decode(interface_data)
       handle:close()

       if type(ubus_table) == "table" then
           for _,data in pairs(ubus_table) do
               for _,value in pairs(data) do
                  if (value["interface"] == "eth5") then
                     eth5state = value["action"]
                  elseif (value["interface"] == "eth4") then
                     eth4state = value["action"]
                  end
               end
           end
       end

       logger:debug("netdev eth4 " .. eth4state ..", eth5 " .. eth5state)
       -- link is down on active WAN phy interface
       -- link is up on eth5 device, switch eth5 endpoint to eth4
         if (eth4state == "down" and eth5state == "up") then
	     crossbarHandling(logger)
	 end
  end
  -- check if wan ethernet port is up
  if scripthelpers.l2HasCarrier("eth4") then
    logger:notice("SFP connection: "..optical.getLinkStatus())
    if optical.getLinkStatus() == "linkup" then
	 logger:notice("SFP connected")
	 return "L3Sense", "SFP"
    else
      logger:notice("Ethernet wan connected")
      return "L3Sense", "ETH"
    end
  elseif not s_variant and mode then
    if match(mode, "ATM") then
      return "L3Sense", "ADSL"
    elseif match(mode, "PTM") then
      return "L3Sense", "VDSL"
    end
  end
  --DR Section to check if wwan is enabled and if not enable it (covered config errors)
  local mobile = x:get("network", "wwan", "auto")
  logger:notice("WAN Sensing Mobile: "..mobile)
  if mobile == "0" then
    logger:notice("WAN Sensing - Enabling Mobile interface")
    x:set("network", "wwan", "auto", "1")
    x:commit("network")
    conn:call("network.interface.wwan", "up", { })
  end
  return "L2Sense"
end

return M

