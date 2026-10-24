local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match
local proxy = require("datamodel")
--[[************* COPYRIGHT AND CONFIDENTIALITY INFORMATION ***************
--** Copyright © 2014 - 2018 TECHNICOLOR DELIVERY TECHNOLOGIES, SAS       **
--** - All Rights Reserved                                                **
--** Technicolor hereby informs you that certain portions                 **
--** of this software module and/or Work are owned by Technicolor         **
--** and/or its software providers.                                       **
--** Distribution copying and modification of all such work are reserved  **
--** to Technicolor and/or its affiliates, and are not permitted without  **
--** express written authorization from Technicolor.                      **
--** Technicolor is registered trademark and trade name of Technicolor,   **
--** and shall not be used in any manner without express written          **
--** authorization from Technicolor                                       **
--*************************************************************************
--]]

-- This will allow to map between interface name and scenario name
-- Map between the interface name and the Scenario name. to be used as: ScenarioName = ScenarioMAP[interface]. Scenario name is the L3 name. 
M.ScenarioMAP = {["adsl"] = 'ADSL',
                     ["vdsl"] = 'VDSL',
                     ["ewan"] = 'EWAN',}
-- Map between the Scenario name and the interface name. to be used as: interface = InterfaceMAP[Scenario]. Scenario name is the L3 name and interface is the data interface for that scenario. 
M.InterfaceMAP = {['ADSL'] = "adsl",
                     ['VDSL'] = "vdsl",
                     ['EWAN'] = "ewan",}

M.Scenarios = {
			["adsl"] = {
				["ifname"] = "atm_wan",
				["proto"] = "pppoa",
				["vpi"] = "0",
				["vci"] = "100",
				["encaps"] = "vc",
				["username"] = "vfnz_pro",
				["password"] = "VUtH2RM3",
				["ipv6"] = "1",
			},
			["vdsl"] = {
				["ifname"] = "vlanptm0",
				["proto"] = "dhcp",
				["reqopts"] = "1 3 6 43 51 54 58 59",
				["ipv6"] = "1",
			},
			["ewan"] = {
				["ifname"] = "vlanwan",
				["proto"] = "dhcp",
				["reqopts"] = "1 3 6 43 51 54 58 59",
				["ipv6"] = "1",
			},
}

--M.wwan_intf = "wwan0"  -- vbnt-r (DMA0120VHA)
--M.wwan_intf = "eth5"  -- vant-9 (DGA0130VDF-NZ)
M.wwan_intf = "eth6"  -- vbnt-z (DNA0130VDF-NZ)


-- This is to avoid sensing on irrelevant scenarios.
-- As the name indicates, list all the relevant data scenario for one phy in each table.
M.ADSL_DataScenarios = {["adsl"] = true, }
M.VDSL_DataScenarios = {["vdsl"] = true, }
M.ETH_DataScenarios = {["ewan"] = true, }

-- Events that indicate a migration occured:
M.UPevents = {
}
--- Given the type of L2 and the name of the ETH wan interface, returns whether the current L2
-- is up or down
--runtime = runtime environment holding references to ubus, uci, logger
-- @param l2type
-- @param ethintf the netdev interface used as wan
-- @return {boolean} true if the current L2 is up
--                   false if the current L2 is down
M.currentL2Up = function (runtime, l2type, ethintf)
   if l2type == "ADSL" or l2type == "VDSL" then
      local mode = xdslctl.infoValue("tpstc")
      if mode then
         if match(mode, "ATM") then
            return l2type == "ADSL"
         elseif match(mode, "PTM") then
            return l2type == "VDSL"
         end
      end
   elseif l2type == "ETH" then
      local carrier = runtime.scripth.l2HasCarrier("eth4")
      return carrier
   end
end

-- L3 Common functions:
M.existInterfaceCommon = function (x,runtime,name,CurrentScenarioName)
   if name == nil then
      return nil
   end
   local section_type = x:get('network',name)
   
   if section_type == 'interface' then
      runtime.logger:debug("L3_"..CurrentScenarioName.."EntryExit: existInterface: interface "..name.." exists.")
      return true
   else
      runtime.logger:debug("L3_"..CurrentScenarioName.."EntryExit: existInterface: interface "..name.." does not exist.")
      return false
   end
end

M.RxByteCheck = function(runtime)
   -- Rx Btyes Increament Check
   -- Returns number of failures
   local result = proxy.get("rpc.network.interface.@wan.rx_bytes")
   local Rx_Bytes = result and result[1].value or 0
   runtime.logger:notice("Rx Byte Check: "..Rx_Bytes .. " <> ".. runtime.l3rx_bytes)
   Rx_Bytes = tonumber(Rx_Bytes)
   if Rx_Bytes ~= tonumber(runtime.l3rx_bytes) then
      runtime.l3rx_bytes = Rx_Bytes
      runtime.l3dhcp_failures = 0
      return 0
   elseif runtime.l3dhcp_failures >= 3 then
      return -1
   else
      runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
      runtime.logger:notice("Rx Byte Check: failure "..runtime.l3dhcp_failures .. " of ".. 3)
      return runtime.l3dhcp_failures
   end
end

--- Get the DNS server list from system file (only IPv4 adresses)
local function getDNSServerList()
    local servers = {}
    local pipe = assert(io.open("/var/resolv.conf.auto", "r"))
    if pipe then
        for line in pipe:lines() do
            local result = line:match("nameserver (%d+%.%d+%.%d+%.%d+)")
            if result then
                servers[#servers+1] = result
            end
        end
    end
    return servers
end

--- Do a Ping check to ensure IP connectivity works
-- @return {boolean} whether the interface is up and a ping query was possible
M.checkPing = function (scripth, logger, iface)
    --PING Check
    logger:notice("Launching PING Request")
    local server_list=getDNSServerList()
    if server_list ~= nil then
        for _,v in ipairs(server_list)
        do
            logger:notice("Launching PING Request with DNS server " .. v)
            local status,successes_or_error = scripth.ping(v,iface,5,nil)
            if status then
                logger:notice("Ping: ".. successes_or_error .." Packets Received")
                if successes_or_error > 0 then
                    return true
                end
            else
                logger:notice("Ping error: ".. successes_or_error)
            end
        end
        logger:notice("Trying again - Launching PING Request with GOOGLE DNS server")
        local status,successes_or_error = scripth.ping('8.8.8.8',iface,5,nil)
        if status then
            logger:notice("Ping: ".. successes_or_error .." Packets Received")
            if successes_or_error > 0 then
                return true
            end
        else
            logger:notice("Ping error: ".. successes_or_error)
        end
    end
    return false
end

M.send_curl_status = function(url, interface)                                                                    
    local tmpfile = '/tmp/curl.txt'
    os.execute('curl -I --connect-timeout 20 --interface '..interface..' '..url..' > '..tmpfile)
    local f = io.open(tmpfile)
    if not f then 
       os.execute('rm -rf '..tmpfile)
       return -1 
    end
    for line in f : lines() do
       if string.match(line, "200.*OK") then
          f: close()
          os.execute('rm -rf '..tmpfile)
          return 1
       end
    end
    f: close()
    os.execute('rm -rf '..tmpfile)
    return 0
end

return M
