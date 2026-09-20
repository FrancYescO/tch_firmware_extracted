local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wwan_ifdown',
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

    logger:notice("The L3DHCP main script is checking link connectivity on l2type interface " .. tostring(l2type))

    if events[event] then
        -- check if wan is up Or wan6 is up and has global IPv6 address
        -- For Telstra, only when wan6 is up and has global IPv6 address, wan6 is applicable for upper layer application
        if scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6", true) then
            -- disable 3G/4G
            failoverhelper.mobiled_enable(runtime, "0", "wwan")
            -- DNS Connectivity Check
            if checkDns(scripthelpers, logger) then
                runtime.l3dhcp_failures = 0
                return "L3DHCP"
            end
        end
        runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
        logger:notice("DNS lookup No " .. tostring(runtime.l3dhcp_failures))
        if runtime.l3dhcp_failures > 3 then
            return "L3DHCPSense"
        else
            return "L3DHCP", true -- do next check using fasttimeout rather than timeout
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
