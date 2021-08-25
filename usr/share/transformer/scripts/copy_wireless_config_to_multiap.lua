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
local mapContrEnabledPath = "uci.multiap.controller.enabled"
local escapeList = {
	['%.'] ='%%.',
	['%-'] ='%%-'
}

local isControllerCredUpdated = false

-- ============================================
-- local helper functions
-- ============================================
-----------------------------------
-- local Customized Result to Object helper functions
-----------------------------------
local function convertResultToObject(basepath, results, sorted)
	local indexstart, indexmatch, subobjmatch, parsedIndex
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
	for k,v in pairs(obj) do
		ret_table[v] = k
	end
	return ret_table
end

-----------------------------------
-- local Datamodel helper functions
-----------------------------------
local function findObjectInstances(objPath, objPathMatch)
	local objectInstances = {}
	for _, v in ipairs(proxy.getPN(objPath, true)) do
		local objectInstance = string.match(v.path, objPathMatch)
		if objectInstance then
			objectInstances[#objectInstances + 1] = objectInstance
		end
	end
	table.sort(objectInstances)
	return objectInstances
end

local function findParamInfo(obj, objPath, pParam)
	local ret_obj = {}
	for _,v in pairs(obj) do
		local search_path = proxy.get(objPath .. "@".. v .. pParam)
		local objFound = search_path and search_path[1].value
		ret_obj[v] = objFound
	end
	table.sort(ret_obj)
	return ret_obj
end

local function findBelowList(obj, objPath, pParam)
	local ret_obj = {}
	for _,v in pairs(obj) do
		local search_path = objPath .. "@".. v .. pParam
		local objFound = proxy.get(search_path)
		local ilist = {}
		for _,l in ipairs(objFound) do
			ilist[#ilist+1] = l.value
		end
		ret_obj[v] = ilist
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
local function addFreqToCred(freq_per_intf,vnet, kcred,freq_bands)
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

local contentControllerCreds = convertResultToObject(mapCredPath, proxy.get(mapCredPath))

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
--   - intfNetworksSplitSSID: uci.web.network{i}.splitssid value
--
-- return: credconfig map to be set to map uci.multiap.controller_credentials.@
local function updateMapCreds(mapCred, intfNetworksCred, intfNetworksSSID, ap_intf,freq_per_intf,intfNetworksSplitSSID)
	local intf_ap = switchValueKey(ap_intf)
	local availableCred =switchValueKey(mapCred)
	local credConfig = {}
	for k,v in pairs(intfNetworksCred) do
		for knet,vnet in pairs(intfNetworksSSID) do
			if k == knet then
				for kcred,vcred in pairs(v) do
					local currCredState = contentControllerCreds[vcred]["state"]
					if not availableCred[vcred] then break end
					credConfig[vcred] = {}
					if (intfNetworksCred[k][2] == vcred) and (intfNetworksSplitSSID[k][1] == "0") then
						-- as cred to disable only and add frequency_bands to network primary cred.
						if isWirelessCredsChanged(currCredState, intfNetworksSplitSSID[k][1]) then
							credConfig[vcred]["enabled"] = "0"
						end
						-- get correct frequency_bands, in case of unsplit, take from all wireless interfaces in the nework
						credConfig[intfNetworksCred[k][1]]["frequency_band"] = addFreqToCred(freq_per_intf,vnet,kcred,credConfig[intfNetworksCred[k][1]]["frequency_band"])
					else
						if not intf_ap[vnet[kcred]] then break end -- if not found, continue
						-- get your credentials - security_mode, wpa_psk_key and ssid -
						local baseapPath = apPath .. "@" .. intf_ap[vnet[kcred]]
						local secmode = proxy.get(baseapPath .. ".security_mode")
						local secmodeVal = secmode and secmode[1].value
						if secmodeVal and isWirelessCredsChanged(contentControllerCreds[vcred]["security_mode"], secmodeVal) then
							credConfig[vcred]["secmode"] = secmodeVal
						end
						local wpa_psk_key = proxy.get(baseapPath .. ".wpa_psk_key")
						local wpa_psk_key_val = wpa_psk_key and wpa_psk_key[1].value
						if wpa_psk_key_val and isWirelessCredsChanged(contentControllerCreds[vcred]["wpa_psk_key"], wpa_psk_key_val) then
							credConfig[vcred]["wpa_psk_key"] = wpa_psk_key_val
						end
						local ssid = proxy.get(intfPath .."@" .. vnet[kcred] .. ".ssid")
						local ssidVal = ssid and ssid[1].value
						if ssidVal and isWirelessCredsChanged(contentControllerCreds[vcred]["ssid"], ssidVal) then
							credConfig[vcred]["ssid"] = ssidVal
						end
						if (intfNetworksCred[k][2] == vcred) and isWirelessCredsChanged(currCredState, intfNetworksSplitSSID[k][1]) then
							credConfig[vcred]["enabled"] = "1"
						end
						-- get correct frequency_bands, in case of unsplit, take from all wireless interfaces in the nework
						credConfig[vcred]["frequency_band"] = addFreqToCred(freq_per_intf,vnet,kcred,credConfig[vcred]["frequency_band"])
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

-- find find cred and interface per network information
local intfNetworkPathMatch = escapePathForPattern(intfNetworkPath)
local intfNetwork = findObjectInstances(intfNetworkPath, intfNetworkPathMatch)
local intfNetworksCred = findBelowList(intfNetwork, intfNetworkPath, ".cred.")
local intfNetworksSSID = findBelowList(intfNetwork, intfNetworkPath, ".intf.")
local intfNetworksSplitSSID = findBelowList(intfNetwork, intfNetworkPath, ".splitssid")

-- get all multiap creds
local mapCredPathMatch = escapePathForPattern(mapCredPath)
local mapCred = findObjectInstances(mapCredPath, mapCredPathMatch)
local mapControlEnabled = proxy.get(mapContrEnabledPath)[1].value

local optionMap = {
	["enabled"] = "state",
	["secmode"] = "security_mode",
	["ssid"] = "ssid",
	["wpa_psk_key"] = "wpa_psk_key",
}

-- ============================================
-- main
-- ============================================
if mapControlEnabled and mapControlEnabled  == "1" then
	--take wireless credentials and update mapCreds
	local mapCreds = updateMapCreds(mapCred, intfNetworksCred, intfNetworksSSID, ap_intf, freq_per_intf, intfNetworksSplitSSID)
	local _, err
	if isControllerCredUpdated then
		for credSection, credData in pairs(mapCreds) do
			for credOption, credValue in pairs(credData) do
				if optionMap[credOption] then
					_, err = proxy.set(string.format("uci.multiap.controller_credentials.@%s.%s", credSection, optionMap[credOption]), tostring(credValue))
				end
	                end
		end
		if not err then
			proxy.apply()
		end
        end
end
