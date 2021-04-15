local M = {}

local uci_helper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local binding_wireless = {config = "wireless"}
local binding_multiap = {config = "multiap"}
local conn = ubus.connect()
local strmatch, format = string.match, string.format
local network = require("transformer.shared.common.network")
local envBinding = { config = "env", sectionname = "var" }
local transactions = {}

if lfs.attributes("/etc/config/multiap", "mode") ~= "file" then
  binding_multiap = nil
end

function M.isBaseIface(iface)
  return "0" == strmatch(iface, "%d+")
end

function M.getBsAp(iface)
  local data = conn:call("wireless.accesspoint", "get",  {})
  if data then
    for k, v in pairs(data) do
      if v.ssid == iface then
        return k, v
      end
    end
  end
  return nil
end

local function getAllSSID()
  local data = conn:call("wireless.ssid", "get",  { })
    if data == nil then
      return {}
    end
  local entries = {}
  for k in pairs(data) do
    entries[#entries + 1] = k
  end
  return entries
end

local function getWirelessUciValue(sectionName, option)
  binding_wireless.sectionname = sectionName
  binding_wireless.option = option
  return uci_helper.get_from_uci(binding_wireless)
end

local function setWirelessUciValue(value, sectionName, option, commitapply, transactions)
  binding_wireless.sectionname = sectionName
  binding_wireless.option = option
  uci_helper.set_on_uci(binding_wireless, value, commitapply)
  if transactions then
    transactions[binding_wireless.config] = true
  end
  return true
end

local function setMultiapUciValue(value, sectionName, option, commitapply, transactions)
  binding_multiap.sectiontype = 'controller_credentials'
  binding_multiap.sectionname = sectionName
  binding_multiap.option = option
  uci_helper.set_on_uci(binding_multiap, value, commitapply)
  if transactions then
    transactions[binding_multiap.config] = true
  end
end

--check if iface is main 2G/5G ssid
local function isMainIface(ap, wl)
    local iface = wl or getWirelessUciValue(ap, 'iface')
    return (not strmatch(iface, '_%d+'))
end

-- multiap configuration only applies to main 2G/5G ssid (i.e. wl0/wl1) when multiap is enabled
function M.isMultiapEnabled(ap, wl)
  if binding_multiap then
    binding_multiap.sectiontype = nil
    binding_multiap.sectionname = "agent"
    binding_multiap.option = "enabled"
    if uci_helper.get_from_uci(binding_multiap) == '1' then
      binding_multiap.sectionname = "controller"
      if uci_helper.get_from_uci(binding_multiap) == '1' then
        return isMainIface(ap, wl)
      end
    end
  end
  return false
end

function M.getBandSteerPeerIface(key)
  local ssidData = getAllSSID()
  if ssidData and next(ssidData) then
    local tmpstr = strmatch(key, ".*_(%d+)")
    for _, v in pairs(ssidData) do
      if v ~= key then
          if not tmpstr then
            if not strmatch(v, ".*_(%d+)") then
              return v
            end
          else
            if tmpstr == strmatch(v, ".*_(%d+)") then
              return v
            end
          end
      end
    end
  end

  return nil, "To get band steer switching SSID failed."
end

function M.isBandSteerSectionConfigured(bandsteerID)
  local data = conn:call("wireless.bandsteer", "get", {})
  if not data then
      return false, "Please configure band steer section " .. bandsteerID
  end

  for k in pairs(data) do
      if k == bandsteerID then
          return true
      end
  end

  return false, "Please configure band steer section " .. bandsteerID
end

function M.getBandSteerId(iface)
  local tmpstr = strmatch(iface, ".*_(%d+)")
  local bsID
  if not tmpstr then
      bsID = format("%s", "bs0")
  else
      bsID = format("%s", "bs" .. tmpstr)
  end

  --to judge whether the section configed or not
  local ret, errmsg = M.isBandSteerSectionConfigured(bsID)
  if not ret then
      return nil, errmsg
  end

  return bsID
end

function M.getApBandSteerId(ap)
  return getWirelessUciValue(ap, "bandsteer_id")
end

local function getControllerCredSections()
  local primaryControllerCredSection, secondaryControllerCredSection
  if binding_multiap then
    binding_multiap.sectiontype = nil
    binding_multiap.option = nil
    binding_multiap.sectionname = 'controller_credentials'
    uci_helper.foreach_on_uci(binding_multiap, function(s)
      if s.fronthaul == '1' then
        if strmatch(s.frequency_bands, 'radio_2G') then
          primaryControllerCredSection = s
        elseif s.frequency_bands == 'radio_5Gu,radio_5Gl' or 'radio_5Gl,radio_5Gu' then
          secondaryControllerCredSection = s
        end
      end
    end)
  end
  return primaryControllerCredSection, secondaryControllerCredSection
end

--When Multiap is enabled, bandsteer can't be enabled so return false
function M.isBandSteerEnabledByAp(ap)
  if M.isMultiapEnabled(ap) then
    return false
  else
    local bandsteerid = M.getApBandSteerId(ap)
    if bandsteerid and strmatch(bandsteerid, "bs%d") and getWirelessUciValue(bandsteerid, "state") ~= "0" then
      return true
    end
  end
  return false
end

--For 5G when bandsteer enabled, the ssid and authentication related option cannot be modified
function M.isBandSteerEnabledByIface(iface)
  local ap = M.getBsAp(iface)
  if type(ap) == 'string' then
      return M.isBandSteerEnabledByAp(ap)
  end

  return false
end

function M.canEnableBandSteer(apKey, apData, iface)
  if type(apKey) ~= 'string' or type(iface) ~= 'string' then
    return false, "Ap or Iface is invalid."
  end

  if not apData or not next(apData) or "1" ~= tostring(apData.admin_state) then
    return false, "Please enable network firstly."
  end

  if M.isBandSteerEnabledByAp(apKey) then
    return false, "Band steering has already been enabled."
  end

  if getWirelessUciValue(apKey, "security_mode") == "wep" then
    return false, "Band steering cannot be supported in wep mode."
  end

  local peerIface, errmsg = M.getBandSteerPeerIface(iface)
  if not peerIface then
    return false, errmsg
  end

  local peerAP, peerAPNode = M.getBsAp(peerIface)
  if not peerAP then
    return false, "Band steering switching node does not exist."
  end

  if tostring(peerAPNode.admin_state) ~= "1" then
    return false, "Please enable network for band steering switching node firstly."
  end

  if getWirelessUciValue(peerAP, "security_mode") == "wep" then
    return false, "Band steering cannot be supported in wep mode."
  end

  return true
end

function M.canDisableBandSteer(apKey, iface, isMultiapEnabled)
  if type(apKey) ~= 'string' then
    return false, "Ap is invalid."
  end

  if isMultiapEnabled then
    local primaryControllerCredSection = getControllerCredSections()
    if primaryControllerCredSection and primaryControllerCredSection['frequency_bands'] == 'radio_2G' then
      return false, "Band steering has already been disabled."
    end
  else
    local bandsteerid = M.getApBandSteerId(apKey)
    local bandSteerstate = bandsteerid and strmatch(bandsteerid, "bs%d") and getWirelessUciValue(bandsteerid, "state") or "0"
    if not bandsteerid or "" == bandsteerid or bandSteerstate == "0" then
      return false, "Band steering has already been disabled."
    end
  end

  local peerIface = M.getBandSteerPeerIface(iface)
  if not peerIface then
    return false, "Band steering switching node does not exist."
  end

  local peerAP = M.getBsAp(peerIface)
  if not peerAP then
    return false, "Band steering switching node does not exist."
  end

  return true
end

function M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, oper, commitapply)
  if "1" == oper then
    --to get the baseiface ssid
    local baseifacessid = getWirelessUciValue(baseiface, "ssid")

    if "" ~= baseifacessid then
      setWirelessUciValue(baseifacessid, needsetiface, "ssid", commitapply, transactions)
    end
  else
    envBinding.option = "commonssid_suffix"
    local suffix = uci_helper.get_from_uci(envBinding)
    setWirelessUciValue(getWirelessUciValue(needsetiface, "ssid") .. suffix, needsetiface, "ssid", commitapply, transactions)
  end
