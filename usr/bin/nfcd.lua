#!/usr/bin/lua


local ubus = require('ubus')
local uloop = require('uloop')
local cursor = require("uci").cursor()

uloop.init()
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local auth_Modes = {
    ["wep"] = "wep_key",
    ["wpa2-psk"] = "wpa_psk_passphrase",
    ["wpa-wpa2-psk"] = "wpa_psk_passphrase",
}

local function getAPForIface(key)
    local iface = key
    local result = conn:call("wireless.accesspoint", "get", {})
    if result == nil then
        error("Cannot retrieve wireless accesspoint from interface " .. iface)
    end
    for k,v in pairs(result) do
        if v["ssid"] == iface then
            return k
        end
    end
    return nil
end


local function setSsids()
    local iface = cursor:get("nfc","wifi_iface", "iface")
    local ssids = {}
    for _, m in pairs(iface) do
        local ssids_data = conn:call("wireless.ssid", "get", {name = m})
        for k,v in pairs(ssids_data) do
            if v["oper_state"] == 1 then
                local id = #ssids+1
                ssids[id] = {}
                local ap = getAPForIface(k)
                if ap then
                    ssids[id]["ssid"] = v["ssid"]
                    ssids[id]["bssmacaddr"] = v["bssid"]
                    local apsecurity = conn:call("wireless.accesspoint.security", "get", { name = ap })
                    local mode = apsecurity and apsecurity[ap] and apsecurity[ap].mode
                    ssids[id]["authmode"] = mode
                    local key = auth_Modes[mode]
                    ssids[id]["keypass"] = apsecurity and apsecurity[ap] and apsecurity[ap][key] or ""
                end
            end
        end
    end
    conn:call("nfcd.wireless", "set", {ssids = ssids})
end

local filename = "/var/run/nfcd_running"
local i = 0
while(i < 20)
do
    local fd = io.open(filename)
    if fd then
        setSsids()
        break
    else
        os.execute("sleep 1")
    end
end

local events = {}

events['wireless.ssid'] = function(msg)
    setSsids()
end
conn:listen(events)

uloop.run()
