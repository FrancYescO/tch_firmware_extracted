local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
}

--- Get the DNS server list from system file
local function getDNSServerList()
    local servers = {}
    local pipe = assert(io.open("/var/resolv.conf.auto", "r"))
    if pipe then
        for line in pipe:lines() do
            local result = line:match("nameserver ([%d%a:%.]+)")
            if result then
                servers[#servers+1] = result
            end
        end
    end
    return servers
end

--- Checks if an interface is up and then do a DNS check to ensure IP connectivity works
-- @param intf the name of the interface (netifd)
-- @return {boolean} whether the interface is up and a dns query was possible
local function checkIfInterfaceIsUpAndDoDns(intf, scripth, logger)
    if scripth.checkIfInterfaceIsUp(intf) then
        --DNS Check
        logger:notice("Launching DNS Request")
        local server_list=getDNSServerList()
        if server_list ~= nil then
            for _,v in ipairs(server_list)
            do
                logger:notice("Launching DNS Request with DNS server " .. v)
                local status,hostname_or_error = scripth.dns_check('telstra.com',v,'telstra.com')
                if status and hostname_or_error then
                    return true
                end
            end
        else
            logger:notice("Launching DNS Request with default DNS server")
            local status,hostname_or_error = scripth.dns_check('telstra.com','telstra.com')
            if status and hostname_or_error then
                return true
            end
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

    if event == "timeout" then
        -- DNS Connectivity Check
        if checkIfInterfaceIsUpAndDoDns("wan", scripthelpers, logger) then
            runtime.l3dhcp_failures = 0
            return "L3DHCP"
        end
        runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
        if runtime.l3dhcp_failures > 3 then
            return "L3Sense"
        else
            return "L3DHCP", true -- do next check using fasttimeout rather than timeout
        end
    else
        if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
        return "L3DHCP" -- if we get there, then we're not concerned, the non used L2 went down
    end
end

return M
