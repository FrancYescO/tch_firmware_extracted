local ipairs, string = ipairs, string
local untaint, format, match = string.untaint, string.format, string.match
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local frequency = {}
local M = {}
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "card")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")

local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = proxy.get(path)[1].value
  frequency[v] = radio
  return radio
end

local function displayOnCard(index)
  return not index or match(index,"[l|w]an") or match(index, "^VLAN%d$")
end

function M.getSSID()
  local availableInterfaces, availableCredentials = {}, {}
  local function loadInterfaceCredList(gettype)
    local interfacesPath = "uci.web.network.@"..gettype..".intf."
    if proxy.getPN("uci.web.network.@"..gettype..".intf.", true) then
      availableInterfaces = content_helper.convertResultToObject(interfacesPath .. "@.", proxy.get(interfacesPath))
    end
    local credentials = "uci.web.network.@"..gettype..".cred."
    if proxy.getPN("uci.web.network.@"..gettype..".cred.", true) then
      availableCredentials = content_helper.convertResultToObject(credentials .. "@.", proxy.get(credentials))
    end
    return availableInterfaces, availableCredentials
  end

  local function generateInterfaceList(gettype)
    availableInterfaces, availableCredentials = loadInterfaceCredList(gettype)
    interface_list, credential_list = {},{}
    for _, intf in ipairs(availableInterfaces) do
      interface_list[#interface_list + 1] = intf.value
    end
    for _, cred in ipairs(availableCredentials) do
      credential_list[#credential_list + 1] = cred.value
    end
    return interface_list, credential_list
  end

  local interface_list, credential_list, guests_interface_list, guests_credential_list = {},{},{},{}
local function loadAvailableInterface()
    local networktype = "uci.web.network."
    networktype = content_helper.convertResultToObject(networktype .. "@.", proxy.get(networktype))
    for i, v in pairs(networktype) do
      if untaint(v.paramindex) == "main" then
        interface_list, credential_list = generateInterfaceList("main")
      end
      if untaint(v.paramindex) == "guest" then
        guests_interface_list, guests_credential_list = generateInterfaceList("guest")
      end
    end
    return interface_list, credential_list, guests_interface_list, guests_credential_list
  end

  loadAvailableInterface()
  --To check whether multiAP is enabled or not
  local multiap_enabled = false
  if post_helper.getVariantValue(variantHelperWireless, "multiAP") then
    local multiap_state = {
      agent = "uci.multiap.agent.enabled",
      controller = "uci.multiap.controller.enabled"
    }
    content_helper.getExactContent(multiap_state)
    multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
  end
  local function checkSplitMode(credential_list)
    if (proxy.getPN("uci.multiap.controller_credentials.", true)) then
      local split_ssid = proxy.get("uci.multiap.controller_credentials.@"..credential_list[2]..".state")[1].value
      return split_ssid
    end
  end
  local splitModeEMDisabled = proxy.get("uci.web.network.@main.splitssid")
  splitModeEMDisabled = splitModeEMDisabled and splitModeEMDisabled[1].value or "1"


  local guestSplitModeEMDisabled = proxy.get("uci.web.network.@guest.splitssid")
  guestSplitModeEMDisabled = guestSplitModeEMDisabled and guestSplitModeEMDisabled[1].value or "1"

  local splitssid = multiap_enabled and checkSplitMode(credential_list) or splitModeEMDisabled
  local guestsplitssid = (multiap_enabled and (#guests_credential_list > 1 )) and checkSplitMode(guests_credential_list) or guestSplitModeEMDisabled
  if splitssid == "0" then
    local interface = interface_list[1]
    interface_list = {}
    interface_list[#interface_list + 1] = interface
  end

  if guestsplitssid == "0" then
    local interface = guests_interface_list[1]
    guests_interface_list = {}
    guests_interface_list[#guests_interface_list + 1] = interface
  end


  local ssid_list = content_helper.convertResultToObject("uci.wireless.wifi-iface.",proxy.get("uci.wireless.wifi-iface."))
  local network_map = {}
  for _,v in ipairs(ssid_list) do
    network_map[format("%s%s",v.paramindex, v.ssid)] = v.network
  end

  ssid_list = {}
  for _, v in ipairs(interface_list) do
    local path = "rpc.wireless.ssid.@" .. v
    local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state")
    if values then
      local index = format("@%s%s", match(path, "rpc.wireless.ssid.@([%w%_]+)."), values[2].value)
      -- In cards it should display only the Main SSID and TG-234 SSID's Fix for NG-43454
      if displayOnCard(network_map[index]) then
        local ap_display_name = proxy.get(path .. ".ap_display_name")[1].value
        local display_ssid
        if ap_display_name ~= "" then
          display_ssid = ap_display_name
        elseif proxy.get(path .. ".stb")[1].value == "1" then
          display_ssid = "IPTV"
        else
          display_ssid = values[2].value
        end
        ssid_list[#ssid_list+1] = {
          radio = getFrequencyBand(values[1].value),
          ssid = display_ssid,
          state = values[3].value,
          split = splitssid,
        }
      end
    end
  end

  if guests_interface_list ~= nil and #guests_interface_list > 0 then
    for _, v in ipairs(guests_interface_list) do
      local path = "rpc.wireless.ssid.@" .. v
      local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state")
      if values then
        local index = format("@%s%s", match(path, "rpc.wireless.ssid.@([%w%_]+)."), values[2].value)
        -- In cards it should display only the Main SSID and TG-234 SSID's Fix for NG-43454
        if displayOnCard(network_map[index]) then
          local ap_display_name = proxy.get(path .. ".ap_display_name")[1].value
          local display_ssid
          if ap_display_name ~= "" then
            display_ssid = ap_display_name
          elseif proxy.get(path .. ".stb")[1].value == "1" then
            display_ssid = "IPTV"
          else
            display_ssid = values[2].value
          end
          ssid_list[#ssid_list+1] = {
            radio = getFrequencyBand(values[1].value),
            ssid = display_ssid,
            state = values[3].value,
            split = guestsplitssid,
          }
        end
      end
    end
  end
  if post_helper.getVariantValue(variantHelper, "sortSSid") then
    table.sort(ssid_list, function(a,b)
      return a.radio < b.radio
    end)
  end
  return ssid_list
end

return M
