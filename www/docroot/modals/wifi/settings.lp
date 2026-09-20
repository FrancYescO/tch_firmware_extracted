--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local posix = require("tch.posix")
local postHelper = require("web.post_helper")
local contentHelper = require("web.content_helper")
local isEnumSelect = postHelper.getValidateInEnumSelect
local dfsValidation = postHelper.getAndValidation
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC
local getClockTime = posix.clock_gettime
local string, ngx = string, ngx
local format, gmatch = string.format, string.gmatch
local ipairs = ipairs
local vdf_helper = require("vodafone_helper")
local ui_helper = require("vdf_ui_helper")

local dfsEnable = "36 40 44 48 52 56 60 64 100 104 108 112 116 132 136 140"
local dfsDisable = "36 40 44 48"

if vdf_helper.getVariant() == "VF-UK" then
  dfsEnable =  "36 40 44 48 52 56 60 64 100 104 108 112 132 136 140"
elseif vdf_helper.getVariant() == "NZ" then
  dfsEnable = "36 40 44 48 52 56 60 64 100 104 108 112 116 132 136 140 149 153 157 161"
  dfsDisable = "36 40 44 48 149 153 157 161"
end

local wifiLowModes = {
  {"bgn", T"Mixed 802.11b/g/n"},
  {"bg", T"Mixed 802.11b/g"},
}

local wifiHighModes = {
  {"anac", T"Mixed 802.11n/ac"},
}

local wifiLowBandwidth = {
  {"20", T"20MHz"},
  {"20/40", T"20/40MHz"}
}

local wifiHighBandwidth = {
  {"20", T"20MHz"},
  {"20/40", T"20/40MHz"},
  {"auto", T"20/40/80MHz"},
}

local wifiLowEncryptionType = {
  {"aes", T"AESEncryption"},
  {"tkipaes", T"TKIPandAESEncryption"},
}

local auto_mode_5GHz = {
 {dfsEnable, T"All Channels"},
 {dfsDisable, T"Compatibility"},
}

local highDFSChannelList = {
  [dfsEnable] = "1",
  [dfsDisable] = "0",
}
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
highDFSChannelList = setmetatable(highDFSChannelList,untaint_mt)

local pageGetParams = {
  wifiLowBeacon  = "rpc.wireless.radio.@radio_2G.beacon_period",
  wifiLowDTIM    = "rpc.wireless.radio.@radio_2G.dtim_interval",
  --TODO wifiLowRTS     = "rpc.wireless.radio.@radio_2G.rts_threshold",
  wifiHighBeacon = "rpc.wireless.radio.@radio_5G.beacon_period",
  wifiHighDTIM   = "rpc.wireless.radio.@radio_5G.dtim_interval",
  --TODO wifiHighRTS    = "rpc.wireless.radio.@radio_5G.rts_threshold",
  securityMode24 = "uci.wireless.wifi-ap.@ap0.security_mode",
  allowedChannels24 = "rpc.wireless.radio.@radio_2G.allowed_channels",
  allowedChannels5 = "uci.wireless.wifi-device.@radio_5G.allowed_channels",
}
contentHelper.getExactContent(pageGetParams)

local function isValidChannelSelected(param, object, key)
  if object[key] == "0" or object[key] == "3600" then
    return true
  end
  return nil, T"Invalid input"
end

local function isValidDFS(value, object, key)   --DFS channel
  if value == "1" then
    object["wifiHighDFS"] = dfsEnable
  else
    object["wifiHighDFS"] = dfsDisable
  end
  return true
end

