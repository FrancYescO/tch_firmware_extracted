#!/usr/bin/env lua

-- DESCRIPTION
-- Update the dynamic dest_ip value in /var/state/firewall for the
-- UCI firewall.*redirect####.dest_ip parameter which
-- is mapped to rpc.network.firewall.*redirect.
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
local log = logger.new("redirecthelper", 6)

-- Keeps track on IP address used in firewall MAC-based redirects for any given device.
-- Table with key on "MAC adress,family"
local redirectips = {}

-- IP families
local families = {"ipv4", "ipv6"};

-- UCI cursor used to save ipv6 values in /var/state/firewall
-- (e.g. dest_ip address for MAC address)
-- see "uci.c" for "cursor" API functions
-- Warning, network.firewall.portforward.map also writes this config file
-- hopefully "cursor" magically merges our writes.
local uci_cursor

local ubus_conn -- Talk to ubus via this connection

-- PURPOSE: Update redirect cache entry
--    Preferred IP address for a given dest_mac & family will be saved in the cache.
-- PARAMS:
--     macAddress - device MAC adress
--     family     - IP address family
--     addresses  - IP address table returned by host manager
local function updateRedirectCacheEntry(macAddress, family, addresses)
    if not (macAddress and family) then
        return
    end

    local key = macAddress .. "," .. family
    if addresses then
        local newvalue
        local oldpref, newpref = 0, 0
        for _, entry in pairs(addresses) do
            if entry.state == "connected" and entry.address then
                local pref = (entry.configuration == "dynamic" and 2 or 1)
                if redirectips[key] == entry.address then
                    oldpref = pref
                elseif newpref < pref then
                    newpref = pref
                    newvalue = entry.address
                end
            end
        end

        if oldpref == 0 or oldpref < newpref then
            redirectips[key] = newvalue
        end
    else
        redirectips[key] = nil
    end
end

-- PURPOSE: Build redirect cache from host manager state
-- PARAMS:
--     devList - hostmanager.devices style list of mac/ipaddrs
local function updateRedirectCache(devList)
    if (devList) then
        for _, dev in pairs(devList) do
            if dev["mac-address"] then
                for _, family in ipairs(families) do
                    updateRedirectCacheEntry(dev["mac-address"], family, dev[family])
                end
            end
        end
    end
end

-- PURPOSE: Remove an entry added by saveDestIp.
--     don't remove any other entries possibly added by other mappers
-- PARAMS:
--     section - name of the redirect rule
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
-- RETURNS:
--      nil + err       on error
--      true            if firewall settings have changed
--      false           if firewall settings were not touched
local function saveDestIp()
    local result, errmsg -- standard return

    result, errmsg = uci_cursor:load("firewall")
    if (not result) then
        return nil, errmsg
    end

    local redirtypes = { ["redirect"] = true }
    uci_cursor:foreach("firewall", "redirectsgroup", function(t)
        redirtypes[t.type] = true
    end)

    local changes = {}
    for redirtype in pairs(redirtypes) do
        uci_cursor:foreach("firewall", redirtype, function(t)
            local section = t[".name"]

            if not section then
                return
            end

            local oldValue = t["dest_ip"]
            local destMac = t["dest_mac"]
            local family = t["family"] and string.lower(t["family"])
            local newValue = destMac and family and redirectips[destMac .. "," .. family]
            if not newValue then
                if oldValue ~= nil and oldValue ~= "" and
                   oldValue ~= "0.0.0.0" and oldValue ~= "::" then
                    -- Drop learned IP addresses
                    changes[section] = ""
                end
            elseif oldValue ~= newValue then
                -- Update redirect IP address
                changes[section] = newValue
            end
        end)
    end

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

-- PURPOSE: Event call back from firewall.*redirect mapper.
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

-- PURPOSE: Event call back from firewall.*redirect mapper.
--    The mapper has changed and the dynamic data in /var/state/firewall
--    might need to change too.
local function handle_update(req)
    saveDestIp()

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
    updateRedirectCache( {msg} )

    -- update /var/state/firewall
    local result, errmsg = saveDestIp()

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
    ubus_conn:add({ ['redirecthelper'] = { update = { handle_update, { } },
                                           delete = { handle_delete, { ["section"] = ubus.STRING } }  } });

    -- Register event listener
    ubus_conn:listen({ ['hostmanager.devicechanged'] = handle_devicechanged} );

    -- Initialize redirect cache
    updateRedirectCache(ubus_conn:call("hostmanager.device", "get", {}))

    -- Initialize firewall.*redirect####.dest_ip parameters and reload firewall
    local result, errmsg = saveDestIp()

    if result then
        os.execute("/etc/init.d/firewall reload")
    end

    -- Idle loop
    xpcall(uloop.run, errhandler)
end

-- Invoke main loop
main()
