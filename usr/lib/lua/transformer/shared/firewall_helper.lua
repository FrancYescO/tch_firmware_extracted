local M = {}

local require = require
local ipairs = ipairs
local uci_helper = require 'transformer.mapper.ucihelper'

local function getincomingpolicyformode(mode)
    return uci_helper.get_from_uci({config= "firewall", sectionname="fwconfig", option="defaultincoming_" .. mode, default="DROP"})
end

local function getoutgoingpolicyformode(mode)
    return uci_helper.get_from_uci({config= "firewall", sectionname="fwconfig", option="defaultoutgoing_" .. mode, default="ACCEPT"})
end

function M.setincomingpolicyto(policy)
    -- set FORWARD and INPUT on wan zone to the policy
    uci_helper.foreach_on_uci({config="firewall", sectionname="zone"}, function(s)
        if s["name"] == "wan" then
            uci_helper.set_on_uci({config="firewall", sectionname=s[".name"], option="forward"}, policy, commitapply)
            uci_helper.set_on_uci({config="firewall", sectionname=s[".name"], option="input"}, policy, commitapply)
            return false
        end
    end)
    uci_helper.commit({config = "firewall"})
end

function M.setoutgoingpolicyto(policy)
    uci_helper.set_on_uci({config= "firewall", sectionname="defaultoutgoing", option="target"}, policy, commitapply)
end

function M.get_firewall_mode()
    local level = uci_helper.get_from_uci({config= "firewall", sectionname="fwconfig", option="level"})
    return level ~= "" and level or "normal"
end

function M.set_firewall_mode(paramvalue)
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
    for k,v in pairs(options) do
      uci_helper.set_on_uci({config= "firewall", sectionname=v[1], option="enabled"}, v[2], commitapply)
    end
    if paramvalue == "user" then
      uci_helper.set_on_uci({config= "firewall", sectionname="userrules_v6", option="enabled"}, "1", commitapply)
    else
      uci_helper.set_on_uci({config= "firewall", sectionname="userrules_v6", option="enabled"}, "0", commitapply)
    end

    local policy = getoutgoingpolicyformode(paramvalue)
    M.setoutgoingpolicyto(policy)
    policy = getincomingpolicyformode(paramvalue)
    M.setincomingpolicyto(policy)

    local blocked = M.get_blocked_redirects()
    local dmz_enabled = blocked["dmzredirects"] and "0" or uci_helper.get_from_uci({config= "firewall", sectionname="fwconfig", option="dmz", default="0"})
    uci_helper.set_on_uci({config= "firewall", sectionname="dmzredirects", option="enabled"}, dmz_enabled, commitapply)
    uci_helper.set_on_uci({config= "firewall", sectionname="userredirects", option="enabled"}, blocked["userredirects"] and "0" or "1", commitapply)

    uci_helper.set_on_uci({config= "firewall", sectionname="fwconfig", option="level"}, paramvalue, commitapply)
    uci_helper.commit({config = "firewall"})
end

function M.dmz_blocked()
    local blocked_redirects = M.get_blocked_redirects()
    return blocked_redirects["dmzredirects"] or false
end

function M.get_blocked_redirects()
    local mode = M.get_firewall_mode()
    local blocked_redirects = uci_helper.get_from_uci({config= "firewall", sectionname="fwconfig", option="blocked_redirects_" .. mode})
    local result = {}
    if type(blocked_redirects) == "table" then
      for _,v in ipairs(blocked_redirects) do
          result[v] = true
      end
    end
    return result
end

function M.set_dmz_enable(paramvalue)
        uci_helper.set_on_uci({config= "firewall", sectionname="fwconfig", option="dmz"}, paramvalue, commitapply)
        if not M.dmz_blocked() then
          uci_helper.set_on_uci({config= "firewall", sectionname="dmzredirects", option="enabled"}, paramvalue, commitapply)
        end
        uci_helper.commit({config = "firewall"})
end

return M
