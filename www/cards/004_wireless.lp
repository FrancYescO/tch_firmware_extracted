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
local variantHelper = post_helper.getVariant(variant_helper, "WirelessCard", "card")
local readOnlyWirelessCard = post_helper.getVariantValue(variantHelper, "readOnlyWirelessCard")
local hideBHSSIDOffState = post_helper.getVariantValue(variantHelper, "hideBHSSIDOffState")
local showLowbandHighband = post_helper.getVariantValue(variantHelper,"showLowbandHighband")
local showMaxIntfsCount = post_helper.getVariantValue(variantHelper,"showMaxIntfsCount")

if not readOnlyWirelessCard or currentuser ~= 'assist' and readOnlyWirelessCard then
  if session:hasAccess("/modals/wireless-modal.lp") then
    modalPath = "/modals/wireless-modal.lp"
  elseif not session:isdefaultuser() then
    return
  end
end

local function checkCurrentUser(currentuser)
  if (currentuser == "user" or currentuser == "support") then
    return true
  else
    return false
  end
end

local backhaulState = {}
if hideBHSSIDOffState then
  local wirelessValues = proxy.get("uci.wireless.wifi-iface.")
  wirelessValues = content_helper.convertResultToObject("uci.wireless.wifi-iface.", wirelessValues)
  for _, intf in ipairs(wirelessValues) do
    if intf.backhaul == "1" then
      backhaulState[#backhaulState + 1] = intf.ssid
    end
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

  local ap_paths = {}
  for i, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
    ap_paths[i] = v.path.."ssid"
  end

  local wl_list = proxy.get(unpack(ap_paths)) or {}
  ssid_list = {}
  for i, v in ipairs(wl_list) do
    local band = ""
    local path = "rpc.wireless.ssid.@" .. v.value
    local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state", path .. ".lan")
    local radioBand = values and getFrequencyBand(values[1].value) or ""
    if values and values[4].value == "1" then
      if (smartWifi == "1" and smartWifiPhase == "2" and role == "admin" and (v.value == "wl0" or v.value == "wl1" )) or ((smartWifi == "") or (smartWifi == "0") or (smartWifi == "1" and smartWifiPhase == "1")) or (smartWifi == "1" and role ~= "admin") then
        if showLowbandHighband then
          if radioBand == "5GHz" then
            local allowedChannel = proxy.get("rpc.wireless.radio.@" .. values[1].value .. ".allowed_channels")[1].value or ""
            for channel in string.gmatch(allowedChannel, "%d+") do
              if tonumber(channel) >= 64 and tonumber(channel) >= 100 then
                band = " HB"
                break
              elseif tonumber(channel) <= 64 then
                band = " LB"
              end
            end
          end
          radioBand = radioBand .. band
        end
        local showSSID = post_helper.getVariantValue(variantHelperWireless, "showSSIDTelusBooster")
        if not showSSID or (showSSID and not match(v.value, "_2$")) then
          ssid_list[#ssid_list+1] = {
            radio = radioBand,
            ssid = values[2].value,
            state = values[3].value,
            iface = v.value
          }
        end
      end
    end
  end
  local sortSSid = post_helper.getVariantValue(variantHelper, "sortSSid")
  if sortSSid then
    table.sort(ssid_list, function(a,b)
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
        local backHaulEnabled = true
        if i <= showMaxIntfsCount  then
          local status_led = v.state == "1" and "light green" or" light off"
          if hideBHSSIDOffState then
            for _, backhaulSsid in ipairs(backhaulState) do
              if v.state == "0" and v.ssid == backhaulSsid then
                backHaulEnabled = false
              end
            end
          end
          local wificard = post_helper.getVariantValue(variantHelper, "wificardValue") and "wificard_"..i or "wireless_ssid_"..v.radio
          if not hideBHSSIDOffState and post_helper.getVariantValue(variantHelperWireless, "hideGuestSSID") then
            if (checkGuestSSID and not match(v.iface, "_1$")) or not checkGuestSSID then   ngx.print('\
              <div id = \'');  ngx.print(wificard); ngx.print('\'>\
                <div class = "');  ngx.print(status_led); ngx.print('"></div>\
                <p class="wifi-card"><strong>');  ngx.print(v.ssid); ngx.print('</strong>(');  ngx.print(v.radio); ngx.print(')</p>\
              </div>\
            ');  end
          else
            if hideBHSSIDOffState and backHaulEnabled or not hideBHSSIDOffState then   ngx.print('\
              <div id = \'');  ngx.print(wificard); ngx.print('\'>\
                <div class = "');  ngx.print(status_led); ngx.print('"></div>\
                <p class="wifi-card"><strong>');  ngx.print(v.ssid); ngx.print('</strong>(');  ngx.print(v.radio); ngx.print(')</p>\
              </div>\
            ');  end
          end  ngx.print('\
        ');  else
          local wificard = post_helper.getVariantValue(variantHelper, "wificardValue") and "wificard_"..i or "wireless_ssid"   ngx.print('\
          <div id= \'');  ngx.print(wificard); ngx.print('\'><p class="wifi-card"><strong style="margin-left:26px;font-size:30px;">...</strong></p></div>\
        ');  end
      end
      if #ssid_list == 2 and guestGhz then   ngx.print('\
        <div  style="font-size:14px" id =\'wificard_3\'><div class = "light orange"></div>\
          <p class="wifi-card"><strong>Fetching 5GHz SSID</strong>(Please wait)</p></div>\
        <div  style="font-size:14px" id =\'wificard_4\'><div class = "light orange"></div>\
          <p class="wifi-card"><strong>Fetching 5GHz SSID</strong>(Please wait)</p></div>\
      ');  end  ngx.print('\
    </div>\
  </div>\
</div>\
\
<script>\
  var varient_check = ');  ngx.print(guestGhz); ngx.print(';\
  var readOnlyWirelessCard = ');  ngx.print(readOnlyWirelessCard); ngx.print(';\
</script>\
<script src="/js/004_wireless.js"></script>\
'); 