local M = {}
local match = string.match
local popen = io.popen


local runtime
local cursor
--- Initializes the library with a wansensing context (uci/ubus/logger)
-- No library calls can be made before this function has completed successfully
-- @param wansensingruntime The wansening context
function M.init(wansensingruntime)
    if wansensingruntime and wansensingruntime.uci and wansensingruntime.ubus and wansensingruntime.logger then
        runtime = wansensingruntime
        cursor = runtime.uci.cursor()
    end
end

--- Helper function to check that the arguments that are passed to dnsget / ping do not contain special characters that make
-- the call turn into an exploit
-- @param str The string to check
-- @return true if the string does not contain an apparent exploit, false otherwise
local function check_for_exploit(str)
    if str then
        -- try to make sure the string is not an exploit in disguise
        -- it is about to be concatenated to a command so ...
        return match(str,"^[^<>%s%*%(%)%|&;~!?\$]+$") and not (match(str,"^-") or match(str,"-$"))
    else
        return false
    end
end

--- Compare an address to a table / array of addresses,
-- @param addresses A table /array of addresses to check against
-- @param expectedaddress The address to check
-- @return true if expectedaddress matches one of the addresses, false otherwise
local function compare_address(addresses,expectedaddress)
    if addresses and type(addresses) == 'table' then
        for _,address in ipairs(addresses)
        do
            if address == expectedaddress then
                return true
            end
        end
    end
    return false
end

--- Check that the given address matches a valid v4/v6 address notation
-- @param address The address string to check
-- @param v6 true if the address is supposed to be a v6 address, false otherwise
-- @return true if address string is valid, false otherwise
local function check_address(address,v6)
    if v6 then
        return match(address,"^[a-f0-9:]+$")
    else
        return match(address,"^%d+%.%d+%.%d+%.%d+$")
    end
end

