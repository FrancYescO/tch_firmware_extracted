--pretranslated: do not change this file
 
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint
local session = ngx.ctx.session

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs = pairs
local match, format, next, lower = string.match, string.format, next, string.lower
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local timhelper = post_helper.getVariantValue(variantHelper, "helperFunction") and require("tim_helper") or ""
local role = session:getrole()

local getargs = ngx.req.get_uri_args()
local gettype = untaint(getargs.type) or "main"
local getValidationIfPropInList = post_helper.getValidationIfPropInList

local validateBoolean = post_helper.validateBoolean
local getOptionalValidation = post_helper.getOptionalValidation
local validatePSK = post_helper.validatePSK
local validateWPSPIN = post_helper.validateWPSPIN
if post_helper.getVariantValue(variantHelper, "helperFunction") then
  validateWPSPIN = timhelper.validateWPSPIN
end

local networktype = "uci.web.network."
local availableInterfaces = {}
if proxy.getPN("uci.web.network.@"..gettype..".intf.", true) then
  availableInterfaces = content_helper.convertResultToObject(networktype .. "@.", proxy.get(networktype))
end
local wls = {}
for _, v in ipairs(availableInterfaces) do
  if v.paramindex ~= "backhaul" then
    wls[#wls+1] = {
      type = v.paramindex,
    }
  end
end

local ap_details = proxy.get("rpc.wireless.ap.")
ap_details = content_helper.convertResultToObject("rpc.wireless.ap.", ap_details)
local device_details = proxy.get("rpc.wireless.radio.")
device_details = content_helper.convertResultToObject("rpc.wireless.radio.", device_details)
local ssid_details = proxy.get("rpc.wireless.ssid.")
ssid_details = content_helper.convertResultToObject("rpc.wireless.ssid.", ssid_details)
local interfacesPath = "uci.web.network.@"..gettype..".intf."
local otherType = "guest"
if gettype == "guest" then
  otherType ="main"
end
local otherInterfacesPath = "uci.web.network.@"..otherType..".intf."
local availableInterfaces = content_helper.convertResultToObject(interfacesPath .. "@.", proxy.get(interfacesPath))
local otherInterfaces = content_helper.convertResultToObject(otherInterfacesPath .. "@.", proxy.get(otherInterfacesPath))
local credentials = "uci.web.network.@"..gettype..".cred."
local availableCredentials, credential_list = {}, {}
if proxy.getPN("uci.web.network.@"..gettype..".cred.", true) then
  availableCredentials = content_helper.convertResultToObject(credentials .. "@.", proxy.get(credentials))
