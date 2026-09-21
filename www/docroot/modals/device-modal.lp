--pretranslated: do not change this file
 
--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local string, ngx, os = string, ngx, os
local json = require("dkjson")
local format, match, untaint, gsub = string.format, string.match, string.untaint, string.gsub
local pattern = "^Unknown%-%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local total_count = {
  numWireless = "sys.hosts.ActiveWirelessNumberOfEntries",
  numEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
  numUsb = "sys.usb.DeviceNumberOfEntries"
}
content_helper.getExactContent(total_count)
local host_list = proxy.get("sys.hosts.host.")
local devices_data = content_helper.convertResultToObject("sys.hosts.host.", host_list)
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "DevicesModal", "globalInfo")
local fontColor = post_helper.getVariantValue(variantHelper, "fontColour")
local variantHelperWirelessCard = post_helper.getVariant(variant_helper, "WirelessCard", "card")
local variantHelperDevicesCard = post_helper.getVariant(variant_heleper, "DevicesCard", "card")
local readOnlyWirelessCard = post_helper.getVariantValue(variantHelperWirelessCard, "readOnlyWirelessCard")
local readOnlyDevicesCard = post_helper.getVariantValue(variantHelperDevicesCard, "readOnlyDevicesCard")
local html_escape = require("web.web").html_escape

local wifi_data = {}
local wifi2_data = {}
local wifi5_data = {}
local guest_wifi2_data = {}
local guest_wifi5_data = {}
local ethernet_data = {}
local guestwificount2 = 0
local guestwificount5 = 0
local wificount2 = 0
local wificount5 = 0
local ethcount = 0
local mocacount = 0

local function checkDuplicate(wifiData, total_device)
  local isDuplicate = 0
  for _ , station in pairs(wifiData) do
    if station["MACAddress"] ==  devices_data[total_device]["MACAddress"] then
      isDuplicate = 1
    end
  end
  return isDuplicate == 0
end

