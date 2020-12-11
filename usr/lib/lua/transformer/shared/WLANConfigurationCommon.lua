local require = require
local table, tostring, tonumber, error =
      table, tostring, tonumber, error
local pairs, string =
      pairs, string
local uci_helper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local format = string.format
local gsub = string.gsub
local nwWifi = require("transformer.shared.wifi")
local floor = math.floor
local nwCommon = require("transformer.mapper.nwcommon")
local getIntfStats = nwCommon.getIntfStats

local bandSteerHelper = require("transformer.shared.bandsteerhelper")
local isBaseIface = bandSteerHelper.isBaseIface
local isBandSteerEnabled = bandSteerHelper.isBandSteerEnabledByIface
local getBandSteerPeerIface = bandSteerHelper.getBandSteerPeerIface
local getApBandSteerId = bandSteerHelper.getApBandSteerId

--[[
-- Static data definitions for use by the functions
 ]]
local binding_wireless = {config="wireless",sectionname="wifi-iface",option = "ssid"}

local BeaconType = {
    none = "Basic",
    wep = "Basic",
    ["wpa-psk"] = "WPA",
    ["wpa2-psk"] = "11i",
    ["wpa-wpa2-psk"] = "WPAand11i",
    ["wpa"] = "WPA",
    ["wpa2"] = "11i",
    ["wpa-wpa2"] = "WPAand11i",
}

local invBeaconType = {
    ["WPA"] = "wpa",
    ["WPAand11i"] = "wpa-wpa2",
    ["11i"] = "wpa2"
}

local WPAAuthenticationMode = {
    ["wpa2-psk"] = "PSKAuthentication",
    ["wpa-wpa2-psk"] = "PSKAuthentication",
    ["none"] = "PSKAuthentication",
    ["wep"] = "PSKAuthentication",
    ["wpa2"] = "EAPAuthentication",
    ["wpa-wpa2"] = "EAPAuthentication",
}

local WPA2AuthenticationMode = {
    ["wpa2-psk"] = "PSKAuthentication",
    ["wpa-wpa2-psk"] = "PSKAuthentication",
    ["none"] = "PSKAuthentication",
    ["wep"] = "PSKAuthentication",
    ["wpa2"] = "EAPAuthentication",
    ["wpa-wpa2"] = "EAPAuthentication",
}

local invAuthenticationServiceMode = {
    ["None"] = "none",
    ["LinkAuthentication"] = "wpa2-psk",
    ["RadiusClient"] = "wpa2"
}

local powerlevel_uci2igd = {
    ['-3'] = '1',
    ['-2'] = '2',
    ['-1'] = '3',
    ['0']  = '4',
}

local powerlevel_igd2uci = {
    ['1'] = '-3',
    ['2'] = '-2',
    ['3'] = '-1',
    ['4']  = '0',
}


--[[
-- Helper functions
 ]]

local function set_on_uci(sectionname, option, value, commitapply)
    binding_wireless.sectionname = sectionname
    binding_wireless.option = option

    uci_helper.set_on_uci(binding_wireless, value, commitapply)
end

local function get_from_uci(sectionname, option)
    binding_wireless.sectionname = sectionname
    binding_wireless.option = option

    return uci_helper.get_from_uci(binding_wireless)
end

--- Following the Wifi certificationw we need to check if the pin with 8 digits the last digit is the
-- the checksum of the others
-- @param #number the PIN code value
local function validatePin8(pin)
    if pin then
        local accum = 0
        accum = accum + 3*(floor(pin/10000000)%10)
        accum = accum + (floor(pin/1000000)%10)
        accum = accum + 3*(floor(pin/100000)%10)
        accum = accum + (floor(pin/10000)%10)
        accum = accum + 3*(floor(pin/1000)%10)
        accum = accum + (floor(pin/100)%10)
        accum = accum + 3*(floor(pin/10)%10)
        accum = accum + (pin%10)
        if 0 == (accum % 10) then
            return true
        end
    end
    return nil, "Invalid Pin"
end

--- valide WPS pin code. Must be 4-8 digits (can have a space or - in the middle)
-- @param #string value the PIN code that was entered
local function validateWPSPIN(value)
    local errmsg = "PIN code must composed of 4 or 8 digits"
    if value == nil or #value == 0 then
        -- empty pin code just means that we don't want to set one
        return true
    end

    local pin4 = value:match("^(%d%d%d%d)$")
    local pin8 = value:match("^(%d%d%d%d%d%d%d%d)$")

    if pin4 then
        return true
    end
    if pin8 then
        return validatePin8(pin8)
    end
    return nil, errmsg
end

-- end of code related to WPS pin validation

local function notSupported(_, param)
    return nil, "Setting param " .. param .. " not supported"
end

local function silentNotSupported()
    return
end

local function nilToEmptyString(st)
    if st == nil then
        return ""
    else
        return tostring(st)
    end
end

local function nilToBoolean(st)
    if st == nil then
        return "0"
    else
        return tostring(st)
    end
end

local function Split(szFullString, szSeparator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)
        nSplitIndex = nSplitIndex + 1
    end
    return nSplitArray
end

--[[
-- UBUS access functions, those don't need to be defined by instance
 ]]
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

-- For a given interface name (wl0 for instance), return the wifi-device section associated with it in UCI (radio_2G)
local function getRadioForIface(key)
    local iface = gsub(key, "_remote", "")
    local result = conn:call("wireless.ssid", "get", { name = iface })
    if result == nil then
        error("Cannot retrieve wireless radio from ssid " .. iface)
    end
    return result[iface].radio

end

local function getAPForIface(key)
    local iface = gsub(key, "_remote", "")
    local result = conn:call("wireless.accesspoint", "get", {})
    if result == nil then
        error("Cannot retrieve wireless accesspoint from interface " .. iface)
    end
    for k,v in pairs(result) do
        -- The property name is ssid but the content is the name of the iface (wl0 ...)
        -- Don't know why it's named like that ...
        if v["ssid"] == iface then
            return k
        end
    end
    return {}
end

local function getKeyPassPhrase(key, optionsec)
    local binding = { config = "cwmpd", sectionname = "cwmpd_config", option = "showpasswords" }
    local show_password = uci_helper.get_from_uci(binding)
    if show_password == "1" then
        local ap = getAPForIface(key)
        if type(ap) == 'string' then
            return get_from_uci(ap, optionsec)
        end
    end
    return ''
end

local function getDataFromSsid(key)
    local iface = gsub(key, "_remote", "")
    local result = conn:call("wireless.ssid", "get", { name = iface })
    if result == nil then
        error("Cannot retrieve ssid info for iface " .. iface)
    end
    return result[iface]
end

local function getAllIfaceDataFromSsid()
    local result = conn:call("wireless.ssid", "get", { })
    if result == nil then
        error("Cannot retrieve ssid.")
    end
    return result
end

local function getDataFromRadio(radio)
    local result = conn:call("wireless.radio", "get", { name = radio })
    if result == nil then
        error("Cannot retrieve radio info for radio " .. radio)
    end
    return result[radio]
end

local function getRatesetForRadio(section)
    return get_from_uci(section, "rateset")
end