end
local interface_list = {}
local splid_ssid
local otherInterfacesList = {}
for _, v in ipairs(wls) do
  if otherType == v.type and v.type ~= "backhaul" then
    for _,intf in ipairs(otherInterfaces) do
      for _, iface in ipairs(ssid_details) do
        iface.paramindex = iface.paramindex and match(iface.paramindex, "@([^%.]+)") or iface.paramindex
        if intf.value and intf.value == iface.paramindex then
          otherInterfacesList[#otherInterfacesList + 1] = intf.value
          break
        end
      end
    end
  end
end
for _, v in ipairs(wls) do
  if gettype == v.type and v.type ~= "backhaul" then
    for _, intf in ipairs(availableInterfaces) do
      for _, iface in ipairs(ssid_details) do
        iface.paramindex = match(iface.paramindex, "@([^%.]+)") or iface.paramindex
        if intf.value == iface.paramindex then
          interface_list[#interface_list + 1] = intf.value
          break
        end
      end
    end
    for _, cred in ipairs(availableCredentials) do
      credential_list[#credential_list + 1] = cred.value
    end
  end
end

local multiap_enabled = false
if post_helper.getVariantValue(variantHelper, "multiAP") then
  local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled"
  }
  content_helper.getExactContent(multiap_state)
  multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
end

if post_helper.getVariantValue(variantHelper, "showsplitToggle") then
  if multiap_enabled then
    split_ssid = proxy.get(format("uci.multiap.controller_credentials.@%s.state", credential_list[2]))[1].value or "1"
  else
    split_ssid = proxy.get("uci.web.network.@main.splitssid")
    split_ssid = split_ssid and split_ssid[1].value or "1"
  end
else
  split_ssid = "0"
end

local ap_list = {}
local other_type_ap_list = {}
for _, ap in ipairs(ap_details) do
  for _, intf in ipairs(interface_list) do
   if intf == ap.ssid then
     ap_list[#ap_list + 1] = match(ap.paramindex, "@([^%.]+)")
   end
  end
  for _, intf in ipairs(otherInterfacesList) do
    if intf == ap.ssid then
      other_type_ap_list[#other_type_ap_list + 1] = match(ap.paramindex, "@([^%.]+)")
    end
  end
end

local radios = {}
for _, v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
  local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
  radios[#radios + 1] = radio and radio
end
table.sort(radios)

local mergeAP, aplist = {}, {}

local wps_ssid = {}
local wps_freq = {}
local sec_modes, wpa3Check = {}, {}
local wps_radio, radioVal
for _, v in ipairs(ap_details) do
  for _, curap in ipairs(ap_list) do
    v.paramindex = match(v.paramindex, "@([^%.]+)")  or v.paramindex
    if curap  == v.paramindex then
      sec_modes[untaint(v.paramindex)] = (v["security.mode"] == "wep" or v["security.mode"] == "wpa1" or v["security.mode"] == "wpa1/2" or v["security.mode"] == "wpa2" or v["security.mode"] == "none") and true or false
      wpa3Check[untaint(v.paramindex)] = v["security.mode"] == "wpa3" and true or false
      wps_ssid[untaint(v.paramindex)] = proxy.get(format("rpc.wireless.ssid.@%s.ssid", v.ssid))
      wps_radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", v.ssid))
      wps_radio = wps_radio and wps_radio[1].value or ""
      wps_freq[untaint(v.paramindex)] = proxy.get(format("rpc.wireless.radio.@%s.supported_frequency_bands", wps_radio))
      if wps_ssid[untaint(v.paramindex)] then
        wps_ssid[untaint(v.paramindex)] = wps_ssid[untaint(v.paramindex)][1].value
      end
      radioVal = proxy.get(format("rpc.wireless.ssid.@%s.radio", v.ssid))[1].value
      if wps_freq[untaint(v.paramindex)] then
        wps_freq[untaint(v.paramindex)] = wps_freq[untaint(v.paramindex)][1].value == "2.4GHz" and "2.4 GHz" or "5 GHz"
        if radioVal == "radio_5G" and #radios == 3 then
          wps_freq[untaint(v.paramindex)] = "5 GHz Low"
        elseif #radios == 3 and radioVal == "radio2"then
          wps_freq[untaint(v.paramindex)] = "5 GHz High"
        end
      end
    end
  end
end

if split_ssid == "0" then
  wps_freq = {}
  for indexVal, apVal in ipairs(ap_list) do
    if indexVal ~= 1 then
      mergeAP[#mergeAP + 1] = apVal
    end
  end
  ap_intf = ap_list[1] and ap_list[1] or ""
  ap_list = {}
  radiofreq = {}
  ap_list[#ap_list + 1] = ap_intf
  wps_freq[ap_intf] = mergeAP and "2.4 GHz and 5 GHz" or "2.4 GHz"
  curiface = interface_list[1]
  interface_list = {}
  interface_list[#interface_list + 1] = curiface
end

local other_wps_count = 0
for _, v in ipairs(ap_details) do
  local interface_check = interface_list[3] and (v.ssid ~= interface_list[3])
  if v.ssid ~= interface_list[1] and v.ssid ~= interface_list[2] and v["wps.admin_state"] == "1" and (interface_check and v["wps.admin_state"] == "1") then
    other_wps_count = other_wps_count + 1
   end
end

local pathap, pathapWpa3

local wps_button_handler = setmetatable({
  ["1"] = "wps_button_pressed.sh",
  ["0"] = "acl_button_pressed.sh"
}, untaint_mt)

local mapParams, mapValid = {}, {}
for _, curap in ipairs(ap_list) do
  pathap = format("rpc.wireless.ap.@%s.", curap)
  if sec_modes[curap] == true or other_wps_count > 0 then
    proxy.set(format("rpc.wireless.ap.@%s.wps.admin_state", curap), "0")
    proxy.apply()
  end
  pathapWpa3 = format("uci.wireless.wifi-ap-credential.@%s_", curap)
  mapParams["wps_button_handler"..curap] = wpshandler_data and "uci.button.button.@wps.handler"
  if proxy.get(pathapWpa3 .. "credential0.passphrase") then
    mapParams["wpa3"..curap] = pathapWpa3 .. "credential0.passphrase"
  end
  mapParams["wps_enabled"..curap] = pathap .. "wps.admin_state"
  if other_wps_ssid then
    mapParams["wps_button_handler"..curap] = nil
  end
  mapValid["wps_enabled"..curap] = getOptionalValidation(validateBoolean)
  mapValid["wpa3"..curap] = getValidationIfPropInList(validatePSK,"security", {"wpa3", "wpa3-psk", "wpa2-wpa3", "wpa2-wpa3-psk"})
  mapValid["wps_button_handler"..curap] = function(val, object)
    object["wps_button_handler"..curap] = wps_button_handler[object["wps_enabled"..curap]]
    return true
  end
end
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local othertype_wps_adminstate = {}
for key,value in pairs(other_type_ap_list) do
  othertype_wps_adminstate[#othertype_wps_adminstate + 1] = value and proxy.get("rpc.wireless.ap.@"..value..".wps.admin_state")[1].value
end

-- Process POST query
if ngx.req.get_method() == "POST" then
  -- Support for device PIN code
  local args = ngx.req.get_post_args()
  local action = args["action"]
  for _, curap in ipairs(ap_list) do
    content["wps_device_pin_code"..curap] = ""
    local pin = args["wps_device_pin_code"..curap]
    if action == "wps_device_pin_code"..curap and content["wps_enabled"..curap] == "1" then
      local res, help = validateWPSPIN(pin)
      content["wps_device_pin_code"..curap] = pin
      if res then
        proxy.set("rpc.wireless.ap.@" .. curap .. ".wps.enrollee_pin", pin)
        if split_ssid == "0" then
          for _, mergeAPVal in ipairs(mergeAP) do
            proxy.set("rpc.wireless.ap.@" .. mergeAPVal .. ".wps.enrollee_pin", pin)
          end
        end
      else
        helpmsg["wps_device_pin_code"..curap] = help
      end
    end
    -- End of device PIN code support
    -- triggered only on a POST with action set wps_pbc
    if action == "wps_pbc" and content["wps_enabled"..curap] == "1" then
      if post_helper.getVariantValue(variantHelper, "wpsValue") then
        proxy.set("rpc.wireless.ap.@"..curap..".wps.enrollee_pbc", "1")
      else
        proxy.set("rpc.wireless.wps_button", "1")
      end
      if split_ssid == "0" and post_helper.getVariantValue(variantHelper, "wpsValue") then
        for _, mergeAPVal in ipairs(mergeAP) do
          proxy.set("rpc.wireless.ap.@"..mergeAPVal..".wps.enrollee_pbc", "1")
        end
      end
    end

    if not post_helper.getVariantValue(variantHelper, "wpsStateSet") then
      if action ~= "wps_pbc" and split_ssid == "0" then
        for _, mergeAPVal in ipairs(mergeAP) do
          proxy.set("rpc.wireless.ap.@" .. mergeAPVal .. ".wps.admin_state", content["wps_enabled"..curap])
        end
      end
    end

    if post_helper.getVariantValue(variantHelper, "wpsStateSet") then
      if action ~= "wps_pbc" and split_ssid == "0" then
        for _, mergeAPVal in ipairs(mergeAP) do
          proxy.set("rpc.wireless.ap.@" .. mergeAPVal .. ".wps.admin_state", content["wps_enabled"..curap])
        end
      end
    end
    proxy.apply()
  end
end
-- AP PIN code and Mac - read only
-- "rpc.wireless.ssid.@wl0." and "rpc.wireless.ssid.@wl1." returns empty during hostapd reload is in progress,
-- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute max)
-- to break this loop
local content_ssid = {}
for _, curap in ipairs(ap_list) do
  pathap = format("rpc.wireless.ap.@%s.", curap)
  content_ssid = {
    pathap .. "wps.ap_pin",
    pathap .. "wps.ap_setup_locked"
  }
  local step = 2
  for i = 0, 60, step do
    ngx.sleep(step)
    local content_val = proxy.get(unpack(content_ssid))
    if (content_val and #content_val > 0) then
      content["wps_ap_pin_code"..curap] = content_val[1].value
      content["wps_ap_setup_locked"..curap] = content_val[2].value
      break
    end
  end
end

ngx.print(ui_helper.createHeader(T"Wireless", false, false))  ngx.print('\
<div class="modal-body update">\
  ');  local lp = require("web.lp")
  if post_helper.getVariantValue(variantHelper, "navTab") then
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  end  ngx.print('\
  <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
    ');  if #wls > 1 then   ngx.print('\
      <div class="span2">\
        <ul class="nav nav-list">\
          ');  local html = {}
          local prevradio = ""
          local active = ""
          html[#html+1] = format('<li class="nav-header">%s</li>', T"NETWORKS")
          for i, v in ipairs(wls) do
            local active = ""
            if v.type == gettype then
              active = "active"
            end
            local url = "modals/wireless-wps-modal.lp?type=" .. v.type
            v.type = v.type == "main" and "Home" or v.type
            local tabName = v.type
            tabName = tabName:gsub("^%l", string.upper)
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, tabName)
          end
          ngx.print(html)  ngx.print('\
        </ul>\
      </div>\
    <div class="span6">\
    ');  end   ngx.print('\
      ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))   ngx.print('\
      <div id = "wpsWirelessModal">\
      <fieldset>\
        ');  local html = {}
        local wps_warning = {
          alert = {
            class = "alert-warning monitor-default-show"
          }
        }
        if not multiap_enabled and #wls > 1 then
          html[#html + 1] = ui_helper.createAlertBlock(T"WPS can only be enabled on Home or on Guest network but not on both at the same time", wps_warning)
        end
        if multiap_enabled then
          html[#html + 1] = ui_helper.createAlertBlock(T"Enabling or disabling WPS is not possible since EasyMesh is enabled", wps_warning)
        end
        ngx.print(html)   ngx.print('\
      </fieldset>\
      <fieldset>\
        ');  for _, curap in ipairs(ap_list) do
          if wps_ssid[untaint(curap)] then   ngx.print('\
            <legend>');  ngx.print( wps_ssid[untaint(curap)].."("..wps_freq[untaint(curap)]..")" ); ngx.print('</legend>\
            ');  html = {}
            if sec_modes[curap] then
              html[#html + 1] = ui_helper.createAlertBlock(T"WPS is disabled since security mode is set to WEP,WPA1,WPA2,WPA1/2 or None", wps_warning)
            end
            local wpsDetails = "wpsDetails"..curap
            html[#html + 1] = format("<div id = \"%s\">", wpsDetails)
            local wps_class = {
              switch = {
                class = "wpsclass"..curap
              }
            }
            html[#html + 1] = ui_helper.createSwitch(T"WPS", "wps_enabled"..curap, content["wps_enabled"..curap], wps_class)

            local wpsOptions = "wpsOptions"..curap
            html[#html + 1] = format("<div id = \"%s\">", wpsOptions)
            if (tonumber(content["wps_ap_setup_locked"..curap]) == 1) then
              content["wps_ap_pin_code"..curap] = "Disabled"
            end
            if post_helper.getVariantValue(variantHelper, "showWPSPin") then
              if not post_helper.isFeatureEnabled("hideWPSAPPin", role) then
                html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN code", content["wps_ap_pin_code"..curap], wps_class)
              end
              wps_class["input"] = {
                class="no-save",
                ["data-for"] = "wps_device_pin_code"..curap,
              }
              wps_class["button"] = {
                ["data-name"] = "action",
                ["data-value"] = "wps_device_pin_code"..curap,
              }
              html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN code", "wps_device_pin_code"..curap, content["wps_device_pin_code"..curap], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"..curap])
            end
            wps_class["button"] = {
              ["data-name"] = "action",
              ["data-value"] = "wps_pbc",
            }
            html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
          end
          html[#html + 1] = [[</div>]]
          ngx.print(html)
         end   ngx.print('\
         </div>\
         </div>\
           </div>\
     </fieldset>\
   </div>\
 </div>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
  var multiap_enabled = "');  ngx.print(multiap_enabled); ngx.print('";\
  var sec_modes = ');  ngx.print( json.encode(sec_modes) ); ngx.print(';\
  var wpa3Check = ');  ngx.print( json.encode(wpa3Check) ); ngx.print(';\
  var ap_list = ');  ngx.print( json.encode(ap_list) ); ngx.print(';\
  var other_wps_count = "');  ngx.print(other_wps_count); ngx.print('";\
  var wps_adminstate = ');  ngx.print( json.encode(content) ); ngx.print(';\
  var othertype_wps_adminstate = ');  ngx.print( json.encode(othertype_wps_adminstate) ); ngx.print(';\
  var flag = "false";\
  for(var ap in ap_list){\
    apVal = ap_list[ap];\
    if(wps_adminstate["wps_enabled"+apVal] == "0") {\
        $("#wpsOptions"+apVal).hide();\
      }\
    if(sec_modes[apVal] == true || other_wps_count != 0) {\
      $("#wpsOptions"+apVal).hide();\
      $(".wpsclass"+apVal).css({"pointer-events":"none","opacity":"0.5"});\
    }\
    if(wpa3Check[apVal] == true){\
      $("#wpsWirelessModal").css({"pointer-events":"none","opacity":"0.5"});\
    }\
    if(multiap_enabled == "true") {\
      $(".wpsclass"+apVal).css({"pointer-events":"none","opacity":"0.5"});\
    }\
  }\
  othertype_wps_adminstate.forEach(function (wpsAdminState, index) {\
    if ((wpsAdminState  == "1") && (flag == "false")) {\
      flag = true;\
      for(var ap in ap_list){\
        apVal = ap_list[ap];\
        $(".wpsclass" + apVal).css({"pointer-events":"none","opacity":"0.5"});\
      }\
    }\
  });\
</script>\
'); 