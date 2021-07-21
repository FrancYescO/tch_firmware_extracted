#!/usr/bin/env lua
---------------------------------------------------------------------
--
-- Easymesh script for get credentials from wireless config in case
-- we enable easymesh controller
--
----------------------------------------------------------------------
local proxy = require("datamodel")

--------------------------------------------
-- constant defines
--------------------------------------------
local intfPath = "uci.wireless.wifi-iface."
local apPath = "uci.wireless.wifi-ap."
local mapCredPath = "uci.multiap.controller_credentials."
local intfNetworkPath = "uci.web.network."
local radioPath = "rpc.wireless.radio."
local bsStatePath = "uci.wireless.wifi-bandsteer."
local mapContrEnabledPath = "uci.multiap.controller.enabled"
local mapSupportedSecModePath = "uci.multiap.controller.supported_security_modes"
local escapeList = {
	['%.'] ='%%.',
	['%-'] ='%%-'
}

local isControllerCredUpdated = false
local mapSupportedSecurityModes = {}

-- ============================================
-- local helper functions
-- ============================================
-----------------------------------
-- local Customized Result to Object helper functions
-----------------------------------
local function convertResultToObject(basepath, results)
	local indexstart, indexmatch, subobjmatch, parsedIndex = false
	local data = {}
	local output = {}
	local find, gsub = string.find, string.gsub

	indexstart = #basepath
	if not basepath:find("%.@%.$") then
		indexstart = indexstart + 1
	end

	basepath = gsub(basepath,"-", "%%-")
	basepath = gsub(basepath,"%[", "%%[")
	basepath = gsub(basepath,"%]", "%%]")

	if results then
		for _, v in ipairs(results) do
			indexmatch, subobjmatch = v.path:match("^([^%.]+)%.(.*)$", indexstart)
			if indexmatch and find(v.path, basepath) then
				if not data[indexmatch] then
					data[indexmatch] = {}
					data[indexmatch]["paramindex"] = indexmatch
					parsedIndex = indexmatch:match("(%w+)")
					output[parsedIndex] = data[indexmatch]
				end
				data[indexmatch][subobjmatch .. v.param] = v.value
			end
		end
	end
	return output
end

-----------------------------------
-- local general helper functions
-----------------------------------
local function escapePathForPattern(path)
	local escapereturn = path
	for k, v in pairs(escapeList) do
		if v then
			escapereturn = escapereturn:gsub(k,v)
		end
	end
	return escapereturn .. "@([^%.]+)%."
end

local function switchValueKey(obj)
	local ret_table = {}
	if obj then
		for k,v in pairs(obj) do
			ret_table[v] = k
		end
	end
	return ret_table
end

