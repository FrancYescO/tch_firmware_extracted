-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---------------------------------
-- The implementation of the UBUS handler functions for multiap controller object.
---------------------------------

local ubus = require('ubus')
local runtime = {}
local M ={}
local conn = {}
local ubusConn = {}
ubusConn.__index = ubusConn
local action_handler = require('vendorextensions.actionHandler')

local function getAgentNumberOfEntries()
  local noOfAgents = 0
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
  for agentMac, agentData in pairs(runtime.agent_ipc_handler.getOnboardedAgents()) do
    if agentMac ~= internalAgentMac then
      noOfAgents = noOfAgents + 1
    end
  end
  return tonumber(noOfAgents)
end

--- gets multiap controller status and sends ubus reply
-- @tparam #string req ubus request
local function get_controller_status(req)
  local response = {
    ["Enable"] = runtime.config.getControllerStatus(),
    ["HardwareVersion"] = runtime.config.getUciValue("env", "var", "hardware_version"),
    ["MultiAPAgentNumberOfEntries"] = getAgentNumberOfEntries(),
    ["PowerOnTime"] = runtime.config.getControllerPowerOnTime(),
    ["FactoryResetTime"] = runtime.config.getFactoryResetTime()
  }
  conn:reply(req,response)
end

local function get_stations(req, msg)
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  local response = {}
  if msg.device and agentData[msg.device] and agentData[msg.device].stations and agentData[msg.device].stations[msg.macaddr] then
    response = agentData[msg.device].stations[msg.macaddr]
  elseif msg.device and not msg.macaddr then
    response = agentData[msg.device] and agentData[msg.device].stations or {}
  elseif not msg.device and msg.macaddr then
    for agentMac, stationInfo in pairs(agentData) do
      for staMac, data in pairs(stationInfo.stations or {}) do
        if staMac == msg.macaddr then
          response[agentMac] = data
        end
      end
    end
  elseif not msg.device and not msg.macaddr then
    for agentMac, stationInfo in pairs(agentData) do
      response[agentMac] = {}
      for staMac, data in pairs(stationInfo.stations or {}) do
        response[agentMac][staMac] = data
      end
    end
  end
  conn:reply(req,response)
end

-- Lookup for interface type to convert the hex byte to String
local interfaceType = {
  ["0000"] = "Ethernet",
  ["0001"] = "Ethernet",
  ["0100"] = "WiFi2.4G",
  ["0101"] = "WiFi2.4G",
  ["0102"] = "WiFi5G",
  ["0103"] = "WiFi2.4G",
  ["0104"] = "WiFi5G",
  ["0105"] = "WiFi5G"
}

-- Lookup table decoded radio type value with corresponding radio type name.
local radioType = {
  [1] = "radio_2G",
  [2] = "radio_5G"
}

local LEDBrightness = {
  ["0"] = "Off",
  ["1"] = "Dim",
  ["2"] = "Normal"
}

local LEDColor = {
  ["0"] = "Green",
  ["1"] = "Yellow",
  ["2"] = "Red",
  ["3"] = "Orange",
  ["4"] = "White",
  ["5"] = "Purple",
  ["6"] = "Blue"
}

local function formatResetTime(resetTime)
  if resetTime ~= "" then
    local date, month, year, time = resetTime:match("(%d+)/(%d+)/(%d+) (.*)")
    if date then
      return year .. "-" .. month .. "-" .. date .. " " .. time
    end
  end
  return ""
end

local function getSoftwareVersion(mainVersion, subVersion)
  if not mainVersion or mainVersion == "" then
    return ""
  end
  return subVersion and subVersion ~= "" and mainVersion .. "_" .. subVersion or mainVersion
end

local function getStaCount(aleMac)
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  local staCount = 0
  if agentData[aleMac] and agentData[aleMac]["stations"] then
    for staMac, staData in pairs(agentData[aleMac]["stations"]) do
      if staData.Active == "1" then
        staCount = staCount + 1
      end
    end
  end
  return staCount
end

