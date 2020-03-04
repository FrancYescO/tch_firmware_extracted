local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_ipoe_ifdown',
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
                local status,hostname_or_error = scripth.dns_check('iinet.net.au',v,'iinet.net.au')
                if status and hostname_or_error then
                    return true
                end
            end
        else
            logger:notice("Launching DNS Request with default DNS server")
            local status,hostname_or_error = scripth.dns_check('iinet.net.au','iinet.net.au')
            if status and hostname_or_error then
                return true
            end
        end
        logger:notice("Trying again - Launching DNS Request with GOOGLE DNS server")
        local status,hostname_or_error = scripth.dns_check('google.com','8.8.8.8','google.com')
        if status and hostname_or_error then
            return true
        end
    end
    return false
end

local function RxByteCheck(runtime)
   -- Rx Btyes Increament Check
   -- Returns number of failures
   local proxy = require("datamodel")
   local result = proxy.get("rpc.network.interface.@wan.rx_bytes")
   local Rx_Bytes = result and result[1].value or 0
   runtime.logger:notice("Rx Byte Check: This time: "..Rx_Bytes .. ", Last time: ".. runtime.l3rx_bytes)
   Rx_Bytes = tonumber(Rx_Bytes)
   if Rx_Bytes < tonumber(runtime.l3rx_bytes) or Rx_Bytes > tonumber(runtime.l3rx_bytes) + 500 then
      runtime.l3rx_bytes = Rx_Bytes
      runtime.l3rxbyte_failures = 0
      return 0
   else
      runtime.l3rxbyte_failures = runtime.l3rxbyte_failures + 1
      runtime.logger:notice("Rx Byte Check: failure "..runtime.l3rxbyte_failures .. " of ".. 2)
      if runtime.l3rxbyte_failures >= 2 then
         return -1
      else
         return runtime.l3rxbyte_failures
      end
   end
end


--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH

local function non_novas_check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP main script is checking link connectivity on l2type interface " .. tostring(l2type))

	--sense PPPoE
	if scripthelpers.checkIfInterfaceIsUp("pppv") then
		return "L3PPPV"
	end
	if scripthelpers.checkIfInterfaceIsUp("ppp") then
		return "L3PPP"
	end
    if event == "timeout" then
        local RxCheck = RxByteCheck(runtime)
        if RxCheck > 0 then
            return "L3DHCP"
        elseif RxCheck == -1 then
            -- DNS Connectivity Check
            if checkIfInterfaceIsUpAndDoDns("wan", scripthelpers, logger) then
                runtime.l3dhcp_failures = 0
                return "L3DHCP"
            end
            runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
            logger:notice("DNS lookup No " .. tostring(runtime.l3dhcp_failures))
            if runtime.l3dhcp_failures > 3 then
                return "L3DHCPSense"
            else
                return "L3DHCP", true -- do next check using fasttimeout rather than timeout
            end
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

local function novas_check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP main script is checking link connectivity on l2type interface " .. tostring(l2type))

    if event == "timeout"  or event == "network_interface_ipoe_ifdown" then
        return "L3DHCP"
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

function M.check(runtime, l2type, event)
    if runtime.variant == "novas" then
        return novas_check(runtime, l2type, event)
    else
        return non_novas_check(runtime, l2type, event)
    end
end

return M
