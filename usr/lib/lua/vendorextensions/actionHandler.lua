-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---------------------------------
-- Handler which takes care of the functionality for the ubus rpc actions triggered from multiap controller object
---------------------------------
local runtime = {}
local M = {}
local process = require('tch.process')
local lfs = require('lfs')
local json = require('dkjson')
local uciHelper = require("transformer.mapper.ucihelper")
local gsub = string.gsub

function M.generateUuid()
  return string.sub(uciHelper.generate_key(), 1, 4)
end

local function createTimerToClearUUID(uuid)
  runtime.log:info("Creating a timer to clear UUID %s if no response is received for 2 minutes", uuid)
  runtime.uloop.timer(function()
    local cursor = runtime.uci.cursor(nil, "/var/state")
    local result = cursor:get("vendorextensions", "multicast_uuid", uuid)
    if result then
      runtime.log:info("UUID %s is deleted on timer expiry at %s", uuid, os.time())
      cursor:delete("vendorextensions", "multicast_uuid")
      cursor:save("vendorextensions")
    else
      runtime.log:info("Existing uuid does not match the requested uuid. So not clearing this as it is a new request.")
    end
  end, 120000)
end

--- Check if any multicast request is sent recently.
function M.checkAndAddMulticastRequest(uuid, multicastRequest)
  local cursor = runtime.uci.cursor(nil, "/var/state")
  local multicastUUID = cursor:get("vendorextensions", "multicast_uuid")
  if not multicastUUID then
    cursor:set("vendorextensions", "multicast_uuid", uuid)
    cursor:set("vendorextensions", "multicast_uuid", uuid, multicastRequest)
    cursor:save("vendorextensions")
    runtime.log:info("UUID %s is stored at %s", uuid, os.time())
    createTimerToClearUUID(uuid)
    return true
  end
  runtime.log:critical("Already a Reset / Reboot is in progress. Please try after it is completed")
end

--- Handler for reboot message.
-- If agent's mac is provided, reboot msg is sent to controller with particular mac and that agent alone will be rebooted.
-- Reboot triggered via Device with type "1" will be provided to reboot all boosters and to restart ctrl and agent.
-- Reboot triggered via Device with type "2" will be provided to reboot all boosters and router.
-- Reboot triggered via RPC with broadcast MAC as address will be provided to reboot all boosters.
-- Reboot triggered via RPC with MAC "FF:FF:FF:FF:FF:FF" will be provided to reboot all boosters and router
-- If broadcast mac or 'FF:FF:FF:FF:FF:FF' is provided in Address field or if no address is specified, reboot msg sent to controller with broadcast mac after adding uuid in vendorextensions config.
function M.rebootActionHandler(req, msg)
  runtime.log:info("Reboot action is triggered")
  local multicastRequest = "REBOOT"
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  local uuid = M.generateUuid()
  if msg and msg.Mode == "2" then
    multicastRequest = "RebootAgentAndGW"
  end
  if msg.Address then
    local mac = gsub(msg.Address, "%:", "")
    if agentData[msg.Address] then
      runtime.client.send_msg("REBOOT", mac, runtime.OUI_ID, uuid, "")
      runtime.agent_ipc_handler.clearAgentInfoForGuiRequests(msg.Address)
      return true
    elseif mac == "FFFFFFFFFFFF" then
      multicastRequest = "RebootAgentAndGW"
    elseif mac == runtime.BROADCAST_MAC then
      multicastRequest = "RebootOfBoostersOnly"
    else
      runtime.log:info("Given MAC address is invalid")
      return false
    end
  end
  local ok = M.checkAndAddMulticastRequest(uuid, multicastRequest)
  if ok then
    runtime.client.send_msg("REBOOT", runtime.BROADCAST_MAC, runtime.OUI_ID, uuid, "")
  end
  return true
end