local function prepareAgentResponse(mac, agentData, response)
  local devInfo = agentData.agentBasicInfo and agentData.agentBasicInfo.DevInfo or {}
  local fwInfo = agentData.agentBasicInfo and agentData.agentBasicInfo.FwInfo or {}
  local connectionType = agentData.interfaceType and interfaceType[agentData.interfaceType] or "Unknown"
  local ledStatus = agentData.LEDStatus or {}
  local aliasName = runtime.config.getAgentAliasName(mac)
  if aliasName == "" then
    aliasName = devInfo.name or "Wi-Fi Booster " .. mac:match(".*:(.*)$")
  end
  local signalStrength = agentData.signalStrength or ""
  if devInfo.name == "Internal agent" or connectionType == "Ethernet" then
    signalStrength = "-127"
  end
  response[mac] = {
    ["Alias"] = aliasName,
    ["ManufacturerName"] = agentData.manufacturerName or "",
    ["IEEE1905Id"] = mac or "",
    ["MACAddress"] = agentData.interfaceMac or "",
    ["SignalStrength"] = signalStrength,
    ["LastDataLinkRate"] = agentData.lastDataLinkRate or "",
    ["ParentAccessPoint"] = agentData.parentMAC or "",
    ["NoOfRadios"] =  agentData.numberOfRadios or "",
    ["ConnectionType"] = devInfo.name ~= "Internal agent" and connectionType or "",
    ["MaxAssociatedDevices"] = "32",
    ["AssociatedDeviceNumberOfEntries"] = getStaCount(mac) or "",
    ["ModelNumber"] = fwInfo and fwInfo.md or "",
    ["SoftwareVersion"] = getSoftwareVersion(fwInfo.mver, fwInfo.subver),
    ["HardwareVersion"] = fwInfo.hwver or "",
    ["IPAddress"] = devInfo.ip or "",
    ["Netmask"] = devInfo.netmask or "",
    ["SerialNumber"] = devInfo.sn or "",
    ["DeviceName"] = aliasName,
    ["DeviceType"] = devInfo.type or "",
    ["FactoryResetTime"] = devInfo.Resettime and formatResetTime(devInfo.Resettime) or "",
    ["UpTime"] = type(devInfo.powerOnTimeInSec) == "number" and os.time() - devInfo.powerOnTimeInSec or "",
    ["PowerOnTime"] = devInfo.powerOnTimeInSec and os.date("%F %T", devInfo.powerOnTimeInSec) or "",
    ["CpuUsage"] = devInfo.cpuU or "",
    ["CpuSys"] = devInfo.cpuS or "",
    ["CpuIdle"] = devInfo.cpuI or "",
    ["TotalMemory"] = devInfo.memT or "",
    ["FreeMemory"] = devInfo.memF or "",
    ["MemoryUsed"] = devInfo.memU or "",
    ["LEDBrightness"] =  ledStatus.bri and LEDBrightness[ledStatus.bri] or "",
    ["LEDColor"] = ledStatus.clr and LEDColor[ledStatus.clr] or ""
  }
  for index = 1, agentData.numberOfRadios or 0 do
    local radio = "radio_" .. index
    response[mac][radio] = {
      ["RadioID"] = agentData[radio].radioID or "",
      ["RadioType"] = radioType[agentData[radio].radiotype] or "",
      ["NoOfBSSID"] = agentData[radio].BSSCount or "",
      ["BSSID"] = agentData[radio]["BSSID"] or {},
    }
  end
end

-- Gets multiap agent parameters and sends ubus reply
local function get_agent_status(req, msg)
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("multiap", "agent", "macaddress")
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  local response = {}
  if msg.device and agentData[msg.device] then
    if msg.device == internalAgentMac then
      runtime.agent_ipc_handler.updateInternalAgentInfo(msg.device)
    end
    prepareAgentResponse(msg.device, agentData[msg.device], response)
    conn:reply(req, response[msg.device])
    return
  end
  for mac, agent in pairs(agentData) do
    if mac == internalAgentMac then
      runtime.agent_ipc_handler.updateInternalAgentInfo(mac)
    end
    prepareAgentResponse(mac, agent, response)
  end
  conn:reply(req, response)
