local M = {}

local require, ipairs, math, pairs, type = require, ipairs, math, pairs, type
local uci_helper = require 'transformer.mapper.ucihelper'
local forEachOnUci = uci_helper.foreach_on_uci
local commit = uci_helper.commit
local fwBinding = { config = "firewall" }
local find = string.find

local function getFromUci(section, option, default)
    fwBinding.sectionname = section
    fwBinding.option = option
    fwBinding.default = default
    return uci_helper.get_from_uci(fwBinding)
end

local function setOnUci(section, option, value, commitapply)
    fwBinding.sectionname = section
    fwBinding.option = option
    uci_helper.set_on_uci(fwBinding, value, commitapply)
end

function M.setincomingpolicyto(policy, commitapply)
    fwBinding.sectionname = "zone"
    -- set FORWARD and INPUT on wan zone to the policy
    forEachOnUci(fwBinding, function(s)
        if s["name"] == "wan" then
            setOnUci(s[".name"], "forward", policy, commitapply)
            setOnUci(s[".name"], "input", policy, commitapply)
            return false
        end
    end)
    commit(fwBinding)
end

function M.setoutgoingpolicyto(policy, commitapply)
    setOnUci("defaultoutgoing", "target", policy, commitapply)
end

function M.get_firewall_mode()
    local level = getFromUci("fwconfig", "level")
    return level ~= "" and level or "normal"
end

function M.set_firewall_mode(paramvalue, commitapply)
    local options = {
        lax = { "laxrules", "0"},
        normal = { "normalrules", "0"},
        high = { "highrules", "0"},
        user = {"userrules", "0"}
    }
    if not options[paramvalue] then
        return nil, "invalid value"
    end

    options[paramvalue][2] = "1"
    for k, v in pairs(options) do
        setOnUci(v[1], "enabled", v[2], commitapply)
    end
    if paramvalue == "user" then
        setOnUci("userrules_v6", "enabled", "1", commitapply)
        if getFromUci("userrules_pxsservices", "enabled") ~= "" then
            setOnUci("userrules_pxsservices", "enabled", "1", commitapply)
        end
    else
        setOnUci("userrules_v6", "enabled", "0", commitapply)
        if getFromUci("userrules_pxsservices", "enabled") ~= "" then
            setOnUci("userrules_pxsservices", "enabled", "0", commitapply)
        end
    end

    if paramvalue == "high" then
        setOnUci("pinholerules", "enabled", "0", commitapply)
    else
        setOnUci("pinholerules", "enabled", "1", commitapply)
    end

    local policy = getFromUci("fwconfig", "defaultoutgoing_" .. paramvalue, "ACCEPT")
    M.setoutgoingpolicyto(policy, commitapply)
    policy = getFromUci("fwconfig", "defaultincoming_" .. paramvalue, "DROP")
    M.setincomingpolicyto(policy, commitapply)

    local blocked = M.get_blocked_redirects(paramvalue)
    local dmz_enabled = blocked["dmzredirects"] and "0" or getFromUci("fwconfig", "dmz", "0")
    setOnUci("dmzredirects", "enabled", dmz_enabled, commitapply)
    setOnUci("userredirects", "enabled", blocked["userredirects"] and "0" or "1", commitapply)

    local blocked_redirect = getFromUci("fwconfig", "blocked_redirects_user")
    if blocked_redirect ~= "" then
        setOnUci("guiredirects", "enabled", blocked["guiredirects"] and "0" or "1", commitapply)
        setOnUci("cliredirects", "enabled", blocked["cliredirects"] and "0" or "1", commitapply)
        setOnUci("acsredirects", "enabled", blocked["acsredirects"] and "0" or "1", commitapply)
    end

    setOnUci("fwconfig", "level", paramvalue, commitapply)

    -- reset acs_admin_config flag if any client other than ACS has changed the mode
    setOnUci("fwconfig", "acs_admin_config", "", commitapply)
    commit(fwBinding)
end