--- Handler for reset message
-- If agent's mac is provided, RTFD msg is sent to controller with particular mac and that agent alone will be reset.
-- Mac 'FF:FF:FF:FF:FF:FF' will be provided to reset router as well as all boosters.
-- If broadcast mac or 'FF:FF:FF:FF:FF:FF' is provided in Address field or if no address is specified, RTFD msg sent to controller with broadcast mac after adding uuid in vendorextensions config.
function M.resetActionHandler(req, msg)
  runtime.log:info("RTFD action triggered")
  local multicastRequest = "RTFD"
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  local uuid = M.generateUuid()
  if msg.Address then
    local mac = gsub(msg.Address, "%:", "")
    if agentData[msg.Address] then
      local cursor = runtime.uci.cursor()
      cursor:delete("vendorextensions", mac .."_alias")
      cursor:commit("vendorextensions")
      runtime.client.send_msg("RTFD", mac, runtime.OUI_ID, uuid, json.encode({ BH = msg.Mode }))
      runtime.agent_ipc_handler.clearAgentInfoForGuiRequests(msg.Address)
      return true
    elseif mac == "FFFFFFFFFFFF" then
      multicastRequest = "RTFDOfBoostersAndGW"
    elseif mac == runtime.BROADCAST_MAC then
      multicastRequest = "RTFDOfBoostersOnly"
    else
      runtime.log:info("Given MAC address is invalid")
      return false
    end
  end
  local ok = M.checkAndAddMulticastRequest(uuid, multicastRequest)
  if ok and (msg.Mode == "1" or msg.Mode == "2") then
    local cursor = runtime.uci.cursor(nil, "/var/state")
    cursor:set("multiap", "controller", "factoryreset_type", msg.Mode)
    cursor:save("multiap")
    runtime.client.send_msg("RTFD", runtime.BROADCAST_MAC, runtime.OUI_ID, uuid, json.encode({ BH = msg.Mode }))
  end
  return true
end

-- Where there are multiple SW table entries with the following conditions then these will be deemed to be an Error State.
-- Identical EligibleSoftwareVersions or 'empty strings' detected as applying to the same [EligibleModel AND EligibleHardwareVersion].
-- Identical SoftwareVersions detected as applying to the same [EligibleModel AND EligibleHardwareVersion].
-- If an Error State is detected an entry will be made in the Gateway system log detailing the error and the Multi-AP Controller will NOT initiate any firmware deployment actions to Multi-AP Agent Devices.
local function getAgentSoftwareImages()
  local cursor = runtime.uci.cursor()
  runtime.log:info("Get Agent's software images")
  local agentSoftwareImagesCache = {}
  local agentSoftwareImages = {}
  local agentSoftwareVersion = {}
  local agentModelHardware = {}
  local duplicateFound
  cursor:foreach("vendorextensions", "agent_sw_image", function(s)
    local section = s['.name']
    local agent_sw_image = cursor:get_all("vendorextensions", section)
    if agent_sw_image and agent_sw_image.eligible_model and agent_sw_image.eligible_hardware_version and agent_sw_image.software_version
    and agent_sw_image.url then
      agentSoftwareImagesCache[section] = agent_sw_image
      local eligible_software_version = agent_sw_image.eligible_software_version or ""
      local sw_image_eligible_model_hw = agent_sw_image.eligible_model .. agent_sw_image.eligible_hardware_version
      local key = sw_image_eligible_model_hw .. eligible_software_version
      local sw_version_key = agent_sw_image.software_version .. sw_image_eligible_model_hw
      if (eligible_software_version == "" and agentModelHardware[sw_image_eligible_model_hw]) or agentSoftwareImages[key] or agentSoftwareImages[sw_image_eligible_model_hw] or agentSoftwareVersion[sw_version_key] then
        duplicateFound = true
        return false
      end
      runtime.log:info("getAgentSoftwareImages key is %s", key)
      runtime.log:info("getAgentSoftwareImages section name is %s", section)
      agentSoftwareImages[key] = section
      agentSoftwareVersion[sw_version_key] = true
      agentModelHardware[sw_image_eligible_model_hw] = true
    end
  end)
  if duplicateFound then
    return nil, "Duplicate Software Images table entries"
  end
  return agentSoftwareImages, nil, agentSoftwareImagesCache
end

-- Logic Summary to validate whether an agent has to be upgraded or not is as follows:
-- If EligibleSoftwareVersion is empty, then Compare Multi-AP Agent Device version with the SoftwareVersion.
-- And Multi-AP Agent Device version is not equal to SoftwareVersion then trigger firmware installation.
-- Else Compare Multi-AP Agent Device version with EligibleSoftwareVersion.
-- If Multi-AP Agent Device version is equal to EligibleSoftwareVersion then then trigger firmware installation.
local function validateAndAddAgentForUpgrade(mac, agentSoftwareImages, agentData, agentsToBeUpgraded, agentSoftwareImagesCache)
  if not mac or not agentData or not agentData.agentBasicInfo or not agentData.agentBasicInfo.FwInfo then
    return
  end
  local agent_model_hw = string.format("%s%s", agentData.agentBasicInfo.FwInfo.md or "", agentData.agentBasicInfo.FwInfo.hwver or "")
  local agent_sw_ver = string.format("%s_%s", agentData.agentBasicInfo.FwInfo.mver or "", agentData.agentBasicInfo.FwInfo.subver or "")
  local agent_key = agent_model_hw .. agent_sw_ver
  local softwareImageSection = agentSoftwareImages[agent_key] or agentSoftwareImages[agent_model_hw]
  if softwareImageSection and agentSoftwareImagesCache[softwareImageSection] and agentSoftwareImagesCache[softwareImageSection].software_version ~= agent_sw_ver then
    runtime.log:info("Adding agent %s to be upgraded", mac)
    agentsToBeUpgraded[mac] = softwareImageSection
  end