end

function M.setBandSteerPeerIfaceSSIDValue(needsetiface, value)
  setWirelessUciValue(value, needsetiface, "ssid")
end

local function setControllerCredOption(value, option, iface, commitapply, transactions)
  local primaryControllerCredSection, secondaryControllerCredSection = getControllerCredSections()
  if M.isBaseIface(iface) then
    if primaryControllerCredSection then
      setMultiapUciValue(value, primaryControllerCredSection['.name'], option, commitapply, transactions)
      if primaryControllerCredSection.frequency_bands ~= 'radio_2G' and secondaryControllerCredSection then
        setMultiapUciValue(value, secondaryControllerCredSection['.name'], option, commitapply, transactions)
      end
      transactions[binding_multiap.config] = true
      return true
    else
      return nil, 'not supported'
    end
  else
    if primaryControllerCredSection and strmatch(primaryControllerCredSection.frequency_bands, 'radio_2G') and secondaryControllerCredSection then
      setMultiapUciValue(value, secondaryControllerCredSection['.name'], option, commitapply, transactions)
      transactions[binding_multiap.config] = true
      return true
    else
      return nil, "Can not modify the value when band steer enabled."
    end
  end
end

function M.setSSID(iface, ap, value, commitapply, transactions)
  if not M.isMultiapEnabled(nil, iface) then
    if ap and M.isBandSteerEnabledByAp(ap) then
      if M.isBaseIface(iface) then --if the band steer enabled, set both 2.4G/5G
        local peerIface, errmsg = M.getBandSteerPeerIface(iface)
        if not peerIface then
          return nil, errmsg
        else
          setWirelessUciValue(value, peerIface, "ssid", commitapply, transactions)
        end
      else
        return nil, "Can not modify the value when band steer enabled."
      end
    end
    setWirelessUciValue(value, iface, "ssid", commitapply, transactions)
  end

  if isMainIface(nil, iface) then
    return setControllerCredOption(value, 'ssid', iface, commitapply, transactions)
  end

  return true
