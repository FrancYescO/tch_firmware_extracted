#!/usr/bin/env lua

---------------------------------
--! @file
--! @brief The implementation of the ubus listener to watch UBUS events and trigger action
---------------------------------

local M = {}
local runtime = {}
local mac
local pendingForWifiDrOnboarding = {}
local acsTriggered = false
local wpsButtonPressed = false
local wpsButtonQueued = false
local wpsButtonPressedTimer
local wpsButtonQueuedTimer
local probableWPSClient

local function getAlMacWirelessTimeout()
  local cursor = runtime.uci.cursor()
  local alMacWirelessTimeout = cursor:get("vendorextensions", "multiap_vendorextensions", "almacwirelesstimeout") or 90
  cursor:close()
  return alMacWirelessTimeout
end

local function addAllAgentsToWifiDrOnboarding()
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
  cursor:close()
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  for macAddr in pairs(agentData) do
    if macAddr ~= internalAgentMac then
      pendingForWifiDrOnboarding[#pendingForWifiDrOnboarding + 1] = macAddr
    end
  end
  if next(pendingForWifiDrOnboarding) then
    mac = pendingForWifiDrOnboarding[1]
  end
end

function M.alMacWirelessHandler()
  wpsButtonPressed = false
  if wpsButtonPressedTimer then
    wpsButtonPressedTimer:cancel()
    wpsButtonPressedTimer = nil
  end
  local updateProbableClientStatus = runtime.action_handler.updateProbableClientStatusTimerAlive()
  if updateProbableClientStatus and probableWPSClient then
    runtime.log:info("Wifi Dr Onboarding already finished, update probable WPS client %s", probableWPSClient)
    runtime.action_handler.updateProbableClientStatus(probableWPSClient)
  end
end

local function eventAction(msg)
  if not msg.al_mac then
    return
  end
  local coolOffTimer = 1
  local macAddr = string.upper(msg.al_mac)
  if msg.al_mac == "ff:ff:ff:ff:ff:ff" then
    runtime.log:info("ACS request for wifi Dr Onboarding")
    acsTriggered = true
    local cursor = runtime.uci.cursor()
    cursor:set("vendorextensions", "multiap_vendorextensions", "onboardingstatus", "IN_PROGRESS")
    cursor:commit("vendorextensions")
    if mac or next(pendingForWifiDrOnboarding) then
      coolOffTimer = 120
      runtime.log:info("Discard existing wifi dr onboarding requests")
      mac = nil
      probableWPSClient = nil
      pendingForWifiDrOnboarding = {}
      runtime.action_handler.inprogressEventHandler(_, _, "timeout", acsTriggered)
      runtime.action_handler.successErrorEventHandler(_, _, "timeout", acsTriggered)
      if wpsButtonPressedTimer then
        wpsButtonPressedTimer:cancel()
        wpsButtonPressedTimer = nil
      end
      wpsButtonPressed = false
      wpsButtonQueued = false
    end
    addAllAgentsToWifiDrOnboarding()
    if mac then
      runtime.uloop.timer(function() runtime.action_handler.wifiDrOnboardingHandler(mac, acsTriggered); end, coolOffTimer * 1000)
    else
      runtime.log:info("No agents connected during ACS onboarding so setting Wifi Dr onboarding status to SUCCESS")
      cursor:set("vendorextensions", "multiap_vendorextensions", "onboardingstatus", "SUCCESS")
      cursor:commit("vendorextensions")
      acsTriggered = false
    end
    cursor:close()
  else
    if mac then
      if mac == "unknown_wps_client" and wpsButtonPressed and not wpsButtonQueued and msg.connection_type == "wireless" then
        probableWPSClient = macAddr
        M.alMacWirelessHandler()
        return
      end
      -- Already request is ongoing. So add to pending list
      if msg.connection_type == "ethernet" or (msg.connection_type == "wireless" and wpsButtonQueued) then
        if msg.connection_type == "wireless" and wpsButtonQueued then
          wpsButtonQueuedTimer:cancel()
          wpsButtonQueuedTimer = nil
          wpsButtonQueued = false
        end
        runtime.log:info("Add new agent %s connected via %s for Wifi Dr Onboarding pending list", macAddr, msg.connection_type)
        pendingForWifiDrOnboarding[#pendingForWifiDrOnboarding + 1] = macAddr
      end
      return
    end
    if msg.connection_type == "wireless" and wpsButtonQueued then
      wpsButtonQueuedTimer:cancel()
      wpsButtonQueuedTimer = nil
      wpsButtonQueued = false
      mac = "unknown_wps_client"
      wpsButtonPressed = true
      local alMacWirelessTimeout = getAlMacWirelessTimeout()
      wpsButtonPressedTimer = runtime.uloop.timer(function() M.alMacWirelessHandler(); end, alMacWirelessTimeout * 1000)
      runtime.log:info("New WPS client for Wifi Dr Onboarding")
      runtime.action_handler.wifiDrOnboardingHandler(mac, acsTriggered)
    end
    if msg.connection_type == "ethernet" then
      mac = macAddr
      runtime.log:info("New agent %s for Wifi Dr Onboarding", mac)
      runtime.action_handler.wifiDrOnboardingHandler(mac, acsTriggered)
    end
  end
end

local function wifiEventAction(msg)
  if mac then
    runtime.log:info("Wifi Dr event %s", msg.event)
    if msg.event == "inprogress_peerdetected" then
      runtime.action_handler.inprogressEventHandler(msg, mac, _, acsTriggered)
    elseif msg.event == "success" or msg.event == "error" then
      runtime.action_handler.successErrorEventHandler(msg, mac, _, acsTriggered)
    end
  else
    runtime.log:error("Wifi Dr event without any new agents")
  end
  return
end

local function updateOverallStatusForWifiDrOnboarding()
  runtime.log:info("Wifi Dr onboarding update overall status")
  local onboardingSuccess = true
  local cursor = runtime.uci.cursor()
  local internalAgentMac = cursor:get("env", "var", "local_wifi_mac")
  local agentData = runtime.agent_ipc_handler.getOnboardedAgents()
  for macAddr, macData in pairs(agentData) do
    if macData.wifiDrOnboardingStatus ~= "success" and macAddr ~= internalAgentMac then
      runtime.log:error("Wifi Dr onboarding failed for one or more agents")
      onboardingSuccess = false
      break
    end
  end
  if onboardingSuccess then
    runtime.log:info("Wifi Dr onboarding success for all agents connected")
    cursor:set("vendorextensions", "multiap_vendorextensions", "onboardingstatus", "SUCCESS")
    cursor:commit("vendorextensions")
  else
    runtime.log:error("Wifi Dr onboarding triggered by ACS failed for one or more agent so updating status as FAILED")
    cursor:set("vendorextensions", "multiap_vendorextensions", "onboardingstatus", "FAILED")
    cursor:commit("vendorextensions")
  end
  acsTriggered = false
  cursor:close()
end

function M.isAgentPendingForWifiDrOnboarding()
  local agents = 0
  for _ in pairs(pendingForWifiDrOnboarding) do
    agents = agents + 1
  end
  if agents > 1 then
    return true
  end
end

function M.getProbableWPSClient()
  return probableWPSClient
end

function M.updateAndTriggerWifiDrOnboardingList()
  runtime.log:info("Update pending agents and trigger next agent if any, else update overall status")
  for key, macAddr in pairs(pendingForWifiDrOnboarding) do
    if mac == macAddr then
      pendingForWifiDrOnboarding[key] = nil
    end
  end
  probableWPSClient = nil
  if not next(pendingForWifiDrOnboarding) then
    mac = nil
    runtime.log:info("No more pending agents to be Wifi Dr onboarded")
    if acsTriggered then
      updateOverallStatusForWifiDrOnboarding()
    end
    return
  end
  for key, macAddr in pairs(pendingForWifiDrOnboarding) do
    mac = macAddr
    runtime.log:info("Next agent to trigger Wifi Dr onboarding is %s", mac)
    break
  end
  runtime.action_handler.wifiDrOnboardingHandler(mac, acsTriggered)
end

local function wirelessWPSEventAction(msg)
  local alMacWirelessTimeout = getAlMacWirelessTimeout()
  if msg.wps_state == "success" then
    if mac or wpsButtonPressed then
      runtime.log:info("Wifi Dr onboarding in progress and received a WPS push button, trigger wifi dr onboarding and also queue it for al_mac event detection")
      wpsButtonQueued = true
      runtime.ubus:send("button", {wps = "pressed"})
      wpsButtonQueuedTimer = runtime.uloop.timer(function() wpsButtonQueued = false; end, alMacWirelessTimeout * 1000)
      return
    end
    mac = "unknown_wps_client"
    wpsButtonPressed = true
    runtime.log:info("WPS button is pressed so initiate Wifi Dr onboarding in GW")
    wpsButtonPressedTimer = runtime.uloop.timer(function() M.alMacWirelessHandler(); end, alMacWirelessTimeout * 1000)
    runtime.action_handler.wifiDrOnboardingHandler(mac, acsTriggered)
  end
end
function M.alMacTimerExpired()
  return not wpsButtonPressedTimer and true
end

--- initializes event watcher part
function M.init(rt)
  runtime = rt
  local events = {}
  runtime.log:info("initialize event watcher")
  events['map.wifidr_agent.added'] = eventAction
  events['wifidoctoragent.onboarding'] = wifiEventAction
  events['wireless.wps_led'] = wirelessWPSEventAction
  runtime.ubus:listen(events)
end

return M