end

-- Forms a list of all valid agents to be upgraded.
-- If mac is passed, it checks if that agent is alone applicable for upgrade.
-- Else it checks for all agents in the database.
local function getAgentsToBeUpgraded(mac, agentSoftwareImages, agentSoftwareImagesCache)
  runtime.log:info("Get agents to be upgraded")
  local agentsToBeUpgraded = {}
  local agentInfoCache = runtime.agent_ipc_handler.getOnboardedAgents()
  runtime.log:info("agentInfoCache is %s", json.encode(agentInfoCache))
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("multiap", "agent", "macaddress")
  if mac and mac ~= internalAgentMac then
    validateAndAddAgentForUpgrade(mac, agentSoftwareImages, agentInfoCache[runtime.agent_ipc_handler.formatMAC(mac)], agentsToBeUpgraded, agentSoftwareImagesCache)
  else
    for agentMAC, agentData in pairs(agentInfoCache) do
      if agentMAC ~= internalAgentMac then
        validateAndAddAgentForUpgrade(agentMAC:gsub(':', ''), agentSoftwareImages, agentData, agentsToBeUpgraded, agentSoftwareImagesCache)
      end
    end
  end
  return agentsToBeUpgraded, agentInfoCache
end

-- If there are any failures while trying to download the firmware image, then the agent is logged as failed and we drop it.
-- Else if successfully downloaded, we take the md5sum output and store it in a internal table for future.
local function downloadImage(agentsToBeUpgraded, agentSoftwareImagesCache)
  runtime.log:info("Downloading firmware images")
  local checksum = {}
  local filesToDelete = {}
  local output_dir = "/tmp/ARC_FW/"
  if lfs.attributes(output_dir, "mode") ~= "directory" then
    lfs.mkdir(output_dir)
  end
  for agent_mac, sw_image_section in pairs(agentsToBeUpgraded) do
    local username = agentSoftwareImagesCache[sw_image_section].username or ""
    local password = agentSoftwareImagesCache[sw_image_section].password or ""
    local creds = username .. ":" .. password
    local file_name = agentSoftwareImagesCache[sw_image_section].url and agentSoftwareImagesCache[sw_image_section].url:match(".*/(%S+)$")
    local file_path = file_name and output_dir .. file_name
    if file_path and not lfs.attributes(file_path) then
      runtime.log:info("Downloading file %s", file_name)
      process.execute("curl", { "--user", creds, "-o",  file_path, agentSoftwareImagesCache[sw_image_section].url})
    end
    if file_path and lfs.attributes(file_path, "mode") == "file" then
      filesToDelete[file_path] = true
      local fd = process.popen("md5sum", {file_path})
      if fd then
        local line = fd:read()
        fd:close()
        runtime.log:info("md5sum output is %s", line or "Error")
        local cksum = line and line:match("^(%S+)")
        if cksum then
          checksum[agent_mac] = cksum
        end
      end
    end
    if not checksum[agent_mac] then
      runtime.log:critical("Upgrade error for AL MAC %s due to failure of image download", agent_mac)
      os.remove(file_path)
      agentsToBeUpgraded[agent_mac] = nil
    end
  end
  return checksum, filesToDelete
end