end

-- Action mapped with corresponding action handler
local actionHandlerMap = {
  ["Reboot"] = action_handler.rebootActionHandler,
  ["DeploySoftwareNow"] = action_handler.deploySoftwareActionHandler,
  ["RTFD"] = action_handler.resetActionHandler,
}

--- trigger a specific action on the multiap network
-- @tparam #string req ubus request
-- @tparam #table msg ubus request action and mode
local function trigger_controller_action(req, msg)
  if msg["Action"] and actionHandlerMap[msg["Action"]] and actionHandlerMap[msg["Action"]](req, msg) then
    return true
  end
  runtime.log:error("No handler for the triggered action")
  return
end

local MAPControllerObject = {
  ['mapVendorExtensions.controller'] = {
    get = {
      get_controller_status, {}
    },
    triggerAction = {
      trigger_controller_action, {["Action"] = ubus.STRING, ["Mode"] = ubus.INT32,  ["Address"] = ubus.STRING}
    },
    sendModifiedWifiConfig = {
      action_handler.sendModifiedWifiConfig, {["Radio"] = ubus.STRING, ["AP"] = ubus.STRING, ["Parameter"] = ubus.STRING, ["Value"] = ubus.STRING }
    }
  }
}

local MAPAgentObject = {
  ['mapVendorExtensions.agent'] = {
    get = {
      get_agent_status, {["device"] = ubus.STRING}
    },
    get_led_status = {
      action_handler.get_led_status, {["Mac"] = ubus.STRING}
    },
    set_led_status = {
      action_handler.set_led_status, {["Mac"] = ubus.STRING, ["Brightness"] = ubus.STRING}
    },
  },
  ['mapVendorExtensions.agent.station'] = {
    get = {
     get_stations, {["device"] = ubus.STRING, ["macaddr"] = ubus.STRING}
    },
  }
}

--- sends ubus response
-- @tparam #string req ubus request
-- @tparam #table data ubus reply data
function ubusConn:reply(req, data)
  if self.ubus then
    self.ubus:reply(req, data)
  end
end

--- adds new ubus object
-- @tparam #string method ubus object name
function ubusConn:add(method)
  if self.ubus then
    self.ubus:add(method)
  end
end

--- executes ubus call to retrieve data
-- @tparam string facility ubus object name
-- @tparam table func list of functions to be called for ubus output
-- @tparam table params parameters for ubus call
function ubusConn:call(facility, func, params)
  if self.ubus then
    return self.ubus:call(facility, func, params)
  end
end

--- sends ubus events
-- @tparam #string facility ubus object name
-- @tparam #table data ubus event data
function ubusConn:send(facility, data)
  if self.ubus then
    self.ubus:send(facility, data)
  end
end

--- listens for ubus events
function ubusConn:listen(events)
  if self.ubus then
    self.ubus:listen(events)
  end
end

--- removes ubus library
function ubusConn:close()
  self.ubus = nil
end

--- checks if ubus object is already existing
-- @treturn #boolean if object is present or not
function ubusConn:hasObject(object)
  if self.ubus then
    local namespaces = self.ubus:objects()
    for _, n in ipairs(namespaces) do
      if n == object then
        return true
      end
    end
  end
  return false
end

--- Initializes ubus plugin
function M.init(rt)
  runtime = rt
  if not runtime.ubus then
    conn = {
      ubus = ubus.connect()
    }
    if not conn.ubus then
      return nil, "Failed to connect to ubus"
    end
    setmetatable(conn, ubusConn)

    if conn:hasObject("mapVendorExtensions.controller") then
      runtime.log:error("MAP controller UBUS objects already present")
      return nil, "Failed to initialize ubus"
    end

    conn:add(MAPControllerObject)

    if conn:hasObject("mapVendorExtensions.agent") then
      runtime.log:error("MAP Agent UBUS objects already present")
      return nil, "Failed to initialize ubus"
    end

    conn:add(MAPAgentObject)
    runtime.ubus = conn
  end
  return true
end

return M