local channels24GHz = {{"auto", T"Auto"}}
for i in gmatch(pageGetParams["allowedChannels24"], "%d+") do
  channels24GHz[#channels24GHz + 1] = {i, i}
end

local channels5GHz = {{"auto", T"Auto"}}
for i in gmatch(pageGetParams["allowedChannels5"], "%d+") do
  channels5GHz[#channels5GHz + 1] = {i, i}
end

local paramMap = {
  wifiLowMode    = "uci.wireless.wifi-device.@radio_2G.standard",
  wifiLowBand    = "uci.wireless.wifi-device.@radio_2G.channelwidth",
  wifiHighBand   = "uci.wireless.wifi-device.@radio_5G.channelwidth",
  wifiHighMode   = "uci.wireless.wifi-device.@radio_5G.standard"
}

local validationMap = {
  wifiLowMode       = isEnumSelect(wifiLowModes),
  wifiHighBand      = isEnumSelect(wifiHighBandwidth),
  wifiLowBand       = isEnumSelect(wifiLowBandwidth)
}
if vdf_helper.getVariant() ~= "VF-UK" then
  paramMap["wifiLowChnSel"]                     =   "uci.wireless.wifi-device.@radio_2G.acs_rescan_period"
  paramMap["wifiHighChnSel"]                    =   "uci.wireless.wifi-device.@radio_5G.acs_rescan_period"
  paramMap["wifiLowEncryption"]                 =   "uci.wireless.wifi-device.@radio_2G.encryptiontype"
  paramMap["wifiHighDFS"]                       =   "uci.wireless.wifi-device.@radio_5G.allowed_channels"
  validationMap["wifiLowChnSel"]                =   isValidChannelSelected
  validationMap["wifiHighMode"]                 =   isEnumSelect(wifiHighModes)
  validationMap["wifiHighChnSel"]               =   isValidChannelSelected
  validationMap["wifiLowEncryption"]            =   isEnumSelect(wifiLowEncryptionType)
  validationMap["wifiHighDFS"]                  =   dfsValidation(postHelper.validateBoolean, isValidDFS)
else
  paramMap["wifiLowChannel"]                    =   "rpc.wireless.radio.@radio_2G.requested_channel"
  paramMap["wifiHighChannel"]                   =   "rpc.wireless.radio.@radio_5G.requested_channel"
  paramMap["wifiHighACSAllowedChannel"]         =   "uci.wireless.wifi-device.@radio_5G.acs_allowed_channels"
  validationMap["wifiHighACSAllowedChannel"]    =   dfsValidation(isEnumSelect(auto_mode_5GHz))
  validationMap["wifiLowChannel"]               =   isEnumSelect(channels24GHz)
  validationMap["wifiHighChannel"]              =   isEnumSelect(channels5GHz)
end

local pageInfo, pageErrmsg = postHelper.handleQuery(paramMap, validationMap)
local resetsettings = {
  reset_wifi_low_mode = "uci.uci-defaults.settings.wifi_low_mode",
  reset_wifi_low_bandwidth = "uci.uci-defaults.settings.wifi_low_bandwidth",
  reset_wifi_low_auto_channel_selection = "uci.uci-defaults.settings.wifi_low_auto_channel_selection",
  reset_wifi_low_channel = "uci.uci-defaults.settings.wifi_low_channel",
  reset_wifi_low_encryption_type = "uci.uci-defaults.settings.wifi_low_encryption_type",
  reset_wifi_high_mode = "uci.uci-defaults.settings.wifi_high_mode",
  reset_wifi_high_bandwidth = "uci.uci-defaults.settings.wifi_high_bandwidth",
  reset_wifi_high_auto_channel_selection = "uci.uci-defaults.settings.wifi_high_auto_channel_selection",
  reset_wifi_high_dfs_channel_selection = "uci.uci-defaults.settings.wifi_high_dfs_channel_selection",
  reset_wifilow_channel  = "uci.uci-defaults.settings.wifilow_channel",
  reset_wifihigh_channel = "uci.uci-defaults.settings.wifihigh_channel"
}
if vdf_helper.getVariant() == "VF-UK" then
  resetsettings["reset_wifihigh_acs_channel"] = "uci.uci-defaults.settings.wifihigh_acschannel"
end

contentHelper.getExactContent(resetsettings)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local setEncryption = {}
  if ngx.req.get_post_args().wifiLowEncryption == "tkipaes" then
    if pageGetParams["securityMode24"] == "wpa2-psk" then
      setEncryption["uci.wireless.wifi-ap.@ap0.security_mode"] = "wpa-wpa2-psk"
    elseif pageGetParams["securityMode24"] == "wpa2" then
      setEncryption["uci.wireless.wifi-ap.@ap0.security_mode"] = "wpa-wpa2"
    end
  elseif  ngx.req.get_post_args().wifiLowEncryption == "aes" then
    if pageGetParams["securityMode24"] == "wpa-wpa2" then
      setEncryption["uci.wireless.wifi-ap.@ap0.security_mode"] = "wpa2"
    elseif pageGetParams["securityMode24"] == "wpa-wpa2-psk" then
      setEncryption["uci.wireless.wifi-ap.@ap0.security_mode"] = "wpa2-psk"
    end
  end
  proxy.set(setEncryption)
  proxy.apply()
  -- "rpc.wireless.radio.@radio_2G." and "rpc.wireless.radio.@radio_5G." returns empty during hostapd restart is in progress,
  -- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute)
  -- to break this loop
  local postRequestTime = getClockTime(CLOCK_MONOTONIC)
  ngx.sleep(3)
  while (getClockTime(CLOCK_MONOTONIC) - postRequestTime) <= 60 do
    local radio2 = proxy.get("rpc.wireless.radio.@radio_2G.")
    local radio5 = proxy.get("rpc.wireless.radio.@radio_5G.")
    if (radio2 and #radio2 > 0 and radio5 and #radio5 > 0) then
      break
    end
    ngx.sleep(2)
  end
  ngx.header.content_type = "application/json"
  if not next(pageErrmsg) then
    ngx.print('{"status":"success"}')
  else
    ngx.print('{"status":"' .. pageErrmsg[next(pageErrmsg)] .. '"}')
  end
  ngx.exit(ngx.HTTP_OK)
end

local encryptType
if pageInfo["wifiLowEncryption"] == "" or pageInfo["wifiLowEncryption"] == "aes" then
  encryptType = "aes"
elseif pageInfo["wifiLowEncryption"] == "tkipaes" then
  encryptType = "tkipaes"
end


local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<script src="js/global-min.js"></script>\
\
<h1>');  ngx.print(T"Settings"); ngx.print('</h1>\
');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
  <h2>');  ngx.print(T"Minimum Sync Speed"); ngx.print('</h2>\
');  else  ngx.print('\
  <h2>');  ngx.print(T"Below you can change parameters for the two Wi-Fi frequencies 2.4 GHz and 5 GHz."); ngx.print('</h2>\
');  end  ngx.print('\
<h3>');  ngx.print(T"2.4 GHz"); ngx.print('</h3>\
<form id="wifiSetForm" method="post" action="modals/wifi/settings.lp">\
  <div class="h3-content wifi-settings wifi-settings-padding-bottom vdf-table led-padding-50">\
      ');  
        local row = {
          label = T"Wi-Fi Mode",
          colRightClass = "rel right no-margin-right padding-left-right-mobile mobile-border-bottom",
          colLeftClass = "left mobile-border-bottom",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-lowmode"
          }, wifiLowModes, pageInfo.wifiLowMode))
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"Bandwidth",
          colRightClass = "rel right no-margin-right padding-left-right-mobile mobile-border-bottom",
          colLeftClass = "left mobile-border-bottom",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-lowband"
          }, wifiLowBandwidth, pageInfo.wifiLowBand))
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
      ');  
        local row = {
          label = T"Encryption Type",
          colRightClass = "rel right no-margin-right padding-left-right-mobile mobile-border-bottom",
          colLeftClass = "left mobile-border-bottom",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-encryption"
          }, wifiLowEncryptionType, encryptType))
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"Beacon Interval (ms)",
          element = ui_helper.createOnlyText({
            id = "wifiset-span-lowbeacon"
          },pageGetParams and pageGetParams["wifiLowBeacon"])
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"DTIM Interval (ms)",
          element = ui_helper.createOnlyText({
            id = "wifiset-span-lowdtim"
          },pageGetParams and pageGetParams["wifiLowDTIM"])
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"Auto Channel Reselection",
          element = ui_helper.createButton({
            id = "wifiset-btn-lowchnsel",
            class = pageInfo and pageInfo['wifiLowChnSel'] == '0' and 'button button-off' or 'button button-on'
          })
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
\
\
    <!-- If vodafone variant is not UK this part will execute -->\
    ');  else  ngx.print('\
      ');  
        local row = {
          label = T"Channel",
          colRightClass = "rel right no-margin-right padding-left-right-mobile",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-lowChannel"
          }, channels24GHz, pageInfo["wifiLowChannel"]))
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
\
    ');  end  ngx.print('\
  </div>\