-- For all the agents which have to be upgraded, we form the IPC message and store it in a table.
-- Then we send a single message for all the agents.
local function sendMessage(agentsToBeUpgraded, agentSoftwareImagesCache, agentInfoCache, checksum)
  local cursor = runtime.uci.cursor()
  local agentSoftwareDeploymentData = {}
  local totalTlvLength = 0
  local gw_ip = cursor:get("network", "lan", "ipaddr") or ""
  local vendor_info = cursor:get_all("vendorextensions", "agent_software_deployment") or {}
  for agent_mac, sw_image_section in pairs(agentsToBeUpgraded) do
    local mver, subver = agentSoftwareImagesCache[sw_image_section].software_version:match("(%S+)_(%S+)")
    if checksum[agent_mac] then
      local formattedMAC = runtime.agent_ipc_handler.formatMAC(agent_mac)
      local key = string.sub(uciHelper.generate_key(), 1, 8)
      local numKey = tonumber(key, 16)
      local id = string.sub(tostring(numKey), 1, 8)
      local deploymentData = {
        url = string.format("%s/fwimg/%s", gw_ip, agentSoftwareImagesCache[sw_image_section].url:match(".*/(%S+)$")),
        user = "",
        pwd = "",
        proto = "2",
        id = id,
        cksum = checksum[agent_mac],
        dwindow = vendor_info.deployment_window or 300,
        write = vendor_info.write or 1,
        woffset = vendor_info.write_offset or 60,
        FwInfo = {
          md = agentInfoCache[formattedMAC].agentBasicInfo.FwInfo.md,
          mver = mver,
          subver = subver,
          hwver = agentInfoCache[formattedMAC].agentBasicInfo.FwInfo.hwver,
        },
      }
      local tlvData = json.encode(deploymentData)
      totalTlvLength = totalTlvLength + #tlvData
      runtime.log:info("Message for %s is %s", formattedMAC, tlvData)
      agentSoftwareDeploymentData[agent_mac] = tlvData
    end
  end
  local uuid = M.generateUuid()
  runtime.client.send_msg("DEPLOYSOFTWARENOW", runtime.OUI_ID, uuid, agentSoftwareDeploymentData, totalTlvLength)
end

local function setUpgradeStatusToInProgress(agentsToBeUpgraded)
  runtime.log:info("Saving upgrade firmware status for applicable agents to in progress in /var/state")
  local cursor = runtime.uci.cursor(nil, "/var/state")
  cursor:delete("vendorextensions", "upgradeFirmwareStatus")
  cursor:delete("vendorextensions", "dwindow")
  cursor:set("vendorextensions", "dwindow", "dwindow")
  cursor:set("vendorextensions", "dwindow", "inprogress", "1")
  local upgradeFirmwareStatus = cursor:get("vendorextensions", "upgradeFirmwareStatus")
  if not upgradeFirmwareStatus then
    cursor:set("vendorextensions", "upgradeFirmwareStatus", "upgradeFirmwareStatus")
  end
  for agent_mac in pairs(agentsToBeUpgraded) do
    cursor:set("vendorextensions", "upgradeFirmwareStatus", agent_mac, "In Progress")
  end
  cursor:save("vendorextensions")
end

-- TODO FIXME: When uloop.fd_add() function is used to listen a socket file descriptor,
-- and message is getting flooded in socket, which inturn keeps the read callback and
-- uloop busy, uloop.timer() function doesn't work sometimes.
local function createTimerForDwindowClose(agentsToBeUpgraded, filesToDelete)
  runtime.log:info("Creating a timer for deployment window close")
  local cursor = runtime.uci.cursor()
  local dwindow = cursor:get("vendorextensions", "agent_software_deployment", "deployment_window") or 420
  runtime.uloop.timer(function()
    runtime.log:info("Deployment window expired")
    local state_cursor = runtime.uci.cursor(nil, "/var/state")
    state_cursor:revert("vendorextensions", "dwindow", "inprogress")
    state_cursor:set("vendorextensions", "dwindow", "inprogress", "0")
    for agent_mac in pairs(agentsToBeUpgraded) do
      local upgradeStatus = state_cursor:get("vendorextensions", "upgradeFirmwareStatus", agent_mac)
      runtime.log:info("Agent %s upgrade status is %s", agent_mac, upgradeStatus or "Failed")
      if not upgradeStatus or upgradeStatus == "In Progress" then
        runtime.log:info("Agents is %s", agent_mac)
        state_cursor:set("vendorextensions", "upgradeFirmwareStatus", agent_mac, "Failed without any response from agent")
      end
    end
    state_cursor:save("vendorextensions")
    runtime.log:info("Deleting firmware images")
    for file in pairs(filesToDelete) do
      os.remove(file)
    end
  end, dwindow * 1000)
end

local function deletePreviousFirmwareImages()
  local output_dir = "/tmp/ARC_FW/"
  if lfs.attributes(output_dir, "mode") == "directory" then
    for file in lfs.dir(output_dir) do
      if file ~= "." and file ~= ".." then
        runtime.log:info("Removing firmware image %s%s", output_dir, file)
        os.remove(output_dir .. file)
      end
    end
  end
end

