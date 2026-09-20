local require, ipairs = require, ipairs
local proxy = require("datamodel")

local M = {}

function M.isBridgedMode()
    if (proxy.get("uci.network.interface.@wan.")) then
        return false
    else
        return true
    end
end

function M.configBridgedMode()
    local success = false
    local ifnames = 'eth0 eth1 eth2 eth3 eth4 wl0 wl0_1 wl1 wl1_1 atm_8_35 ptm0'
    success = proxy.set({
        ["uci.wansensing.global.enable"] = '0',
        ["uci.network.interface.@lan.ifname"] = ifnames,
        ["uci.dhcp.dhcp.@lan.ignore"] = '1',
    })

    local delnames = {
        "uci.network.interface.@ppp.",
        "uci.network.interface.@ipoe.",
        "uci.network.interface.@wan.",
        "uci.network.interface.@wan6.",
        "uci.network.interface.@wwan.",
        "uci.network.interface.@Guest1.",
        "uci.network.interface.@Guest1_5GHz.",
        "uci.network.interface.@Guest2.",
        "uci.network.interface.@Guest2_5GHz.",
        "uci.network.interface.@lan.pppoerelay.",
    }

    for _,v in ipairs(delnames) do
        proxy.del(v)
    end

    success = success and proxy.apply()
    return success
end

return M