\
  <h3>');  ngx.print(T"5 GHz"); ngx.print('</h3>\
  <div class="h3-content wifi-settings wifi-settings-padding-bottom vdf-table">\
    <div class="vdf-row">\
      <div class="left mobile-border-bottom">\
        <span>');  ngx.print(T"Wi-Fi Mode"); ngx.print('</span>\
      </div>\
      <div class="rel right no-margin-right padding-left-right-mobile mobile-border-bottom">\
        ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
          <select chosen="" id="wifiset-sel-highmode">\
            ');  for _, mode in ipairs(wifiHighModes) do
              if pageInfo and mode[1] == pageInfo.wifiHighMode then
                ngx.print(format("<option selected='selected' value='%s'>%s</option>", mode[1], mode[2]))
              else
                ngx.print(format("<option value='%s'>%s</option>", mode[1], mode[2]))
              end
            end  ngx.print('\
          </select>\
        ');  else  ngx.print('\
          ');  for _, mode in ipairs(wifiHighModes) do
            if pageInfo and mode[1] == pageInfo.wifiHighMode then   ngx.print('\
              <span id="wifiset-sel-modehigh">');  ngx.print(mode[2]); ngx.print('</span>\
            ');  end
          end  ngx.print('\
        ');  end  ngx.print('\
      </div>\
    </div>\
\
      ');  
        local row = {
          label = T"Bandwidth",
          colRightClass = "rel right no-margin-right padding-left-right-mobile mobile-border-bottom",
          colLeftClass = "left mobile-border-bottom",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-highband"
          }, wifiHighBandwidth, pageInfo.wifiHighBand))
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
\
      ');  
        local row = {
          label = T"Beacon Interval (ms)",
          element = ui_helper.createOnlyText({
            id = "wifiset-span-highbeacon"
          },pageGetParams and pageGetParams["wifiHighBeacon"])
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"DTIM Interval (ms)",
          element = ui_helper.createOnlyText({
            id = "wifiset-span-highdtim"
          },pageGetParams and pageGetParams["wifiHighDTIM"])
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"Auto Channel Reselection",
          element = ui_helper.createButton({
            id = "wifiset-btn-highchnsel",
            class = pageInfo and pageInfo['wifiHighChnSel'] == '0' and 'button button-off' or 'button button-on'
          })
        }
        ngx.print(ui_helper.createRow(row))

        local row = {
          label = T"DFS Channel",
          element = ui_helper.createButton({
            id = "wifiset-btn-highdfs",
            class = pageInfo and highDFSChannelList[pageInfo.wifiHighDFS] == "1" and 'button button-on' or 'button button-off'
          })
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
\
    <!-- If vodafone variant is not UK this part will execute -->\
    ');  else  ngx.print('\
      ');  
        local row = {
          label = T"Channel",
          colRightClass = "rel right no-margin-right padding-left-right-mobile mobile-border-bottom",
          colLeftClass = "left mobile-border-bottom",
          element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
          {
            id = "wifiset-sel-HighChannel",
            name = "wifiset-sel-HighChannel",
            onchange = "ChannelChangeOption(this)",
          }, channels5GHz, pageInfo["wifiHighChannel"]))
        }
        ngx.print(ui_helper.createRow(row))


       local row = {
         label = T"Auto Mode",
         rowId = "wifisel-auto-mode-wifiHigh",
         rowClass = "vdf-row hide",
         colRightClass = "rel right no-margin-right padding-left-right-mobile ",         
         element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown(
         {
           id = "wifiset-sel-auto-mode-wifiHigh",
           name = "auto_mode",
           onchange = "autoModeChangeOption(this)",
         }, auto_mode_5GHz, auto_mode_5GHz[pageInfo.wifiHighACSAllowedChannel]))
       }
       ngx.print(ui_helper.createRow(row))  ngx.print('\
     ');  end  ngx.print('\
  </div>\
');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
  <div class="h3-content auto-mode-all-channel-error hide"  id = "auto-allChannel-info">\
    <div class="message message-info" style="padding-right:50px;">\
      <span class="font-normal">\
        ');  ngx.print(T"The All Channels Mode will use all available channels in the region you live."); ngx.print('<br>\
        ');  ngx.print(T"Some channels will not be used if RADAR is detected."); ngx.print('<br>\
        ');  ngx.print(T"Notes"); ngx.print('<br>\
        ');  ngx.print(T"1: Not all client devices support channels above 48."); ngx.print('<br>\
        ');  ngx.print(T"2: After clicking Apply the wireless may take some time before reconnection is available."); ngx.print('<br>\
        ');  ngx.print(T"If you're unsure of what these options do, we recommend you maintain the default settings."); ngx.print('\
      </span>\
    </div>\
  </div>\
  <div class="h3-content auto-mode-all-channel-error hide" id = "auto-compChannel-info">\
    <div class="message message-info" style="padding-right:50px;">\
      <span class="font-normal">\
        ');  ngx.print(T"The Compatibility Mode will find the best channel from 36, 40, 44, and 48."); ngx.print('<br>\
        ');  ngx.print(T"It is possible to use All Channels Mode or manually configure one of the other available channels using the Channel dropdown."); ngx.print('<br>\
        ');  ngx.print(T"Note: Not all client devices support channels above 48."); ngx.print('<br>\
        ');  ngx.print(T"If you're unsure of what these options do, we recommend you maintain the default settings."); ngx.print('\
      </span>\
    </div>\
  </div>\
  <div class="h3-content auto-mode-all-dfschannel-error hide"  id = "dfs-channelsel-info">\
    <div class="message message-info" style = "padding-right : 50px;" >\
      <span class="font-normal" >');  ngx.print(T"If you select channels above 48 and the current channel changes after you have saved it is due to RADAR detection, so that channel can not be used."); ngx.print('<br><br>\
         Note: Not all client devices support channels above 48.</span>\
    </div>\
  </div>\
  </div>\
