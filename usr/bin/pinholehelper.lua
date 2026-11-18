#!/usr/bin/env lua

-- DESCRIPTION
-- Update the dynamic dest_ip value in /var/state/firewall for the
-- UCI firewall.pinholerule####.dest_ip parameter which
-- is mapped to rpc.network.firewall.pinholerule.
-- Register and wait for events to do this.
-- Register with hostmanager to know when LAN device IP addresses change.
-- Register with the rpc mapper to know when the rpc data modal updates.
--
-- The mapper code (transformer thread) must not reload the firewall rules
-- when it receives an event. This process does that work.
--

-- global functions used
local xpcall, string, io = xpcall, string, io
local table, require, next = table, require, next

-- library helpers
local ubus = require("ubus")
local tprint = require("tch.tableprint")
local logger = require 'transformer.logger'

logger.init(6, false)
local log = logger.new("pinholehelper", 6)

-- UCI cursor used to save ipv6 values in /var/state/firewall
-- (e.g. dest_ip address for MAC address)
-- see "uci.c" for "cursor" API functions
-- Warning, network.firewall.portforward.map also writes this config file
-- hopefully "cursor" magically merges our writes.
local uci_cursor

local ubus_conn -- Talk to ubus via this connection

-- PURPOSE: extract connected IP addresses from a hostmanager device IP list
-- PARAMS:
--       srcList     - Lua list with possibly many named entries
-- RETURNS: list of connected elements from "srcList"
--          or nil or {}
local function makeIpList(srcList)
    local retList  -- Build up this list from connected items in srcList

    if not srcList then
        return nil
    end

    retList = {}
    for _, entry in pairs(srcList) do
        if entry.state == "connected" or entry.state == "stale" then
            table.insert(retList, entry.address)
        end
    end
    return retList
end


-- PURPOSE: Given a hostmanager style list of devices,mac addresses and IP
--     addresses create a table of ALL the IP addresses associated with
--     the given mac address. It is indexed by mac address.
--     This format makes parsing in saveDestIp() easier
--      {
--        <MACAddr as index> = { ipv4 = {A,B,C}, ipv6 = {X,Y,Z} },
--        <MacAddr2>         = { ipv6 = {D,E},   ipv4 = {F} },
--        ...
--      }
-- PARAMS:
--     devList - hostmanager.devices style list of  mac/ipaddrs
--
-- RETURNS: return the MacAddr map with ipv4/ipv6 addresses or {}
--          (suitable for calling saveDestIp)
local function massageHostmanagerDeviceList(devList)
    local retArray  -- return this array of addresses

    retArray = {}

    if (devList) then
        for _, dev in pairs(devList) do
            if dev["mac-address"] then
                retArray[dev["mac-address"]] = {
                    ipv6 = makeIpList(dev["ipv6"]),
                    ipv4 = makeIpList(dev["ipv4"]),
                }
            end
        end

    end

    return retArray
end

-- PURPOSE: Remove an entry added by saveDestIp.
--     don't remove any other entries possibly added by other mappers
-- PARAMS:
--     section - name of the pinhole rule
-- RETURNS: true (or nil + err)
local function clearDestIpEntry(section)
    local result, errmsg -- standard return

    if not section then
        return nil, "section not specified"
    end

    result, errmsg = uci_cursor:load("firewall")
    if (not result) then
        return nil, errmsg
    end

    uci_cursor:revert("firewall", section, "dest_ip")

    uci_cursor:unload("firewall")

    return true
end

-- PURPOSE: Read an entire file and returns its content
-- PARAMS:
--     name - name of the file
-- RETURNS:
--      file content on success or nil + err on error
local function readFile(name)
    local f = io.open(name, "rb")
    local content

    if f then
        content = f:read("*all")
        f:close()
    end

    return content
end