end

local function getBandSteerRelatedNode(apKey, apNode)
  local peerIface, errmsg = M.getBandSteerPeerIface(apNode.ssid)
  if not peerIface then
    return nil, errmsg
  end

  local bspeerap = M.getBsAp(peerIface)
  if not bspeerap then
    return nil, "Band steering switching node does not exist"
  end

  if M.isBaseIface(apNode.ssid) then
    return apKey, bspeerap, apNode.ssid, peerIface
  else
    return bspeerap, apKey, peerIface, apNode.ssid
  end
end

--to set pmf value
local function setPmfValue(baseap, needsetap)
  local value = getWirelessUciValue(baseap, "security_mode")
  if value == "wpa3-psk" then
    setWirelessUciValue("required", needsetap, "pmf", commitapply, transactions)
  elseif value == "wpa2-wpa3-psk" then
    setWirelessUciValue("enabled", needsetap, "pmf", commitapply, transactions)
  else
    setWirelessUciValue("disabled", needsetap, "pmf", commitapply, transactions)
  end
end

--to set the authentication related content
local function setBandSteerPeerApAuthentication(baseap, needsetap)
  local value = getWirelessUciValue(baseap, "security_mode")
  setWirelessUciValue(value, needsetap, "security_mode", commitapply, transactions)
  local wpaKey = getWirelessUciValue(baseap, "wpa_psk_key")
  setWirelessUciValue(wpaKey, needsetap, "wpa_psk_key", commitapply, transactions)
  local passPhrase = getWirelessUciValue(baseap.."_credential0", "passphrase")
  if value == "wpa3-psk" or value == "wpa2-wpa3-psk" then
     setWirelessUciValue(passPhrase, needsetap.."_credential0", "passphrase", commitapply, transactions)
  end
end

--For main ssid, if value is set, should modify the peer ssid also
local function setPeerApSecurityOption(param, value, iface, commitapply, transactions)
  local bspeeriface = M.getBandSteerPeerIface(iface)
  if not bspeeriface then
    return nil, "Can not find band steering switching node."
  else
    local bspeerap = M.getBsAp(bspeeriface)
    if not bspeerap then
      return nil, "Band steering switching node does not exist"
    end
    setWirelessUciValue(value, bspeerap, param, commitapply, transactions)
  end
  return true
end

local function setBandsteerApOption(ap, option, value, commitapply, transactions)
  if option=="security_mode" and value == "wep" then
    return nil, "Can not modify the value when band steer enabled"
  end

  local iface = getWirelessUciValue(ap, 'iface')
  if M.isBaseIface(iface) then
    --To get peer ap, and set related authentication option
    local ret, errmsg = setPeerApSecurityOption(option, value, iface, commitapply, transactions)
    if not ret then
      return nil, errmsg
    end
  else
    return nil, "Can not modify the value when band steer enabled"
  end
  setWirelessUciValue(value, ap, option, commitapply, transactions)
  return true
end

