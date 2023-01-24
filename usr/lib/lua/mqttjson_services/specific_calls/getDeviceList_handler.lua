-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.

-- Script connects to specified IOT Thing
-- Receives an MQTT Messages which contains the TR069 datamodel parameter
-- Sends an MQTT Message response of the specified TR069 datamodel parameter
-- The TR069 datamodel parameter can be IGD or Device2 datamodel.
-- The script is derived from the existing orchestra agent.

--- Handler to produce the response message containing the list of the connected devices and their related rule like: URL Filtering, TOD Rules, etc..
-- Payload from this specific call is published, when receiving the request from the topic containing "/cmd/getDeviceList"
-- and the config "mqttjson_services.handlers.getDeviceList" is enabled.
-- The output response is framed into a table and published back to Cloud.
--
-- @module getDeviceList_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log
local gsub = string.gsub

--- loads the parameters field for the response message.
-- @function addParameterValue
-- @param gwParameter request parameter
-- @param value value of the request parameter
-- @return table
local function addParameterValue(gwParameter, value)
  local param = {}
  param['gwParameter'] = gwParameter
  param['value'] = value
  return param
end

-- Get the list of devices connected to extender and get wifi information (radioType,...)
local function getExtenderDeviceList()
  local returnList = {}
  local stationList = mqtt_lookup.utils.get_instance_list("rpc.multiap.sta.")

  for _, stations in pairs(stationList or {}) do
    local macPath = stations .. "mac"
    local deviceMac = mqtt_lookup.utils.get_path_value(macPath)

    local rssiPath = stations .. "rssi" -- This is in fact a rscp
    local rcpiValue = mqtt_lookup.utils.get_path_value(rssiPath) or 0
    -- Calculate the rssi value
    local rssiValue = rcpiValue and (rcpiValue/2)-110 or 0

    local agentPath = stations .. "assoc_agent_mac"
    local agentMac = mqtt_lookup.utils.get_path_value(agentPath) or ""

    local deviceDetails = {}
    deviceDetails["agentPath"] = agentPath
    deviceDetails["agent"] = agentMac
    deviceDetails["rssiPath"] = rssiPath
    deviceDetails["rssi"] = rssiValue

    -- Check radios associated to agentMac
    local path = "rpc.multiap.device.@" .. agentMac .. ".radio."
    local radioList, radioListMsg = mqtt_lookup.utils.get_instance_list(path)

    local connPath = "rpc.multiap.device.@" .. agentMac .. ".state"
    local connValue = mqtt_lookup.utils.get_path_value(connPath)

    local connDevPath = "rpc.multiap.device.@" .. agentMac .. ".device_name"
    local connDevName = mqtt_lookup.utils.get_path_value(connDevPath)
    if connDevName then
      deviceDetails["extAgentName"] = connDevName
      deviceDetails["extAgentPath"] = connDevPath
    end

    local devFound = false
    if connValue then
      deviceDetails["devConnected"] = connValue
      deviceDetails["devConnPath"] = connPath
    end
    for _, instance in pairs(radioList or {}) do
      local instData, errMsg = proxy.get(instance)
      if errMsg then
        result.status = mqtt_lookup.mqtt_constants.generalError
        result.error = errMsg or "Given parameter or input format is Incorrect"
        return result
      end
      local freqPath = instance .. "freq"
      local freqPathValue = mqtt_lookup.utils.get_path_value(freqPath)
      local bssList = mqtt_lookup.utils.get_instance_list(instance .. "bss.")

      -- Check rpc.multiap.device.[@agentMac].radio.[@agentMac].
      for _, data in pairs(bssList or {}) do
        local staListPath = data .. "sta_list"
        local staListValue = mqtt_lookup.utils.get_path_value(staListPath)
        if string.find(staListValue, deviceMac) then
          log:debug("Filling in station details")
          deviceDetails['radioTypePath'] = freqPath
          deviceDetails['radioType'] = freqPathValue
          devFound = true
          break
        end
      end
      if devFound == true then
        break
      end
    end
    returnList[deviceMac] = deviceDetails
  end
  return returnList
end

