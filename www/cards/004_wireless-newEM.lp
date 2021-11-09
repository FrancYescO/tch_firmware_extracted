--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ipairs, ngx, string = ipairs, ngx, string
local format, match, untaint = string.format, string.match, string.untaint
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local modalPath
local session = ngx.ctx.session
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "card")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local guestGhz = post_helper.isFeatureEnabled("logoStyleTI")
local smartWifi = proxy.get("rpc.wireless.SmartWiFi.Active")
smartWifi = smartWifi and untaint(smartWifi[1].value) or ""
local smartWifiPhase = proxy.get("rpc.wireless.SmartWiFi.Phase")
smartWifiPhase = smartWifiPhase and untaint(smartWifiPhase[1].value) or ""
local role = session:getrole()
local currentuser = session:getusername()

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
  interface_list, credential_list = {}, {}
  local apList = "rpc.wireless.ap."
  apList = content_helper.convertResultToObject(apList .. "@.", proxy.get(apList))
  for _, intf in ipairs(availableInterfaces) do
    for _, apVal in ipairs(apList) do
      if intf.value == apVal.ssid then
        interface_list[#interface_list + 1] = intf.value
      end
    end
  end
  for _, cred in ipairs(availableCredentials) do
    credential_list[#credential_list + 1] = cred.value
  end
  return interface_list, credential_list
end

local interface_list, credential_list, guests_interface_list, guests_credential_list = {}, {}, {}, {}
local function loadAvailableInterface()
  local objPath = "uci.web.network."
  local objFound = proxy.getPN(objPath, true)
  local networktype = {}
  if objFound then
    for _, v in ipairs(objFound) do
      if v.path and v.path ~= "" then
        networktype[#networktype + 1] = v.path:match("%@(.*)%.")
      end
    end
  end
  for _, v in pairs(networktype) do
    if untaint(v) == "main" then
      interface_list, credential_list = generateInterfaceList("main")
    end
    if untaint(v) == "guest" then
      guests_interface_list, guests_credential_list = generateInterfaceList("guest")
    end
  end
end

loadAvailableInterface()

local function checkSplitMode(credential_list)
  if (proxy.getPN("uci.multiap.controller_credentials.", true)) then
    local split_ssid = credential_list[2] and proxy.get("uci.multiap.controller_credentials.@"..credential_list[2]..".state")[1].value or "0"
    return split_ssid
  end
end

local splitssid = checkSplitMode(credential_list)

local guestsplitssid
if #guests_credential_list > 1 then
  guestsplitssid = checkSplitMode(guests_credential_list)
end

if not post_helper.getVariantValue(variantHelperWireless, "showsplitToggle") then
  splitssid = "0"
  guestsplitssid = "0"
end

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

if session:hasAccess("/modals/wireless-ap-modal-newEM.lp") then
  modalPath = "/modals/wireless-ap-modal-newEM.lp"
elseif not session:isdefaultuser() then
  return
end

local function checkCurrentUser(currentuser)
  if (currentuser == "user" or currentuser == "support") then
    return true
  else
    return false
  end
end

local radios = {}
for _, v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
  local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
  if radio then
    radios[#radios + 1] = radio
  end
end
function getFrequencyBand(v)
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands", v)
  local radio_value = proxy.get(path)
  local radio = ""
  if radio_value then
    radio = radio_value[1].value
  end
  return radio
end

local ssid_list = {}
local function getSSID()
  ssid_list = content_helper.convertResultToObject("uci.wireless.wifi-iface.", proxy.get("uci.wireless.wifi-iface."))

  ssid_list = {}

  for i, v in ipairs(interface_list) do
    local path = "rpc.wireless.ssid.@" .. v
    local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state", path .. ".lan")
    if values and values[4].value == "1" then
      if (smartWifi == "1" and smartWifiPhase == "2" and role == "admin" and (v == "wl0" or v == "wl1" )) or ((smartWifi == "") or (smartWifi == "0") or (smartWifi == "1" and smartWifiPhase == "1")) or (smartWifi == "1" and role ~= "admin") then
        local showSSID = post_helper.getVariantValue(variantHelperWireless, "showSSIDTelusBooster")
        if not showSSID or (showSSID and not match(v, "_%d$")) and (ssid_list[i] and ssid_list[i].backhaul ~= "1" or true) then
          ssid_list[#ssid_list+1] = {
            radio = getFrequencyBand(values[1].value),
            ssid = values[2].value,
            state = values[3].value,
            iface = v,
            split = splitssid
          }
        end
      end
    end
  end

  if guests_interface_list ~= nil and #guests_interface_list > 0 then
    for i, v in ipairs(guests_interface_list) do
      local path = "rpc.wireless.ssid.@" .. v
      local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state", path .. ".lan")
      if values and values[4].value == "1" then
        if (smartWifi == "1" and smartWifiPhase == "2" and role == "admin" and (v == "wl0" or v == "wl1" )) or ((smartWifi == "") or (smartWifi == "0") or (smartWifi == "1" and smartWifiPhase == "1")) or (smartWifi == "1" and role ~= "admin") then
          local showSSID = post_helper.getVariantValue(variantHelperWireless, "showSSIDTelusBooster")
          if not showSSID or (showSSID and not match(v, "_%d$")) and (ssid_list[i] and ssid_list[i].backhaul ~= "1" or true) then
            ssid_list[#ssid_list+1] = {
            radio = getFrequencyBand(values[1].value),
              ssid = values[2].value,
              state = values[3].value,
              iface = v,
              split = guestsplitssid
            }
          end
        end
      end
    end
  end
  local sortSSid = post_helper.getVariantValue(variantHelper, "sortSSid")
  if sortSSid then
    table.sort(ssid_list, function(a,b)
      if #radios == 3 then
        return a.iface < b.iface
      end
      return a.radio < b.radio
    end)
  end
  return ssid_list
end
  ssid_list = getSSID()
  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print(ui_helper.createCardHeader(T"Wireless", modalPath, nil, nil) ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
      <div class="content">\
    ');  else   ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf140;">\
    ');  end
      local checkGuestSSID = checkCurrentUser(currentuser)
      for i, v in ipairs(ssid_list) do
        local freq = (#radios == 3 and ( v.iface == "wl1" and "5 GHz LOW") or (v.iface == "wl2" and "5 GHz HIGH")) or v.radio
        freq = (freq == "2.4GHz" and ( "2.4 GHz") or (freq == "5GHz" and "5 GHz")) or freq
        freq = v.split and v.split == "0" and "2.4 GHz & 5 GHz" or freq
        if i <= 4  then
          local status_led = v.state == "1" and "light green" or" light off"
          local wificard = post_helper.getVariantValue(variantHelper, "wificardValue") and "wificard_"..i or "wireless_ssid_"..v.radio
          if post_helper.getVariantValue(variantHelperWireless, "hideGuestSSID") then
            if (checkGuestSSID and not match(v.iface, "_1$")) or not checkGuestSSID then   ngx.print('\
              <div id = \'');  ngx.print(wificard); ngx.print('\'>\
                <div class = "');  ngx.print(status_led); ngx.print('"></div>\
                <p class="wifi-card"><strong>');  ngx.print(v.ssid); ngx.print('</strong>(');  ngx.print(freq); ngx.print(')</p>\
              </div>\
            ');  end
          else  ngx.print('\
            <div id = \'');  ngx.print(wificard); ngx.print('\'>\
              <div class = "');  ngx.print(status_led); ngx.print('"></div>\
              <p class="wifi-card"><strong>');  ngx.print(v.ssid); ngx.print('</strong>(');  ngx.print(freq); ngx.print(')</p>\
            </div>\
          ');  end  ngx.print('\
        ');  else
          local wificard = post_helper.getVariantValue(variantHelper, "wificardValue") and "wificard_"..i or "wireless_ssid"   ngx.print('\
          <div id= \'');  ngx.print(wificard); ngx.print('\'><p class="wifi-card"><strong style="margin-left:26px;font-size:30px;">...</strong></p></div>\
        ');  end
      end
      if #ssid_list == 2 and guestGhz then
        if splitssid == "1" then   ngx.print('\
          <div  style="font-size:14px" id =\'wificard_3\'><div class = "light orange"></div>\
            <p class="wifi-card"><strong>Fetching 5 GHz SSID</strong>(Please wait)</p></div>\
        ');  end  ngx.print('\
        ');  if guestsplitssid == "1" then   ngx.print('\
          <div  style="font-size:14px" id =\'wificard_4\'><div class = "light orange"></div>\
            <p class="wifi-card"><strong>Fetching 5 GHz SSID</strong>(Please wait)</p></div>\
        ');  end  ngx.print('\
      ');  end  ngx.print('\
    </div>\
  </div>\
</div>\
\
<script>\
  var varient_check = ');  ngx.print(guestGhz); ngx.print(';\
</script>\
<script src="/js/004_wireless.js"></script>\
'); 