');  end  ngx.print('\
</form>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script>\
var  dfsEnable = "');  ngx.print(dfsEnable); ngx.print('";\
var  dfsDisable = "');  ngx.print(dfsDisable); ngx.print('";\
$(function(){\
  var wifiLowFrag = "');  ngx.print(pageInfo and pageInfo["wifiLowFrag"]); ngx.print('";\
  var wifiHighFrag = "');  ngx.print(pageInfo and pageInfo["wifiHighFrag"]); ngx.print('";\
  $("#wifiset-txt-lowfrag").val(wifiLowFrag);\
  $("#wifiset-txt-highfrag").val(wifiHighFrag);\
  $("#wifiset-btn-highdfs").click(function(){\
    if ($(this).hasClass("button-on")){\
      $(this).removeClass("button-off").addClass("button-on");\
    } else {\
      $(this).removeClass("button-on").addClass("button-off");\
    }\
  });\
  ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
    var automode = "');  ngx.print(pageInfo and pageInfo["wifiHighACSAllowedChannel"]); ngx.print('";\
    $("#wifiset-sel-auto-mode-wifiHigh").val(automode);\
    if ($("#wifiset-sel-HighChannel").val() == "auto") {\
      $("#wifisel-auto-mode-wifiHigh").removeClass(\'hide\');\
      $("#dfs-channelsel-info").addClass(\'hide\');\
      if ($("#wifiset-sel-auto-mode-wifiHigh").val() == dfsEnable) {\
        $("#auto-allChannel-info").removeClass(\'hide\');\
        $("#auto-compChannel-info").addClass(\'hide\');\
      }\
      else {\
        $("#auto-compChannel-info").removeClass(\'hide\');\
        $("#auto-allChannel-info").addClass(\'hide\');\
      }\
    }\
    else {\
      $("#wifisel-auto-mode-wifiHigh").addClass(\'hide\');\
      if (($("#wifiset-sel-HighChannel").val() != "36") && ($("#wifiset-sel-HighChannel").val() != "40") && ($("#wifiset-sel-HighChannel").val() != "44") && ($("#wifiset-sel-HighChannel").val() != "48")){\
        $("#dfs-channelsel-info").removeClass(\'hide\');\
      }\
      else {\
        $("#auto-allChannel-info, #auto-compChannel-info, #dfs-channelsel-info").addClass(\'hide\');\
      }\
    }\
    $("#wifiset-sel-HighChannel").change(function() {\
      var current = $(this).val();\
      if (current != \'36\' || current != \'40\' || current != \'44\' || current != \'48\') {\
        $("#auto-compChannel-info").addClass(\'hide\');\
      } else {\
        $("#auto-compChannel-info").removeClass(\'hide\');\
      }\
    });\
  ');  end  ngx.print('\
  $("#global-apply, #modal-apply").click(function(){\
    ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
      if (typeof(Storage) !== "undefined") {\
        sessionStorage.setItem("user_interacted", "pristine");\
      }\
    ');  else  ngx.print('\
      sessionStorage.setItem(\'apply_changes\', "Y");\
    ');  end  ngx.print('\
    var params = [];\
    var wifiLowChnSel, wifiHighChnSel, wifiHighDfs\
    var target = $("#wifiSetForm").attr("action");\
    var wifiLowMode = $("#wifiset-sel-lowmode").children("option").filter(":selected").val();\
    var wifiLowBand = $("#wifiset-sel-lowband").children("option").filter(":selected").val();\
    var wifiHighBand = $("#wifiset-sel-highband").children("option").filter(":selected").val();\
    params.push({\
      name  : "wifiLowMode",\
      value : wifiLowMode\
    },{\
      name  : "wifiLowBand",\
      value : wifiLowBand\
    },{\
      name  : "wifiHighBand",\
      value : wifiHighBand\
    },{\
      name : "action",\
      value : "SAVE"\
    },{\
      name : "CSRFtoken",\
      value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    });\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
      var wifiLowEncryption = $("#wifiset-sel-encryption").children("option").filter(":selected").val();\
      var wifiLowFrag = $("#wifiset-txt-lowfrag").val();\
      wifiLowChnSel = $("#wifiset-btn-lowchnsel").hasClass("button-off") ? "0" : "3600";\
      wifiHighChnSel = $("#wifiset-btn-highchnsel").hasClass("button-off") ? "0" : "3600";\
      var wifiHighMode = $("#wifiset-sel-highmode").children("option").filter(":selected").val();\
      var wifiHighFrag = $("#wifiset-txt-highfrag").val();\
      var wifiHighDFS = $("#wifiset-btn-highdfs").hasClass("button-on") ? "1" : "0";\
      params.push({\
        name  : "wifiLowFrag",\
        value : wifiLowFrag\
      },{\
        name  : "wifiLowChnSel",\
        value : wifiLowChnSel\
      },{\
        name  : "wifiHighMode",\
        value : wifiHighMode\
      },{\
        name  : "wifiHighFrag",\
        value : wifiHighFrag\
      },{\
        name  : "wifiHighChnSel",\
        value : wifiHighChnSel\
      },{\
        name  : "wifiLowEncryption",\
        value : wifiLowEncryption\
      },{\
        name  : "wifiHighDFS",\
        value : wifiHighDFS\
      });\
    ');  else  ngx.print('\
      var wifiLowChannel  = $("#wifiset-sel-lowChannel").val();\
      var wifiHighChannel = $("#wifiset-sel-HighChannel").val();\
      var wifiHighAutoMode = $("#wifiset-sel-auto-mode-wifiHigh").val();\
      params.push({\
        name  : "wifiLowChannel",\
        value : wifiLowChannel\
      },{\
        name  : "wifiHighChannel",\
        value : wifiHighChannel\
      },\
      { name  : "wifiHighACSAllowedChannel",\
        value : wifiHighAutoMode\
      });\
    ');  end  ngx.print('\
    postHandler(target, params, true);\
  });\
});\
var decodeHtmlEntity = function(str) {\
  return str.replace(/&#(\\d+);/g, function(match, dec) {\
    return String.fromCharCode(dec);\
  });\
};\
$("#resetR, .resetR").click(function(){\
  $("#wifiset-sel-lowmode").val("');  ngx.print(resetsettings["reset_wifi_low_mode"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-lowband").val(decodeHtmlEntity("');  ngx.print(resetsettings["reset_wifi_low_bandwidth"]); ngx.print('")).trigger("chosen:updated");\
  $("#wifiset-sel-channel").val("');  ngx.print(resetsettings["reset_wifi_low_channel"]); ngx.print('".split(",")).trigger("chosen:updated");\
  $("#wifiset-sel-encryption").val("');  ngx.print(resetsettings["reset_wifi_low_encryption_type"]); ngx.print('".split(",")).trigger("chosen:updated");\
  $("#wifiset-sel-highmode").val("');  ngx.print(resetsettings["reset_wifi_high_mode"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-highband").val("');  ngx.print(resetsettings["reset_wifi_high_bandwidth"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-lowChannel").val("');  ngx.print(resetsettings["reset_wifilow_channel"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-HighChannel").val("');  ngx.print(resetsettings["reset_wifihigh_channel"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-auto-mode-wifiHigh").val("');  ngx.print(resetsettings["reset_wifihigh_acs_channel"]); ngx.print('").trigger("chosen:updated");\
\
  changeButton("#wifiset-btn-lowchnsel", ');  ngx.print(resetsettings["reset_wifi_low_auto_channel_selection"]); ngx.print(');\
  changeButton("#wifiset-btn-highchnsel", ');  ngx.print(resetsettings["reset_wifi_high_auto_channel_selection"]); ngx.print(');\
  changeButton("#wifiset-btn-highdfs", ');  ngx.print(resetsettings["reset_wifi_high_dfs_channel_selection"]); ngx.print(');\
  $("#wifisel-auto-mode-wifiHigh").removeClass(\'hide\');\
  $("#auto-allChannel-info,#auto-compChannel-info, #dfs-channelsel-info").addClass(\'hide\');\
  if ($("#wifiset-sel-auto-mode-wifiHigh").val() == dfsDisable) {\
    $("#auto-compChannel-info").removeClass(\'hide\');\
  }\
\
});\
');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
  function ChannelChangeOption(options) {\
    var selectedValue = options.value;\
    if (selectedValue == "auto") {\
      $("#wifisel-auto-mode-wifiHigh").removeClass(\'hide\');\
      $("#dfs-channelsel-info").addClass("hide");\
      if ($("#wifiset-sel-auto-mode-wifiHigh").val() == dfsEnable) {\
        $("#auto-allChannel-info").removeClass(\'hide\');\
      }\
      else {\
        $("#auto-compChannel-info").removeClass(\'hide\');\
      }\
    }\
    else{\
      $("#wifisel-auto-mode-wifiHigh").addClass(\'hide\');\
      if((selectedValue != "36") && (selectedValue != "40") && (selectedValue != "44") && (selectedValue != "48")) {\
        $("#dfs-channelsel-info").removeClass(\'hide\');\
      }\
      else{\
        $("#auto-allChannel-info, #auto-compChannel-info,#dfs-channelsel-info").addClass(\'hide\');\
      }\
    }\
  }\
  function autoModeChangeOption(options) {\
    var selectedValue = options.value;\
    if (selectedValue == dfsEnable ) {\
      $("#auto-allChannel-info").removeClass(\'hide\');\
      $("#auto-compChannel-info, #dfs-channelsel-info").addClass(\'hide\');\
    }\
    else {\
      $("#auto-compChannel-info").removeClass(\'hide\');\
      $("#auto-allChannel-info, #dfs-channelsel-info").addClass(\'hide\');\
    }\
  }\
');  end  ngx.print('\
</script>\
\
'); 