function M.setSecurityOption(ap, option, value, commitapply, transactions)
  if value then
    local success, msg
    if not M.isMultiapEnabled(ap) then
      if M.isBandSteerEnabledByAp(ap) then
        success, msg = setBandsteerApOption(ap, option, value, commitapply, transactions)
        if not success then
            return success, msg
        end
      else
        success = setWirelessUciValue(value, ap, option, commitapply, transactions)
      end
    end

    if isMainIface(ap) then
      local iface = getWirelessUciValue(ap, 'iface')
      success, msg = setControllerCredOption(value, option, iface, commitapply, transactions)
      if not success then
        return success, msg
      end
    end
    if success then
      return true
    end
  else
    return "Unsupported  value"
  end
end

local function setBandSteerID(ap, bspeerap, bsid, commitapply, transactions)
  setWirelessUciValue(bsid, ap, "bandsteer_id", commitapply, transactions)
  setWirelessUciValue(bsid, bspeerap, "bandsteer_id", commitapply, transactions)
end

local function disableBandSteer(key, commitapply)
  local apData = network.getAccessPointInfo(key)
  if not apData or not next(apData) then
    return nil, "The related AP node cannot be found."
  end

  local isMultiapEnabled = M.isMultiapEnabled(key)
  local ret, errmsg = M.canDisableBandSteer(key, apData.ssid, isMultiapEnabled)
  if not ret then
    return nil, errmsg
  end

  local primaryControllerCredSection, secondaryControllerCredSection
  if isMainIface(key) then
    primaryControllerCredSection, secondaryControllerCredSection = getControllerCredSections()
  end

  if primaryControllerCredSection and secondaryControllerCredSection then
    setMultiapUciValue("radio_2G", primaryControllerCredSection['.name'], "frequency_bands", commitapply, transactions)
    setMultiapUciValue("1", secondaryControllerCredSection['.name'], "state", commitapply, transactions)
    envBinding.option = "commonssid_suffix"
    local suffix = uci_helper.get_from_uci(envBinding)
    setMultiapUciValue(primaryControllerCredSection['ssid'] .. suffix, secondaryControllerCredSection['.name'], "ssid", commitapply, transactions)
  end

  if not isMultiapEnabled then
    local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(key, apData)
    local bsid, errorMsg = M.getBandSteerId(apData.ssid)
    if not bsid then
      return nil, errorMsg
    end
    setBandSteerID(baseap, needsetap, bsid, commitapply, transactions)
    setWirelessUciValue("0", bsid, "state", commitapply, transactions)
    --to reset the ssid
    M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, "0", commitapply)
  end
  return true
end

--1\Only the admin_state enabled, then enable bandsteering
--2\2.4G related ap will act as based node
local function enableBandSteer(key, commitapply)
  local apNode = network.getAccessPointInfo(key)
  if not apNode then
    return nil, "AP node is invalid."
  end

  local isMultiapEnabled = M.isMultiapEnabled(key)
  local ret, errmsg = M.canEnableBandSteer(key, apNode, apNode.ssid, isMultiapEnabled)
  if not ret then
    return nil, errmsg
  end

  local primaryControllerCredSection, secondaryControllerCredSection
  if isMainIface(key) then
    primaryControllerCredSection, secondaryControllerCredSection = getControllerCredSections()
  end

  if primaryControllerCredSection and secondaryControllerCredSection then
    setMultiapUciValue("radio_2G,radio_5Gu,radio_5Gl", primaryControllerCredSection['.name'], "frequency_bands", commitapply, transactions)
    setMultiapUciValue("0", secondaryControllerCredSection['.name'], "state", commitapply, transactions)
  end

  if not isMultiapEnabled then
    --to set the bandsteer ids
    local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(key, apNode)
    local bsid, errorMsg = M.getBandSteerId(apNode.ssid)
    if not bsid then
      return nil, errorMsg
    end
    setBandSteerID(baseap, needsetap, bsid)
    setWirelessUciValue("1", bsid, "state", commitapply, transactions)
    M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, "1", commitapply)
    setBandSteerPeerApAuthentication(baseap, needsetap)
    setPmfValue(baseap, needsetap)
  end
  return true
end

function M.setBandSteerValue(value, key, commitapply)
  local bandSteer, errMsg
  if value == "1" then
    bandSteer, errMsg = enableBandSteer(key, commitapply)
  else
    bandSteer, errMsg = disableBandSteer(key, commitapply)
  end
  if not bandSteer then
    return nil, errMsg
  end
  return bandSteer
end

function M.uci_commit()
  for config in pairs(transactions) do
    uci_helper.commit({config = config})
  end
  transactions = {}
end

function M.uci_revert()
  for config in pairs(transactions) do
    uci_helper.revert({ config = config })
  end
  transactions = {}
end

return M
