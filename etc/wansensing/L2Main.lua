package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")

local M = {}
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

local xdslctl = require('transformer.shared.xdslctl')
local match = string.match

local ADSL_DataScenarios = myhelpers.ADSL_DataScenarios
local VDSL_DataScenarios = myhelpers.VDSL_DataScenarios
local ETH_DataScenarios = myhelpers.ETH_DataScenarios

--Map between interface name and scenario name
local ScenarioMAP = myhelpers.ScenarioMAP
local InterfaceMAP = myhelpers.InterfaceMAP

local lowerinterfaces2Scenario = {
    atm_wan = "ADSL",
    ptm0 = "VDSL",
    vlanptm0 = "VDSL",
    eth4 = "EWAN",
    vlanwan = "EWAN",
}

function M.check(runtime)
    local scripthelpers = runtime.scripth
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    local cur = uci.cursor()

    -- if wan has a lower interface, then we need to find the interface that wan has been copied to, and copy it back, then copy dummy to wan
    -- usually caught by exit of L3 scripts, but a restart may put it out of sync
    local wanifname = cur:get("network", "wan", "ifname")
    if wanifname then
        CurrentScenarioName = lowerinterfaces2Scenario[wanifname]
        if CurrentScenarioName then
            CurrentScenario = InterfaceMAP[CurrentScenarioName]
            if CurrentScenario then
                --remove CurrentScenario if it already existed (copy_interface would only merge otherwise)
                scripthelpers.delete_interface(CurrentScenario)
                --Make a copy of "network.wan" to "network.CurrentScenario"
                scripthelpers.copy_interface("wan",CurrentScenario)
                --remove the wan interface(copy_interface done next would only merge otherwise)
                scripthelpers.delete_interface("wan") -- yet another commit
                --Make a copy of "network.dummy" to "network.wan"
                scripthelpers.copy_interface("dummy","wan")
                --reload the network topic as it was changed by the scripthelpers functions
                cur:load("network")
                --Make Sure that dummy wan and CurrentScenario does not come up
                cur:set("network", "dummy", "auto", "0" )
                cur:set("network", "wan", "auto", "0" )
                cur:set("network", CurrentScenario, "auto", "0" )
                cur:commit("network")
            else
--                runtime.logger:notice("L2Main: wan has lower interface but no known scenario for interface "..CurrentScenarioName..".")
            end
        else
--            runtime.logger:notice("L2Main: wan has lower interface but no known interface for "..wanifname..".")
        end
    end

    -- check if wan ethernet port is up
    -- TBD: Foresee a mechanism to avoid looping here forever L2-L3Sense.
    if scripthelpers.l2HasCarrier("eth4") then
        return "L3Sense", "ETH"
    end

    -- check if xDSL is up
    local mode = xdslctl.infoValue("tpstc")
    if mode then
        if match(mode, "ATM") then
            return "L3Sense", "ADSL"
        elseif match(mode, "PTM") then
            return "L3Sense", "VDSL"
        end
    end

    local autofailover = cur:get("wansensing", "global", "autofailover")
    local wwan_auto = cur:get("network", "wwan", "auto")
    local vodafone_variant = cur:get("env", "var", "vodafone_variant")
    if (autofailover == "1") and (wwan_auto == "0") then  -- If automatic failover and wwan auto is not enabled yet
        local origL2 = cur:get("wansensing", "global", "l2type")
        local section
        cur:foreach("mobiled", "device", function(s) section=s[".name"] end) -- there will be only 1 device section
        local mobiled_enabled = cur:get("mobiled", section, "enabled")

        if mobiled_enabled == nil then   -- in case of this option is missed
            mobiled_enabled = "1"   -- default value is 1
        end
        if mobiled_enabled == "1" then
            if cur:get("mobiled", "globals", "enabled") == "0" then
               mobiled_enabled = "0"
            end
        end
        logger:notice("WAN Sensing - Mobile device state is " .. mobiled_enabled)
        if mobiled_enabled == "1" then -- and if mobiled is enabled
            local ltebackup_delay_counter_value = (origL2 == "ETH" and 1) or (origL2 == "MOBILE" and 1) or 11 -- If previous connection was Ethernet WAN then wait 2 polls, otherwise wait for 12 polls
            runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter or 0
            if runtime.ltebackup_delay_counter > ltebackup_delay_counter_value then -- Once number of polls reached
                local device = conn:call("mobiled", "status", {}) -- Check that status of mobiled
                if device and device.status ~= "WaitingForDevice" then -- If it has started up correctly then enable the wwan interface
                    if wwan_auto == "0" then
                        logger:notice("WAN Sensing - Enabling Mobile interface")
                        cur:set("network", "wwan", "auto", "1")
                        cur:commit("network")
                        os.execute("/etc/init.d/network reload")
                    end
                end
            else
	            runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
            end
        end
	end
    if vodafone_variant == "VHA" then
        -- Curl check for VHA to check if mobile is barred. If a web page can be loaded the http has not been blocked, therefore service is active
        -- If service is active, then mobile LED needs to show connected, and cwmp and VoIP interface switches to mobile
        if scripthelpers.checkIfInterfaceIsUp("wwan") then
            if not runtime.ltebackup_curl_delay_counter_value then
			    runtime.ltebackup_curl_delay_counter_value = 5
			    runtime.ltebackup_curl_delay_counter = 0
		    end
            logger:notice("L2Main.lua: check curl delay " .. tostring(runtime.ltebackup_curl_delay_counter) .. " out of " .. tostring(runtime.ltebackup_curl_delay_counter_value))
            if runtime.ltebackup_curl_delay_counter == 0 then
                local curlurl = cur:get("env","var","curlurl") or "barred-check.vodafone.net.au"
                if myhelpers.send_curl_status(curlurl,myhelpers.wwan_intf) == 1 then
                    conn:send("mobile", { event = "internet_connected"})
	                local currentstate = cur:get("cwmpd", "cwmpd_config", "interface")
                    if currentstate ~= "wwan_4" then
                        cur:set("cwmpd", "cwmpd_config", "interface", "wwan_4")
                        cur:set("cwmpd", "cwmpd_config", "interface6", "wwan_6")
                        cur:commit("cwmpd")
                        os.execute("/etc/init.d/cwmpd reload")
                    end
                    -- No need to worry about mmpbxrvsipnet.sip_net.interface as VHA does not have voice
                    if (cur:get("web","remote", "interface") ~= "wan") then
                        cur:set("web", "remote", "interface", "wan")
                        cur:commit("web")
                        run_command(runtime, "wget http://127.0.0.1:55555/ra?remote=reload_interface -O-")
                    end
                    runtime.ltebackup_curl_delay_counter_value = 11  -- 60s = 5s poll x (11 + 1)
                else
                    conn:send("mobile", { event = "barred"})
				    runtime.ltebackup_curl_delay_counter_value = 5  -- 30s = 5s poll x (5 + 1)
                end
                runtime.ltebackup_curl_delay_counter = 1
            elseif runtime.ltebackup_curl_delay_counter >= runtime.ltebackup_curl_delay_counter_value then
                runtime.ltebackup_curl_delay_counter = 0
            else
                runtime.ltebackup_curl_delay_counter = runtime.ltebackup_curl_delay_counter + 1
            end
	    else
		    conn:send("mobile", { event = "limited_service"})
        end
    end
    return "L2Sense"
end

return M