--- Handler for agent software deployment.
-- Fetches the software images table, detects Error states if any and returns.
-- If no error state, then it identifies the agents to be upgraded.
-- If mac is passed, it checks only for that particular agent. Else it tries for all agents.
-- If there is atleast one agent to be upgraded, then it tries to download the firmware image for required agents.
-- Finally form the IPC data to be sent to controller. Then sends the message to controller.
function M.deploySoftwareActionHandler(_, _, mac)
  runtime.log:info("Deploy software action handler started")
  if not mac then
    -- For safety purpose, do not delete firmware images if the software deployment process is triggered because of Agent onboarding.
    -- Because while an agent is upgrading, in parallel another agent can onboard. At this point, if we delete the firware image, it might cause problem.
    -- So delete software images when triggered through TR-069 or Daily nightly schedule.
    runtime.log:info("Delete previous firmware images if any")
    deletePreviousFirmwareImages()
  end
  local agentSoftwareImages, errMsg, agentSoftwareImagesCache = getAgentSoftwareImages()
  if not agentSoftwareImages then
    runtime.log:critical(errMsg)
    return
  end
  runtime.log:info("Software images successfully fetched")
  local agentsToBeUpgraded, agentInfoCache = getAgentsToBeUpgraded(mac, agentSoftwareImages, agentSoftwareImagesCache)
  if not next(agentsToBeUpgraded) then
    runtime.log:info("No agents to be upgraded")
    return
  end
  runtime.log:info("Agents to be upgraded successfully fetched")
  local checksum, filesToDelete = downloadImage(agentsToBeUpgraded, agentSoftwareImagesCache)
  if not next(checksum) then
    runtime.log:critical("Downloading firmware image failed")
    return
  end
  runtime.log:info("Firmware image download success")
  sendMessage(agentsToBeUpgraded, agentSoftwareImagesCache, agentInfoCache, checksum)
  setUpgradeStatusToInProgress(agentsToBeUpgraded)
  createTimerForDwindowClose(agentsToBeUpgraded, filesToDelete)
  return true
end

local function convertAlMacToMac(almac)
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  for macAddr, macData in pairs(agentData) do
    if macData.interfaceMac == almac then
      return macAddr
    end
  end
  return almac
end

--Handler for WifiDr Onboarding Request message
function M.wifidr_onboarding_request(mac)
  if mac then
    runtime.log:info("Triggered WiFi Dr Onboarding request message for agent: %s", mac)
    local uuid = M.generateUuid()
    local macAddr = mac and string.gsub(mac, ":", "")
    if macAddr then
      runtime.client.send_msg("WIFI_DR_ONBOARDING_REQUEST", macAddr, runtime.OUI_ID, uuid, json.encode({onboarding = "1"}))
    end
  end
  return true
end

local function setOnboardingStatus(status)
  local cursor = runtime.uci.cursor()
  cursor:set("vendorextensions", "multiap_vendorextensions", "onboardingstatus", status)
  cursor:commit("vendorextensions")
end

local inprogressEventTimer
local successErrorTimer
local probableWPSClientStatus
local updateProbableClientStatusTimer
local inprogressTimeout = 130
local successTimeout = 360
local coolOffTimeout = 120

function M.updateProbableClientStatus(probableWPSClient)
  local status = probableWPSClientStatus == "success" and "SUCCESS" or "NEEDED"
  if probableWPSClient and probableWPSClientStatus then
    runtime.log:info("Updating probableWPSClient %s to Wifi Dr onboarding state %s", probableWPSClient, probableWPSClientStatus)
    setOnboardingStatus(status)
    runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
  end
  if not probableWPSClient and probableWPSClientStatus then
    runtime.log:info("Probable client is empty after timeout so considering it as Non easymesh device.")
    if status == "SUCCESS" then
      runtime.log:info("Update status to success for non easy mesh device")
      setOnboardingStatus(status)
    end
    runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
  end
  probableWPSClientStatus = nil
  if updateProbableClientStatusTimer then
    updateProbableClientStatusTimer:cancel()
    updateProbableClientStatusTimer = nil
  end
end

function M.updateProbableClientStatusTimerAlive()
  return updateProbableClientStatusTimer and true
end

