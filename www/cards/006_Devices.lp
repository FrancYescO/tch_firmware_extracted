--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber

local lfs = require("lfs")
local table = table
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local variant_helper = require("variant_helper")
local format, find, sub, match = string.format, string.find, string.sub, string.match
local host_list = proxy.get("sys.hosts.host.")
local host_data = content_helper.convertResultToObject("sys.hosts.host.", host_list)
local multiap_state = {
  agent = "uci.multiap.agent.enabled",
  controller = "uci.multiap.controller.enabled"
}
content_helper.getExactContent(multiap_state)
multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"

-- Devices data
local devices_data = {
  numWireless = "sys.hosts.ActiveWirelessNumberOfEntries",
  numEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
}
content_helper.getExactContent(devices_data)

local modalPath = nil
local switchName = nil
local modal_link = ""
local session = ngx.ctx.session
local usersValue = session:getusername()
local variantHelper = post_helper.getVariant(variant_helper, "DevicesCard", "card")
local readOnlyDevicesCard = post_helper.getVariantValue(variantHelper, "readOnlyDevicesCard")

if multiap_enabled then
  local wifi_data = 0
  local ethernet_data = 0
  for total_device, device_value in pairs (host_data) do
    if host_data[total_device]["InterfaceType"] == "wireless" and  tonumber(host_data[total_device]["State"]) == 1 then
      wifi_data = wifi_data + 1
    end
    if host_data[total_device]["InterfaceType"] == "ethernet" and tonumber(host_data[total_device]["State"]) == 1 then
      ethernet_data = ethernet_data + 1
    end
  end
  devices_data.numWireless = wifi_data
  devices_data.numEthernet = ethernet_data
end

if not readOnlyDevicesCard or usersValue ~= 'assist' and readOnlyDevicesCard then
  if session:hasAccess("/modals/device-modal.lp") then
    modalPath = "/modals/device-modal.lp"
    modal_link='class="modal-link" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"'
  elseif not session:isdefaultuser() then
    return
  end
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Devices", modalPath, switchName, nil)  ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
      <div class = "content">\
    ');  else   ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf015;">\
    ');  end
        local Hotspot_len = {}
        local ap_path = "rpc.wireless.ap."
        local ap_path_value = content_helper.convertResultToObject(ap_path,proxy.get(ap_path))
        for _,v in ipairs(ap_path_value) do
          if match(v.ssid, "wl%d_%d") then
            local ap = match(v.paramindex, "@([^%.]+)")
            local station_path = "rpc.wireless.ap.@" .. ap .. ".station."
            local station_path_value = content_helper.convertResultToObject(station_path,proxy.get(station_path))
            for _,v in ipairs(station_path_value) do
              if v.state == "Authenticated Associated" then
                Hotspot_len[#Hotspot_len+1] = v.state
              end
            end
          end
        end
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0
        local nHot = #Hotspot_len or 0
        ngx.print(
            '<p class="subinfos">',
            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet device</strong> connected',
                      '<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet devices</strong> connected', nEth),
                      modal_link, nEth),
            '</p>',
            '<p class="subinfos">',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d Wi-Fi device</strong> connected',
                      '<strong id = "Wifi_Devices" %1$s>%2$d Wi-Fi devices</strong> connected', nWiFi),
                      modal_link, nWiFi),
            '</p>'
        )
        if lfs.attributes("/etc/config/hotspot", "mode") == "file" then  ngx.print('\
           <p class="subinfos">\
           ');  
           ngx.print(format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot device</strong> connected',
                               '<strong id = "Ethernet_Devices" %1$s>%2$d Hotspot devices</strong> connected', nHot),
                                modal_link, nHot))
             ngx.print('\
           </p>\
      %>\
        ');  end  ngx.print('\
    </div>\
  </div>\
</div>\
'); 