function M.dmz_blocked()
    local blocked_redirects = M.get_blocked_redirects(M.get_firewall_mode())
    return blocked_redirects["dmzredirects"] or false
end

function M.get_blocked_redirects(mode)
    local blocked_redirects = getFromUci("fwconfig", "blocked_redirects_" .. mode)
    local result = {}
    if type(blocked_redirects) == "table" then
      for _,v in ipairs(blocked_redirects) do
          result[v] = true
      end
    end
    return result
end

function M.set_dmz_enable(paramvalue, commitapply)
    setOnUci("fwconfig", "dmz", paramvalue, commitapply)
    if not M.dmz_blocked() then
        setOnUci("dmzredirects", "enabled", paramvalue, commitapply)
        fwBinding.sectionname = "dmzredirect"
        forEachOnUci(fwBinding, function(s)
            setOnUci(s[".name"], "enabled", paramvalue, commitapply)
        end)
    end
    commit(fwBinding)
end

-- PURPOSE: Find the existingSections according to binding
-- INPUT: binding which give config  and sectionname
-- RETURNS: a section names list
local function find_existing_section(binding)
    local existing_instances = {}
    if not binding or not binding.config or not binding.sectionname then
       return {}
    end
    forEachOnUci(binding, function(s)
        -- collect all portmapping sections
        existing_instances[s['.name']] = s['.name']
    end)
    return existing_instances
end

-- PURPOSE: Generate a unique entry for the table existingSections
--      using the prefix "prefix".
-- RETURNS: unique string for index in map (or nil, err)
function M.generate_unused_section(binding)
    local name   -- new name
    local start  -- start for unique number
    local id     -- current unique # to test.

    start = math.random(0, 0xfffe)
    id = start
    local existingSections = find_existing_section(binding)
    local prefix = binding.sectionname
    -- keep counting until we find an open spot
    repeat
        if id >= 0xFFFF then
            id = 0
        else
            id = id + 1
        end
        if id == start then
            return nil, "Failed to generate an unique name for the new object"
        end
        name = prefix .. string.format("%04X", id)
    until existingSections[name] == nil

    return name
end

-- PURPOSE: Given an IP address retrieve the MAC address from hostmanager
-- RETURNS: String with MAC address (or nil)
function M.ip2mac(ubus_connect, ipFamily, ipAddr, ipConfiguration)
    local macAddr -- MAC addr for ipAddr
    local devices -- table of hostmanager device with ipAddr

    if not(ubus_connect and (ipFamily == "ipv4" or ipFamily == "ipv6") and ipAddr) then
        return nil
    end

ipAddr = ipAddr:match("([^%s]+)") or ""
    -- talk to ubus directly ... we can't use proxy.get because
    -- we are inside of a transformer mapper. ... right? That's why?
    devices = ubus_connect:call("hostmanager.device",
                                "get",
                                { [ipFamily .. "-address"] = ipAddr })
    if (devices) then

        -- select the device that currently owns this IP address
        for _, dev in pairs(devices) do
            if type(dev[ipFamily]) == "table" then
                for _, ip in pairs(dev[ipFamily]) do
                    if ip["address"] == ipAddr and (ip["state"] == "connected" or ip["state"] == "stale") then
                        if ipConfiguration and ip["configuration"] ~= ipConfiguration then
                            return nil
                        end
                        macAddr = dev["mac-address"]
                        break
                    end
                end
                if macAddr then
                    break
                end
            end
        end

        if not macAddr then
            -- if none of the devices currently owns this IP address,
            -- select the first device returned by host manager query
            local _, dev = next(devices, nil)
            if dev and type(dev[ipFamily]) == "table" then
                for _, ip in pairs(dev[ipFamily]) do
                    if ip["address"] == ipAddr then
                        if ipConfiguration and ip["configuration"] ~= ipConfiguration then
                            return nil
                        end
                        macAddr = dev["mac-address"]
                        break
                    end
                end
            end
        end
    end

    return macAddr
end

return M