--- Helper function that performs the actual dnsget
-- it is pcalled by dns_lookup
-- @param query The fqdn to resolve
-- @param server The nameserver of sending dns request to
-- @param v6 Whether dns query type is IPv6. 1:ipv6 , 0:ipv4.
-- @param attempts:num - number of attempt to resovle a query.
-- @param timeout:sec  - initial query timeout .
-- @return resolvedhostnamer The resolved hostname for query or nil if not resolved
-- @return resolvedaddressesv4 Table/array of resolved ipv4 addresses for query
-- @return resolvedaddressesv6 Table/array of resolved ipv6 addresses for query
local function run_dnsget(query,server,v6,attempts,timeout)
    if check_for_exploit(query) then
        if type(attempts) ~= 'number' then
            attempts=1
        end

        if type(timeout) ~= 'number' then
            timeout=1
        end

        local cmd
        if server ~= nil then
            cmd='dnsget -n ' .. server
        else
            cmd='dnsget'
        end
        if v6 then
            cmd=cmd .. ' -t AAAA'
        else
            cmd=cmd .. ' -t A'
        end
        cmd=cmd .. ' -o timeout:' ..timeout.. ' -o attempts:' ..attempts.. ' ' .. query .. ' 2>/dev/null'

        runtime.logger:notice("run_dnsget::trigger dns query by " .. cmd)
        local pipe = popen(cmd,'r')
        if pipe then
            local resolvedhostname,resolvedaddressesv4,resolvedaddressesv6,addr,addr6
            for line in pipe:lines() do
                resolvedhostname = match(line,"([^%s]+)%.%s")
                if resolvedhostname then
                    if v6 == nil then
                        addr=match(line,"%s+(%d+%.%d+%.%d+%.%d+)")
                        if addr then
                            if not resolvedaddressesv4 then
                                resolvedaddressesv4 = {}
                            end
                            resolvedaddressesv4[#resolvedaddressesv4+1] = addr
                        end
                    else
                        addr6=match(line,"%s+([a-f0-9]*:[a-f0-9:]*:[a-f0-9]*)")
                        if addr6 then
                            if not resolvedaddressesv6 then
                                resolvedaddressesv6 = {}
                            end
                            resolvedaddressesv6[#resolvedaddressesv6+1] = addr6
                        end
                    end
                end
            end
            pipe:close()

            if resolvedhostname and (resolvedaddressesv4 or resolvedaddressesv6) then
                return resolvedhostname,resolvedaddressesv4,resolvedaddressesv6
            else
                return nil -- unresolved , not an error
            end
        else
            error("Failed to run dnsget")
        end
    else
        error("Invalid query '" .. tostring(query) .. "'")
    end
end

--- performs a dns lookup for the given query / fqdn
-- @param query The fqdn to resolve
-- @param server The nameserver of sending dns request to
-- @param v6 Whether dns query type is IPv6. 1:ipv6 , 0:ipv4.
-- @param attempts:num  Number of attempt to resovle a query.
-- @param timeout:sec   Initial query timeout .
-- @return status true if no errors occurred, false otherwise
-- @return resolvedhostname_or_error 	if status = true, the resolved hostname for query,
-- 					if status = false the error message
-- @return resolvedaddressesv4 Table/array of resolved ipv4 addresses for query
-- @return resolvedaddressesv6 Table/array of resolved ipv6 addresses for query
function M.dns_lookup(query,server,v6,attempts,timeout)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,resolvedhostname_or_error,resolvedaddressesv4,resolvedaddressesv6 = pcall(run_dnsget,query,server,v6,attempts,timeout)
    return status,resolvedhostname_or_error,resolvedaddressesv4,resolvedaddressesv6
end

--- Performs a dns lookup and compares the resolved hostname and addressesses to expectedhostname and expectedaddress/spoofedaddress
-- @param query The dns query /fqdn to resolve
-- @param attempts The max number of dns query attemts that are performed before dns_check fails
-- @param expectedhostname The expected hostname that will be resolved
-- @param expectedaddress The expected address that will be resolved. May be set to nil (do not check).
-- @param spoofedaddress The expected address that will be resolved in case of dns spoofing (wan interface down). May be set to nil (do not check).
-- @param v6 true if the addresses to check are ipv6 addresses, false if the addresses are v4 addresses. May be set ot nil (ipv4).
--
-- @return status true if no errors occurred, false otherwise
-- @return hostname_or_error 	if status = true, true if resolved hostname matches expectedhostname, false otherwise
-- 				if status = false, the error message
-- @return addressresolved true if resolved addresses contain expectedaddress, false otherwise
-- @return spoofedaddressresolved true if resolved addresses contain spoofedaddress, false otherwise.
function M.dns_check(query,server,expectedhostname,expectedaddress,expectedspoofedaddress,v6,attempts,timeout)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    if (expectedaddress and not check_address(expectedaddress,v6)) or (expectedspoofedaddress and not check_address(expectedspoofedaddress,v6)) then
        return false,"Wrong format for expected address or expected spoofed address"
    end

    if attempts and type(attempts) ~= 'number' then
        return false,"Wrong format for expected attempts"
    end

    if timeout and type(timeout) ~= 'number' then
        return false,"Wrong format for expected attempts"
    end

    local status,hostname_or_error,addressesv4,addressesv6 = M.dns_lookup(query,server,v6,attempts,timeout)
    if not status then
        return status,hostname_or_error
    end

    if hostname_or_error then
        local hostnameresult = (hostname_or_error == expectedhostname)

        local addresses = addressesv4
        if v6 then
            addresses = addressesv6
        end

        if expectedaddress and compare_address(addresses,expectedaddress) then
            return true,hostnameresult,true,false
        elseif expectedspoofedaddress and compare_address(addresses,expectedspoofedaddress) then
            return true,hostnameresult,false,true
        else
            return true,hostnameresult,false,false
        end
    end

    return true,false,false,false -- did not resolve

end

--- Helper function that performs the actual ping
-- is pcalled from ping
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return successes_or_error The number of successfull pings
-- @return failures The number of failed pings
local function run_ping(address,source,count,v6)
    if not address or not check_for_exploit(address) or (source and not check_for_exploit(source)) then
        error("Invalid parameters, address = '" .. tostring(address) .. "', source = '" .. tostring(source) .. "'")
    end
    local cmd = 'ping'
    if v6 then
        cmd = 'ping -6'
    end
    if type(count) ~= 'number' then
        count = 1
    end
    cmd = cmd .. ' ' .. address .. ' -c ' .. count
    if source and type(source) == 'string' then
        cmd = cmd .. ' -I ' .. source
    end
    cmd = cmd .. ' 2>/dev/null'
    local pipe = popen(cmd,'r')
    if pipe then
        for line in pipe:lines() do
            local transmitted,received = match(line,"(%d+) packets transmitted, (%d+) packets received")
            if transmitted and received then
                pipe:close()
                return tonumber(received),tonumber(transmitted)-tonumber(received)
            end
        end
        pipe:close()
        error('Ping command generated an error ' .. tostring(cmd))
    else
        error('Failed to launch ping command ' .. tostring(cmd))
    end
end

--- Performs a ping with the specified source address/interface and count
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return status true if no errors occurred, false otherwise
-- @return successes_or_error 	if status = true, the number of successfull pings
-- 				if status = false, the error message
-- @return failures the number of failed pings
function M.ping(address,source,count,v6)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,successes_or_error,failures = pcall(run_ping,address,source,count,v6)
    return status,successes_or_error,failures
end

--- Performs a ping with the specified source address/interface and count
-- returns true if the number of failures is lower than the specified value
-- @param address The address / fqdn to ping to
-- @param source The source interface or address to use. May be set to nil (no specific interface/addr to use).
-- @param count The number of echo requests to send. May be set to nil (count = 1).
-- @param max_failures The maximum number of failed pings that can occurr before the test fails
-- @param v6 If true, ping is executed over ipv6, if false over ipv4. May be set to nil (ipv4).
-- @return status true if no errors occurred, false otherwise
-- @return successes_or_error 	if status = true, true if the number of failed pings is lower than max_failures, false otherwise
-- 				if status = false, the error message
function M.ping_check(address,source,count,max_failures,v6)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end
    --  Deletes an interface in the uci network configuration
    -- does not bring the interface down prior to deleting
    -- this has to be handled by the library user
    -- @param intf The name of the interface to delete
    -- @return status true if successful, false otherwise
    -- @return err the errormessage if status = false

    if not max_failures then
        max_failures = 0
    end

    local status,successes_or_error,failures = M.ping(address,source,count,v6)
    if not status then
        return status,successes_or_error
    end
    if tonumber(failures)>tonumber(max_failures) then
        return true,false
    else
        return true,true
    end
end

--- Helper function that does the actual deleting of the interface
-- It is pcalled by delete_interface
-- @param intf The name of the interface to delete
local function run_delete(intf)
    local config='network'
    if not intf then
        error("intf must be filled in")
    end
    cursor:load(config)
    cursor:delete(config,intf)
    cursor:commit(config)
end

--- Deletes an interface in the uci network configuration
-- does not bring the interface down prior to deleting
-- this has to be handled by the library user
-- @param intf The name of the interface to delete
-- @return status true if successful, false otherwise
-- @return err the errormessage if status = false
function M.delete_interface(intf)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_delete,intf)
    return status,err
end

--- Helper function that performs the actual copying of the interface
-- It is pcalled by copy_interface
-- @param src The name of the src interface to copy from
-- @param dst The name of the dst interface to copy to
local function run_copy(src,dst)
    if not src or not dst then
        error("src or dst not filled in")
    end
    local config='network'
    cursor:load(config)
    local src_attribs
    local interfaces_found = cursor:foreach(config,'interface',function(s)
        if s['.name']==src then
            src_attribs = s
            return false -- exit from loop
        end
    end)
    if interfaces_found and src_attribs and type(src_attribs)=='table' then
        cursor:set(config,dst,'interface')
        for k,v in pairs(src_attribs)
        do
            if k and v and not string.match(k,"^%.") then
                cursor:set(config,dst,k,v)
            end
        end
        cursor:commit(config)
    else
        error('Failed to find source interface or its attributes')
    end
end

--- Copies an existing interface in the uci network configuration
-- does not bring the interface down prior to copying
-- this has to be handled by the library user
-- @param src The name of the src interface to copy from
-- @param dst The name of the dst interface to copy to
-- @return status true if successful, false otherwise
-- @return err the errormessage if status = false
function M.copy_interface(src,dst)
    if not runtime or not cursor then
        return false,"Library was not properly initialized"
    end

    local status,err = pcall(run_copy,src,dst)
    return status,err
end

--- Given the type of L2, the event received and the name of the ETH wan interface, returns whether the current L2 went
-- down or not
-- @param l2type
-- @param event
-- @param ethintf the netdev interface used as wan
-- @return {boolean} whether the current L2 went down or not
M.checkIfCurrentL2WentDown = function(l2type, event, ethintf)
    local intfdown = 'network_device_' .. ethintf .. '_down'
    if event == 'xdsl_0' and (l2type == "ADSL" or l2type == "VDSL") then
        -- xDSL interface is down and we were over xDSL
        return true
    elseif event == intfdown and l2type == "ETH" then
        -- ETH interface is down and we were over ETH
        return true
    end
    return false
end

--- Given an event and the name of the ETH wan interface, returns whether any L2 interface went up (based on event)
-- @param event
-- @param ethintf the netdev interface used as wan
-- @return {boolean} whether an L2 interface went up
M.checkIfAnyL2WentUp = function(event, ethintf)
    if event == 'xdsl_5' or event == 'network_device_' .. ethintf .. '_up' then
        return true
    end
    return false
end

--- Checks if the 3G backup is in the enabled state.
-- Assumes that if not set, it is disabled
M.checkIf3GBackupIsEnabled = function()
    local config = "mobiledongle"

    cursor:load(config)
    local enabled = cursor:get(config, "config", "enabled")
    return enabled == "1"
end

--- Checks if an interface given by name is up
-- @param intf the interface name (netifd interface)
-- @return {boolean} whether the given interface is up or not
M.checkIfInterfaceIsUp = function(intf)
    local conn = runtime.ubus
    local status

    status = conn:call("network.interface." .. intf, "status", { })
    if status and status.up then
        return true
    end
    return false
end

--- Checks if a GPON interface given by name is up
-- @return {boolean} whether the given interface is up or not
M.checkIfGPONInterfaceIsUp = function()
    local conn = runtime.ubus
    local state

    state = conn:call("gpon.omciport", "state", { })
    if state and state.statuscode then
        return state.statuscode == 1
    end
    return false
end

--- Helper function that performs the actual Link State check
-- it is pcalled by l2HasCarrier
-- @param l2intf the interface name (netdevice interface name)
-- @return {up/down} the linkstate
local function run_checkLinkState(intf)
   local cmd='ethctl ' .. intf .. ' media-type 2>&1'
   local pipe = popen(cmd,'r')
   if pipe then
      local linkstate
      for line in pipe:lines() do
          if not linkstate then
             linkstate = match(line,"^Link is%s+([^%s]+)$")
          end
      end
      pipe:close()

      if linkstate then
         return linkstate
      else
          return 'down'
      end
   end
end

--- Checks if a l2 device has carrier
-- @param l2intf the interface name (netdevice interface name)
-- @return {boolean} whether the given interface has carrier or not
M.l2HasCarrier = function(l2intf)
    local status, carrier = pcall(run_checkLinkState,l2intf)

    if status and carrier == 'up' then
       return true
    else
       return false
    end
end

return M