function M.successErrorEventHandler(msg, mac, timeout, acsTriggered)
  local acsTimeout = false
  if inprogressEventTimer or not successErrorTimer then
    runtime.log:info("Peer detected event not yet triggered or No timer for success or error, ignoring event")
    -- Should not do anything because inprogress event is still alive.
    return
  end
  if timeout then
    if not mac and acsTriggered then
      runtime.log:info("Wifi Dr Acs request so discarding current success or error timer")
      acsTimeout = true
    else
      runtime.log:error("Wifi Dr Success or Error Timedout")
      -- WPS case
      if mac == "unknown_wps_client" then
        runtime.log:error("WPS client connected and Wifi Dr onboarding failure")
        local probableWPSClient = runtime.eventWatcher.getProbableWPSClient()
        if probableWPSClient then
          runtime.log:error("Easy mesh supported device failed to do Wifi Dr onboarding so setting status to NEEDED")
          setOnboardingStatus("NEEDED")
        end
        runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
        return
      end
      -- Ethernet or ACS case
      if not acsTriggered then
        setOnboardingStatus("NEEDED")
      else
        runtime.agent_ipc_handler.updateWifiDrOnboardingStatus(convertAlMacToMac(mac), "error")
      end
    end
  end
  if msg and msg.event then
    -- WPS case
    local status = msg.event == "success" and "SUCCESS" or "NEEDED"
    if mac == "unknown_wps_client" then
      runtime.log:info("WPS client connected and Wifi Dr onboarding status is %s", msg.event)
      local alMacTimerExpired = runtime.eventWatcher.alMacTimerExpired()
      if alMacTimerExpired then
        local probableWPSClient = runtime.eventWatcher.getProbableWPSClient()
        if probableWPSClient then
          runtime.log:info("WPS Clients probable mac address already found so update onboarding status")
          setOnboardingStatus(status)
        else
          runtime.log:info("WPS Client which is not Easy mesh supported, done Wifi Dr onboarding with %s state", msg.event)
          if status == "SUCCESS" then
            setOnboardingStatus("SUCCESS")
          end
        end
      else
        runtime.log:info("WPS Clients probable mac address not found event after success so wait for easy mesh onboarding event")
        probableWPSClientStatus = msg.event
        updateProbableClientStatusTimer = runtime.uloop.timer(function() M.updateProbableClientStatus(); end, 90 * 1000)
        return
      end
    end
    if not acsTriggered and mac ~= "unknown_wps_client" then
      setOnboardingStatus(status)
    else
      runtime.agent_ipc_handler.updateWifiDrOnboardingStatus(convertAlMacToMac(mac), msg.event)
    end
    runtime.log:info("Wifi Dr Onboarding Event : %s", msg.event)
  end
  if successErrorTimer then
    successErrorTimer:cancel()
    successErrorTimer = nil
    if acsTimeout then
      return
    end
  end
  -- Ethernet or ACS case
  local isAgentPending = runtime.eventWatcher.isAgentPendingForWifiDrOnboarding()
  if acsTriggered and isAgentPending then
    runtime.log:info("Trigger next pending agent for wifi dr onboarding after 120 seconds")
    runtime.uloop.timer(function() runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList(); end, coolOffTimeout * 1000)
  else
    runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
  end
end

function M.inprogressEventHandler(msg, mac, timeout, acsTriggered)
  if not inprogressEventTimer then
    runtime.log:info("Peer detected event without any timer, ignoring it")
    return
  end
  if timeout then
    if not mac and acsTriggered then
      runtime.log:info("Wifi Dr Acs request so discarding current peer detection timer")
    else
      runtime.log:error("Wifi Dr Peer detection timedout")
      -- WPS case
      if mac == "unknown_wps_client" then
        runtime.log:error("WPS client connected and Wifi Dr peer not found")
        local probableWPSClient = runtime.eventWatcher.getProbableWPSClient()
        if probableWPSClient then
          runtime.log:error("Easy mesh supported device failed to detect peer so setting status to NEEDED")
          setOnboardingStatus("NEEDED")
        end
        runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
        return
      end
      -- Ethernet or ACS case
      if not acsTriggered then
        setOnboardingStatus("NEEDED")
      else
        runtime.agent_ipc_handler.updateWifiDrOnboardingStatus(convertAlMacToMac(mac), "error")
      end
      local isAgentPending = runtime.eventWatcher.isAgentPendingForWifiDrOnboarding()
      if acsTriggered and isAgentPending then
        runtime.log:info("Trigger next pending agent for wifi dr onboarding after 120 seconds")
        runtime.uloop.timer(function() runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList(); end, coolOffTimeout * 1000)
      else
        runtime.eventWatcher.updateAndTriggerWifiDrOnboardingList()
      end
      return
    end
  end
  if msg and msg.event then
    runtime.log:info("Wifi Dr Onboarding Event : %s", msg.event)
    successErrorTimer=runtime.uloop.timer(function() M.successErrorEventHandler(_, mac, "timeout", acsTriggered); end, successTimeout * 1000)
  end
  if inprogressEventTimer then
    inprogressEventTimer:cancel()
    inprogressEventTimer = nil
  end
end