--- Frames the response message of the special handler.
-- @function frameResponse
-- @param payload Request message from cloud
-- @return table
local function frameResponse(payload)
  local result = {}
  local parameters = {}
  local dmData = {}
  result.status = mqtt_lookup.mqtt_constants.successCode
  result.parameters = parameters
  result.requestId = payload and payload.requestId and payload.requestId
  if payload["rsp-parameter"] then
    -- Get host info
    local apList, apListerrMsg = mqtt_lookup.utils.get_instance_list('rpc.wireless.ap.') -- Returns list of aps
    local urlList, urlListerrMsg = mqtt_lookup.utils.get_instance_list('uci.parental.URLfilter.') -- Returns list of url filters
    local path = 'sys.hosts.host.'
    local deviceList, deviceListMsg = mqtt_lookup.utils.get_instance_list(path)

    if apListerrMsg or urlListerrMsg or deviceListMsg then
      result.error = apListerrMsg or urlListerrMsg or deviceListMsg or "Given parameter or input format is Incorrect"
      result.status = mqtt_lookup.mqtt_constants.generalError
      return result
    end

    -- Check if Easymesh is enabled
    local easyMeshEnabled = (mqtt_lookup.utils.get_path_value("uci.multiap.controller.enabled") == "1")
    local deviceExtendersList = {}
    if easyMeshEnabled then
      deviceExtendersList = getExtenderDeviceList()
    end

    for _, instance in pairs(deviceList or {}) do
      local instData, errMsg = proxy.get(instance)
      if errMsg then
	result.status = mqtt_lookup.mqtt_constants.generalError
	result.error = errMsg or "Given parameter or input format is Incorrect"
	return result
      end
      dmData[path] = instData
      local device = {}
      local id = instance:gsub('sys.hosts.host.', '')
      id = id:gsub("%.", "")
      device['$id'] = id
      -- default values for ethernet
      device['isGuest'] = addParameterValue('', '')
      device['signalStrength'] = addParameterValue('', '')
      device['radioType'] = addParameterValue('', '')
      device['ssid'] = addParameterValue('', '')
      device['blockedHelper'] = addParameterValue('', '')
      device['macIpBindingTemp'] = addParameterValue('', '')
      device['$macIpBindingId'] = ''
      device['$blockedRuleId'] = ''
      for _, data in pairs(dmData or {}) do
	for _, inst in pairs(data or {}) do
	  if inst.path and inst.param and inst.value then
	    if inst.param == "HostType" then
	      device['type'] = addParameterValue(inst.path .. inst.param, inst.value)
	    elseif inst.param == "L2Interface" then
	      device['connectionType'] = addParameterValue(inst.path .. inst.param, inst.value)
	      local ssidPath = "uci.wireless.wifi-iface.@" .. inst.value .. ".ssid"
	      local ssidPathValue = mqtt_lookup.utils.get_path_value(ssidPath)
              if ssidPathValue then
		device['ssid'] = addParameterValue(ssidPath, ssidPathValue)
	      end
              local radioPath = "uci.wireless.wifi-iface.@" .. inst.value .. ".device"
	      local radioPathValue = mqtt_lookup.utils.get_path_value(radioPath)
	      if radioPathValue then
		device['radioType'] = addParameterValue(radioPath, radioPathValue )
	      end
	      for _, apInst in pairs(apList or {}) do
		if apInst then
                  local ssidPath = apInst .. 'ssid'
		  local ssidValue = mqtt_lookup.utils.get_path_value(ssidPath)
	          if ssidValue == inst.value then
	            device['ap'] = addParameterValue(ssidPath, ssidValue)
		    local isolationPath = apInst .. 'ap_isolation'
		    local isolationValue = mqtt_lookup.utils.get_path_value(isolationPath)
		    device['isGuest'] = addParameterValue(isolationPath, isolationValue)
		    break
		  end
		end
	      end
	    elseif inst.param == "FriendlyName" then
	      device['name'] = addParameterValue(inst.path .. inst.param, inst.value)
	    elseif inst.param == "MACAddress" then
	      local mac = inst.value
	      device['mac'] = addParameterValue(inst.path .. inst.param, inst.value)

              -- Check if it's in easymesh
              local devEasymesh = deviceExtendersList[inst.value]
              if devEasymesh then
                if devEasymesh['radioTypePath'] and devEasymesh['radioType'] then
                  device['extRadioType']  = addParameterValue(devEasymesh['radioTypePath'], devEasymesh['radioType'])
                end
                if devEasymesh['rssiPath'] and devEasymesh['rssi'] then
                  device['extSignalStrength'] = addParameterValue(devEasymesh['rssiPath'], devEasymesh['rssi'])
                end
                if devEasymesh['devConnPath'] and devEasymesh['devConnected'] then
                  device['extDevConnected'] = addParameterValue(devEasymesh['devConnPath'], devEasymesh['devConnected'])
                end
                if devEasymesh['extAgentPath'] and devEasymesh['extAgentName'] then
                  device['extAgentName'] = addParameterValue(devEasymesh['extAgentPath'], devEasymesh['extAgentName'])
                end
                if devEasymesh['agentPath'] and devEasymesh['agent'] then
                  device['extAgentMac'] = addParameterValue(devEasymesh['agentPath'], devEasymesh['agent'])
                end
              end
              -- End easymesh part

	      for _, apInst in pairs(apList or {}) do
		if apInst then
                  local apRssiPath = apInst .. 'station.@'.. inst.value ..'.rssi'
                  local rssiValue = mqtt_lookup.utils.get_path_value(apRssiPath)
		  if rssiValue then
		    device['signalStrength'] = addParameterValue(apRssiPath, rssiValue)
		    break
		  end
		end
	      end
	      local deviceUrlList = {}
	      -- Loop the urls
	      for _, urlInst in pairs(urlList or {}) do
		if urlInst then
                  local urlMacPath = urlInst .. 'mac'
		  local macValue = mqtt_lookup.utils.get_path_value(urlMacPath)
		  if macValue == inst.value then
		    local urlSitePath = urlInst .. 'site'
		    local urlSiteValue = mqtt_lookup.utils.get_path_value(urlSitePath)
		    local urlParam = addParameterValue(urlSitePath, urlSiteValue)
		    deviceUrlList[#deviceUrlList + 1] = urlParam
		  end
               end
	      end
	      -- Get binding id --> uci.dhcp.host.$macIpBindingId.mac == $mac
	      local bindingList = mqtt_lookup.utils.get_instance_list('uci.dhcp.host.') -- Returns list of bindings
	      for _, bindingInst in pairs(bindingList or {}) do
	        if bindingInst then
		  local bindingMacPath = bindingInst .. 'mac'
		  local bindingMacValue = mqtt_lookup.utils.get_path_value(bindingMacPath)
		  if bindingMacValue == mac then
		    device['macIpBindingTemp'] = addParameterValue(bindingMacPath, bindingMacValue)
		    local macIpBindingId = bindingMacPath:gsub('uci.dhcp.host.', '')
		    device['$macIpBindingId'] = macIpBindingId:gsub(".mac", "")
		  end
		end
	      end
		-- Check whether this device is fully blocked
		-- uci.tod.host.$tod.rule_name == blocked", && uci.tod.host.$tod.id == $mac
		-- "apiParameter": "blockedHelper"
		local todList = mqtt_lookup.utils.get_instance_list('uci.tod.host.')
		for _, todInst in pairs(todList or {}) do
		  if todInst then
		    -- Check for full blocked tods
		    local todNamePath = todInst .. 'rule_name'
		    local todNameValue = mqtt_lookup.utils.get_path_value(todNamePath)
		    if todNameValue == '__bL0Ck_D3vIC3_ID__' then -- For now blocked is the fix name for this kind of tods (it might change)
		      -- This is the kind of tod we are looking for. Check mac now
		      local todMacPath = todInst .. 'id'
		      local todMacValue = mqtt_lookup.utils.get_path_value(todMacPath)
		      if todMacValue == mac then
		        device['blockedHelper'] = addParameterValue(todMacPath, todMacValue)
		        local blockedRuleId = todMacPath:gsub('uci.tod.host.', '')
			device['$blockedRuleId'] = blockedRuleId:gsub(".id", "")
		        break
		      end
		    end
		  end
		end
	      device['blockedSites'] = deviceUrlList
	    elseif inst.param == "IPv4" then
	      device['ipv4Address'] = addParameterValue(inst.path .. inst.param, inst.value)
	    elseif inst.param == "IPv6" then
	      device['ipv6Address'] = addParameterValue(inst.path .. inst.param, inst.value)
	    elseif inst.param == "State" then
	      device['connected'] = addParameterValue(inst.path .. inst.param, inst.value)
	    elseif inst.param == "LeaseType" then
	      device['mapIpBinding'] = addParameterValue(inst.path .. inst.param, inst.value)
	    end
          end
	end
        parameters[ #parameters + 1 ] = device
      end
    end
  end
  result['parameters'] = parameters
  return result
end

--- loads the config data to the module parameters and contains a call back for framing the response.
-- @function cmd
-- @param lookup table containing config data for the module parameters
-- @param payload Request message from cloud
function M.cmd(lookup, payload)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  log:debug("getDeviceList handler")
  return frameResponse(payload)
end

return M
