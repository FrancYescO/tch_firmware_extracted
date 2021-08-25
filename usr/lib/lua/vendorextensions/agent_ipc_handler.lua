-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---
--  Common module to handle the onboard, offboard, updates and metrics of agents and stations.
---

local json = require('dkjson')
local floor = math.floor
local processorInfo = require("transformer.shared.processinfo")
local bit = require("bit")
local process = require("tch.process")
local onboardedAgents = {}
local internalAgentOnboardedTime
local proxy = require("datamodel")
local runtime = {}
local open = io.open
local M = {}

local downloadFirmwareResponseCodeToResult = {
  ["0"] = "Firmware download completed without error",
  ["1"] = "Firmware file not found at specified URL",
  ["2"] = "Firmware download resulted in CRC error with downloaded file",
  ["3"] = "Firmware download is already in progress",
  ["100"] = "Write firmware completed without error",
  ["101"] = "Write Firmware attempt detected invalid file format",
  ["102"] = "Write firmware attempt resulted in system error",
  ["103"] = "Write firmware is already in progress",
}

local function setOnboardedAgentInUci(sectionName, macAddress)
  local cursor = runtime.uci.cursor()
  local isAgentInUci = false
  local notOnboardedAgents = {}
  cursor:foreach("vendorextensions", "agent", function(s)
    local section = s[".name"]
    if s and s.aleMac == macAddress then
      isAgentInUci = true
      return
    elseif not s.aleMac then
      notOnboardedAgents[#notOnboardedAgents + 1] = section
    end
  end)
  if not isAgentInUci then
    if notOnboardedAgents[1] then
      cursor:set("vendorextensions", notOnboardedAgents[1], "aleMac", macAddress)
    else
      cursor:set("vendorextensions", sectionName, "agent")
      cursor:set("vendorextensions", sectionName, "aleMac", macAddress)
    end
    cursor:commit("vendorextensions")
  end
end

local function getCpuIdle()
  local cpuData = open("/proc/stat", "r")
  local user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice
  if cpuData then
    local firstLine = cpuData:read("*l")
    if firstLine then
      user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice = firstLine:match("^cpu%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
    end
    cpuData:close()
  end
  if not user then
    return "0"
  end
  local cpuIdle = ioWait + idle
  local cpuNonIdle = user + nice + sys + irq + softIrq + steal + guest + guestNice
  local total = cpuIdle + cpuNonIdle
  cpuIdle = floor(((total - cpuNonIdle)/total) * 100)
  return tostring(cpuIdle)
end

local function getCpuSys()
  local cpuData = process.popen("top", {"-b", "-n1"})
  if not cpuData then
    return "0"
  end
  local sys
  for line in cpuData:lines() do
    sys = line:match("^CPU:.*usr%s*(%d+).*")
    if sys then
      break
    end
  end
  cpuData:close()
  return sys and tostring(sys) or "0"
end

--- Converts MAC in string format(A01245CB55AA) to MAC address with colon separated form(A0:12:45:CB:55:AA)
-- @tparam #string mac Macaddress to be formatted.
-- @treturn #string mac Macaddress seperated by colon.
M.formatMAC = function(mac)
  return mac and mac:gsub("%x%x",  ":" .. '%1'):sub(2) or ""
end

--- Updates the Internal agents basic details.
-- @tparam #string aleMac Mac address of internal agent.
M.updateInternalAgentInfo = function(aleMac)
  onboardedAgents[aleMac].agentBasicInfo = {}
  local internalAgentStats = runtime.ubus:call("system", "info", {})
  local cursor = runtime.uci.cursor()
  local memU = next(internalAgentStats.memory) and internalAgentStats.memory.total - internalAgentStats.memory.free

  onboardedAgents[aleMac].interfaceType = ""
  onboardedAgents[aleMac].parentMAC = ""

  onboardedAgents[aleMac].agentBasicInfo.DevInfo = {
    sn = cursor:get("env", "var", "serial") or "",
    ip = cursor:get("network", "lan", "ipaddr") or "",
    netmask = cursor:get("network", "lan", "netmask") or "",
    name = "Internal agent",
    type = 0,
    cpuU = processorInfo.getCPUUsage() or "",
    cpuI = getCpuIdle(),
    cpuS = getCpuSys(),
    memT = next(internalAgentStats.memory) and tostring(internalAgentStats.memory.total) or "",
    memF = next(internalAgentStats.memory) and tostring(internalAgentStats.memory.free) or "",
    memU = memU and tostring(memU) or "",
    Resettime = "",
    powerOnTimeInSec = internalAgentOnboardedTime
  }

  onboardedAgents[aleMac].agentBasicInfo.FwInfo = {
    md = cursor:get("env", "var", "prod_friendly_name") or "",
    mver = cursor:get("version.@version[0].version") or "",
    subver = "",
    hwver = cursor:get("env", "var", "hardware_version") or ""
  }
end

--- Handles agent onboard data of agent sent by the controller.
-- @tparam #table data Decoded info of onboard message.
M.handleAgentOnboardData = function(data)
  local cursor = runtime.uci.cursor()
  if not data or not next(data) then
    return nil, "No agent info found in decoded data"
  end
  local mac = M.formatMAC(data.aleMac)
  runtime.log:info("Handling onboarding data of agent : %s", mac)
  runtime.log:debug("Decoded onboarding data of agent %s is %s", mac, json.encode(data))
  local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
  onboardedAgents[mac] = data
  if mac == internalAgentMac then
    internalAgentOnboardedTime = os.time()
    M.updateInternalAgentInfo(mac)
  else
    setOnboardedAgentInUci(data.aleMac, mac)
    runtime.ubus:send("mapVendorExtensions.agent", { state = "Connect", ExtenderMAC = mac})
    runtime.action_handler.setWifiConfiguration(mac)
    local uuid = runtime.action_handler.generateUuid()
    runtime.client.send_msg("GET_BASIC_INFO", data.aleMac, runtime.OUI_ID, uuid, "")
  end
  return true
end

local function agentDataFromUpdate(data, internalAgentMac)
  local aleMac = M.formatMAC(data.aleMac)
  if data.msgType == "0009" and internalAgentMac ~= aleMac then
    onboardedAgents[aleMac].manufacturerName = data.manufacturerName
    return true
  end
  for agentKey, agentValue in pairs(data) do
    if aleMac ~= internalAgentMac and agentKey == "parentMAC" and agentValue ~= onboardedAgents[aleMac][agentKey] then
      runtime.ubus:send("mapVendorExtensions.agent", { state = "Update", ExtenderMAC = aleMac })
    end
    onboardedAgents[aleMac][agentKey] = agentValue
  end
  if aleMac ~= internalAgentMac then
    runtime.action_handler.setWifiConfiguration(aleMac)
  end
  return true
end

--- Handles Update data of agent sent by controller.
-- @tparam #table data Decoded info of update message.
M.handleAgentUpdateData = function(data)
  if not data or not next(data) then
    return nil, "No agent info found in decoded data"
  end
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
  local aleMac = M.formatMAC(data.aleMac)
  runtime.log:info("Handling update info of agent : %s", aleMac)
  runtime.log:debug("Decoded update data for agent %s is %s", aleMac, json.encode(data))
  if aleMac ~= internalAgentMac then
    setOnboardedAgentInUci(data.aleMac, aleMac)
  end
  if data.msgType == "0009"  or data.msgType == "0005" then
    runtime.log:info("Agent update message type is %s", data.msgType == "0009" and "WSC M1" or "VENDOR_TYPE_TOPOLOGY_TREE_ATTACH")
    if not onboardedAgents[aleMac] then
      runtime.log:info("Agent update called without onboard message creating new agent %s", aleMac)
      onboardedAgents[aleMac] = {}
      if aleMac == internalAgentMac then
        internalAgentOnboardedTime = os.time()
        M.updateInternalAgentInfo(aleMac)
      else
        runtime.ubus:send("mapVendorExtensions.agent", { state = "Connect", ExtenderMAC = aleMac})
      end
    end
    if aleMac ~= internalAgentMac then
      runtime.log:info("Sending Get basic info request to %s from agent update message", aleMac)
      local uuid = runtime.action_handler.generateUuid()
      runtime.client.send_msg("GET_BASIC_INFO", data.aleMac, runtime.OUI_ID, uuid, "")
      agentDataFromUpdate(data, internalAgentMac)
    end
    return true
  end
  runtime.log:info("Agent update message type is Topology Changes")
  if not onboardedAgents[aleMac] then
    return nil, "Received update message of Agent which is not onboarded"
  end
  agentDataFromUpdate(data, internalAgentMac)
  return true
end

--- Handles Offboard data of agent sent by the controller.
-- @tparam #string aleMac ale macaddress of the agent offboarded.
M.handleAgentOffboardData = function(aleMac)
  local cursor = runtime.uci.cursor()
  if not aleMac then
    return nil, "No agent ALE MAC address is given"
  end
  local mac = M.formatMAC(aleMac)
  runtime.log:info("Handling offboard message of agent: %s", mac)
  onboardedAgents[mac] = nil
  runtime.ubus:send("mapVendorExtensions.agent", { state = "Disconnect", ExtenderMAC = mac })
  cursor:foreach("vendorextensions", "agent", function(s)
    local section = s[".name"]
    if s and s.aleMac == mac then
      if aleMac == section then
          cursor:delete("vendorextensions", aleMac)
      else
        cursor:delete("vendorextensions", section, "aleMac")
      end
    end
  end)
  cursor:commit("vendorextensions")
  return true
end

-- Checks whether agent is onboarded for the first time or not.
local function isNewAgent(aleMac, cursor)
  local agents = cursor:get("vendorextensions", "brightness", "mac") or {}
  for _, agentMac in  ipairs(agents) do
    if agentMac == aleMac then
      return false
    end
  end
  return true, agents
end

-- Updates the LED brightness of an agent.
M.updateLedStatus = function(aleMac, brightness)
  if onboardedAgents[M.formatMAC(aleMac)] then
    if not onboardedAgents[M.formatMAC(aleMac)].LEDStatus then
      onboardedAgents[M.formatMAC(aleMac)].LEDStatus = {}
    end
    onboardedAgents[M.formatMAC(aleMac)].LEDStatus.bri = brightness or ""
  end
end

-- Sets Default LED state when agent onboards for very first time.
local function setDefaultLedState(aleMac)
  local cursor = runtime.uci.cursor()
  local newAgent, knownAgents = isNewAgent(aleMac, cursor)
  if newAgent then
    local uuid = runtime.action_handler.generateUuid()
    knownAgents[#knownAgents + 1] = aleMac
    cursor:set("vendorextensions", "brightness", "led")
    cursor:set("vendorextensions", "brightness", "mac", knownAgents)
    cursor:commit("vendorextensions")
    M.updateLedStatus(aleMac, "2")
    runtime.client.send_msg("SET_LED_STATUS", aleMac, runtime.OUI_ID, uuid, json.encode({data = {{idx = "0", clr = "2", bri = "2"}} }))
  end
end

--- Handles recieved 1905 messages.
-- @tparam #table data Decoded 1905 message.
M.handleReceived1905Data = function(data)
  local cursor = runtime.uci.cursor(nil, "/var/state")
  if not data or not next(data) then
    return nil, "No vendor specific info found in the decoded data"
  end
  local mac = M.formatMAC(data.aleMac)
  runtime.log:info("Handling 1905 message from agent: %s", mac)
  runtime.log:debug("Decoded 1905 data of agent %s is %s", mac, json.encode(data))
  if not onboardedAgents[mac] then
    return nil, "Received vendor specific info of Agent which is not onboarded"
  end
  if data.msgType == 4 then
    if data.responseType == 1 then
      runtime.log:info("GET BASIC INFO request message from agent: %s", mac)
      local internalAgentStats = runtime.ubus:call("system", "info", {})
      local memU = next(internalAgentStats.memory) and internalAgentStats.memory.total - internalAgentStats.memory.free
      local getBasicInfoResponse = {
        DevInfo = {
          sn = cursor:get("env", "var", "serial") or "",
          ip = cursor:get("network", "lan", "ipaddr") or "",
          netmask = cursor:get("network", "lan", "netmask") or "",
          name = "Gateway",
          Type = 0,
          uptime = tostring(internalAgentStats.uptime) or "",
          cpuU = processorInfo.getCPUUsage() or "",
          cpuS = getCpuSys(),
          cpuI = getCpuIdle(),
          memT = next(internalAgentStats.memory) and tostring(internalAgentStats.memory.total) or "",
          memF = next(internalAgentStats.memory) and tostring(internalAgentStats.memory.free) or "",
          memU = memU and tostring(memU) or "",
          Resettime = "",
        },
        FwInfo = {
          md = cursor:get("env", "var", "prod_friendly_name") or "",
          mver = cursor:get("version.@version[0].version") or "",
          subver = "",
          hwver = cursor:get("env", "var", "hardware_version") or ""
        }
      }
      runtime.log:debug("GET BASIC INFO response for agent : %s is %s", mac, json.encode(getBasicInfoResponse))
      local uuid = runtime.action_handler.generateUuid()
      runtime.client.send_msg("GET_BASIC_INFO_RESPONSE", data.aleMac, runtime.OUI_ID, uuid, json.encode(getBasicInfoResponse))
    elseif data.responseType == 2 then
      runtime.log:info("GET BASIC INFO response message from agent: %s", mac)
      local oldSWVersion, newSWVersion
      local prevData = onboardedAgents[mac].agentBasicInfo and onboardedAgents[mac].agentBasicInfo.FwInfo or {}
      if prevData.mver and prevData.mver ~= "" then
        oldSWVersion = prevData.mver .. "_" .. prevData.subver
      end
      onboardedAgents[mac].agentBasicInfo = json.decode(data.vendorInfo) or {}
      if onboardedAgents[mac].agentBasicInfo.DevInfo and onboardedAgents[mac].agentBasicInfo.DevInfo.uptime then
        onboardedAgents[mac].agentBasicInfo.DevInfo.powerOnTimeInSec = os.time() - onboardedAgents[mac].agentBasicInfo.DevInfo.uptime
        runtime.ubus:send("mapVendorExtensions.agent", { Action = "powerOnTimeUpdated", MAC = mac })
      end
      if onboardedAgents[mac].agentBasicInfo.FwInfo and onboardedAgents[mac].agentBasicInfo.FwInfo.mver
      and onboardedAgents[mac].agentBasicInfo.FwInfo.mver ~= "" then
        newSWVersion = onboardedAgents[mac].agentBasicInfo.FwInfo.mver .. "_" .. onboardedAgents[mac].agentBasicInfo.FwInfo.subver
      end
      if oldSWVersion and newSWVersion and oldSWVersion ~= newSWVersion then
        runtime.log:info("Old software version is %s", oldSWVersion)
        runtime.log:info("New software version is %s", newSWVersion)
        runtime.log:info("Trigger a cwmpd inform for agent %s, with new software version %s", mac, newSWVersion)
        -- If both old and new firmware information are valid, and old firmware is not equal to new firmware, then send cwmpd inform for new software version
        runtime.ubus:send("mapVendorExtensions.agent", { Action = "softwareVersionUpdated", MAC = mac })
      end
      if not oldSWVersion and newSWVersion then
        runtime.log:info("Old software version is Empty or Nil")
        runtime.log:info("New software version is %s", newSWVersion)
        runtime.log:info("Triggering software upgrade eligibility for newly added agent %s", data.aleMac)
        -- If no firmware information is already found. It means this is the first Get Basic Info response after Agent onboarding.
        local ok = runtime.action_handler.deploySoftwareActionHandler(nil, nil, data.aleMac)
        -- Send set LED status request message with default brightness("1") when agent onboards for the  first time
        if not ok then
          setDefaultLedState(data.aleMac)
        end
      end
    elseif data.responseType == 4 then
      runtime.log:info("Download firmware complete response for %s is %s", mac, data.vendorInfo or "")
      local downloadFirmwareResponse = json.decode(data.vendorInfo) or {}
      local dwindowInProgress = cursor:get("vendorextensions", "dwindow", "inprogress")
      if downloadFirmwareResponseCodeToResult[downloadFirmwareResponse.result] and dwindowInProgress == "1" then
        local agentPresent = cursor:get("vendorextensions", "upgradeFirmwareStatus", data.aleMac)
        if not agentPresent then
          return nil, "Received download firmware complete of Agent which is not listed for upgrade"
        end
        cursor:set("vendorextensions", "upgradeFirmwareStatus", data.aleMac, downloadFirmwareResponseCodeToResult[downloadFirmwareResponse.result])
        cursor:save("vendorextensions")
        runtime.log:info("Firmware upgrade status for %s is %s", mac, downloadFirmwareResponseCodeToResult[downloadFirmwareResponse.result] or "Error")
      end
    elseif data.responseType == 13 then
      runtime.log:info("GET LED STATUS response message from agent: %s", mac)
      local ledStatus = json.decode(data.vendorInfo)
      onboardedAgents[mac].LEDStatus = ledStatus and ledStatus["data"] and ledStatus["data"][1] or {}
    end
  end
  return true
end

--- Returns the info of onboarded agents.
-- @treturn #table onboardedAgents A table containing details of currently connected agents.
M.getOnboardedAgents = function()
  return onboardedAgents
end

--- Handles the sation connect message sent by controller.
-- @tparam #table data Decoded info of station connect message.
M.handleStationConnectData = function(data)
  if not data or not next(data) then
    return nil, "No station info found in decoded data"
  end
  local aleMac = M.formatMAC(data.aleMac)
  runtime.log:debug("Decoded station connect data of agent %s is %s", aleMac, json.encode(data))
  for staMac, staData in pairs(data[data.aleMac].stations) do
    runtime.log:info("handleStationConnectData mac: %s", staMac)
    runtime.ubus:send("mapVendorExtensions.agent.station", { state = "Connect", station = staMac, bssid = staData.BSSID })
    if onboardedAgents[aleMac] then
      if not onboardedAgents[aleMac].stations then
        onboardedAgents[aleMac].stations = {}
      end
      onboardedAgents[aleMac].stations[staMac] = staData
    else
      return nil, "Agent not onboarded"
    end
  end
  return true
end

--- Handles the sation disconnect message sent by controller.
-- @tparam #table data Decoded info of station disconnect message.
M.handleStationDisconnectData = function(data)
  if not data or not next(data) then
    return nil, "No station info found in decoded data"
  end
  local aleMac = M.formatMAC(data.aleMac)
  runtime.log:debug("Decoded station disconnect data of agent %s is %s", aleMac, json.encode(data))
  for staMac, staData in pairs(data[data.aleMac].stations) do
    runtime.log:info("handleStationDisConnectData mac: %s", staMac)
    runtime.ubus:send("mapVendorExtensions.agent.station", { state = "Disconnect", station = staMac, bssid = staData.BSSID })
    if onboardedAgents[aleMac] and onboardedAgents[aleMac].stations and onboardedAgents[aleMac].stations[staMac] then
      onboardedAgents[aleMac].stations[staMac] = staData
    else
      return nil, "Agent not onboarded"
    end
  end
  return true
end

--- Handles the sation metrics message sent by controller.
-- @tparam #table data Decoded info of station metrics message.
M.handleStationMetrics = function(data)
  if not data or not next(data) then
    return nil, "No station metrics found in decoded data"
  end
  runtime.log:debug("Decoded station metrics data is %s", json.encode(data))
  for staMAC, metrics in pairs(data) do
    local staMac = M.formatMAC(staMAC)
    for agentMac in pairs(onboardedAgents) do
      if onboardedAgents[agentMac] and onboardedAgents[agentMac].stations and onboardedAgents[agentMac].stations[staMac] and onboardedAgents[agentMac].stations[staMac].Active and onboardedAgents[agentMac].stations[staMac].Active == "1" then
        for stats, value in pairs(metrics) do
          if stats == "SignalStrength" then
            if value == 0 then
              value = -109.5
            elseif value >= 1 and value <= 220 then
              value = value and (value / 2) - 110 or ""
            else
              value = ""
            end
          end
          onboardedAgents[agentMac].stations[staMac][stats] = value
        end
      end
    end
  end
  return true
end

local function unsignedToSignedInt(value)
  if not value or type(value) ~= "number" then
    return ""
  end
  if bit.band(value, 128) == 128 then
    value = bit.bnot(value)
    value = bit.band(value, 255)
    value = "-" .. value + 1
  end
  return value
end

--- Handles the AP metrics message sent by controller.
-- @tparam #table data Decoded info of ap metrics message.
M.handleAPMetrics = function(data)
  runtime.log:info("Handling AP metrics message")
  if not data or not next(data) then
    return nil, "No agent info is found in decoded data"
  end
  runtime.log:debug("Decoded ap metrics data is %s", json.encode(data))
  for agentMac, agentInfo  in pairs(data) do
    if onboardedAgents[agentMac] then
      onboardedAgents[agentMac].lastDataLinkRate = agentInfo.lastDataLinkRate
      runtime.log:info("Signal strength of agent %s is %d", agentMac, agentInfo.signalStrength)
      onboardedAgents[agentMac].signalStrength = unsignedToSignedInt(agentInfo.signalStrength)
    else
      runtime.log:info("Received metrics info for agent which is not onboarded")
    end
  end
  return true
end

M.updateWifiDrOnboardingStatus = function(mac, status)
  if onboardedAgents[mac] then
    runtime.log:info("Update Wifi Dr status in internal structure for %s", mac)
    onboardedAgents[mac]["wifiDrOnboardingStatus"] = status
  end
  return true
end

--- Clears the agent information, in case the reboot or rtfd is triggered from GUI for specific agent.
-- @tparam #string agent Agent which needs to be cleared from uci and internal VE structure.
M.clearAgentInfoForGuiRequests = function(agent)
  local cursor = runtime.uci.cursor()
  local macWithoutColon = string.gsub(agent, "%:", "")
  cursor:foreach("vendorextensions", "agent", function(s)
    local section = s[".name"]
    if s and s.aleMac == agent then
      if macWithoutColon == section then
          cursor:delete("vendorextensions", section)
      else
        cursor:delete("vendorextensions", section, "aleMac")
      end
      return false
    end
  end)
  cursor:commit("vendorextensions")
  onboardedAgents[agent] = nil
end

--- Handles multicast status message from controller.
-- @tparam #table data Decoded data of status message.
M.handleMulticastStatus = function(data)
  local cursor = runtime.uci.cursor(nil, "/var/state")
  local uciCursor = runtime.uci.cursor()
  if not data or not next(data) then
    return nil, "No multicast status information found"
  end
  runtime.log:debug("Decoded multicast status data is %s", json.encode(data))
  local multicastRequest = cursor:get("vendorextensions", "multicast_uuid", data.uuid)
  if multicastRequest and multicastRequest ~= "" then
    cursor:delete("vendorextensions", "multicast_uuid")
    cursor:delete("vendorextensions", "multicast_uuid", data.uuid)
    cursor:save("vendorextensions")
    uciCursor:foreach("vendorextensions", "agent", function(s)
      if s['.name']:match("^agent") then
        uciCursor:delete("vendorextensions", s[".name"], "aleMac")
      else
        uciCursor:delete("vendorextensions", s[".name"])
      end
    end)
    uciCursor:commit("vendorextensions")
    onboardedAgents = {}
    if string.match(multicastRequest, 'RTFD') then
      runtime.log:info("Multicast status message recieved for RTFD")
      cursor:delete("vendorextensions", "brightness" )
      cursor:foreach("vendorextensions", "alias_name", function(s)
        cursor:delete("vendorextensions", s[".name"])
      end)
      cursor:commit("vendorextensions")
      if multicastRequest ~= "RTFDOfBoostersOnly" then
        local date = os.date("%Y-%m-%d %H:%M:%S", os.time())
        cursor:set("multiap", "controller", "factoryreset_time", date)
        cursor:save("multiap")
        runtime.ubus:send("mapVendorExtensions.controller", { Action = "FactoryResetTime" })
        local resetType =  cursor:get("multiap", "controller", "factoryreset_type")
        runtime.log:info("Reseting Controller and Agent Settings for reset type %d",resetType)
        proxy.set("rpc.vendorextensions.MulticastHandler", "RTFD"..resetType)
        if multicastRequest == "RTFDOfBoostersAndGW" then
          proxy.set("rpc.system.reset","1")
        end
        proxy.apply()
      end
    elseif string.match(string.upper(multicastRequest), 'REBOOT') then
      runtime.log:info("Multicast status message received for Reboot")
      if multicastRequest ~= "RebootOfBoostersOnly" then
        proxy.set("rpc.vendorextensions.MulticastHandler", "Reboot")
        if multicastRequest == "RebootAgentAndGW" then
          proxy.set("rpc.system.reboot","GUI")
        end
        proxy.apply()
      end
    end
  end
  return true
end

--- Initializes agent's IPC message handlers.
-- @tparam #table rt Runtime table containing ubus and action handlers
M.init = function(rt)
  runtime  = rt
end

return M