--Handler to Manage WiFi Dr Onboarding events
function M.wifiDrOnboardingHandler(macAddr, acsTriggered)
  runtime.log:info("Wifi Dr onboarding Handler for %s", macAddr)
  runtime.ubus:send("button", {wps = "pressed"})
  if acsTriggered then
    if macAddr ~= "unknown_wps_client" then
      M.wifidr_onboarding_request(convertAlMacToMac(macAddr))
    end
  else
    if macAddr ~= "unknown_wps_client" then
      setOnboardingStatus("NEEDED")
    end
  end
  inprogressEventTimer=runtime.uloop.timer(function() M.inprogressEventHandler(_, macAddr, "timeout", acsTriggered); end, inprogressTimeout * 1000)
  return true
end

--Handler for GET LED status request message.
function M.get_led_status(_, msg)
  runtime.log:info(" Triggered GET LED status request message for agent: %s", msg.Mac)
  local uuid = M.generateUuid()
  local mac = msg.Mac and gsub(msg.Mac, ":", "")
  if mac then
    runtime.client.send_msg("GET_LED_STATUS", mac, runtime.OUI_ID, uuid, "")
  end
  return true
end

-- Handler for SET LED status request message
function M.set_led_status(_, msg)
  runtime.log:info(" Triggered SET LED status request message for agent %s with brightness %s", msg.Mac, msg.Brightness)
  local uuid = M.generateUuid()
  local mac = msg.Mac and gsub(msg.Mac, ":", "")
  local brightness = msg and msg.Brightness
  if mac and brightness then
    runtime.agent_ipc_handler.updateLedStatus(mac, brightness)
    runtime.client.send_msg("SET_LED_STATUS", mac, runtime.OUI_ID, uuid, json.encode({data = {{idx = "0", clr = "2", bri = brightness}}}))
  end
  return true
end

local pmfMap = {
  ["enabled"] = "1",
  ["required"] = "1",
  ["disabled"] = "0"
}

local function getWifiConfig(radio)
  local cursor = runtime.uci.cursor()
  local radio_iface, fronthaul_config, backhaul_config = {}, {}, {}
  cursor:foreach("wireless", "wifi-iface", function(s)
    if s.device == radio then
      if s.fronthaul == "1" then
        radio_iface["fronthaul_iface"] = s['.name']
      elseif s.backhaul == "1" then
        radio_iface["backhaul_iface"] = s['.name']
      end
    end
  end)
  cursor:foreach("wireless", "wifi-ap", function(s)
    if s.iface == radio_iface.fronthaul_iface then
      fronthaul_config["wps_state"] = s.wps_state
      fronthaul_config["broadcast"] = s.public
      fronthaul_config["pmf"] = pmfMap[s.pmf] or "0"
    elseif s.iface == radio_iface.backhaul_iface then
      backhaul_config["wps_state"] = s.wps_state
      backhaul_config["broadcast"] = s.public
      backhaul_config["pmf"] = pmfMap[s.pmf] or "0"
    end
  end)
  return fronthaul_config, backhaul_config
end

local channelWidth = {
  ["20MHz"] = "0",
  ["40MHz"] = "1",
  ["20/40MHz"] = "2",
  ["80MHz"] = "3",
  ["20/40/80MHz"] = "4"
}

local function getChannelWidth(radio)
  local cursor = runtime.uci.cursor()
  local width = cursor:get("wireless", radio, "channelwidth") or ""
  if radio == "radio_2G" then
    width = width == "auto" and "20/40MHz" or width
  else
    width = width == "auto" and "20/40/80MHz" or width
  end
  return channelWidth[width]
end

local modeToValueMap = {
  ["b"] = "0",
  ["g"] = "1",
  ["bg"] = "2",
  ["a"] = "3",
  ["n"] = "4",
  ["gn"] = "5",
  ["bgn"] = "6",
  ["an"] = "7",
  ["ac"] = "8",
  ["anac"] = "9",
  ["ad"] = "10",
  ["af"] = "11"
}

local function getMode(radio)
  local cursor = runtime.uci.cursor()
  local  mode = cursor:get("wireless", radio, "standard") or ""
  return modeToValueMap[mode]
end

local radioTypeMap = {
  [1] = "radio_2G",
  [2] = "radio_5G"
}

local function bssidData(bssid, configData, param, value, backhaulState)
  if not next(configData) then
    return nil
  end
  local intf = {}
  local broadcast = configData.broadcast or ""
  if backhaulState and backhaulState == "1" then
    broadcast = "0"
  elseif backhaulState and backhaulState == "0" then
    broadcast = "1"
  end
  for _, bssidMac in pairs(bssid) do
    intf = {
      bssid = gsub(bssidMac, ":", ""),
      broadcast = broadcast,
      wps = configData.wps_state or "",
      pmf = configData.pmf or "0",
    }
  end
  if param and value then
    if param == "pmf" then
      value = pmfMap[value] or "0"
    else
      param = param == "wps_state" and "wps" or "broadcast"
    end
    intf[param] = value
  end
  return next(intf) and intf
