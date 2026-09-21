local require = require
local table, tostring, tonumber, error, open, execute, popen = table, tostring, tonumber, error, io.open, os.execute, io.popen
local ipairs, pairs, string = ipairs, pairs, string
local uci_helper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local format = string.format

--[[
-- Static data definitions for use by the functions
 ]]
local binding = {config="wireless",sectionname="wifi-iface"}

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

local invBasicAuthenticationMode = {
    ["None"] = "none",
    ["WEPEncryption"] = "wep"
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

local function firstline(filename)
    local fd, msg = open(filename)
    if not fd then
        -- you could return nil and and error message but that will abort
        -- iterating over all parameters.
        -- so here I opt to just return an empty string.
        return ""
    end
    local result = fd:read("*l")
    fd:close()
    return result
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
    local iface = string.gsub(key, "_remote", "")
    local result = conn:call("wireless.ssid", "get", { name = iface })
    if result == nil then
        error("Cannot retrieve wireless radio from ssid " .. iface)
    end
    return result[iface].radio

end

local function getAPForIface(key)
    local iface = string.gsub(key, "_remote", "")
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
           return uci_helper.get_from_uci({ config = "wireless", sectionname = ap, option = optionsec })
        end
      end
      return ''
end


local function getDataFromSsid(iface)
    local result = conn:call("wireless.ssid", "get", { name = iface })
    if result == nil then
        error("Cannot retrieve ssid info for iface " .. iface)
    end
    return result[iface]
end

local function getDataFromRadio(radio)
    local result = conn:call("wireless.radio", "get", { name = radio })
    if result == nil then
        error("Cannot retrieve radio info for radio " .. radio)
    end
    return result[radio]
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
    return "Auto"
    -- Until I figure out how I find out how to choose between Auto and actual speed
    --[[
    local max = tonumber(radiodata["max_phy_rate"])
    if(max == nil) then
        error("Could not retrieve max phy rate")
        return "0"
    end

    max = max / 1000
    return tostring(max)
    ]]
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
    local mode = "none"
    local iface = string.match(key, "(.*)_remote")
    if iface then
        local apsecurity = getDataFromAPSecurity(ap)
        mode = apsecurity["mode"]
    else
        mode = uci_helper.get_from_uci({config = "wireless", sectionname = ap, option = "security_mode"})
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
        local bss_info = format("%s:%s:%s:%s;",bssid,
            nilToEmptyString(v["ssid"]),nilToEmptyString(v["channel"]),nilToEmptyString(v["rssi"]))
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

    local autoCHEnable
    if(tostring(acsdata["state"]) == "Selecting") then
        autoCHEnable = "1"
    else
        autoCHEnable = "0"
    end

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
        AutoChannelEnable = autoCHEnable,
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

local function entriesPreSharedKey(mapping, parentkey)
    return { parentkey .. "_psk_1", parentkey .. "_psk_2", parentkey .. "_psk_3", parentkey .. "_psk_4", parentkey .. "_psk_5", parentkey .. "_psk_6", parentkey .. "_psk_7", parentkey .. "_psk_8", parentkey .. "_psk_9", parentkey .. "_psk_10" }
end

--[[
-- Associated Devices related functions
 ]]
local function getStaMACFromKey(key)
    local pattern = "_sta_([%da-fA-F:]+)$"
    local mac = key:match(pattern)
    return mac
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
            local iface = string.gsub(key, "_remote", "")
            local ssiddata = getDataFromSsid(iface)
            local state = tostring(ssiddata["oper_state"])
            if state == "1" then
                return "Up"
            else
                return "Disabled"
            end
        end,
        BSSID = function(mapping, param, key)
            local iface = string.gsub(key, "_remote", "")
            local ssiddata = getDataFromSsid(iface)
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
        SSID = function(mapping, param, key)
            local iface = string.match(key, "(.*)_remote")
            if iface then
                local ssiddata = getDataFromSsid(iface)
                local ssid = tostring(ssiddata["ssid"])
                return nilToEmptyString(ssid)
            else
                return uci_helper.get_from_uci({config = "wireless", sectionname = key, option = "ssid"})
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
            return "0" -- TODO
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
            local ap = getAPForIface(key)
            local secmode = getDataFromAPSecurity(ap)["mode"]
            if secmode == "wep" then
                return "WEPEncryption"
            else
                return "None"
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
            local ap = getAPForIface(key)
            local secmode = getDataFromAPSecurity(ap)["mode"]
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
            local ap = getAPForIface(key)
            local secmode = getDataFromAPSecurity(ap)["mode"]
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
            local rateset = getDataFromRadio(radio)["rateset"]
            local basicrates = {}
            for rate in string.gmatch(rateset, "([%d%.]+)%(b%)") do
                basicrates[#basicrates+1] = rate
            end
            return table.concat(basicrates, ",")
        end,
        --- Taken from UCI, all the rates in rateset
        OperationalDataTransmitRates = function(mapping, param, key)
            local radio = getRadioForIface(key)
            local rateset = getDataFromRadio(radio)["rateset"]
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
            local ap = getAPForIface(key)
            local public = getDataFromAP(ap)["public"]
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
            local autoCHEnable
            local radio = getRadioForIface(key)
            local acsdata = getDataFromAcs(radio)
            if(tostring(acsdata["state"]) == "Selecting") then
                autoCHEnable = "1"
            else
                autoCHEnable = "0"
            end
            return autoCHEnable
        end,
        X_000E50_ACSRescan = "0",
        X_000E50_ACSBssList = function(mapping, param, key)
            local radio = getRadioForIface(key)
            return getAcsbsslist(radio)
        end,
        X_000E50_ChannelMode = function(mapping, param , key)
            local channelMode
            local radio = getRadioForIface(key)
            local requested_channel = nilToEmptyString(getDataFromRadio(radio)["requested_channel"])
            if (requested_channel == "auto" ) then 
              channelMode = "Auto"
            else 
              channelMode = "Manual"
            end
            return channelMode
        end,
        X_000E50_Power = function(mapping, param , key)
            local radio = getRadioForIface(key)
            local p = uci_helper.get_from_uci({
                config = "wireless", sectionname = radio, option = "tx_power_adjust"})
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
        X_000E50_UpgradeSWVersion =  function(mapping, param, key)
            local radio = getRadioForIface(key)
            local radioremoteupgradedata = getDataFromRadioRemoteUpgrade(radio)
            return nilToEmptyRadioRemoteUpgradeData(radioremoteupgradedata,"software_version" )
        end,
    }

    local setWLANDevice = {
        Enable = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            local state = uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "state"
            }, value, commitapply)
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
                local state = uci_helper.set_on_uci({
                    config = "wireless", sectionname = radio, option = "channel"
                }, value, commitapply)
            else
                return nil, "Channel is invalid or not allowed"
            end
        end,
        SSID = function(mapping, param, value, key)
            local ssid = uci_helper.set_on_uci({
                config = "wireless", sectionname = key, option = "ssid"
            }, value, commitapply)
        end,
        BeaconType = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            local apsecurity = getDataFromAPSecurity(ap)
            local secmode = apsecurity["mode"]
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
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "security_mode"
            }, bt, commitapply)
        end,
        MACAddressControlEnabled = notSupported,
        WEPKeyIndex = function(mapping, param, value, key)
        --- relies on the emulation layer, if we're actually changing the key index
        --  then we take the value stored in the array and set it as the wep_key
        --  and update the local key index
            local indexnumber = tonumber(value)
            if WEPKeyIndex ~= indexnumber then
                WEPKeyIndex = indexnumber
                local ap = getAPForIface(key)
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "wep_key"
                }, wepkeys[indexnumber], commitapply)
            end
        end,
        KeyPassphrase = function(mapping, param, value, key)
        -- WEPEncryptionLevel 40-bit,104-bit
            local len = string.len(value)
            if (len ~= 10 and len ~=26) or string.match(value,"[^%x]") ~= nil then
                return nil,"invalid value"
            end
            local ap = getAPForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "wep_key"
            }, value, commitapply)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "wpa_psk_key"
            }, value, commitapply)
            for k, _ in pairs(wepkeys) do
                wepkeys[k] = value
            end
        end,
        BasicEncryptionModes = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value == "WEPEncryption" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wep", commitapply)
            elseif value == "None" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "none", commitapply)
            end
        end,
        BasicAuthenticationMode = function(mapping, param, value, key)
            if value ~= "None" then
                return notSupported("",param)
            end
        end,
        WPAEncryptionModes = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value ~= "TKIPEncryption" then
                return notSupported("",param)
            end
            local secmode = getDataFromAPSecurity(ap)["mode"]
            local wpaauthmode = nilToEmptyString(WPAAuthenticationMode[secmode])
            if wpaauthmode == "PSKAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa-wpa2-psk", commitapply)
            elseif wpaauthmode == "EAPAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa-wpa2", commitapply)
            end
        end,
        WPAAuthenticationMode = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value == "PSKAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa-wpa2-psk", commitapply)
            elseif value == "EAPAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa-wpa2", commitapply)
            end
        end,
        IEEE11iEncryptionModes = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value ~= "AESEncryption" then
                return notSupported("",param)
            end
            local secmode = getDataFromAPSecurity(ap)["mode"]
            local wpa2authmode = nilToEmptyString(WPA2AuthenticationMode[secmode])
            if wpa2authmode == "PSKAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa2-psk", commitapply)
            elseif wpa2authmode == "EAPAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa2", commitapply)
            end
        end,
        -- We do not support PSK+EAP so no set on EAPandPSKAuthentication
        IEEE11iAuthenticationMode = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            if value == "PSKAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa2-psk", commitapply)
            elseif value == "EAPAuthentication" then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "security_mode"
                }, "wpa2", commitapply)
            end
        end,
        BasicDataTransmitRates = notSupported,
        OperationalDataTransmitRates = notSupported,
        InsecureOOBAccessEnabled = notSupported,
        SSIDAdvertisementEnabled = function(mapping, param, value, key)
            local ap = getAPForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "public"
            }, value, commitapply)
        end,
        RadioEnabled = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "state"
            }, value, commitapply)
        end,
        AutoRateFallBackEnabled = notSupported,
        LocationDescription = function(mapping, param, value, key)
            return nil, "LocationDescription not supported"
        end,
        RegulatoryDomain = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            value = string.gsub(value, " ", "") -- remove whitespaces in name
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "country"
            }, value, commitapply)
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
            local mode = invAuthenticationServiceMode[value]
            local ap = getAPForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "security_mode"
            }, mode, commitapply)
        end,

        WMMEnable = notSupported,
        UAPSDEnable = notSupported,
        X_000E50_ACSCHMonitorPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_channel_monitor_period"
            }, value, commitapply)
        end,
        X_000E50_ACSRescanPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_rescan_period"
            }, value, commitapply)
        end,
        X_000E50_ACSRescanDelayPolicy = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_rescan_delay_policy"
            }, value, commitapply)
        end,
        X_000E50_ACSRescanDelay = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_rescan_delay"
            }, value, commitapply)
        end,
        X_000E50_ACSRescanDelayMaxEvents = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_rescan_delay_max_events"
            }, value, commitapply)
        end,
        X_000E50_ACSCHFailLockoutPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "acs_channel_fail_lockout_period"
            }, value, commitapply)
        end,
        X_000E50_ACSRescan = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            conn:call("wireless.radio.acs", "rescan", { name = radio, act = value  })
        end,
        X_000E50_ChannelMode = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local radiodata = getDataFromRadio(radio)
            local channel = radiodata["channel"]
            local p 
            if (value == "Auto") then 
               p = "auto"
            else 
               p = channel
            end 
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "channel"
            }, p, commitapply)
        end,
        X_000E50_Power = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            local p = powerlevel_igd2uci[value] or '-3'
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "tx_power_adjust"
            }, p, commitapply)
        end,
        X_000E50_RemotelyManaged =  notSupported,
        X_000E50_UpgradeURL = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "remote_upgrade_url"
            }, value, commitapply)
        end,
        X_000E50_UpgradeCheckPeriod = function(mapping, param, value, key)
            local radio = getRadioForIface(key)
            uci_helper.set_on_uci({
                config = "wireless", sectionname = radio, option = "remote_upgrade_check_period"
            }, value, commitapply)
        end,
        X_000E50_UpgradeSWVersion =  notSupported,
    }

    local function commitWLANDevice()
        uci_helper.commit({config = "wireless"})
    end

    local function revertWLANDevice()
        uci_helper.revert({config = "wireless"})
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
            uci_helper.set_on_uci({
                config = "wireless", sectionname = ap, option = "wep_key"
            }, value, commitapply)
        end
        wepkeys[keynumber] = value
    end

    local function commitWEPKey()
        uci_helper.commit({config = "wireless"})
    end

    local function revertWEPKey()
        uci_helper.revert({config = "wireless"})
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
            local ap = getAPForIface(parentkey)

            -- We do not support having a specific PSK per device, so only work on the "main" ones
            if idx == 1 then
                uci_helper.set_on_uci({
                    config = "wireless", sectionname = ap, option = "wpa_psk_key"
                }, value, commitapply)
            end
        end,
        AssociatedDeviceMACAddress = silentNotSupported,
    }

    local function commitPreSharedKey()
        uci_helper.commit({config = "wireless"})
    end

    local function revertPreSharedKey()
        uci_helper.revert({config = "wireless"})
    end

    --[[
    -- Associated devices section
     ]]

    local entriesAssociatedDevice = function(mapping, parentkey)
        local ssid = uci_helper.get_from_uci({
            config = "wireless", sectionname = parentkey, option = "ssid"
        })
        local ap = getAPForIface(parentkey)
        local result = conn:call("wireless.accesspoint.station", "get", { name = ap })
        if result == nil or result[ap] == nil then
            error("Cannot retrieve stations list for ssid " .. ssid)
            return
        end

        local stations = {}
        local sta
        for mac,sta in pairs(result[ap]) do
            if sta["state"]:match("Associated") and sta["last_ssid"] == ssid then
                table.insert(stations, parentkey .. "_sta_" .. mac)
            end
        end
        return stations
    end

    local getStaDataFromIface = function(iface, stamac)
        local ssid = uci_helper.get_from_uci({
            config = "wireless", sectionname = iface, option = "ssid"
        })
        local ap = getAPForIface(iface)
        local result = conn:call("wireless.accesspoint.station", "get", { name = ap })
        if result == nil or result[ap] == nil then
            --error("Cannot retrieve station info for ssid " .. ssid)
            return
        end

        local sta
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

    return {
        wlan = {
            -- do not return entries, that's up to the mapping to select which interfaces to include or not
            getAll = getallWLANDevice,
            get = getWLANDevice,
            set = setWLANDevice,
            commit = commitWLANDevice,
            revert = revertWLANDevice,
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