-----------------------------------
-- local Datamodel helper functions
-----------------------------------
local function findObjectInstances(objPath, objPathMatch)
	local objectInstances = {}
	local objFound = proxy.getPN(objPath, true)
	if objFound then
		for _, v in ipairs(objFound) do
			local objectInstance = string.match(v.path, objPathMatch)
			if objectInstance then
				objectInstances[#objectInstances + 1] = objectInstance
			end
		end
	end
	table.sort(objectInstances)
	return objectInstances
end

local function findParamInfo(obj, objPath, pParam, iList)
	local ret_obj = {}
	if obj and objPath and pParam then
		for i, v in pairs(obj) do
			local search_path = proxy.get(objPath .. "@".. v .. pParam)
			local objFound = search_path and search_path[1].value
			if objFound ~= "" then
				v = iList and i or v
				ret_obj[v] = objFound
			end
		end
	end
	table.sort(ret_obj)
	return ret_obj
end

local function findBelowList(obj, objPath, pParam)
	local ret_obj = {}
	if not obj and not objPath and not pParam then return ret_obj end
	for _, v in pairs(obj) do
		local search_path = objPath .. "@".. v .. pParam
		local objFound = proxy.get(search_path)
		local ilist = {}
		for _,l in ipairs(objFound) do
			if l.value ~= "" then
				ilist[#ilist+1] = l.value
			end
		end
		if next(ilist) then
			ret_obj[v] = ilist
		end
	end
	table.sort(ret_obj)
	return ret_obj
end

-----------------------------------
-- local dedicated helper functions
-----------------------------------

-- findFirstAndLastChannel: as we are only interested in the lowest and highest channel, this function returns it for you
-- eq param "36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140"
--    return table {
--                first_channel = 36 ,
--                last_channel = 140,
--             }
local function findFirstAndLastChannel(channel_list)
	local i = 0
	local j = 0
	local ret_obj = {}
	repeat
		i = i+1
		j = string.find(channel_list, " ", i, true)
		local label
		if i == 1 and j then
			label = string.sub(channel_list, i, j)
			ret_obj["first_channel"] = label
		else
			if not j then
				label = string.sub(channel_list, i, #channel_list)
				ret_obj["last_channel"] = label
			end
		end
		i = j
	until not j
	return ret_obj
end

-- findfreqPerIntf provides you the credx.frequency_bands value. this is based on the radio_channel list.
--    in case of 2G max channel is 13 > we check if lower then 20 => frequency_bands='radio_2G'
--    in case of 5G
--           max channel is < 100  => frequency_bands='radio_5Gl'
--           min channel is > 99  => frequency_bands='radio_5Gu'
--           else frequency_bands='radio_5Gl,radio_5Gu'
-- return table with intf vs frequency_bands
-- eq.
--{
--  wl0 = radio_2G,
--  wl1 = radio_5Gl, radio_5Gu,
--  wl0_1 = radio_2G,
--}
local function findfrequencyBandsPerIntf(intf_device_list, radio_channels)
	local ret_obj = {}
	local freq = ""
	for k,v in pairs(radio_channels) do
		local channel_boundaries = findFirstAndLastChannel(v)
		local last_channel = tonumber(channel_boundaries["last_channel"])
		local first_channel = tonumber(channel_boundaries["first_channel"])
		if last_channel and last_channel < 20 then
			freq = "radio_2G"
		elseif last_channel and last_channel < 100 then
			freq = "radio_5Gl"
		elseif first_channel and first_channel < 99 then
			freq = "radio_5Gl,radio_5Gu"
		else
			freq = "radio_5Gu"
		end
		for ki, vi in pairs(intf_device_list) do
			if vi == k then
				ret_obj[ki] = freq
			end
		end
	end
	return ret_obj
end

-- concatenate the frequency_bands if needed
local function addFreqToCred(freq_per_intf, vnet, kcred, freq_bands)
	local credConfig = {}
	if freq_per_intf[vnet[kcred]] then
		if not freq_bands then
			freq_bands = freq_per_intf[vnet[kcred]]
		else
			freq_bands = freq_bands .. "," .. freq_per_intf[vnet[kcred]]
		end
	end
	return freq_bands
end

local function isWirelessCredsChanged(currData, updatedWirelessData)
	if not currData or (currData ~= updatedWirelessData) then
		isControllerCredUpdated = true
		return true
	end
	return
end

-- update the multiap credential SSID, key and security type from the related AP and SSID interface objectInstances
-- what done:
--   - for every availble mulitap cred configuration, we configure the correct ssid, security_mode, wpa_psk_key, enable and frequency_bands
--   - in case of unsplitssid (common ssid), we disable the not used cred. and add the frequency_bands to the used cred.
--
-- parameters:
--   - mapCred: the actual available cred{i} configuration
--   - intfNetworksCred: uci.web.network.{i} list of cred{i}
--   - intfNetworksSSID: uci.web.network.{i} list of ssid{i} --wireless inferfaces
--   - ap_intf: table with accesspoint maps to ssid
--   - freq_per_intf: table with frequency_bands mapped on ssid
--   - bsState_intf: uci.wireless.wifi-bandsteer.@{i}.state -- mapped to corresponding ap
--
-- return: credconfig map to be set to map uci.multiap.controller_credentials.@
local function updateMapCreds(mapCred, intfNetworksCred, intfNetworksSSID, ap_intf, freq_per_intf, bsState_intf)
	local contentControllerCreds = convertResultToObject(mapCredPath, proxy.get(mapCredPath))
	local intf_ap = switchValueKey(ap_intf)
	local availableCred = switchValueKey(mapCred)
	local credConfig = {}
	-- changeApplied controls that only the wireless interface with changes is applied on the credentials
	local changeApplied = false
	for k,v in pairs(intfNetworksCred) do
		for knet,vnet in pairs(intfNetworksSSID) do
			if k == knet then
				for kcred, vcred in pairs(v) do
					if not availableCred[vcred] then break end
					-- Check changes already applied on the current vcred
					if (changeApplied and (intfNetworksCred[k][2] == vcred) and (intfNetworksCred[k][2] == intfNetworksCred[k][1])) then
						changeApplied = false
						break
					end
					local currCredState = contentControllerCreds[vcred]["state"]
					local credState = proxy.get(mapCredPath .. "@" .. vcred .. ".state")
					credState = credState and credState[1].value
					credConfig[vcred] = {}
					if (intfNetworksCred[k][2] == vcred) and (credState == "0") then
						-- as cred to disable only and add frequency_bands to network primary cred.
						-- get correct frequency_bands, in case of unsplit, take from all wireless interfaces in the nework
						credConfig[intfNetworksCred[k][1]]["frequency_bands"] = addFreqToCred(freq_per_intf,vnet,kcred,credConfig[intfNetworksCred[k][1]]["frequency_bands"])
						changeApplied = true
						isControllerCredUpdated = true
					else
						-- get correct frequency_bands, in case of unsplit, take from all wireless interfaces in the nework
						credConfig[vcred]["frequency_bands"] = addFreqToCred(freq_per_intf,vnet,kcred,credConfig[vcred]["frequency_bands"])
						changeApplied = true
						isControllerCredUpdated = true
					end

					if not intf_ap[vnet[kcred]] then break end -- if not found, continue
					-- get your credentials - security_mode, wpa_psk_key and ssid -
					local baseapPath = apPath .. "@" .. intf_ap[vnet[kcred]]
					local secmode = proxy.get(baseapPath .. ".security_mode")
					local secmodeVal = secmode and secmode[1].value
					-- update to the highest security mode
					-- incase the security mode in wireless is not available in multiap supported_security_modes
					for kMode, sMode in pairs(mapSupportedSecurityModes) do
						if sMode == secmodeVal then
							break -- apply the secMode in wireless to MAP
						elseif kMode == #mapSupportedSecurityModes then
							secmodeVal = sMode
						end
					end
					if secmodeVal and isWirelessCredsChanged(contentControllerCreds[vcred]["security_mode"], secmodeVal) then
						credConfig[vcred]["secmode"] = secmodeVal
						changeApplied = true
					end
					local wpa_psk_key = proxy.get(baseapPath .. ".wpa_psk_key")
					local wpa_psk_key_val = wpa_psk_key and wpa_psk_key[1].value
					if wpa_psk_key_val and isWirelessCredsChanged(contentControllerCreds[vcred]["wpa_psk_key"], wpa_psk_key_val) then
						credConfig[vcred]["wpa_psk_key"] = wpa_psk_key_val
						changeApplied = true
					end
					local ssid = proxy.get(intfPath .."@" .. vnet[kcred] .. ".ssid")
					local ssidVal = ssid and ssid[1].value
					if ssidVal and isWirelessCredsChanged(contentControllerCreds[vcred]["ssid"], ssidVal) then
						credConfig[vcred]["ssid"] = ssidVal
						changeApplied = true
					end
				end
			end
		end
	end
	return credConfig
end

-- ============================================
-- initialize
-- ============================================

-- get intfs and aps, this to get ap intf relationship
local apPathMatch = escapePathForPattern(apPath)
local aps = findObjectInstances(apPath, apPathMatch)
local ap_intf = findParamInfo(aps, apPath, ".iface")
local intfPathMatch = escapePathForPattern(intfPath)
local wl_intf_list = findObjectInstances(intfPath, intfPathMatch)
local intf_device = findParamInfo(wl_intf_list, intfPath, ".device")
local wl_radio_allowed_channels = findParamInfo(intf_device, radioPath, ".allowed_channels")
local freq_per_intf = findfrequencyBandsPerIntf(intf_device, wl_radio_allowed_channels)
local bs_ap = findParamInfo(aps, apPath, ".bandsteer_id")
local bsState_intf = findParamInfo(bs_ap, bsStatePath, ".state", true)
local bsStatePathMatch = escapePathForPattern(bsStatePath)
local bs_list = findObjectInstances(bsStatePath, bsStatePathMatch)

-- find find cred and interface per network information
local intfNetworkPathMatch = escapePathForPattern(intfNetworkPath)
local intfNetwork = findObjectInstances(intfNetworkPath, intfNetworkPathMatch)
local intfNetworksCred = findBelowList(intfNetwork, intfNetworkPath, ".cred.")
local intfNetworksSSID = findBelowList(intfNetwork, intfNetworkPath, ".intf.")

-- get all multiap creds
local mapCredPathMatch = escapePathForPattern(mapCredPath)
local mapCred = findObjectInstances(mapCredPath, mapCredPathMatch)
local mapControlEnabled = proxy.get(mapContrEnabledPath)[1].value

local mapSupportedModes = proxy.get(mapSupportedSecModePath)
mapSupportedModes = mapSupportedModes and mapSupportedModes[1].value
for sMode in mapSupportedModes:gmatch("([^%s]+)") do
	mapSupportedSecurityModes[#mapSupportedSecurityModes + 1] = sMode
end

local optionMap = {
	["secmode"] = "security_mode",
	["ssid"] = "ssid",
	["wpa_psk_key"] = "wpa_psk_key",
	["frequency_bands"] = "frequency_bands",
}

-- ============================================
-- main
-- ============================================
if mapControlEnabled and mapControlEnabled  == "1" then
	--take wireless credentials and update mapCreds
        local webData = convertResultToObject(intfNetworkPath, proxy.get(intfNetworkPath))
	for i,v in pairs(webData) do
		if v["splitssid"] then
			if i == "main" then
				proxy.set("uci.multiap.controller_credentials.@cred1.state", v["splitssid"])
			elseif i == "guest" then
				proxy.set("uci.multiap.controller_credentials.@cred4.state", v["splitssid"])
			end
		end
	end
	proxy.apply()
	local mapCreds = updateMapCreds(mapCred, intfNetworksCred, intfNetworksSSID, ap_intf, freq_per_intf, bsState_intf)
	local _, err
	if isControllerCredUpdated then
		for credSection, credData in pairs(mapCreds) do
			for credOption, credValue in pairs(credData) do
				if optionMap[credOption] then
					_, err = proxy.set(string.format("uci.multiap.controller_credentials.@%s.%s", credSection, optionMap[credOption]), tostring(credValue))
				end
	                end
		end
        end
	-- Disable BS when Easymesh is enabled
        for _, bsVal in pairs(bs_list) do
		local bs_state = proxy.get(bsStatePath.. "@" ..bsVal.. ".state")
		bs_state = bs_state and bs_state[1] and bs_state[1].value or "0"
		proxy.set(bsStatePath.. "@" ..bsVal.. ".last_state", bs_state)
                proxy.set(bsStatePath.."@"..bsVal..".state", "0")
        end
	for i, v in pairs(ap_intf) do
		local backhaul_state = proxy.get(intfPath.."@"..v..".backhaul")
		if backhaul_state and backhaul_state[1].value == "1" then
			proxy.set(intfPath.."@"..v..".state","1")
		end
	end
	if not err then
		proxy.apply()
	end
else
	local multiAPData = convertResultToObject(mapCredPath, proxy.get(mapCredPath))
	for i,v in pairs(multiAPData) do
		if v["state"] then
			if i == "cred1" then
				proxy.set("uci.web.network.@main.splitssid", v["state"])
			elseif i == "cred4" then
				if proxy.get("uci.web.network.@guest.splitssid") then proxy.set("uci.web.network.@guest.splitssid", v["state"]) end
			end
		end
	end
	for _, bsVal in pairs(bs_list) do
		local bs_last_state = proxy.get(bsStatePath.. "@" ..bsVal.. ".last_state")
		bs_last_state = bs_last_state and bs_last_state[1] and bs_last_state[1].value or "0"
		proxy.set(bsStatePath.. "@" ..bsVal.. ".state", bs_last_state)
	end
	for i, v in pairs(ap_intf) do
		local backhaul_state = proxy.get(intfPath.."@"..v..".backhaul")
		if backhaul_state and backhaul_state[1].value == "1" then
			proxy.set(intfPath.."@"..v..".state","0")
		end
	end
	proxy.apply()
end