end

local function getWifiConfiguration(aleMac, msg, backhaulState)
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  if not agentData[aleMac] or not next(agentData[aleMac]) then
    return
  end
  local agentInfo = agentData[aleMac]
  local wifiConfig = {}
  for index = 1, agentInfo.numberOfRadios or 0 do
    local key = "radio_" .. index
    local radioType = agentInfo[key] and agentInfo[key].radiotype and radioTypeMap[agentInfo[key].radiotype]
    local modifiedRadio = msg and msg.Radio or radioType
    local modifiedAP = msg and msg.AP
    local modifiedParam = msg and msg.Parameter or ""
    local modifiedValue = msg and msg.Value or ""
    if modifiedRadio and radioType and radioType == modifiedRadio then
      local radioConfig = {}
      radioConfig.ruid = agentInfo[key].radioID and gsub(agentInfo[key].radioID, "%:", "") or ""
      radioConfig.bw = getChannelWidth(radioType) or ""
      radioConfig.mode = getMode(radioType) or ""
      radioConfig.intf = {}
      if modifiedParam == "standard" then
        radioConfig.mode = modeToValueMap[modifiedValue]
      elseif modifiedParam == "channelwidth" then
        if modifiedValue == "auto" then
          modifiedValue = radioType == "radio_2G" and "20/40MHz" or "20/40/80MHz"
        end
        radioConfig.bw = channelWidth[modifiedValue]
      end
      local fronthaul_config, backhaul_config = getWifiConfig(radioType)
      local fh_BSSID = agentInfo[key] and agentInfo[key].BSSID["BSSID_Fronthaul"] or {}
      local bh_BSSID = agentInfo[key] and agentInfo[key].BSSID["BSSID_Backhaul"] or {}
      if modifiedAP then
        local cursor = runtime.uci.cursor()
        local apData = cursor:get_all("wireless", modifiedAP) or {}
        local ifaceInfo = cursor:get_all("wireless", apData.iface) or {}
        if ifaceInfo.fronthaul then
          radioConfig.intf[ #radioConfig.intf + 1] = bssidData(fh_BSSID, fronthaul_config, modifiedParam, modifiedValue)
        elseif ifaceInfo.backhaul then
          radioConfig.intf[ #radioConfig.intf + 1] = bssidData(bh_BSSID, backhaul_config, modifiedParam, modifiedValue)
        end
      else
        radioConfig.intf[ #radioConfig.intf + 1] = bssidData(fh_BSSID, fronthaul_config)
        radioConfig.intf[ #radioConfig.intf + 1] = bssidData(bh_BSSID, backhaul_config, nil, nil, backhaulState)
      end
      wifiConfig[ #wifiConfig + 1 ] = radioConfig
    end
  end
  if next(wifiConfig) then
    return json.encode({["config"] = wifiConfig})
  end
end

-- Sends SET WIFI CONFIGURATION message either when agent onboards or when the wifi configuration is changed.
function M.setWifiConfiguration(aleMac, msg)
  local wifiConfig = {}
  local cursor = runtime.uci.cursor()
  local totalTlvLength = 0
  if aleMac then
    local backhaulState = cursor:get("multiap", "agent", "hidden_backhaul") or ""
    local configData = getWifiConfiguration(aleMac, nil, backhaulState)
    if configData then
      totalTlvLength = totalTlvLength + #configData
      wifiConfig[aleMac] = configData
    end
  else
    local onboardedAgentData = runtime.agent_ipc_handler.getOnboardedAgents()
    local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
    for agentMac, agentInfo in pairs(onboardedAgentData) do
      if agentMac ~= internalAgentMac then
        local configData = getWifiConfiguration(agentMac, msg)
        if configData then
          totalTlvLength = totalTlvLength + #configData
          wifiConfig[agentMac] = configData
        end
      end
    end
  end
  if next(wifiConfig) then
    local uuid = M.generateUuid()
    runtime.client.send_msg("SET_WIFI_CONFIG_REQUEST", runtime.OUI_ID, uuid, wifiConfig, totalTlvLength)
  end
  return true
end

-- Handler for SET WIFI CONFIGURATION REQUEST message when wireless configuration is changed via ACS/GUI
function M.sendModifiedWifiConfig(req, msg)
  M.setWifiConfiguration(nil, msg)
  return true
end

function M.init(rt)
  runtime = rt
end

return M