-- PURPOSE: Save the dest_ip addresses to /var/state/firewall
--          That way it is available for UCI but it doesn't persist across
--          reboots.
-- PARAMS:
--     newDevList - table indexed by macAddress with lists of the most up
--                  to date ipv6 addresses. see massageHostmanagerDeviceList()
--     complete_list - True when newDevList contains the entire list of known
-- RETURNS:
--      nil + err       on error
--      true            if firewall settings have changed
--      false           if firewall settings were not touched
local function saveDestIp(newDevList, complete_list)
    local result, errmsg -- standard return

    if (not newDevList) then
        return nil, "this should never happen"
    end

    result, errmsg = uci_cursor:load("firewall")
    if (not result) then
        return nil, errmsg
    end

    local changes = {}
    uci_cursor:foreach("firewall", "pinholerule", function(t)
        local section = t[".name"]

        if not section then
            return
        end

        local oldValue = t["dest_ip"]
        local destMac = t["dest_mac"]
        local newTable = newDevList[destMac]
        if not newTable then
            if (complete_list or destMac == nil or destMac == "") and
                oldValue ~= nil and oldValue ~= "" and 
                oldValue ~= "0.0.0.0" and oldValue ~= "::" then
                -- Drop learned IP addresses
                changes[section] = ""
            end
            return
        end

        -- The input parameter has the new/current list of ip addresses
        -- as hostmanager has learned it.
        -- The "t" parameter has the ip list as UCI knows about it.
        newTable = newTable[t["family"]]
        if newTable and #newTable > 0 then
            -- sorting makes compare easy
            table.sort(newTable)
            -- testing
            --table.sort(newTable, function(a,b) return a>b end)
            local newValue = table.concat(newTable, " ")
            if oldValue ~= newValue then
                changes[section] = newValue
            end
        elseif oldValue ~= nil and oldValue ~= "" and
               oldValue ~= "0.0.0.0" and oldValue ~= "::" then
            -- Drop learned IP addresses
            changes[section] = ""
        end
    end)

    local modified = false
    if next(changes, nil) then
        local old_var_state = readFile("/var/state/firewall")

        for section, newValue in pairs(changes) do
            uci_cursor:revert("firewall", section, "dest_ip")
            if newValue ~= "" then
                uci_cursor:set("firewall", section, "dest_ip", newValue)
            end
        end

        uci_cursor:save("firewall")
        uci_cursor:unload("firewall")

        local new_var_state = readFile("/var/state/firewall")

        modified = (old_var_state ~= new_var_state)
    end

    return modified
end

-- PURPOSE: Rewrite all pinhole rules dest_ip
--     It means an entry has been deleted. Just erase all of the
--     /var/state/firewall entries. They will be recreated when the
--     mapping commits the change and sends an update event
-- RETURNS:
--     nil + err        on error
--     true             if firewall settings have changed
--     false            if firewall settings were not touched
local function rewriteAllRulesDestIp()
    -- Want a list of all known MacAddress/ipAddress
    -- talk to ubus directly
    devList = massageHostmanagerDeviceList(ubus_conn:call("hostmanager.device",
                                           "get", {}))

    -- update /var/state/firewall
    local result, errmsg = saveDestIp(devList, true)

    return result, errmsg
end

-- PURPOSE: Event call back from firewall.pinhole mapper.
--     It means an entry has been deleted, so its /var/state/firewall
--     status must be cleard as well.
local function handle_delete(req, msg)
    local ret = { }

    if type(msg) == "table" and type(msg.section) == "string" then
        -- erase dest_ip entry
        clearDestIpEntry(msg.section)
    else
        ret.error = "invalid args"
    end

    ubus_conn:reply(req, ret)
end

-- PURPOSE: Event call back from firewall.pinhole mapper.
--    The mapper has changed and the dynamic data in /var/state/firewall
--    might need to change too.
local function handle_update(req)
    rewriteAllRulesDestIp()

    ubus_conn:reply(req, {})
end

-- PURPOSE: Event call back with message from hostmanager saying
--     the data for a LAN side device has changed
--     We need to rewrite our ip addresses and make certain
--     the firewall is reloaded so that new ip(6)table rules
--     are generated. (But if the data hasn't changed don't reload)
-- PARAMS:
--     msg - The device that hostmanager thinks has changed
-- RETURNS: false, caller does nothing, array makes caller send more events
local function handle_devicechanged(msg)
    local devList -- MacAddr index list of ipAddrs suitable for saveDestIp

    -- update /var/state/firewall
    devList = massageHostmanagerDeviceList( {msg} )
    local result, errmsg = saveDestIp(devList, false)

    if result then
        -- Reload firewall if changes were made
        os.execute("/etc/init.d/firewall reload")
    end

    return false
end


-- PURPOSE: error callback for uloop errors
-- RETURNS: none
local function errhandler(err)
        log:critical(err)
        for line in string.gmatch(debug.traceback(), "([^\n]*)\n") do
                log:critical(line)
        end
end

-- PURPOSE: Run forever to handle ubus events
-- RETURNS: Doesn't (except on startup error)
local function main()

    local uloop = require("uloop")

    uci_cursor = require("uci").cursor(UCI_CONFIG, "/var/state")
    if not uci_cursor then
        log:error("Failed to get uci cursor")
        return
    end

    uloop.init();
    ubus_conn = ubus.connect()
    if not ubus_conn then
        log:error("Failed to connect to ubus")
        return
    end

    -- Register RPC callbacks
    ubus_conn:add({ ['pinholehelper'] = { update = { handle_update, { } },
                                          delete = { handle_delete, { ["section"] = ubus.STRING } }  } });

    -- Register event listener
    ubus_conn:listen({ ['hostmanager.devicechanged'] = handle_devicechanged} );

    -- Initialize firewall.pinholerule####.dest_ip parameters and reload firewall
    local result, errmsg = rewriteAllRulesDestIp()
    if result then
        os.execute("/etc/init.d/firewall reload")
    end

    -- Idle loop
    xpcall(uloop.run, errhandler)
end

-- Invoke main loop
main()