for total_device, device_value in pairs (devices_data) do
  if tonumber(devices_data[total_device]["State"]) == 1 then
    if devices_data[total_device]["InterfaceType"] == "wireless" then
      wifi_data[#wifi_data+1] = devices_data[total_device]
      if devices_data[total_device]["Radio"] == "radio_2G" then
        if match(devices_data[total_device]["L3Interface"], "^br.lan$") then
          wificount2 = wificount2 + 1
          wifi2_data[#wifi2_data+1] = devices_data[total_device]
        elseif match(devices_data[total_device]["L3Interface"], "^br.guest$") or devices_data[total_device]["L3Interface"] == "wl0_1" then
          guestwificount2 = guestwificount2 + 1
          guest_wifi2_data[#guest_wifi2_data+1] = devices_data[total_device]
        end
      elseif devices_data[total_device]["Radio"] == "radio_5G" then
        if match(devices_data[total_device]["L3Interface"], "^br.lan$") then
          wificount5 = wificount5 + 1
          wifi5_data[#wifi5_data+1] = devices_data[total_device]
        elseif match(devices_data[total_device]["L3Interface"], "^br.guest$") or devices_data[total_device]["L3Interface"] == "wl1_1" then
          guestwificount5 = guestwificount5 + 1
          guest_wifi5_data[#guest_wifi5_data+1] = devices_data[total_device]
        end
      end
    end

    if match(devices_data[total_device]["L2Interface"], "moca*") then
      mocacount = mocacount + 1
    end

    if  devices_data[total_device]["InterfaceType"] == "ethernet" then
      ethcount = ethcount + 1
      ethernet_data[#ethernet_data+1] = devices_data[total_device]
    end

    if match(devices_data[total_device]["L2Interface"], "ppp*") then
      ethernet_data[#ethernet_data+1] = devices_data[total_device]
    end
  end
end

total_count.numWireless = wificount2 + wificount5 + guestwificount5 + guestwificount2

local usb_list = proxy.get("sys.usb.device.")
local usb_data = content_helper.convertResultToObject("sys.usb.device.", usb_list)

local usb_device = {}
local partitionTable = {}
local icon_names = {"console","laptop","printer","smartphone","playstation","tablet","tv","router"}

local function select_icon()
  local html ={}
  html[#html+1] = '<div class="row" id="icon-list">'
  html[#html+1] = '<div class="icon-wrapper" id="oviewmodal-icon-name" clearfix"="" style="display: flex;width: 70%;position: relative;left: 60px;">'
  for _, icon in ipairs (icon_names) do
    html[#html+1] = format ([[<div class="icon" icon-name = "%s" id ="%s" >
      <div class="black"><img class="device_icons" src="img/device-icons/%s.png" alt="%s"></div>
      <div class="red hide"><img class="device_icons" src="img/device-icons/%s_active.png" alt="%s"></div>
    </div>]],icon,icon,icon,icon,icon,icon)
  end
    html[#html+1] = '</div></div>'
    return html
end
for _, usbValues in ipairs (usb_data) do
  local paramValues = {}
  for param, value in pairs(usbValues) do
    local paramName = match(param, "partition%.%d+%.%S+") or param
    paramValues[paramName] = value
  end
  usb_device[#usb_device + 1] = paramValues
end

if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if  post_data.action == "EDIT" then
    for postData, post_value in pairs (devices_data) do
      if post_data.macAddress == devices_data[postData]["MACAddress"] then
        local success, errmsg = post_helper.validateStringIsDomainName(post_data.edit_values)
        if errmsg then
          ngx.header.content_type = "application/json"
          local buffer = {}
          success = json.encode(errmsg, {indent = false, buffer = buffer})
          if success then
            ngx.print(buffer)
            ngx.exit(ngx.HTTP_OK)
          end
        else
          proxy.set({[format("sys.hosts.host.%s.FriendlyName", devices_data[postData]["paramindex"])] =  post_data.edit_values})
          if post_data.icon then
            proxy.set({[format("sys.hosts.host.%s.DeviceType", devices_data[postData]["paramindex"])] =  post_data.icon})
          end
          proxy.apply()
          break
        end
      end
    end
  end
  if post_data.action == "delete" then
    for postData, post_value in pairs (devices_data) do
      if post_data.macAddress == devices_data[postData]["MACAddress"] then
        local success, errmsg = proxy.del(format("sys.hosts.host.%s.", devices_data[postData]["paramindex"]))
        if success then
          proxy.apply()
        end
        break
      end
    end
  end
end

  ngx.print('\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');  
    local tabs = {
        {
            desc = T"Global Information",
            active = "active",
            target = "modals/device-modal.lp"
        },
        {
            desc =  T"Devices List",
            target = "modals/ipv6devices-modal.lp"
        }
    }
    ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">\
    ');  
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Devices" ); ngx.print('</legend>\
      <div class="container" id="total_device" style="width:auto">\
        <div class="row" id="row_id" >\
          <div class="wifi_details span3" style="margin-left:10%; width:220px; float: left" >\
            <h1 style="position: relative;left: 80px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(total_count.numWireless); ngx.print('</h1>\
            <div class="section_name_wifi">\
              <div class="head_wifi" style="position: relative;left: 25px;">\
                <img src="/img/wifi_all.png" style="float: left;">\
                <h3 style="position: relative;bottom: 9px;left: 10px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(T"WiFi"); ngx.print('</h3>\
              </div>\
              <hr style="position: relative;bottom: 10px;border-top: 2px solid;">\
 ');  local wifi_freqency = {"2" , "5"}
 local duplicate_flag = true
 for  _ ,wifi in ipairs(wifi_freqency) do
  local boolean_toggle = wifi == "2"
  local wifi_array = boolean_toggle and wifi2_data or wifi5_data
  local wifi_interface = boolean_toggle and "radio_2G" or "radio_5G"
  local count =   boolean_toggle and wificount2 or wificount5   ngx.print('\
  <div class= \'');  ngx.print((boolean_toggle and "wifi2.4"or"wifi5")); ngx.print('\' style="position: relative;left: 21px;">\
    <img src="/img/wifi_all.png" style="float: left;">\
    <h4 style="color:');  ngx.print(fontColor); ngx.print(';position: relative;left: 6px;">');  ngx.print((boolean_toggle and T"Wifi-2.4GHz" or T"Wifi-5GHz")); ngx.print('</h4>\
  </div>\
  <hr style="width: 150px;border: 0.5px solid;position: relative;left: 10px;">\
  ');  for wifiData = 1, #wifi_array do
    if wifi_array[wifiData]["FriendlyName"] and wifi_array[wifiData]["FriendlyName"] ~= "" then
      wifi_array[wifiData]["FriendlyName"] = html_escape(wifi_array[wifiData]["FriendlyName"])
    end
    if wifi_array[wifiData]["Radio"] == wifi_interface then
      if wifiData > 3 and duplicate_flag then   ngx.print('\
	 <div id="lang-string" class="foldable-container-title smallArrow">\
           <div style="display: block;" class="fold-title">\
             <p><span class="overview-text-wrap overview-text-normal">');  ngx.print(format("%s (%d %s)", T"Show more",count - 3, T"devices")); ngx.print('</span></p>\
           </div>\
           <div class="unfold-title" style="display: none;">\
             <p><span class="overview-text-wrap overview-text-normal" id = "overview-span-hidedevices">');  ngx.print(T"Hide Devices"); ngx.print('</span></p>\
           </div>\
        </div>\
           <div class="foldable-container-content" style="display: none;">\
        ');  duplicate_flag = false
      end  ngx.print('\
      <div class="wifi_list" style="position: relative;left: 10px;">\
        <div class="wifi_list_name">\
	   ');  if wifi_array[wifiData]["DeviceType"] ~= "" then   ngx.print('\
             <img src="img/device-icons/');  ngx.print(wifi_array[wifiData]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
           ');  end  ngx.print('\
           <span class="wifi_list_align">');  ngx.print(wifi_array[wifiData]["FriendlyName"]); ngx.print('</span>\
           ');  if wifi_array[wifiData]["State"] ~= "0" then  ngx.print('\
	     ');  if wifi_array[wifiData]["DeviceType"] == "" then   ngx.print('\
               <img src="img/arrow-down.png" class = "wifi');  ngx.print(wifi); ngx.print('_arrow_down');  ngx.print(wifiData); ngx.print(' show" onclick="details(');  ngx.print(wifiData); ngx.print(', \'wifi');  ngx.print(wifi); ngx.print('\' , \'show\' , \'hide\')" style="width:12px;position: relative;left:136px;bottom:22px;">\
             ');  else   ngx.print('\
               <img src="img/arrow-down.png" class = "wifi');  ngx.print(wifi); ngx.print('_arrow_down');  ngx.print(wifiData); ngx.print('" onclick="details(');  ngx.print(wifiData); ngx.print(', \'wifi');  ngx.print(wifi); ngx.print('\' , \'show\' , \'hide\')" style="width:12px;position: relative;left:-1px;bottom:7px;">\
             ');  end   ngx.print('\
             <img src="img/arrow-up.png" class = "wifi');  ngx.print(wifi); ngx.print('_arrows');  ngx.print(wifiData); ngx.print(' hide" onclick="details(');  ngx.print(wifiData); ngx.print(',\'wifi');  ngx.print(wifi); ngx.print('\',\'hide\',\'show\')" style="width:12px;position: relative;left:136px;bottom:22px">\
           ');  else   ngx.print('\
              <a href="#" onclick = "deleteDev(\'');  ngx.print(wifi_array[wifiData]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
           ');  end  ngx.print('\
	   <div id="wifi');  ngx.print(wifi); ngx.print('showDropdown');  ngx.print(wifiData); ngx.print('" style="display:none;width: 7%;">\
             <div class="icon_align_wifi" style="width:33px;position: relative;left: 30px;bottom:3px;">\
               ');  if wifi_array[wifiData]["State"] ~= "0" then  ngx.print('\
                 <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(wifiData); ngx.print('\', \'wifi');  ngx.print(wifi); ngx.print('\')">\
                 <img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(wifiData); ngx.print('\', \'wifi');  ngx.print(wifi); ngx.print('\')" style="float: right;position: relative;left: 40px;bottom: 34px;">\
           ');  end  ngx.print('\
          </div>\
          <div id="wifi');  ngx.print(wifi); ngx.print('Arrow');  ngx.print(wifiData); ngx.print('" class="popup smallcard span4" style="left: 85%; margin: 0px; border-radius: 13px;display:none;top:-202%;">\
            <div class="header">\
              <div class="header-title pull-left">\
                <p class="device_poptitle">');  ngx.print(wifi_array[wifiData]["FriendlyName"]); ngx.print('</p>\
              </div>\
            </div>\
	    <div id="device_Poptxt" class="content">\
               <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(wifi_array[wifiData]["DeviceType"]); ngx.print('</span></div>\
               <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(wifi_array[wifiData]["IPAddress"]); ngx.print('</span></div>\
               <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(wifi_array[wifiData]["MACAddress"]); ngx.print('</span></div>\
               ');  if not readOnlyWirelessCard and not readOnlyDevicesCard then  ngx.print('\
               <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"SSID"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(wifi_array[wifiData]["SSID"]); ngx.print('</span></div>\
               ');  end  ngx.print('\
               <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"AP"); ngx.print('</span><span class="hostinforight" id="state">');  ngx.print(untaint(wifi_array[wifiData]["State"]) == "1" and "Online" or "Offline"); ngx.print('</span></div>\
             </div>\
             <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
               <div id="modal-no-change">\
                 <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(wifiData); ngx.print('\', \'wifi');  ngx.print(wifi); ngx.print('\')">');  ngx.print(T"Close"); ngx.print('</div>\
               </div>\
             </div>\
            </div>\
            <div class="popup smallcard span4 edit hidden" id ="modal_edit_info_wifi');  ngx.print(wifi); ngx.print(wifiData); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
              <div class="header">\
                <div class="header-title pull-left">\
                  <p id="edit_wifi');  ngx.print((wifi == '2' and '24' or '5')); ngx.print('">');  ngx.print(wifi_array[wifiData]["FriendlyName"]); ngx.print('</p>\
                </div>\
              </div>\
              <div class="modal-content" style="position: relative;left: 17px;">\
                <div class = "control-group">\
                  <div class="edit_wifi_icon">\
                    <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                      ');  ngx.print(select_icon())  ngx.print('\
                       <br>\
                    <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                    <input id="edit_device_name_wifi');  ngx.print(wifi); ngx.print(wifiData); ngx.print('" value ="');  ngx.print(wifi_array[wifiData]["FriendlyName"]); ngx.print('"></input><br>\
                      <span id="edit_device_name_wifi');  ngx.print(wifi); ngx.print('_errmsg_');  ngx.print(wifiData); ngx.print('" class="alert-error hide"></span>\
                      <span id="edit_device_name_wifi');  ngx.print(wifi); ngx.print('_error1_');  ngx.print(wifiData); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                      <span id="edit_device_name_wifi');  ngx.print(wifi); ngx.print('_error2_');  ngx.print(wifiData); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
                      <span id="edit_device_name_wifi');  ngx.print(wifi); ngx.print('_error3_');  ngx.print(wifiData); ngx.print('" class ="alert-error hide"> Device name should not more then 63 characters</span>\
                    </div>\
                  </div>\
                </div>\
			  <div class="footer modal-no-change" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                <button class="cancel btn" id = "cancel-config-button"  onclick="close_modal()">');  ngx.print(T"Cancel"); ngx.print('</button>\
                <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(wifiData); ngx.print('\', \'');  ngx.print(wifi_array[wifiData]["MACAddress"]); ngx.print('\', \'wifi');  ngx.print(wifi); ngx.print('\')">');  ngx.print(T"Save"); ngx.print('</button>\
              </div>\
            </div>\
          </div>\
        </div>\
        <hr style="width: 150px;border: 0.5px solid;">\
      </div>\
       ');  if  wifiData > 3 and wifiData == #wifi_array then  ngx.print('\
    </div>\
   ');  end
     end
     end   ngx.print('\
 ');  end  ngx.print('\
             ');  if guestwificount2 > 0 or guestwificount5 > 0 then   ngx.print('\
              <div class="head_wifi" style="position: relative;left: 25px;">\
                <img src="/img/wifi_all.png" style="float: left;">\
                <h3 style="position: relative;bottom: 9px;left: 10px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(T"Guest WiFi"); ngx.print('</h3>\
             </div>\
             <hr style="position: relative;bottom: 10px;border-top: 2px solid;">\
             <div class="wifi5" style="position: relative;left: 23px;">\
                <img src="/img/wifi_all.png" style="float: left;">\
                <h4 style="color:');  ngx.print(fontColor); ngx.print(';position: relative;left: 6px;">');  ngx.print(T"Wifi-2.4GHz"); ngx.print('</h4>\
             </div>\
             <hr style="width: 150px;border: 0.5px solid;position: relative;left: 10px;">\
              ');  for wifiData5, wifiValue5 in pairs (guest_wifi2_data) do
                   if guest_wifi2_data[wifiData5]["FriendlyName"] and guest_wifi2_data[wifiData5]["FriendlyName"] ~= "" then
                     guest_wifi2_data[wifiData5]["FriendlyName"] = html_escape(guest_wifi2_data[wifiData5]["FriendlyName"])
                   end
                   if guest_wifi2_data[wifiData5]["L2Interface"] == "wl0_1" or match(guest_wifi2_data[wifiData5]["L3Interface"], "^br.guest$") then
                     if wifiData5 > 2 then
                       break
                     end  ngx.print('\
              <div class="wifi_list" style="position: relative;left: 10px;">\
                <div class="wifi_list_name">\
                  ');  if guest_wifi2_data[wifiData5]["DeviceType"] ~= "" then   ngx.print('\
                    <img src="img/device-icons/');  ngx.print(guest_wifi2_data[wifiData5]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
                  ');  end  ngx.print('\
                  <span class="wifi_list_align">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</span>\
                  ');  if guest_wifi2_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                  <img src="img/arrow-down.png" class = "guest2_arrow_down');  ngx.print(wifiData5); ngx.print(' show" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest2\',\'show\',\'hide\')" style="width:12px;position:relative;left:136px;bottom:22px">\
                  <img src="img/arrow-up.png" class = "guest2_arrows');  ngx.print(wifiData5); ngx.print(' hide" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest2\',\'hide\',\'show\')" style="width:12px;position: relative;left:136px;bottom:22px">\
                  ');  else   ngx.print('\
                    <a href="#" onclick = "deleteDev(\'');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
                  ');  end  ngx.print('\
                  <div id="guest2showDropdown');  ngx.print(wifiData5); ngx.print('" style="display:none;width: 7%;">\
                    <div class="icon_align_wifi" style="width:33px;position: relative;left: 30px;bottom:3px;">\
                      ');  if guest_wifi2_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(wifiData5); ngx.print('\' , \'guest2\')">\
<img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest2\')" style="float: right;position: relative;left: 40px;bottom: 34px;">\
                      ');  end  ngx.print('\
                    </div>\
                    <div id="guest2Arrow');  ngx.print(wifiData5); ngx.print('" class="popup smallcard span4" style="left: 85%; margin: 0px; border-radius: 13px;display:none;top:-202%;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content">\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["DeviceType"]); ngx.print('</span></diV>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["IPv4"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"]); ngx.print('</span></div>\
                        ');  if not readOnlyWirelessCard and not readOnlyDevicesCard then  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"SSID"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(guest_wifi2_data[wifiData5]["SSID"]); ngx.print('</span></div>\
                        ');  end  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"AP"); ngx.print('</span><span class="hostinforight" id="state">');  ngx.print(untaint(guest_wifi2_data[wifiData5]["State"]) == "1" and "Online" or "Offline"); ngx.print('</span></div>\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                          <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest2\')">');  ngx.print(T"Close"); ngx.print('</div>\
                        </div>\
                      </div>\
                    </div>\
<div class="popup smallcard span4 edit hidden" id ="modal_edit_info_guest2');  ngx.print(wifiData5); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
                      <div class="header">\
                       <div class="header-title pull-left">\
                         <p id="edit_wifi5">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                       </div>\
                      </div>\
                      <div class="modal-content" style="position: relative;left: 17px;">\
                        <div class = "control-group">\
                          <div class="edit_wifi_icon">\
                            <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                            ');  ngx.print(select_icon())  ngx.print('\
                            <br>\
                            <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                            <input id="edit_device_name_guest2');  ngx.print(wifiData5); ngx.print('" value="');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('"></input><br>\
                            <span id="edit_device_name_guest_errmsg_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide"></span>\
                            <span id="edit_device_name_guest2_error1_');  ngx.print(wifiData5); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                            <span id="edit_device_name_guest2_error2_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
                            <span id="edit_device_name_guest2_error3_');  ngx.print(wifiData5); ngx.print('" class ="alert-error hide"> Device name should not more then 63 characters</span>\
                          </div>\
                        </div>\
                      </div>\
                      <div class="footer" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                        <button class="cancel btn" id = "cancel-config-button"  onclick="close_modal()">');  ngx.print( T"Cancel"); ngx.print('</button>\
                        <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(wifiData5); ngx.print('\', \'');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"]); ngx.print('\', \'guest2\')">');  ngx.print(T"Save"); ngx.print('</button>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
                <hr style="width: 150px;border: 0.5px solid;">\
              </div>\
              ');  end  ngx.print('\
              ');  end  ngx.print('\
              ');  if guestwificount2 > 2 then  ngx.print('\
              <div id="lang-string" class="foldable-container-title smallArrow">\
                <div style="display: block;" class="fold-title">\
                  <p><span class="overview-text-wrap overview-text-normal">');  ngx.print(format("%s (%d %s)", T"Show more",guestwificount2 - 2, T"devices")); ngx.print('</span></p>\
                </div>\
                <div class="unfold-title" style="display: none;">\
                  <p><span class="overview-text-wrap overview-text-normal" id = "overview-span-hidedevices">');  ngx.print(T"Hide Devices"); ngx.print('</span></p>\
                </div>\
              </div>\
              <div class="foldable-container-content" style="display: none;">\
              ');  for wifiData5 = 3, #guest_wifi2_data do
                if guest_wifi2_data[wifiData5]["L2Interface"] == "wl0_1" or match(guest_wifi2_data[wifiData5]["L3Interface"], "^br.guest$") then   ngx.print('\
                <div class="wifi_list" style="position: relative;left: 10px;">\
                  <div class="wifi_list_name">\
                  ');  if guest_wifi2_data[wifiData5]["DeviceType"] ~= "" then   ngx.print('\
                    <img src="img/device-icons/');  ngx.print(guest_wifi2_data[wifiData5]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
                  ');  end  ngx.print('\
                  <span class="wifi_list_align">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</span>\
                  ');  if guest_wifi2_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                  <img src="img/arrow-down.png" class = "guest2_arrow_down');  ngx.print(wifiData5); ngx.print(' show" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest2\',\'show\',\'hide\')" style="width:12px;position:relative;left:136px;bottom:22px">\
                  <img src="img/arrow-up.png" class = "guest2_arrows');  ngx.print(wifiData5); ngx.print(' hide" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest2\',\'hide\',\'show\')" style="width:12px;position: relative;left:136px;bottom:22px">\
                  ');  else   ngx.print('\
                    <a href="#" onclick = "deleteDev(\'');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
                  ');  end  ngx.print('\
                  <div id="guest2showDropdown');  ngx.print(wifiData5); ngx.print('" style="display:none;width: 7%;">\
                    <div class="icon_align_wifi" style="width:33px;position: relative;left: 30px;bottom:3px;">\
                      ');  if guest_wifi2_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest2\')">\
<img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest2\')" style="float: right;position: relative;left: 40px;bottom: 34px;">\
                      ');  end  ngx.print('\
                    </div>\
                    <div id="guest2Arrow');  ngx.print(wifiData5); ngx.print('" class="popup smallcard span4" style="left: 85%; margin: 0px; border-radius: 13px;display:none;top:-202%;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content">\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["DeviceType"]); ngx.print('</span></diV>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["IPv4"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"]); ngx.print('</span></div>\
                        ');  if not readOnlyWirelessCard and not readOnlyDevicesCard then  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"SSID"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(guest_wifi2_data[wifiData5]["SSID"]); ngx.print('</span></div>\
                        ');  end  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"AP"); ngx.print('</span><span class="hostinforight" id="state">');  ngx.print(untaint(guest_wifi2_data[wifiData5]["State"]) == "1" and "Online" or "Offline"); ngx.print('</span></div>\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                          <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest2\')">');  ngx.print(T"Close"); ngx.print('</div>\
                        </div>\
                      </div>\
                    </div>\
<div class="popup smallcard span4 edit hidden" id ="modal_edit_info_guest2');  ngx.print(wifiData5); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
                      <div class="header">\
                       <div class="header-title pull-left">\
                         <p id="edit_wifi5">');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                       </div>\
                      </div>\
                      <div class="modal-content" style="position: relative;left: 17px;">\
                        <div class = "control-group">\
                          <div class="edit_wifi_icon">\
                            <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                              ');  ngx.print(select_icon())  ngx.print('\
                            <br>\
                            <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                            <input id="edit_device_name_guest2');  ngx.print(wifiData5); ngx.print('" value="');  ngx.print(guest_wifi2_data[wifiData5]["FriendlyName"]); ngx.print('"></input><br>\
                            <span id="edit_device_name_guest2_errmsg_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide"></span>\
                            <span id="edit_device_name_guest2_error1_');  ngx.print(wifiData5); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                            <span id="edit_device_name_guest2_error2_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
                            <span id="edit_device_name_guest2_error3_');  ngx.print(wifiData5); ngx.print('" class ="alert-error hide"> Device name should not more then 63 characters</span>\
                          </div>\
                        </div>\
                      </div>\
                      <div class="footer modal-no-change" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                        <button class="cancel btn" id = "cancel-config-button"  onclick="close_modal()">');  ngx.print(T"Cancel"); ngx.print('</button>\
                        <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(wifiData5); ngx.print('\', \'');  ngx.print(guest_wifi2_data[wifiData5]["MACAddress"]); ngx.print('\', \'guest2\')">');  ngx.print( T"Save"); ngx.print('</button>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
                <hr style="width: 150px;border: 0.5px solid;">\
              </div>\
              ');  end
              end  ngx.print('\
            </div>\
           ');  end
           end  ngx.print('\
           ');  if guestwificount5 > 0 then   ngx.print('\
           <div class="wifi5" style="position: relative;left: 23px;">\
             <img src="/img/wifi_all.png" style="float: left;">\
             <h4 style="color:');  ngx.print(fontColor); ngx.print(';position: relative;left: 6px;">');  ngx.print(T"Wifi-5GHz"); ngx.print('</h4>\
           </div>\
           <hr style="width: 150px;border: 0.5px solid;position: relative;left: 10px;">\
           ');  for wifiData5, wifiValue5 in pairs (guest_wifi5_data) do
             if guest_wifi5_data[wifiData5]["FriendlyName"] and guest_wifi5_data[wifiData5]["FriendlyName"] ~= "" then
               guest_wifi5_data[wifiData5]["FriendlyName"] = html_escape(guest_wifi5_data[wifiData5]["FriendlyName"])
             end
             if match(guest_wifi5_data[wifiData5]["L3Interface"], "^br.guest$") or guest_wifi5_data[wifiData5]["L2Interface"] == "wl1_1" then
                  if wifiData5 > 3 then
                    break
                 end  ngx.print('\
              <div class="wifi_list" style="position: relative;left: 10px;">\
                <div class="wifi_list_name">\
                  ');  if guest_wifi5_data[wifiData5]["DeviceType"] ~= "" then   ngx.print('\
                    <img src="img/device-icons/');  ngx.print(guest_wifi5_data[wifiData5]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
                  ');  end  ngx.print('\
                  <span class="wifi_list_align">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</span>\
                  ');  if guest_wifi5_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                  <img src="img/arrow-down.png" class = "guest5_arrow_down');  ngx.print(wifiData5); ngx.print(' show" onclick="details(');  ngx.print(wifiData5); ngx.print(',\'guest5\',\'show\',\'hide\')" style="width:12px;position:relative;left:136px;bottom:22px">\
                  <img src="img/arrow-up.png" class = "guest5_arrows');  ngx.print(wifiData5); ngx.print(' hide" onclick="details(');  ngx.print(wifiData5); ngx.print(',\'guest5\',\'hide\',\'show\')" style="width:12px;position: relative;left:136px;bottom:22px">\
                  ');  else   ngx.print('\
                    <a href="#" onclick = "deleteDev(\'');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
                  ');  end  ngx.print('\
                  <div id="guest5showDropdown');  ngx.print(wifiData5); ngx.print('" style="display:none;width: 7%;">\
                    <div class="icon_align_wifi" style="width:33px;position: relative;left: 30px;bottom:3px;">\
                      ');  if guest_wifi5_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')">\
                      <img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')" style="float: right;position: relative;left: 40px;bottom: 34px;">\
                      ');  end  ngx.print('\
                    </div>\
                    <div id="guest5Arrow');  ngx.print(wifiData5); ngx.print('" class="popup smallcard span4" style="left: 85%; margin: 0px; border-radius: 13px;display:none;top:-202%;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content">\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["DeviceType"]); ngx.print('</span></diV>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["IPv4"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"]); ngx.print('</span></div>\
                        ');  if not readOnlyWirelessCard and not readOnlyDevicesCard then  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"SSID"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(guest_wifi5_data[wifiData5]["SSID"]); ngx.print('</span></div>\
                        ');  end  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"AP"); ngx.print('</span><span class="hostinforight" id="state">');  ngx.print(untaint(guest_wifi5_data[wifiData5]["State"]) == "1" and "Online" or "Offline"); ngx.print('</span></div>\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                          <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')">');  ngx.print(T"Close"); ngx.print('</div>\
                        </div>\
                      </div>\
                    </div>\
                    <div class="popup smallcard span4 edit hidden" id ="modal_edit_info_guest5');  ngx.print(wifiData5); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
                      <div class="header">\
                       <div class="header-title pull-left">\
                         <p id="edit_wifi5">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                       </div>\
                      </div>\
                      <div class="modal-content" style="position: relative;left: 17px;">\
                        <div class = "control-group">\
                          <div class="edit_wifi_icon">\
                            <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                              ');  ngx.print(select_icon())  ngx.print('\
                            <br>\
                            <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                            <input id="edit_device_name_guest5');  ngx.print(wifiData5); ngx.print('" value="');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('"></input><br>\
                            <span id="edit_device_name_guest5_errmsg_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide"></span>\
                            <span id="edit_device_name_guest5_error1_');  ngx.print(wifiData5); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                            <span id="edit_device_name_guest5_error2_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
                            <span id="edit_device_name_guest5_error3_');  ngx.print(wifiData5); ngx.print('" class ="alert-error hide"> Device name should not more then 63 characters</span>\
                          </div>\
                        </div>\
                      </div>\
                      <div class="footer modal-no-change" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                        <button class="cancel btn" id = "cancel-config-button"  onclick="close_modal()">');  ngx.print(T"Cancel"); ngx.print('</button>\
                        <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(wifiData5); ngx.print('\', \'');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"]); ngx.print('\', \'guest5\')">');  ngx.print(T"Save"); ngx.print('</button>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
                <hr style="width: 150px;border: 0.5px solid;">\
              </div>\
              ');  end  ngx.print('\
              ');  end  ngx.print('\
              ');  if guestwificount5 > 3 then  ngx.print('\
              <div id="lang-string" class="foldable-container-title smallArrow">\
                <div style="display: block;" class="fold-title">\
                   <p><span class="overview-text-wrap overview-text-normal">');  ngx.print(format("%s (%d %s)", T"Show more",guestwificount5 - 3, T"devices")); ngx.print('</span></p>\
                </div>\
               <div class="unfold-title" style="display: none;">\
                 <p><span class="overview-text-wrap overview-text-normal" id = "overview-span-hidedevices">');  ngx.print(T"Hide Devices"); ngx.print('</span></p>\
               </div>\
             </div>\
            <div class="foldable-container-content" style="display: none;">\
            ');  for wifiData5 = 4, #guest_wifi5_data do
              if match(guest_wifi5_data[wifiData5]["L3Interface"], "^br.guest$") or guest_wifi5_data[wifiData5]["L2Interface"] == "wl1_1" then   ngx.print('\
              <div class="wifi_list" style="position: relative;left: 10px;">\
                <div class="wifi_list_name">\
                  ');  if guest_wifi5_data[wifiData5]["DeviceType"] ~= "" then   ngx.print('\
                    <img src="img/device-icons/');  ngx.print(guest_wifi5_data[wifiData5]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
                  ');  end  ngx.print('\
                  <span class="wifi_list_align">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</span>\
                  ');  if guest_wifi5_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                  <img src="img/arrow-down.png" class = "guest5_arrow_down');  ngx.print(wifiData5); ngx.print('" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest5\',\'show\',\'hide\')" style="width:12px;position:relative;">\
                  <img src="img/arrow-up.png" class = "guest5_arrows');  ngx.print(wifiData5); ngx.print(' hide" onclick="details(');  ngx.print(wifiData5); ngx.print(', \'guest5\',\'hide\',\'show\')" style="width:12px;position: relative;left:133px;bottom:25px">\
                  ');  else   ngx.print('\
                    <a href="#" onclick = "deleteDev(\'');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
                  ');  end  ngx.print('\
                  <div id="guest5showDropdown');  ngx.print(wifiData5); ngx.print('" style="display:none;width: 7%;">\
                    <div class="icon_align_wifi" style="width:33px;position: relative;left: 30px;bottom:3px;">\
                      ');  if guest_wifi5_data[wifiData5]["State"] ~= "0" then  ngx.print('\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')">\
<img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')" style="float: right;position: relative;left: 40px;bottom: 34px;">\
                      ');  end  ngx.print('\
                    </div>\
                    <div id="guest5Arrow');  ngx.print(wifiData5); ngx.print('" class="popup smallcard span4" style="left: 85%; margin: 0px; border-radius: 13px;display:none;top:-202%;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content">\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["DeviceType"]); ngx.print('</span></diV>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["IPv4"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"]); ngx.print('</span></div>\
                        ');  if not readOnlyWirelessCard and not readOnlyDevicesCard then  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"SSID"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(guest_wifi5_data[wifiData5]["SSID"]); ngx.print('</span></div>\
                        ');  end  ngx.print('\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"AP"); ngx.print('</span><span class="hostinforight" id="state">');  ngx.print(untaint(guest_wifi5_data[wifiData5]["State"]) == "1" and "Online" or "Offline"); ngx.print('</span></div>\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                          <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(wifiData5); ngx.print('\', \'guest5\')">');  ngx.print(T"Close"); ngx.print('</div>\
                        </div>\
                      </div>\
                    </div>\
<div class="popup smallcard span4 edit hidden" id ="modal_edit_info_guest5');  ngx.print(wifiData5); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
                      <div class="header">\
                       <div class="header-title pull-left">\
                         <p id="edit_wifi5">');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('</p>\
                       </div>\
                      </div>\
                      <div class="modal-content" style="position: relative;left: 17px;">\
                        <div class = "control-group">\
                          <div class="edit_wifi_icon">\
                            <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                               ');  ngx.print(select_icon())  ngx.print('\
                            <br>\
                            <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                            <input id="edit_device_name_guest5');  ngx.print(wifiData5); ngx.print('" value="');  ngx.print(guest_wifi5_data[wifiData5]["FriendlyName"]); ngx.print('"></input><br>\
                            <span id="edit_device_name_guest_5_errmsg_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide"></span>\
                            <span id="edit_device_name_guest5_error1_');  ngx.print(wifiData5); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                            <span id="edit_device_name_guest5_error2_');  ngx.print(wifiData5); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
                            <span id="edit_device_name_guest5_error3_');  ngx.print(wifiData5); ngx.print('" class ="alert-error hide"> Device name should not more then 63 characters</span>\
                          </div>\
                        </div>\
                      </div>\
                      <div class="footer modal-no-change" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                        <button class="cancel btn" id = "cancel-config-button"  onclick="close_modal()">');  ngx.print(T"Cancel"); ngx.print('</button>\
                        <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(wifiData5); ngx.print('\', \'');  ngx.print(guest_wifi5_data[wifiData5]["MACAddress"]); ngx.print('\', \'guest5\')">');  ngx.print(T"Save"); ngx.print('</button>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
                <hr style="width: 150px;border: 0.5px solid;">\
              </div>\
              ');  end  ngx.print('\
              ');  end  ngx.print('\
            </div>\
            ');  end
             end  ngx.print('\
            </div>\
          </div>\
          <div class="network_details span3" style="width:220px; float: left; margin-left:9%">\
            <h1 style="position: relative;left: 85px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(ethcount); ngx.print('</h1>\
            <div class="section_name_eth">\
              <div class="head_network" style="position: relative;left: 20px;">\
                <img src="/img/network.png" style="float:left">\
                <h3 style="position: relative;bottom: 6px;left: 6px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(T"Network"); ngx.print('</h3>\
              </div>\
              <hr style="position: relative;bottom: 10px;border-top: 2px solid;">\
              ');  for ethernetData, ethernetValue in pairs (ethernet_data) do
                   ethernet_data[ethernetData]["FriendlyName"] = html_escape(ethernet_data[ethernetData]["FriendlyName"])   ngx.print('\
              <div class="eth_list" style="position: relative;left: 15px;">\
                <div class="eth_list_name">\
                  ');  if ethernet_data[ethernetData]["DeviceType"] ~= "" then   ngx.print('\
                  <img src="img/device-icons/');  ngx.print(ethernet_data[ethernetData]["DeviceType"]); ngx.print('.png"  style="width: 30px;position: relative;bottom: 7px;">\
                  ');  end  ngx.print('\
                  <span class ="eth_list_align">');  ngx.print(ethernet_data[ethernetData]["FriendlyName"]); ngx.print('</span>\
                  ');  if ethernet_data[ethernetData]["State"] ~= "0" then  ngx.print('\
                    ');  if ethernet_data[ethernetData]["DeviceType"] == "" then  ngx.print('\
                      <img src="img/arrow-down.png" class = "eth_arrow_down');  ngx.print(ethernetData); ngx.print(' show" onclick="details(');  ngx.print(ethernetData); ngx.print(', \'eth\',\'show\',\'hide\')" style="width:12px;position:relative;bottom:22px;left:136px">\
                    ');  else   ngx.print('\
                      <img src="img/arrow-down.png" class = "eth_arrow_down');  ngx.print(ethernetData); ngx.print('" onclick="details(');  ngx.print(ethernetData); ngx.print(', \'eth\',\'show\',\'hide\')" style="width:12px;position:relative;bottom:7px;left:-2px">\
                    ');  end  ngx.print('\
                    <img src="img/arrow-up.png" class = "eth_arrows');  ngx.print(ethernetData); ngx.print(' hide" onclick="details(');  ngx.print(ethernetData); ngx.print(', \'eth\',\'hide\',\'show\')" style="width:12px;position: relative;left:136px;bottom:22px;">\
                  ');  else   ngx.print('\
                    <a href="#" onclick = "deleteDev(\'');  ngx.print(ethernet_data[ethernetData]["MACAddress"] ); ngx.print('\')" class="icon-remove"></a>\
                  ');  end  ngx.print('\
                  <div id="ethshowDropdown');  ngx.print(ethernetData); ngx.print('" style="display:none;width: 10%">\
                    ');  if ethernet_data[ethernetData]["State"] ~= "0" then  ngx.print('\
                    <div class="icon_align_eth" style="width:33px;position: relative;left: 30px;bottom: 3px;">\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(ethernetData); ngx.print('\', \'eth\')">\
                      <img href="#" src="img/button-edit.png" onclick="device_edit_info(\'');  ngx.print(ethernetData); ngx.print('\', \'eth\')" style="float: right;position: relative;left: 100%;bottom: 28px;margin: -5px;">\
                    </div>\
                    ');  end  ngx.print('\
                    <div id="ethArrow');  ngx.print(ethernetData); ngx.print('" class="popup smallcard span4" style="left:1px;margin: 0px; border-radius: 13px;display:none;top:-148px;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(ethernet_data[ethernetData]["FriendlyName"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content">\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"Device Type"); ngx.print('</span><span class="hostinforight">');  ngx.print(ethernet_data[ethernetData]["DeviceType"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"IP Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(ethernet_data[ethernetData]["IPAddress"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"MAC Address"); ngx.print('</span><span class="hostinforight">');  ngx.print(ethernet_data[ethernetData]["MACAddress"]); ngx.print('</span></div>\
                        <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print( T"Port"); ngx.print('</span><span class="hostinforight" id="speed">');  ngx.print(ethernet_data[ethernetData]["Port"]); ngx.print('</span></div>\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                       <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(ethernetData); ngx.print('\', \'eth\')">');  ngx.print(T"Close"); ngx.print('</div>\
                       </div>\
                      </div>\
                    </div>\
                    <div class="popup smallcard span4 edit hidden" id ="modal_edit_info_eth');  ngx.print(ethernetData); ngx.print('" style="border-radius: 13px;position: fixed;left: 32%;">\
                      <div class="header">\
                       <div class="header-title pull-left">\
                         <p id="edit_eth">');  ngx.print(ethernet_data[ethernetData]["FriendlyName"]); ngx.print('</p>\
                       </div>\
                      </div>\
                      <div class="modal-content" style="position:relative; left:17px;">\
                        <div class = "control-group">\
                        <div class="edit_wifi_icon">\
                          <span style="font-weight: bold;">');  ngx.print(T"Select Icon"); ngx.print('</span>\
                            ');  ngx.print(select_icon())  ngx.print('\
                          <br>\
                          <span style="font-weight: bold;">');  ngx.print(T"Name"); ngx.print('</span><br>\
                          <input id="edit_device_name_eth');  ngx.print(ethernetData); ngx.print('" value="');  ngx.print(ethernet_data[ethernetData]["FriendlyName"]); ngx.print('"></input><br>\
                          <span id="edit_device_name_eth_errmsg_');  ngx.print(ethernetData); ngx.print('" class="alert-error hide"></span>\
                          <span id="edit_device_name_eth_error1_');  ngx.print(ethernetData); ngx.print('"class="alert-error hide">Device name should not empty</span>\
                          <span id="edit_device_name_eth_error2_');  ngx.print(ethernetData); ngx.print('" class="alert-error hide">Special characters not allowed</span>\
			  <span id="edit_device_name_eth_error3_');  ngx.print(ethernetData); ngx.print('" class ="alert-error hide"> Device name should not more then 63characters</span>\
                        </div>\
                        </div>\
                      </div>\
                      <div class="footer modal-no-change" style="height: 40px;position: relative;left: 110px;top: 8px;">\
                        <button class="cancel btn" id = "cancel-config-button" onclick="close_modal()">');  ngx.print(T"Cancel"); ngx.print('</button>\
                        <button class="submit btn btn-primary" id = "device_btn_save" onclick="device_Edit(\'');  ngx.print(ethernetData); ngx.print('\', \'');  ngx.print(ethernet_data[ethernetData]["MACAddress"]); ngx.print('\', \'eth\')">');  ngx.print(T"Save"); ngx.print('</button>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
                <hr style="width: 150px;border: 0.5px solid;">\
              </div>\
              ');  end  ngx.print('\
            </div>\
          </div>\
          ');  if mocacount >0 then  ngx.print('\
          <div class="moca_details span3" style="width:220px; float: left; margin-left:9%">\
            <h1 style="position: relative;left: 80px;color:');  ngx.print(fontColor); ngx.print(';">0</h1>\
            <div class="section_name_moca">\
              <div class="head_moca" style="position: relative;left: 15%;">\
                <img src="img/moca.png" style="width: 50px;position: relative;top: 4px;float: left;">\
                <h3  style="position: relative;right:11px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(T"MoCA"); ngx.print('</h3>\
              </div>\
              <hr style="position: relative;bottom: 10px;border: 1.5px solid;">\
            </div>\
          </div>\
          ');  end  ngx.print('\
          <div class="usb_details span3" style="width:220px; float: left; margin-left:9%" >\
            <h1 style="position: relative;left: 80px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print(total_count.numUsb); ngx.print('</h1>\
            <div class="section_name_usb">\
              <div class="head_usb" style="position: relative;left: 34px;">\
                <img src="/img/usb.png" style="float: left;width: 35px;">\
                <h3 style="position: relative;bottom: 0px;left: 0px;color:');  ngx.print(fontColor); ngx.print(';">');  ngx.print( T"USB"); ngx.print('</h3>\
              </div>\
              <hr style="position: relative;bottom: 10px;border-top: 2px solid;">\
              <div class="usb_list row" style="width:30px;position:relative;left:3px;">\
                ');  for usbData, usbValue in pairs (usb_device) do   ngx.print('\
                <div class="usb_list" style="position: relative;left: 40px;">\
                  <img src="img/device-icons/tablet.png">\
                  <span id ="usb_name" style="float: left;position: relative;left: 36px;bottom: 27px;width: 110px;overflow: hidden !important;text-overflow: ellipsis !important;white-space: nowrap !important;">');  ngx.print(usb_device[usbData]["product"]); ngx.print('</span>\
                  <img src="img/arrow-down.png" class = "usb_arrow_down');  ngx.print(usbData); ngx.print(' show" onclick="details(');  ngx.print(usbData); ngx.print(', \'usb\',\'show\',\'hide\')" style="width:12px;position: relative;bottom:40px;left: 156px">\
                  <img src="img/arrow-up.png" class = "usb_arrows');  ngx.print(usbData); ngx.print(' hide" onclick="details(');  ngx.print(usbData); ngx.print(',\'usb\',\'hide\',\'show\')" style="width:12px;position: relative;left:156px;bottom:40px">\
                </div>\
                <div id="usbshowDropdown');  ngx.print(usbData); ngx.print('" style="display:none;width: 7%;">\
                    <div class="icon_align_usb" style="width: 33px;position: relative;left: 95px;bottom: 19px;">\
                      <img href="#" src="img/button-info-desktop.png" onclick="device_info(\'');  ngx.print(usbData); ngx.print('\', \'usb\')">\
                    </div>\
                    <div id="usbArrow');  ngx.print(usbData); ngx.print('" class="popup smallcard span4" style="left: -150px; margin:-200px; border-radius: 13px;display:none;top:-10%;">\
                      <div class="header">\
                        <div class="header-title pull-left">\
                          <p class="device_poptitle">');  ngx.print(usb_device[usbData]["product"]); ngx.print('</p>\
                        </div>\
                      </div>\
                      <div id="device_Poptxt" class="content"  style = "overflow-y:scroll; max-height:200px">\
                      <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(T"Product Name"); ngx.print('</span><span class="hostinforight">');  ngx.print(usb_device[usbData]["product"]); ngx.print('</span></div>\
                      ');  for data, parameters in ipairs(usb_device) do
                        if data == usbData then
                          local partition_index = 1
                            local data_value = tonumber(untaint(parameters.paramindex))
                              local partition_count = tonumber(untaint(parameters.partitionOfEntries))
                                while(partition_index <=partition_count) do
                                  if match(format("sys.usb.device.%s.partition.%s.Share", data_value, partition_index), "partition%.%d+.Share") then
                                    local Share = proxy.get(format("sys.usb.device.%s.partition.%s.Share", data_value, partition_index))[1].value   ngx.print('\
                                    <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(partition_index); ngx.print(T".Manufacturer"); ngx.print('</span><span class="hostinforight">');  ngx.print(Share); ngx.print('</span></div>\
                                  ');  end
                                  if match(format("sys.usb.device.%s.partition.%s.TotalSpace", data_value, partition_index), "partition%.%d+.TotalSpace") then
                                    local TotalSpace = proxy.get(format("sys.usb.device.%s.partition.%s.TotalSpace", data_value, partition_index))[1].value   ngx.print('\
                                    <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(partition_index); ngx.print(T".Total Space"); ngx.print('</span><span class="hostinforight">');  ngx.print(TotalSpace); ngx.print('</span></div>\
                                  ');  end
                                  if match(format("sys.usb.device.%s.partition.%s.UsedSpace", data_value, partition_index),"partition%.%d+.UsedSpace") then
                                    local  UsedSpace = proxy.get(format("sys.usb.device.%s.partition.%s.UsedSpace", data_value, partition_index))[1].value   ngx.print('\
                                    <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(partition_index); ngx.print(T".Used Space"); ngx.print('</span><span class="hostinforight">');  ngx.print(UsedSpace); ngx.print('</span></div>\
                                  ');  end
                                  if match(format("sys.usb.device.%s.partition.%s.AvailableSpace", data_value, partition_index),"partition%.%d+.AvailableSpace")then
                                    local AvailableSpace= proxy.get(format("sys.usb.device.%s.partition.%s.AvailableSpace", data_value, partition_index))[1].value   ngx.print('\
                                    <div class="ctsinfoline"><span class="hostinfoleft">');  ngx.print(partition_index ); ngx.print(T".Free Space"); ngx.print('</span><span class="hostinforight">');  ngx.print(AvailableSpace); ngx.print('</span></div>\
                                  ');  end
                                  partition_index = partition_index+1
                                end
                        end
                      end   ngx.print('\
                      </div>\
                      <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
                        <div id="modal-no-change">\
                          <div id="close-config-button" class="btn btn-primary" onclick="close_modal_info(\'');  ngx.print(usbData); ngx.print('\', \'usb\')">');  ngx.print(T"Close"); ngx.print('</div>\
                        </div>\
                      </div>\
                    </div>\
                  </div>\
                <hr class = "usb_line" style="width: 169px;border: 0.5px solid;position: relative;left: 40px;bottom:15px;">\
               ');  end   ngx.print('\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
var ethernet_data = ');  ngx.print(json.encode(ethernet_data)); ngx.print(';\
var wifi2_data = ');  ngx.print( json.encode(wifi2_data)); ngx.print(';\
var wifi5_data = ');  ngx.print( json.encode(wifi5_data)); ngx.print(';\
var guest_wifi2_data = ');  ngx.print( json.encode(guest_wifi2_data)); ngx.print(';\
var guest_wifi5_data = ');  ngx.print( json.encode(guest_wifi5_data)); ngx.print(';\
</script>\
<script src="/js/device.js"></script>\
'); 