local function getDataFromAcs(radio)
    local result = conn:call("wireless.radio.acs", "get", { name = radio })
    if result == nil then
        error("Cannot retrieve acs info for radio " .. radio)
    end
    return result[radio]
end

local function getDataFromBssList(radio)
    local result = conn:call("wireless.radio.bsslist", "get", { name = radio })
    if result == nil then
        error("Cannot retrieve bss info for radio " .. radio)
    end
    return result[radio]
end

local function getDataFromSsidStats(key)
    local iface = gsub(key, "_remote", "")
    local result = conn:call("wireless.ssid.stats", "get", { name = iface })
    if result == nil then
        error("Cannot retrieve ssid stats for iface " .. iface)
    end
    return result[iface]
end

local function getDataFromRadioStats(radio)
    local result = conn:call("wireless.radio.stats", "get", { name = radio })
    if result == nil then
        error("Cannot retrieve radio info for radio " .. radio)
    end
    return result[radio]
end

local function getDataFromAP(ap)
    local result = conn:call("wireless.accesspoint", "get", { name = ap })
    if result == nil then
        error("Cannot retrieve ap info for ap " .. ap)
    end
    return result[ap]
end

local function getDataFromAPSecurity(ap)
    local result = conn:call("wireless.accesspoint.security", "get", { name = ap })
    if result == nil then
        error("Cannot retrieve ap security info for ap " .. ap)
    end
    return result[ap]
end

local function getDataFromRadioRemoteUpgrade(radio)
    local result = conn:call("wireless.radio.remote.upgrade", "get", { name = radio })
    if result == nil then
        return nil -- Just return nil when no external (Quantenna) module is attached or supported.
    end
    return result[radio]
end

local function getRegulatoryDomainForRadio(radio)
    local country = getDataFromRadio(radio).country

    if country == nil then
        error("Cannot retrieve country or invalid country")
    end

    -- if no 3rd character, add trailing space as specified in spec
    if country:len() <2 then
        country = "   "
    end

    -- if no 3rd character, add trailing space as specified in spec
    if country:len() == 2 then
        country = country .. " "
    end

    return country
end

local function getMaxBitRateFromRadioData(radiodata)
    local max = radiodata["max_phy_rate"] and tonumber(radiodata["max_phy_rate"])
    if not max then
        return "Auto"
    end

    max = max / 1000
    return tostring(max)
end

local function getChannelFromRadioData(radiodata)
    local channel = radiodata["channel"]
    if(channel == nil) then
        error("Could not retrieve channel")
    end
    return tostring(channel)
end

local function getStandardFromRadioData(radiodata)
    local standard = radiodata["standard"]
    if standard == nil then
        error("Could not retrieve standard")
    end

    if string.find(standard, "n") then
        return "n"
    elseif string.find(standard, "g") then
        if string.find(standard, "b") then
            return "g"
        else
            return "g-only"
        end
    else
        return "b"
    end
end

local function getPossibleChannelsFromRadioData(radiodata)
    local channels = radiodata["allowed_channels"]
    if channels == nil then
        error("Could not retrieve list of allowed channels")
    end
    channels = channels:gsub("%s+", ",")
    channels = channels:gsub(",$", "")
    return channels
end

local function getPossibleDataTransmitRatesFromRadioData(radiodata)
    local rates = radiodata["rateset"]
    -- Replace spaces by commas
    rates = rates:gsub("%s+", ",")
    -- Remove anything not numeric or comma (we get rid of (b) in list)
    rates = rates:gsub("[^%d%.,]", "")
    -- Remove the trailing comma
    rates = rates:gsub(",$", "")
    return rates
end


local function getChannelsInUseFromRadioData(radiodata)
    local usedChannels = radiodata["used_channels"]
    local allowedChannels = radiodata["allowed_channels"]
    local channel = radiodata["channel"]
    local aac = {}
    local result = ""
    local first = true

    -- create array of allowed channels and store index of current channel
    local i = 1
    local idxChannel = -1
    for ac in allowedChannels:gmatch("%d+") do
        ac = tonumber(ac)
        table.insert(aac, ac)
        if ac == channel then
            idxChannel = i
        end
        i = i+1
    end
    i = 1
    for uc in usedChannels:gmatch("%d+") do
        if tonumber(uc) > 0 or i == idxChannel then
            if(not first) then
                result = result .. ","
            end
            first = false
            result = result .. aac[i]
        end
        i = i + 1
    end
    return result
end

local function getAuthenticationServiceModeFromApSecurity(key)
    local ap = getAPForIface(key)
    local mode
    local iface = string.match(key, "(.*)_remote")
    if iface then
        local apsecurity = getDataFromAPSecurity(ap)
        mode = apsecurity["mode"]
    else
        mode = get_from_uci(ap, "security_mode")
    end
    if mode == "wpa" or mode == "wpa2" or mode == "wpa-wpa2" then
        return "RadiusClient"
    elseif mode == "none" or mode == "wep" then
        return "None"
    else
        return "LinkAuthentication"
    end
end

