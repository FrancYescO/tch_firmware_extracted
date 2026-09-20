local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wwan_ifdown',
    'bfdecho_wan_nok',
    'bfdecho_wan_ok',
    'bfdecho_wan6_nok',
    'bfdecho_wan6_ok',
}

local events = {
    timeout = true,
    network_interface_wwan_ifdown = true,
}
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

--- Do a DNS check to ensure IP connectivity works
-- @return {boolean} whether the interface is up and a dns query was possible
local function checkDns(scripth, logger)
    --DNS Check
    logger:notice("Launching DNS Request")
    local server_list=getDNSServerList()
    if server_list ~= nil then
        for _,v in ipairs(server_list)
        do
            logger:notice("Launching DNS Request with DNS server " .. v)
            local status,hostname_or_error = scripth.dns_check('fbbwan.telstra.net',v,'fbbwan.telstra.net',nil,nil,nil,1,5)
            if status and hostname_or_error then
                return true
            end
        end
        logger:notice("Trying again - Launching DNS Request with GOOGLE DNS server")
        local status,hostname_or_error = scripth.dns_check('apple.com','8.8.8.8','apple.com',nil,nil,nil,1,5)
        if status and hostname_or_error then
            return true
        end
    else
        logger:notice("Launching DNS Request with default DNS server")
        local status,hostname_or_error = scripth.dns_check('fbbwan.telstra.net',nil,'fbbwan.telstra.net',nil,nil,nil,1,5)
        if status and hostname_or_error then
            return true
        end
    end
    return false
end

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end


    local x = uci.cursor()

    if events[event] then
        logger:notice("The L3DHCP main script is checking link connectivity on l2type interface " .. tostring(l2type))
        local mode = x:get("wansensing", "global", "supervision_mode")

        if runtime.mode == "BFD" then
            if mode == "Disabled" or mode == "DNS" then
               -- kill the currently running bfdecho daemons since mode has changed from 'BFD' to 'Disabled' or 'DNS' via GUI or ACS
               os.execute("killall -9 bfdecho.lua 2>/dev/null")
            end
        else
            if mode == "BFD" then
               -- first kill the currently possible running bfdecho daemons
               os.execute("killall -9 bfdecho.lua 2>/dev/null")
               local v4enable = x:get("bfdecho", "bfdecho_config", "ipv4_enabled")
               local v6enable = x:get("bfdecho", "bfdecho_config", "ipv6_enabled")
               if v4enable == "enabled" then
                  -- start IPv4 BFD echo daemon with wan intf
                  logger:notice("Starting IPv4 BFD Echo daemon ...")
                  os.execute("/usr/bin/bfdecho.lua wan ipv4 &")
               end
               if v6enable == "enabled" then
                  -- start IPv6 BFD echo daemon with wan6 intf
                  logger:notice("Starting IPv6 BFD Echo daemon ...")
                  os.execute("/usr/bin/bfdecho.lua wan6 ipv6 &")
               end
            end
        end
        runtime.mode = mode

        -- check if wan is up Or wan6 is up and has global IPv6 address
        -- For Telstra, only when wan6 is up and has global IPv6 address, wan6 is applicable for upper layer application
        if scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6", true) then
            -- disable 3G/4G
            failoverhelper.mobiled_enable(runtime, "0", "wwan")
            -- if supervision mode is disabled or BFD echo mode, it is always "successful" when event is timeout
            -- if BFD echo mode is selected, BFD daemon is already started in L3DHCPEntry and it will send ubus event regularly about the results.
            if mode == "Disabled" or mode == "BFD" then
                runtime.l3dhcp_failures = 0
                return "L3DHCP"
            elseif mode == "DNS" then
                -- DNS Connectivity Check
                if checkDns(scripthelpers, logger) then
                    runtime.l3dhcp_failures = 0
                    return "L3DHCP"
                else
                    logger:notice("DNS lookup No " .. tostring(runtime.l3dhcp_failures + 1))
                end
            end
        end
        runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
        if runtime.l3dhcp_failures > 3 then
            return "L3DHCPSense"
        else
            return "L3DHCP", true -- do next check using fasttimeout rather than timeout
        end
    elseif event == "bfdecho_wan_ok" then
        runtime.l3dhcp_failures_v4 = 0
        --logger:notice("IPv4 BFD Echo is successful.")
        return "L3DHCP"
    -- BFD echo IPv4 fails
    elseif event == "bfdecho_wan_nok" then
        runtime.l3dhcp_failures_v4 = runtime.l3dhcp_failures_v4 + 1
        logger:notice("IPv4 BFD Echo failed No " .. tostring(runtime.l3dhcp_failures_v4))

        local count_limit = x:get("bfdecho", "bfdecho_config", "failed_limit")
        if runtime.l3dhcp_failures_v4 > count_limit - 1 then
            -- Failure account has reach the limitation, reset the counter and bring down wan intf, then bring up again
            runtime.l3dhcp_failures_v4 = 0
            conn:call("network.interface.wan", "down", { })
            conn:call("network.interface.wan", "up", { })
            if scripthelpers.checkIfInterfaceHasIP("wan6", true) then
               -- MMPBX and CWMP will switch to wan6 intf by itself once it receives the wan down event
                return "L3DHCP"
            else -- both wan and wan6 intf are down
                return "L3DHCPSense"
            end
        else
            return "L3DHCP"
        end
    elseif event == "bfdecho_wan6_ok" then
        runtime.l3dhcp_failures_v6 = 0
        --logger:notice("IPv6 BFD Echo is successful.")
        return "L3DHCP"
    -- BFD echo IPv6 fails
    elseif event == "bfdecho_wan6_nok" then
        runtime.l3dhcp_failures_v6 = runtime.l3dhcp_failures_v6 + 1
        logger:notice("IPv6 BFD Echo failed No " .. tostring(runtime.l3dhcp_failures_v6))

        local count_limit = x:get("bfdecho", "bfdecho_config", "failed_limit")
        if runtime.l3dhcp_failures_v6 > count_limit - 1 then
            -- Failure account has reach the limitation, reset the counter and bring down wan6 intf, then bring up again
            runtime.l3dhcp_failures_v6 = 0
            conn:call("network.interface.wan6", "down", { })
            conn:call("network.interface.wan6", "up", { })
            if scripthelpers.checkIfInterfaceIsUp("wan") then
               -- MMPBX and CWMP will switch to wan intf by itself once it receives the wan6 down event
                return "L3DHCP"
            else -- both wan and wan6 intf are down
                return "L3DHCPSense"
            end
        else
            return "L3DHCP"
        end
    else
        if l2type == 'ETH' then
            if not scripthelpers.l2HasCarrier("eth4") then
                return "L2Sense"
            end
        elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
        return "L3DHCP" -- if we get there, then we're not concerned, the non used L2 went down
    end
end

return M
