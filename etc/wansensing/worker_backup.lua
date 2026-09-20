local M = {}

M.SenseEventSet = {
    ['start'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_wan_ifdown'] = true,
    ['network_interface_wwan_ifup'] = true,
    ['network_interface_wwan_ifdown'] = true,
    ['cc_voip_fail'] = true,
}

Backup = { state="", error="" }

--Run a command
local function run_command(runtime,s)
   runtime.logger:info(s)
   os.execute(s)
end

--- mmpbxSipNetIface
-- @param runtime the runtime environment
-- @param intf the interface name
-- @param intf6 the interface6 name
local function mmpbxSipNetIface(runtime, intf, intf6)
    local uci = runtime.uci
    local cur = uci:cursor()
    if (cur:get("mmpbxrvsipnet","sip_net", "interface") ~= intf) then
	cur:set("mmpbxrvsipnet", "sip_net", "interface", intf)
	if intf6 then
		cur:set("mmpbxrvsipnet", "sip_net", "interface6", intf6)
	end
	cur:commit("mmpbxrvsipnet")
	run_command(runtime, "/etc/init.d/mmpbxd reload")
    end
end

--- cwmpdIface
-- @param runtime the runtime environment
-- @param intf the interface name
local function cwmpdIface(runtime, intf, intf6)
    local uci = runtime.uci
    local cur = uci:cursor()
    if (cur:get("cwmpd","cwmpd_config", "interface") ~= intf) then
	cur:set("cwmpd", "cwmpd_config", "interface", intf)
	if intf6 then
		cur:set("cwmpd", "cwmpd_config", "interface6", intf6)
	end
	cur:commit("cwmpd")
	run_command(runtime, "/etc/init.d/cwmpd reload")
    end
end

-- helper function to set remote access interface
-- @param runtime the runtime environment
-- @param intf the interface name
local function raIface(runtime, intf)
    local uci = runtime.uci
    local x = uci:cursor()
    if (x:get("web","remote", "interface") ~= intf) then
        x:set("web", "remote", "interface", intf)
        x:commit("web")
        run_command(runtime, "wget http://127.0.0.1:55555/ra?remote=reload_interface -O-")
    end
end

-- @param runtime  the runtime environment
-- @param event (e.g., ifup ifdown fail timeout)
local function UpdateBackUpState(runtime)
   local uci = runtime.uci
   local conn = runtime.ubus
   local cur = uci.cursor(UCI_CONFIG, "/var/state")
   Backup.state="BackupNotActive"
   Backup.error="ConnectionToMobileDown"

   --Administrative Enabled?
   if (cur:get("network","wwan", "auto") == '0') then
      Backup.error="Disabled"
   end

   local status = conn:call("network.interface.wwan", "status", { })
   if status and status.up then
      Backup.state="BackUpActive"
      Backup.error="None"
   end

   runtime.logger:notice("UpdateBackUpState  (state="..Backup.state..", error="..Backup.error.. ")")
   --Set current backupStatus and backupError in /var/state
   runtime.scripth.set_state(uci,"backupStatus", Backup.state)
   runtime.scripth.set_state(uci,"backupError", Backup.error)
end

local function SwitchCWMPSIPInterface(runtime, intf, vodafone_variant)
   local intf4
   local intf6
   local uci = runtime.uci
   local conn = runtime.ubus
   local cur = uci.cursor(UCI_CONFIG, "/var/state")

   if intf == "wan" then
     intf4 = "wan"
     intf6 = "wan6"
   elseif intf == "wwan" then
     intf4 = "wwan_4"
     intf6 = "wwan_6"
   else
     return
   end

   if cur:get("cwmpd", "cwmpd_config", "interface") ~= intf4 then
      runtime.logger:notice("WAN Sensing - cwmpd interface = " .. intf)
      cur:set("cwmpd", "cwmpd_config", "interface", intf4)
      cur:set("cwmpd", "cwmpd_config", "interface6", intf6)
      cur:commit("cwmpd")
      run_command(runtime, "/etc/init.d/cwmpd reload")
   else
      runtime.logger:notice("WAN Sensing - cwmpd interface already = " .. intf)
   end
   if (cur:get("mmpbxrvsipnet","sip_net", "interface") ~= intf4) and vodafone_variant == "NZ" then
      runtime.logger:notice("WAN Sensing - sip interface = " .. intf)
	  cur:set("mmpbxrvsipnet", "sip_net", "interface", intf4)
      cur:set("mmpbxrvsipnet", "sip_net", "interface6", intf6)
      cur:commit("mmpbxrvsipnet")
      run_command(runtime, "/etc/init.d/mmpbxd reload")
   end
end

--- BackUpData
-- @param runtime the runtime environment
-- @param event the event seen on the wan interface
--               only interested in the ifup/ifdown event
-- @param intf the interface name
local function BackUpData(runtime, event, intf)
   local uci = runtime.uci
   local cur = uci:cursor()
   local conn = runtime.ubus
   local scripthelpers = runtime.scripth
   local new_intf = ""
   local mobilestate = cur:get("network", "wwan", "auto")
   local autofailover = cur:get("wansensing", "global", "autofailover")
   local vodafone_variant = cur:get("env", "var", "vodafone_variant")

   if intf == "wan" then
      if event == "ifup" then
         if vodafone_variant == "NZ" then
            local status = conn:call("network.interface.wwan", "status", { })
            if status and status.up or mobilestate == "1" then
               runtime.logger:notice("WAN Sensing - disabling Mobile interface")
               cur:set("network", "wwan", "auto", "0")
               cur:commit("network")
               run_command(runtime, "/etc/init.d/network reload")
            end
            SwitchCWMPSIPInterface(runtime, "wan", vodafone_variant)
         elseif vodafone_variant == "VHA" then
           SwitchCWMPSIPInterface(runtime, "wan", vodafone_variant)
           conn:send("mobile", { event = "off"})  -- when wan is up, the LTE led should be off
         end
         raIface(runtime, "wan")
         new_intf = "wan"
         runtime.logger:notice("WAN Sensing - moving Backup to Primary Interface")
      elseif event == "ifdown" then
         -- To handle FTTH scenario where physical line will be UP always whereas Intf can goes down
         -- In that case L2 sensing will not reach sensing mobile, if eth connection is available.
         if autofailover == "1" then
            runtime.logger:notice("WAN Sensing - autofailover on")
            if mobilestate == "0" and vodafone_variant == "NZ" then
               cur:set("network", "wwan", "auto", "1");
               cur:commit("network")
               run_command(runtime, "/etc/init.d/network reload")
               runtime.logger:notice("WAN Sensing - Enabling Mobile interface")
            end
            new_intf = "wwan"
         else
            runtime.logger:notice("WAN Sensing - autofailover off")
            new_intf = "wan"
         end
     end
   elseif intf == "wwan" then
      if event == "ifup" and scripthelpers.checkIfInterfaceIsUp("wan") == false then
		 if vodafone_variant == "NZ" then
            -- Vodafone NZ requirement that cwmpd and VoIP interface switch to mobile if wan is down and wwan is up
			-- VHA requires an http page to be fetched before switching to guarantee the service is not barred
            SwitchCWMPSIPInterface(runtime, "wwan", vodafone_variant)
            raIface(runtime, "wwan")
         end
         runtime.logger:notice("WAN Sensing - mobile backup enabled")
         new_intf = "wwan"
      elseif event == "ifdown" then
         if autofailover == "1" then
            -- start from L2 state
            if vodafone_variant == "NZ" then
               cur:set("network", "wwan", "auto", "0")
               cur:commit("network")
               run_command(runtime, "/etc/init.d/network reload")
               runtime.logger:notice("WAN Sensing - mobile backup disabled")
            end
            new_intf = "wan"
         else
            new_intf = "wwan"
         end
         conn:send("mobile", { event = "off"})
      end
   end

   --Set data service in /var/state
   runtime.scripth.set_state(uci,"dataService", new_intf)
   -- to avoid conntrack flush for false events
   if (Backup.state == "BackupNotActive" and new_intf == "wan") or (Backup.state == "BackUpActive" and new_intf == "wwan") then
      run_command(runtime, "echo flush > /proc/net/nf_conntrack")
   end
end

--runtime = runtime environment holding references to ubus, uci, logger
function M.check(runtime, event)
   runtime.logger:notice("event received to backup worker "..event)
   UpdateBackUpState(runtime)
   if event == "start" then
      if runtime.scripth.checkIfInterfaceIsUp("wan") then
         M.check(runtime, "network_interface_wan_ifup")
      else
         M.check(runtime, "network_interface_wan_ifdown")
      end
      return
   elseif event=="network_interface_wan_ifup" then
      --Move Data Service to wan intf
      BackUpData(runtime, "ifup", "wan")
      return
   elseif event=="network_interface_wan_ifdown" then
      os.execute("cat /proc/net/dev_extstats; xtmctl operate intf --stats; xdslctl info --stats; xdslctl info") 
      --Move Data Service to mobile Intf
      BackUpData(runtime, "ifdown", "wan")
      return
   elseif event == "network_interface_wwan_ifup" then
      --Move Data Service to mobile intf
      BackUpData(runtime, "ifup", "wwan")
      return
   elseif event == "network_interface_wwan_ifdown" then
      --Move Data Service to wan intf
      BackUpData(runtime, "ifdown", "wwan")
      return
   end
   return
end

return M