local function getAcsbsslist(radio)
    local blist = getDataFromBssList(radio)
    local blists = ""
    if blist then
      for k,v in pairs(blist) do
        local maclist = Split(k, ":")
        local bssid=""
        for i = 1, #maclist do
          bssid = format("%s%s",bssid,maclist[i])
        end
        local bss_info = format("%s:%s:%s:%s:%s:%s;",bssid,
            nilToEmptyString(v["ssid"]),nilToEmptyString(v["channel"]),nilToEmptyString(v["rssi"]),
            nilToEmptyString(v["sec"]),nilToEmptyString(v["cap"]))
        if ( (#blists + #bss_info) <= 16*1024) then
          blists = format("%s%s",blists,bss_info)
        else
          break
        end
      end
    end
    return blists
end

local function nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata, param)
    if radioremoteupgradedata == nil then
        return ""
    else
        return nilToEmptyString(radioremoteupgradedata[param])
    end
end

--- Try to avoid repetitive ubus / uci calls
-- should save 10 ubus calls and as many uci calls
local function getallWLANDevice(mapping, key)
    local radio = getRadioForIface(key)
    local radiodata = getDataFromRadio(radio)
    local acsdata = getDataFromAcs(radio)
    local radiostats = getDataFromRadioStats(radio)
    local channelMode
    if(nilToEmptyString(radio["requested_channel"]) == "auto") then
        channelMode = "Auto"
    else
        channelMode = "Manual"
    end
    return {
        MaxBitRate = getMaxBitRateFromRadioData(radiodata),
        Channel = getChannelFromRadioData(radiodata),
        Standard = getStandardFromRadioData(radiodata),
        PossibleChannels = getPossibleChannelsFromRadioData(radiodata),
        RegulatoryDomain = getRegulatoryDomainForRadio(radio),
        ChannelsInUse = getChannelsInUseFromRadioData(radiodata),
        AuthenticationServiceMode = getAuthenticationServiceModeFromApSecurity(key),
        TotalBytesSent = tostring(radiostats["tx_bytes"]),
        TotalBytesReceived = tostring(radiostats["rx_bytes"]),
        TotalPacketsSent = tostring(radiostats["tx_packets"]),
        TotalPacketsReceived = tostring(radiostats["rx_packets"]),
        X_000E50_ACSState = tostring(acsdata["state"]),
        X_000E50_ACSMode = tostring(acsdata["policy"]),
        X_000E50_ACSCHMonitorPeriod = tostring(acsdata["channel_monitor_period"]),
        X_000E50_ACSScanReport = tostring(acsdata["scan_report"]),
        X_000E50_ACSScanHistory = tostring(acsdata["scan_history"]),
        X_000E50_ACSRescanPeriod = tostring(acsdata["rescan_period"]),
        X_000E50_ACSRescanDelayPolicy = tostring(acsdata["rescan_delay_policy"]),
        X_000E50_ACSRescanDelay = tostring(acsdata["rescan_delay"]),
        X_000E50_ACSRescanDelayMaxEvents = tostring(acsdata["rescan_delay_max_events"]),
        X_000E50_ACSCHFailLockoutPeriod = tostring(acsdata["channel_lockout_period"]),
        X_000E50_ACSRescan = "0",
        X_000E50_ACSBssList= getAcsbsslist(radio),
        X_000E50_ChannelMode = channelMode,
        X_000E50_PowerDefault = '1',
        X_000E50_PowerList = '1,2,3,4',
        X_000E50_PacketsDropped = tostring(radiostats["rx_discards"]+radiostats["tx_discards"]),
        X_000E50_PacketsErrored = tostring(radiostats["rx_errors"]+radiostats["tx_errors"]),
        X_000E50_RemotelyManaged = nilToBoolean(radiodata["remotely_managed"]),
    }
end

--[[
-- WEPKey related functions
 ]]
local function getwepkeynumber(key)
    local pattern = ".+_wep_(%d+)$"
    return tonumber(string.match(key, pattern))
end

local function entriesWEPKey(mapping, parentkey)
    return { parentkey .. "_wep_1", parentkey .. "_wep_2", parentkey .. "_wep_3", parentkey .. "_wep_4" }
end

--[[
-- PSK related functions
 ]]
local function getpresharedkeynumber(key)
    local pattern = ".+_psk_(%d+)$"
    return tonumber(string.match(key, pattern))
end

--[[
-- Associated Devices related functions
 ]]
local function getStaMACFromKey(key)
    local pattern = "_sta_([%da-fA-F:]+)$"
    local mac = key:match(pattern)
    return mac
end

local function setBandSteerPeerIfaceSSID(baseiface, needsetiface, oper, commitapply)
    if "1" == oper then
        local baseifacessid = get_from_uci(baseiface, "ssid")
        if "" ~= baseifacessid then
            set_on_uci(needsetiface, "ssid", baseifacessid, commitapply)
        end
    else
        local value = get_from_uci(needsetiface, "ssid") .. "-5G"
        set_on_uci(needsetiface, "ssid", value, commitapply)
    end

    return
end

local function setBandSteerID(ap, bspeerap, bsid, oper, commitapply)
  if "1" == oper then
    set_on_uci(ap, "bandsteer_id", bsid, commitapply)
    set_on_uci(bspeerap, "bandsteer_id", bsid, commitapply)
  else
    set_on_uci(ap, "bandsteer_id", "off", commitapply)
    set_on_uci(bspeerap, "bandsteer_id", "off", commitapply)
  end

  return
end

--To set the authentication according to base ap authentication
local function setBandSteerPeerApAuthentication(baseap, needsetap, commitapply)
    set_on_uci(needsetap, "security_mode", get_from_uci(baseap, "security_mode"), commitapply)
    set_on_uci(needsetap, "wpa_psk_key", get_from_uci(baseap, "wpa_psk_key"), commitapply)

    return
end

local function getBandSteerRelatedNode(ap, iface1)
    local iface2 = getBandSteerPeerIface(iface1)
    if not iface2 then
        return nil, "Band steering switching node does not exist."
    end

    local bspeerap = getAPForIface(iface2)
    if type(bspeerap) ~= 'string' then
        return nil, "Band steering peer Ap is invalid."
    end

    if isBaseIface(iface1) then
        return ap, bspeerap, iface1, iface2
    else
        return bspeerap, ap, iface2, iface1
    end
end

--1\Only the admin_state enabled, then enable bandsteering
--2\2.4G related ap will act as based node
local function enableBandSteer(key, commitapply)
    local ap = getAPForIface(key)
    if type(ap) ~= 'string' then
        return nil, "Ap is invalid."
    end

    local ret, errmsg = bandSteerHelper.canEnableBandSteer(ap, getDataFromAP(ap), key)
    if not ret then
        return nil, errmsg
    end

    --No need to check the return value now
    local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(ap, key)
    local bsid, errmsg = bandSteerHelper.getBandSteerId(key)
    if not bsid then
        return nil, errmsg
    end

    setBandSteerID(baseap, needsetap, bsid, "1", commitapply)
    setBandSteerPeerIfaceSSID(baseiface, needsetiface, "1", commitapply)
    setBandSteerPeerApAuthentication(baseap, needsetap, commitapply)
    return
end

local function disableBandSteer(key, commitapply)
    local ap = getAPForIface(key)
    if type(ap) ~= 'string' then
        return nil, "Ap is invalid."
    end

    local ret, errmsg = bandSteerHelper.canDisableBandSteer(ap, key)
    if not ret then
        return nil, errmsg
    end

    local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(ap, key)
    setBandSteerID(baseap, needsetap, "off", "0", commitapply)
    setBandSteerPeerIfaceSSID(baseiface, needsetiface, "0", commitapply)
    return
end

local function toModifyBSPeerNodeAuthentication(option, value, iface, commitapply)
    local ap = getAPForIface(iface)
    if type(ap) ~= 'string' then
        return
    end

    local bandsteerid = getApBandSteerId(ap)
    if not bandsteerid or "" == bandsteerid or "off" == bandsteerid then
        return
    else
        local bspeeriface = getBandSteerPeerIface(iface)
        if not bspeeriface then
            return nil, "Band steering switching node does not exist."
        end

        if isBaseIface(iface) then
            local sectionname
            if "ssid" == option then
                sectionname = bspeeriface
            else
                local bspeerap = getAPForIface(bspeeriface)
                if type(bspeerap) == "string" then
                    sectionname = bspeerap
                end
            end

            set_on_uci(sectionname, option, value, commitapply)
        end
    end
    return
end


--[[
 Module content here
]]--
local M = {}
M.getMappings = function(commitapply)

    --- The WEP keys as we store them here (transient ... I don't think it's worth doing anything more
    -- using WEP is criminal in itself ...)
    -- we're going to "emulate" the expected behavior by IGD. just because we're nice people.
    -- when started, we initialize the index current index to 1 and the wep key to the one used by the AP
    -- when storing a wep key to a given index, we check if the current used key is this one
    -- if it is, then we
    local wepkeys = { "", "", "", "" }
    local WEPKeyIndex = 1

    --[[
    -- WLANConfiguration section
     ]]
    local getWLANDevice = {
        Enable = function(mapping, param, key)
            local ap = getAPForIface(key)
            local state = tostring(getDataFromAP(ap).admin_state)
            return nilToBoolean(state)
        end,
        Status = function(mapping, param, key)
            local ssiddata = getDataFromSsid(key)
            local state = tostring(ssiddata["oper_state"])
            if state == "1" then
                return "Up"
            else
                return "Disabled"
            end
        end,
        BSSID = function(mapping, param, key)
            local ssiddata = getDataFromSsid(key)
            local addr = tostring(ssiddata["bssid"])
            return nilToEmptyString(addr)
        end,
        --- need to figure out when to return auto and when to return a specific speed
        MaxBitRate = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getMaxBitRateFromRadioData(getDataFromRadio(radio))
        end,
        Channel = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getChannelFromRadioData(getDataFromRadio(radio))
        end,
        Name = function(mapping, param, key)
            local iface = string.gsub(key, "_remote", "")
            return iface or ""
        end,
        SSID = function(mapping, param, key)
            local iface = string.match(key, "(.*)_remote")
            if iface then
                local ssiddata = getDataFromSsid(iface)
                local ssid = tostring(ssiddata["ssid"])
                return nilToEmptyString(ssid)
            else
                return get_from_uci(key, "ssid")
            end
        end,
        --- my understanding is that
        -- for wep or no security => Basic
        -- for WPA modes => WPA
        -- for WPA2 modes => 11i
        -- for WPA-WPA2 modes => WPAand11i
        BeaconType = function(mapping, param, key)
            local ap = getAPForIface(key)
            local secmode = getDataFromAPSecurity(ap)["mode"]
            return nilToEmptyString(BeaconType[secmode])
        end,
        MACAddressControlEnabled = function(mapping, param, key)
            local enabled
            local ap = getAPForIface(key)
            local aclmode = get_from_uci(ap, "acl_mode")
            if aclmode == "lock" or aclmode == "register" then
                enabled = "1"
            else
                enabled = "0"
            end
            return enabled
        end,
        --- Enum a,b,g (and n now)
        -- we need to convert our current mode string which contains "all modes" like bgn
        Standard = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getStandardFromRadioData(getDataFromRadio(radio))
        end,
        --- I don't see where we can access that ...
        WEPKeyIndex = function(mapping, param, key)
            return tostring(WEPKeyIndex)
        end,
        KeyPassphrase = function(mapping, param, key)
            return getKeyPassPhrase(key, "wpa_psk_key")
        end,
        WEPEncryptionLevel = function(mapping, param, key)
            return "Disabled,40-bit,104-bit" -- We support WEP (sic...) in all its flavours
        end,
        --- This should only be queried when beacon type is basic
        -- My understanding is that:
        -- wep security => WEPEncryption
        -- no security => None
        -- So in wep mode returns WEPEncryption and for any other mode returns None
        BasicEncryptionModes = function(mapping, param, key)
            local secmode = getDataFromAPSecurity(getAPForIface(key))["mode"]
            if secmode == "wep" then
                return "WEPEncryption"
            elseif secmode == "none" then
                return "None"
            else
                return ""
            end
        end,
        --- This should only be queried when beacon type is basic
        -- My understanding:
        -- no security => None
        -- WEP => None, we do not support Shared
        -- Other potential values (all optional) are
        -- EAPAuthentication
        BasicAuthenticationMode = function(mapping, param, key)
            return "None"
        end,
        --- This should only be queried when beacon type includes WPA
        -- My understanding: we only expose TKIP, we keep AES for WPA2
        WPAEncryptionModes = function(mapping, param, key)
            return "TKIPEncryption"
        end,
        --- This should only be queried when beacon type includes WPA
        -- My understanding
        -- WPA-PSK => PSKAuthentication
        -- WPA => EAPAuthentication (radius)
        WPAAuthenticationMode = function(mapping, param, key)
            local secmode = getDataFromAPSecurity(getAPForIface(key))["mode"]
            return nilToEmptyString(WPAAuthenticationMode[secmode])
        end,
        --- This should only be queried when beacon type includes WPA2
        -- My understanding: we only expose AES in WPA2
        IEEE11iEncryptionModes = function(mapping, param, key)
            return "AESEncryption"
        end,
        --- This should only be queried when beacon type includes WPA2
        -- My understanding:
        -- WPA2-PSK => PSKAuthentication
        -- WPA2 => EAPAuthentication
        -- I don't think we allow the dual EAPandPSKAuthentication
        IEEE11iAuthenticationMode = function(mapping, param, key)
            local secmode = getDataFromAPSecurity(getAPForIface(key))["mode"]
            return nilToEmptyString(WPA2AuthenticationMode[secmode])
        end,
        --- Taken from ubus call to wireless.radio => allowed_channels
        PossibleChannels = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getPossibleChannelsFromRadioData(getDataFromRadio(radio))
        end,
        --- Taken from UCI, all the rates with a (b) next to them in rateset
        BasicDataTransmitRates = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local rateset = getRatesetForRadio(radio)
            local basicrates = {}
            for rate in rateset:gmatch("([%d%.]+)%(b%)") do
                basicrates[#basicrates+1] = rate
            end
            return table.concat(basicrates, ",")
        end,
        --- Taken from UCI, all the rates in rateset
        OperationalDataTransmitRates = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local rateset = getRatesetForRadio(radio)
            return getPossibleDataTransmitRatesFromRadioData({rateset=rateset})
        end,
        --- Taken from ubus call to wireless.radio => rateset
        PossibleDataTransmitRates = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getPossibleDataTransmitRatesFromRadioData(getDataFromRadio(radio))
        end,
        InsecureOOBAccessEnabled = function(mapping, param, key)
            return "1" -- Not configurable
        end,
        --- Do we send beacons
        --- BeaconAdvertisementEnabled should be a read-only parameter ,hard coded as 'true'
        BeaconAdvertisementEnabled = function(mapping, param, key)
            return "1" -- Cannot be configured
        end,
        SSIDAdvertisementEnabled = function(mapping, param, key)
            local public = getDataFromAP(getAPForIface(key))["public"]
            return nilToBoolean(public)
        end,
        RadioEnabled = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local state = getDataFromRadio(radio)["admin_state"]
            return nilToBoolean(state)
        end,
        AutoRateFallBackEnabled = function(mapping, param, key)
            return "1" -- Cannot be configured
        end,
        LocationDescription = function(mapping, param, key)
            return "" -- kept empty as per spec since we have nothing to put here
        end,
        --- Taken from ubus call to wireless.radio => country
        RegulatoryDomain = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getRegulatoryDomainForRadio(radio)
        end,
        TotalPSKFailures = function(mapping, param, key)
            return "0" -- TODO
        end,
        TotalIntegrityFailures = function(mapping, param, key)
            return "0" -- TODO
        end,
        --- Taken from ubus call to wireless.radio => used_channels
        ChannelsInUse = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getChannelsInUseFromRadioData(getDataFromRadio(radio))
        end,
        DeviceOperationMode = function(mapping, param, key)
            return "InfrastructureAccessPoint"
        end,
        DistanceFromRoot = function(mapping, param, key)
            return "0"
        end,
        PeerBSSID = function(mapping, param, key)
            return "" -- WDS not supported yet

        end,
        --- My understanding
        -- None => no security or WEP modes
        -- LinkAuthentication => PSK modes
        -- RadiusClient => EAP modes
        AuthenticationServiceMode = function(mapping, param, key)
            return getAuthenticationServiceModeFromApSecurity(key)
        end,
        TotalBytesSent = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local txbytes = getDataFromRadioStats(radio)["tx_bytes"]
            return tostring(txbytes)
        end,
        TotalBytesReceived = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local rxbytes = getDataFromRadioStats(radio)["rx_bytes"]
            return tostring(rxbytes)
        end,
        TotalPacketsSent = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local txpackets = getDataFromRadioStats(radio)["tx_packets"]
            return tostring(txpackets)
        end,
        TotalPacketsReceived = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local rxpackets = getDataFromRadioStats(radio)["rx_packets"]
            return tostring(rxpackets)
        end,
        X_000E50_ACSState = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["state"])
        end,
        X_000E50_ACSMode = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["policy"])
        end,
        X_000E50_ACSCHMonitorPeriod = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["channel_monitor_period"])
        end,
        X_000E50_ACSScanReport = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["scan_report"])
        end,
        X_000E50_ACSScanHistory = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["scan_history"])
        end,
        X_000E50_ACSRescanPeriod = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["rescan_period"])
        end,
        X_000E50_ACSRescanDelayPolicy = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["rescan_delay_policy"])
        end,
        X_000E50_ACSRescanDelay = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["rescan_delay"])
        end,
        X_000E50_ACSRescanDelayMaxEvents = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["rescan_delay_max_events"])
        end,
        X_000E50_ACSCHFailLockoutPeriod = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            return tostring(acsdata["channel_lockout_period"])
        end,
        AutoChannelEnable  = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local channel = get_from_uci(radio, "channel")

            return (channel == "auto") and "1" or "0"
        end,
        X_000E50_ACSRescan = "0",
        X_000E50_ACSBssList = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getAcsbsslist(radio)
        end,
        X_000E50_ChannelMode = function(mapping, param , key)
            local radio = getRadioForIface(key)
            local requested_channel = nilToEmptyString(getDataFromRadio(radio)["requested_channel"])

            return (requested_channel == "auto" ) and "Auto" or "Manual"
        end,
        X_000E50_Power = function(mapping, param , key)
            local radio = getRadioForIface(key)
            local p = get_from_uci(radio, "tx_power_adjust")
            if p=='' then
                return '4'
            else
                return powerlevel_uci2igd[p] or ''
            end
        end,
        X_000E50_PowerDefault = "1",
        X_000E50_PowerList = "1,2,3,4",
        X_000E50_PacketsDropped = function(mapping, param, key, parentkey)
            local radio = getRadioForIface(key)
            local stats = getDataFromRadioStats(radio)
            local rx = stats["rx_discards"]
            local tx = stats["tx_discards"]
            return tostring(rx+tx)
        end,
        X_000E50_PacketsErrored = function(mapping, param, key, parentkey)
            local radio = getRadioForIface(key)
            local stats = getDataFromRadioStats(radio)
            local rx = stats["rx_errors"]
            local tx = stats["tx_errors"]
            return tostring(rx+tx)
        end,
        X_000E50_RemotelyManaged = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local radioremoteupgradedata = getDataFromRadio(radio)
            return nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata,"remotely_managed" )
        end,
        X_000E50_UpgradeURL = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local radioremoteupgradedata = getDataFromRadioRemoteUpgrade(radio)
            return nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata,"url" )
        end,
        X_000E50_UpgradeCheckPeriod = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local radioremoteupgradedata = getDataFromRadioRemoteUpgrade(radio)
            return nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata,"check_period" )
        end,
        X_000E50_UpgradeSWVersion = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local radioremoteupgradedata = getDataFromRadioRemoteUpgrade(radio)
            return nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata,"software_version" )
        end,
        X_000E50_BandSteerEnable = function(mapping, param, key)
            local ap = getAPForIface(key)
            if type(ap) ~= 'string' then
              return "0"
            end
            return bandSteerHelper.isBandSteerEnabledByAp(ap) and "1" or "0"
        end,
        X_000E50_ChannelWidth = function(mapping, param , key)
            local radio = getRadioForIface(key)
            return get_from_uci(radio, "channelwidth")
        end,
        X_000E50_ShortGuardInterval = function(mapping, param , key)
            local radio = getRadioForIface(key)
            return get_from_uci(radio, "sgi")
        end,
        X_000E50_SpaceTimeBlockCoding = function(mapping, param , key)
            local radio = getRadioForIface(key)
            return get_from_uci(radio, "stbc")
        end,
        X_000E50_CyclicDelayDiversity = function(mapping, param , key)
            local radio = getRadioForIface(key)
            return get_from_uci(radio, "cdd")
        end,
    }

    local setWLANDevice = {
        Enable = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            set_on_uci(ap, "state", value, commitapply)

            --if the bandsteer is enabled, should disabled
            if value == "0" and isBandSteerEnabled(key) then
                return disableBandSteer(key, commitapply)
            end
        end,
        MaxBitRate = silentNotSupported,
        Channel = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local possibleChannels = getPossibleChannelsFromRadioData(getDataFromRadio(radio))
            local channellist = Split(possibleChannels, ",")
            local isvalidChannel = false
            for i = 1, #channellist
            do
                if channellist[i] == value then
                    isvalidChannel = true
                    break
                end
            end
            if isvalidChannel then
                set_on_uci(radio, "channel", value, commitapply)
            else
                return nil, "Channel is invalid or not allowed"
            end
        end,
        SSID = function(mapping, param, value, key)
            local iface = string.match(key, "(.*)_remote")
            local sectionname
            if iface then
                sectionname = iface
            else
                sectionname = key
            end

            if not isBaseIface(sectionname) and isBandSteerEnabled(sectionname) then
                return nil, "Can not modify the value when band steer enabled"
            else
                  set_on_uci(sectionname, "ssid", value, commitapply)

                  --To set the bandsteer configuration:
                  --1\to get the related ap and check whether bandsteer is enabled
                  --2\to confirm whether current node is 2.4G
                  --3\to get the related 5G iface and modify the ssid and encryption
                  toModifyBSPeerNodeAuthentication("ssid", value, key, commitapply)
            end
        end,
        BeaconType = function(mapping, param, value, key)
            --When bandsteer enabled, cannot set the mode to WEP
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                local apsecurity = getDataFromAPSecurity(ap)
                -- The security_mode uci could has been changed from "AuthenticationMode" but not applied, so get value from uci instead of ubus.
                local secmode = get_from_uci(ap, "security_mode")
                -- Get base of beacon type and then add psk if we're in currently in a PSK mode (we cannot know from value)
                local bt = invBeaconType[value]
                if not bt then
                    if value == "Basic" then
                        local supportedmode = apsecurity["supported_modes"]
                        if secmode ~= 'none' and secmode ~= 'wep' then
                            if string.find(supportedmode, "wep") then
                                bt = "wep"
                            else
                                bt = "none"
                            end
                        else
                            bt = secmode
                        end
                    else
                        return nil, "Beacon type " .. value .. " unsupported"
                    end
                else
                    if string.find(secmode, "psk") then
                        bt = bt .. "-psk"
                    end
                end

                if isBaseIface(key) and isBandSteerEnabled(key) and bt == "wep" then
                     return nil, "Can not set the value to wep when bandsteer is enabled."
                end

                set_on_uci(ap, "security_mode", bt, commitapply)

                --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                toModifyBSPeerNodeAuthentication("security_mode", bt, key, commitapply)
            end
        end,
        MACAddressControlEnabled = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            local aclmode = "disabled"
            if value == "1" then
                aclmode = "lock"
            end
            set_on_uci(ap, "acl_mode", aclmode, commitapply)
        end,
        WEPKeyIndex = function(mapping, param, value, key)
        --- relies on the emulation layer, if we're actually changing the key index
        --  then we take the value stored in the array and set it as the wep_key
        --  and update the local key index
            local indexnumber = tonumber(value)
            if WEPKeyIndex ~= indexnumber then
                WEPKeyIndex = indexnumber
                local ap = getAPForIface(key)
                set_on_uci(ap, "wep_key", wepkeys[indexnumber], commitapply)
            end
        end,
        KeyPassphrase = function(mapping, param, value, key)
        -- WEPEncryptionLevel 40-bit,104-bit
            local len = string.len(value)
            if (len ~= 10 and len ~=26) or string.match(value,"[^%x]") ~= nil then
                return nil,"invalid value"
            end

            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                set_on_uci(ap, "wep_key", value, commitapply)
                set_on_uci(ap, "wpa_psk_key", value, commitapply)

                --Bandsteer processing: if bs is enabled reset the value for bs peer node
                toModifyBSPeerNodeAuthentication("wpa_psk_key", value, key, commitapply)

                for k, _ in pairs(wepkeys) do
                    wepkeys[k] = value
                end
            end
        end,
        BasicEncryptionModes = function(mapping, param, value, key)
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                local apsecurity = getDataFromAPSecurity(ap)
                local supportedmode = apsecurity["supported_modes"]
                local secmode = get_from_uci(ap, "security_mode")
                local modevalue = ""

                -- BasicEncryptionModes is effect only when BeaconType=Basic
                if secmode == "none" or secmode == "wep" then
                    if value == "WEPEncryption" then
                        if not string.find(supportedmode, "wep") then
                            return nil, "wep is not supported"
                        end
                        modevalue = "wep"
                    elseif value == "None" then
                        modevalue = "none"
                    end

                    if isBaseIface(key) and isBandSteerEnabled(key) and modevalue == "wep" then
                        return nil, "Can not set the value to wep when bandsteer is enabled."
                    end

                    if modevalue ~= "" then
                        set_on_uci(ap, "security_mode", modevalue, commitapply)
                        --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                        toModifyBSPeerNodeAuthentication("security_mode", modevalue, key, commitapply)
                    end
                else
                    return nil, "Not supported if BeaconType is not 'Basic'"
                end
            end
        end,
        BasicAuthenticationMode = function(mapping, param, value, key)
            if value ~= "None" then
                return notSupported("",param)
            end
        end,
        WPAEncryptionModes = function(mapping, param, value, key)
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                if value ~= "TKIPEncryption" then
                    return notSupported("",param)
                end
                local secmode = getDataFromAPSecurity(ap)["mode"]
                local wpaauthmode = nilToEmptyString(WPAAuthenticationMode[secmode])
                local optionvalue = nil

                if wpaauthmode == "PSKAuthentication" then
                    optionvalue = "wpa-wpa2-psk"
                elseif wpaauthmode == "EAPAuthentication" then
                    optionvalue = "wpa-wpa2"
                end

                if optionvalue then
                    set_on_uci(ap, "security_mode", optionvalue, commitapply)

                    --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                    toModifyBSPeerNodeAuthentication("security_mode", optionvalue, key, commitapply)
                end
            end
        end,
        WPAAuthenticationMode = function(mapping, param, value, key)
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                local optionvalue = nil

                if value == "PSKAuthentication" then
                    optionvalue = "wpa-wpa2-psk"
                elseif value == "EAPAuthentication" then
                    optionvalue = "wpa-wpa2"
                end

                if optionvalue then
                    set_on_uci(ap, "security_mode", optionvalue, commitapply)

                    --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                    toModifyBSPeerNodeAuthentication("security_mode", optionvalue, key, commitapply)
                end
            end
        end,
        IEEE11iEncryptionModes = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value ~= "AESEncryption" then
                return notSupported("",param)
            end

            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local secmode = getDataFromAPSecurity(ap)["mode"]
                local wpa2authmode = nilToEmptyString(WPA2AuthenticationMode[secmode])
                local modevalue = nil

                if wpa2authmode == "PSKAuthentication" then
                    modevalue = "wpa2-psk"
                elseif wpa2authmode == "EAPAuthentication" then
                    modevalue = "wpa2"
                end

                if modevalue then
                    set_on_uci(ap, "security_mode", modevalue, commitapply)

                    --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                    toModifyBSPeerNodeAuthentication("security_mode", modevalue, key, commitapply)
                end
            end
        end,
        -- We do not support PSK+EAP so no set on EAPandPSKAuthentication
        IEEE11iAuthenticationMode = function(mapping, param, value, key)
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local ap = getAPForIface(key)
                local modevalue = nil
                if value == "PSKAuthentication" then
                    modevalue = "wpa2-psk"
                elseif value == "EAPAuthentication" then
                    modevalue = "wpa2"
                end

                if modevalue then
                    set_on_uci(ap, "security_mode", modevalue, commitapply)

                    --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                    toModifyBSPeerNodeAuthentication("security_mode", modevalue, key, commitapply)
                end
            end
        end,
        BasicDataTransmitRates = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local rateset = getRatesetForRadio(radio)
            local ratesetValue, errMsg = nwWifi.setBasicRateset(value,rateset)
            if ratesetValue then
              set_on_uci(radio, "rateset", ratesetValue, commitapply)
            else
              return nil, errMsg
            end
        end,
        OperationalDataTransmitRates = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local rateset = getRatesetForRadio(radio)
            local ratesetValue, errMsg = nwWifi.setOperationalRateset(value,rateset)
            if ratesetValue then
              set_on_uci(radio, "rateset", ratesetValue, commitapply)
            else
              return nil, errMsg
            end
        end,
        InsecureOOBAccessEnabled = notSupported,
        SSIDAdvertisementEnabled = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            set_on_uci(ap, "public", value, commitapply)
        end,
        RadioEnabled = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "state", value, commitapply)
        end,
        AutoRateFallBackEnabled = notSupported,
        LocationDescription = function(mapping, param, value, key)
            return nil, "LocationDescription not supported"
        end,
        RegulatoryDomain = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            value = gsub(value, " ", "") -- remove whitespaces in name
            set_on_uci(radio, "country", value, commitapply)
        end,
        DeviceOperationMode = function(mapping, param, value, key)
            if value == "InfrastructureAccessPoint" then
                return true
            else
                return nil, "DeviceOperationMode not supported"
            end
        end,
        DistanceFromRoot = notSupported,
        PeerBSSID = notSupported,
        AuthenticationServiceMode = function(mapping, param, value, key)
            if not isBaseIface(key) and isBandSteerEnabled(key) then
                return nil, "Can not modify the value when band steer enabled"
            else
                local mode = invAuthenticationServiceMode[value]

                if isBaseIface(key) and isBandSteerEnabled(key) and mode == "wep" then
                    return nil, "Can not set the value to wep when bandsteer is enabled."
                end

                set_on_uci(getAPForIface(key), "security_mode", mode, commitapply)

                --Bandsteer processing: if bs is enabled reset the security_mode for bs peer node
                toModifyBSPeerNodeAuthentication("security_mode", mode, key, commitapply)
            end
        end,

        WMMEnable = notSupported,
        UAPSDEnable = notSupported,
        X_000E50_ACSCHMonitorPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_channel_monitor_period", value, commitapply)
        end,
        X_000E50_ACSRescanPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_rescan_period", value, commitapply)
        end,
        X_000E50_ACSRescanDelayPolicy = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_rescan_delay_policy", value, commitapply)
        end,
        X_000E50_ACSRescanDelay = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_rescan_delay", value, commitapply)
        end,
        X_000E50_ACSRescanDelayMaxEvents = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_rescan_delay_max_events", value, commitapply)
        end,
        X_000E50_ACSCHFailLockoutPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "acs_channel_fail_lockout_period", value, commitapply)
        end,
        AutoChannelEnable  = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local option = "channel"
            local channel = get_from_uci(radio, option)
            local flag = false
            if channel == "auto" and value == "0" then
                flag = true
                channel = getChannelFromRadioData(getDataFromRadio(radio))
            elseif channel ~= "auto" and value == "1" then
                flag = true
                channel = "auto"
            end
            if flag then
                set_on_uci(radio, option, channel, commitapply)
            end
        end,
        X_000E50_ACSRescan = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            conn:call("wireless.radio.acs", "rescan", { name = radio, act = value  })
        end,
        X_000E50_ChannelMode = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local channel = get_from_uci(radio, "channel")
            if channel == "auto" and value == "Manual" then
                channel = getChannelFromRadioData(getDataFromRadio(radio))
                set_on_uci(radio, "channel", channel, commitapply)
            elseif channel ~= "auto" and value == "Auto" then
                channel = "auto"
                set_on_uci(radio, "channel", channel, commitapply)
            end
        end,
        X_000E50_Power = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local p = powerlevel_igd2uci[value] or '-3'
            set_on_uci(radio, "tx_power_adjust", p, commitapply)
        end,
        X_000E50_RemotelyManaged =  notSupported,
        X_000E50_UpgradeURL = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "remote_upgrade_url", value, commitapply)
        end,
        X_000E50_UpgradeCheckPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "remote_upgrade_check_period", value, commitapply)
        end,
        X_000E50_UpgradeSWVersion = notSupported,
        X_000E50_BandSteerEnable = function(mapping, param, value, key)
            if "1" == value then
                return enableBandSteer(key, commitapply)
            else
                return disableBandSteer(key, commitapply)
            end
        end,
        X_000E50_ChannelWidth = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "channelwidth", value, commitapply)
        end,
        X_000E50_ShortGuardInterval = function(mapping, param , value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "sgi", value, commitapply)
        end,
        X_000E50_SpaceTimeBlockCoding = function(mapping, param , value, key)
            local radio = getRadioForIface(key)
            if radio == "radio_2G" then
                set_on_uci(radio, "stbc", value, commitapply)
            else
                return  --For 5G mode, BCM setting is not available. NOT permmit to change default set, do nothing.
            end
        end,
        X_000E50_CyclicDelayDiversity = function(mapping, param , value, key)
            local radio = getRadioForIface(key)
            set_on_uci(radio, "cdd", value, commitapply)
        end,


    }

    local function commitWLANDevice()
        uci_helper.commit(binding_wireless)
    end

    local function revertWLANDevice()
        uci_helper.revert(binding_wireless)
    end

    --[[
    -- WEPKey section
     ]]
    local function getWEPKey(mapping, param, key, parentkey)
          return getKeyPassPhrase(parentkey, "wep_key")
    end

    local function setWEPKey(mapping, param, value, key, parentkey)
    -- WEPEncryptionLevel 40-bit,104-bit
        local len = string.len(value)
        if (len ~= 10 and len ~=26) or string.match(value,"[^%x]") ~= nil then
            return nil,"invalid value"
        end
        local keynumber = getwepkeynumber(key)
        -- if we set the "current key", then we set it on uci as well
        -- otherwise, just update the keys array
        if WEPKeyIndex == keynumber then
            local ap = getAPForIface(parentkey)
            set_on_uci(ap, "wep_key", value, commitapply)
        end
        wepkeys[keynumber] = value
    end

    local function commitWEPKey()
        uci_helper.commit(binding_wireless)
    end

    local function revertWEPKey()
        uci_helper.revert(binding_wireless)
    end

    --[[
    -- PSK section
     ]]
    local getPreSharedKey =  {
        PreSharedKey = function(mapping, param, key, parentkey)
            return ''   -- as per spec
        end,
        KeyPassphrase = function(mapping, param, key, parentkey)
            return getKeyPassPhrase(parentkey, "wpa_psk_key")
        end,
        AssociatedDeviceMACAddress = function(mapping, param, key, parentkey)
            return '' -- not supported
        end,
    }

    local setPreSharedKey = {
        PreSharedKey = silentNotSupported,
        KeyPassphrase = function(mapping, param, value, key, parentkey)
            local idx = getpresharedkeynumber(key)

            -- We do not support having a specific PSK per device, so only work on the "main" ones
            if idx == 1 then
                local tmpKey = string.match(key, "(.*)_psk_")
                if not isBaseIface(tmpKey) and isBandSteerEnabled(tmpKey) then
                    return nil, "Can not modify the value when band steer enabled"
                else
                    set_on_uci(getAPForIface(parentkey), "wpa_psk_key", value, commitapply)

                    --Bandsteer processing: if bs is enabled reset the value for bs peer node
                    toModifyBSPeerNodeAuthentication("wpa_psk_key", value, tmpKey, commitapply)
                end
            end
        end,
        AssociatedDeviceMACAddress = silentNotSupported,
    }

    local function commitPreSharedKey()
        uci_helper.commit(binding_wireless)
    end

    local function revertPreSharedKey()
        uci_helper.revert(binding_wireless)
    end

    --[[
    -- Associated devices section
     ]]

    local entriesAssociatedDevice = function(mapping, parentkey)
        local ssid = get_from_uci(parentkey, "ssid")
        local ap = getAPForIface(parentkey)
        local result = conn:call("wireless.accesspoint.station", "get", { name = ap })
        if result == nil or result[ap] == nil then
            error("Cannot retrieve stations list for ssid " .. ssid)
            return
        end

        local stations = {}
        for mac,sta in pairs(result[ap]) do
            if sta["state"]:match("Associated") and sta["last_ssid"] == ssid then
                table.insert(stations, parentkey .. "_sta_" .. mac)
            end
        end
        return stations
    end

    local getStaDataFromIface = function(iface, stamac)
        local ssid = get_from_uci(iface, "ssid")
        local ap = getAPForIface(iface)
        local result = conn:call("wireless.accesspoint.station", "get", { name = ap })
        if result == nil or result[ap] == nil then
            --error("Cannot retrieve station info for ssid " .. ssid)
            return
        end

        for mac,sta in pairs(result[ap]) do
            if mac == stamac and sta["state"]:match("Associated") and sta["last_ssid"] == ssid then
                return sta
            end
        end
        return nil
    end

    local getAssociatedDevice = {
        AssociatedDeviceMACAddress = function(mapping, param, stakey, parentkey)
            return getStaMACFromKey(stakey)
        end,
        AssociatedDeviceIPAddress = function(mapping, param, stakey, parentkey)
            local stamac = getStaMACFromKey(stakey)
            local result = conn:call("hostmanager.device", "get", { ["mac-address"] = stamac })
            if result == nil or result["dev0"] == nil then
                --error("Cannot retrieve ip for " .. stamac)
                return ""
            end

            local ipv4 = result["dev0"]["ipv4"]
            if ipv4 and type(ipv4)=='table' then
                for _, v in pairs(ipv4) do
                    if v.state and v.state == "connected" then
                        return v.address or ""
                    end
                end
            end
            local ipv6 = result["dev0"]["ipv6"]
            if ipv6 and type(ipv6)=='table' then
                for _, v in pairs(ipv6) do
                    if v.state and v.state == "connected" then
                        return v.address or ""
                    end
                end
            end
            return ""
        end,
        AssociatedDeviceAuthenticationState = function(mapping, param, stakey, parentkey)
            local stamac = getStaMACFromKey(stakey)
            local stadata = getStaDataFromIface(parentkey,stamac)
            local state = stadata and stadata["state"]
            if not state then
                return "0"
            end
            if state:match("Authenticated")  then
                return "1"
            else
                return "0"
            end
        end,
        LastRequestedUnicastCipher = function(mapping, param, stakey, parentkey)
            local stamac = getStaMACFromKey(stakey)
            local stadata = getStaDataFromIface(parentkey,stamac)
            local cipher = stadata and stadata["encryption"]
            return cipher or ""
        end,
        LastRequestedMulticastCipher = function(mapping, param, key, parentkey)
            return "" -- TODO ask FRV what to put there?
        end,
        LastPMKId = function(mapping, param, key, parentkey)
            return "" -- TODO
        end,
        LastDataTransmitRate = function(mapping, param, key, parentkey)
            local mac = getStaMACFromKey(key)
            local data = getStaDataFromIface(parentkey,mac)
            local rateHistory = data and data["tx_data_rate_history"]
            return rateHistory and rateHistory:match("%d+") or ""
        end,
        X_000E50_AssociatedDeviceRSSI  = function(mapping, param, stakey, parentkey)
            local stamac = getStaMACFromKey(stakey)
            local stadata = getStaDataFromIface(parentkey,stamac)
            local rssi= stadata and stadata["rssi"]
            if not rssi then
              return "0"
            else
              return tostring(rssi)
            end
        end,
    }

    local getWPS = {
        Enable = function(mapping, param, key)
            local ap = getAPForIface(key)
            return get_from_uci(ap, "wps_state")
         end,
        DevicePassword = "0",
    }

    local setWPS ={
         Enable = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            set_on_uci(ap, "wps_state", value, commitapply)
         end,
         DevicePassword = function(mapping, param, pin, key)
             local ap = getAPForIface(key)
             local res, help = validateWPSPIN(pin)
             if res then
                 conn:call("wireless.accesspoint.wps", "enrollee_pin", { name = ap, value = pin  })
             else
                 return nil,help
             end
         end,
    }


    local function commitWPS()
          uci_helper.commit(binding_wireless)
    end

    local function revertWPS()
          uci_helper.revert(binding_wireless)
    end

    local wlanStatsMap = {
        UnicastPacketsSent = "tx_unicast_packets",
        UnicastPacketsReceived = "rx_unicast_packets",
        MulticastPacketsSent = "tx_multicast_packets",
        MulticastPacketsReceived = "rx_multicast_packets",
        BroadcastPacketsSent = "tx_broadcast_packets",
        BroadcastPacketsReceived = "rx_broadcast_packets",
        DiscardPacketsSent = "tx_discards",
        DiscardPacketsReceived = "rx_discards",
        ErrorsSent = "tx_errors",
        ErrorsReceived = "rx_errors",
    }

    local function getWLANStats(mapping, param, key)
        if param == "UnknownProtoPacketsReceived" then
            return getIntfStats(key, "rxerr", "0")
        end
        local ssidStats = getDataFromSsidStats(key)
        return tostring(ssidStats[wlanStatsMap[param]] or 0)
    end

    local function getallWLANStats(mapping, key)
        local ssidStats = getDataFromSsidStats(key)
        return {
            UnicastPacketsSent = tostring(ssidStats[wlanStatsMap["UnicastPacketsSent"]] or 0),
            UnicastPacketsReceived = tostring(ssidStats[wlanStatsMap["UnicastPacketsReceived"]] or 0),
            MulticastPacketsSent = tostring(ssidStats[wlanStatsMap["MulticastPacketsSent"]] or 0),
            MulticastPacketsReceived = tostring(ssidStats[wlanStatsMap["MulticastPacketsReceived"]] or 0),
            BroadcastPacketsSent = tostring(ssidStats[wlanStatsMap["BroadcastPacketsSent"]] or 0),
            BroadcastPacketsReceived = tostring(ssidStats[wlanStatsMap["BroadcastPacketsReceived"]] or 0),
            DiscardPacketsSent = tostring(ssidStats[wlanStatsMap["DiscardPacketsSent"]] or 0),
            DiscardPacketsReceived = tostring(ssidStats[wlanStatsMap["DiscardPacketsReceived"]] or 0),
            ErrorsSent = tostring(ssidStats[wlanStatsMap["ErrorsSent"]] or 0),
            ErrorsReceived = tostring(ssidStats[wlanStatsMap["ErrorsReceived"]] or 0),
            UnknownProtoPacketsReceived = getIntfStats(key, "rxerr", "0")
        }
    end

    local function entriesPreSharedKey(mapping, parentkey)
        local fmt="%s_psk_%d"
        local entries = {}
        for i=1,10 do
            entries[i] = fmt:format(parentkey, i)
        end
        return entries
    end

    return {
        wlan = {
            -- do not return entries, that's up to the mapping to select which interfaces to include or not
            getAll = getallWLANDevice,
            get = getWLANDevice,
            set = setWLANDevice,
            commit = commitWLANDevice,
            revert = revertWLANDevice,
        },
        wps = {
           get = getWPS,
           set = setWPS,
           commit = commitWPS,
           revert = revertWPS,
        },
        stats = {
           getAll = getallWLANStats,
           get = getWLANStats,
        },
        wepkey = {
            entries = entriesWEPKey,
            get = getWEPKey,
            set = setWEPKey,
            commit = commitWEPKey,
            revert = revertWEPKey,
        },
        psk = {
            entries = entriesPreSharedKey,
            get = getPreSharedKey,
            set = setPreSharedKey,
            commit = commitPreSharedKey,
            revert = revertPreSharedKey,
        },
        assoc = {
            entries = entriesAssociatedDevice,
            get = getAssociatedDevice,
        }
    }
end

return M

