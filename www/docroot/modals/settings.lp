--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local posix = require("tch.posix")
local postHelper = require("web.post_helper")
local contentHelper = require("web.content_helper")
local isEnumSelect = postHelper.getValidateInEnumSelect
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC
local getClockTime = posix.clock_gettime
local string, ngx, tonumber = string, ngx, tonumber
local format, gmatch = string.format, string.gmatch
local untaint = string.untaint
local ipairs = ipairs

local wifiLowModes = {
  {"bgn", T"Mixed 802.11b/g/n"},
  {"bg", T"Mixed 802.11b/g"},
}

local wifiHighModes = {
  {"anac", T"Mixed 802.11n/ac"},
}

local wifiLowBandwidth = {
  {"20", T"20MHz"},
  {"20/40", T"20/40MHz"},
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

local pageGetParams = {
  wifiLowBeacon  = "rpc.wireless.radio.@radio_2G.beacon_period",
  wifiLowDTIM    = "rpc.wireless.radio.@radio_2G.dtim_interval",
  --TODO wifiLowRTS     = "rpc.wireless.radio.@radio_2G.rts_threshold",
  wifiHighBeacon = "rpc.wireless.radio.@radio_5G.beacon_period",
  wifiHighDTIM   = "rpc.wireless.radio.@radio_5G.dtim_interval",
  --TODO wifiHighRTS    = "rpc.wireless.radio.@radio_5G.rts_threshold",
  securityMode24 = "uci.wireless.wifi-ap.@ap0.security_mode",
}
contentHelper.getExactContent(pageGetParams)

local function isValidChannelSelected(param, object, key)
  if object[key] == "0" or object[key] == "3600" then
    return true
  end
  return nil, T"Invalid input"
end

local function isValidAllowedChannels24(value)
  local channel
  for i in gmatch(value, "[^,]+") do
    channel = tonumber(i)
    if not channel or channel<1 or 13<channel then
      return nil, T"Invalid input"
    end
  end
 return true
end

local paramMap = {
  wifiLowMode    = "uci.wireless.wifi-device.@radio_2G.standard",
  wifiLowBand    = "uci.wireless.wifi-device.@radio_2G.channelwidth",
  wifiLowChnSel  = "uci.wireless.wifi-device.@radio_2G.acs_rescan_period",
  wifiHighMode   = "uci.wireless.wifi-device.@radio_5G.standard",
  wifiHighBand   = "uci.wireless.wifi-device.@radio_5G.channelwidth",
  wifiHighChnSel = "uci.wireless.wifi-device.@radio_5G.acs_rescan_period",
  wifiLowEncryption = "uci.wireless.wifi-device.@radio_2G.encryptiontype"
}

local validationMap = {
  wifiLowMode       = isEnumSelect(wifiLowModes),
  wifiLowBand       = isEnumSelect(wifiLowBandwidth),
  wifiLowChnSel     = isValidChannelSelected,
  wifiHighMode      = isEnumSelect(wifiHighModes),
  wifiHighBand      = isEnumSelect(wifiHighBandwidth),
  wifiHighChnSel    = isValidChannelSelected,
  wifiLowEncryption = isEnumSelect(wifiLowEncryptionType),
}

local pageInfo, pageErrmsg = postHelper.handleQuery(paramMap, validationMap)
local resetsettings = {
  reset_wifi_low_mode = "uci.uci-defaults.settings.wifi_low_mode",
  reset_wifi_low_bandwidth = "uci.uci-defaults.settings.wifi_low_bandwidth",
  reset_wifi_low_auto_channel_selection = "uci.uci-defaults.settings.wifi_low_auto_channel_selection",
  reset_wifi_low_channel = "uci.uci-defaults.settings.wifi_low_channel",
  reset_wifi_low_encryption_type = "uci.uci-defaults.settings.wifi_low_encryption_type",
  reset_wifi_high_mode = "uci.uci-defaults.settings.wifi_high_mode",
  reset_wifi_high_bandwidth = "uci.uci-defaults.settings.wifi_high_bandwidth",
  reset_wifi_high_auto_channel_selection = "uci.uci-defaults.settings.wifi_high_auto_channel_selection"
}
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
  if not next(pageErrmsg) then
    ngx.print(format('<input type="hidden" id="post_status" value="success">'))
  else
    ngx.print(format('<input type="hidden" id="post_status" value="error">'))
  end
end

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<script src="js/global.js"></script>\
<script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
\
<h1>');  ngx.print(T"Settings"); ngx.print('</h1>\
<h2>');  ngx.print(T"Minimum Sync Speed"); ngx.print('</h2>\
<h3>');  ngx.print(T"2.4 GHz"); ngx.print('</h3>\
<form id="wifiSetForm" method="post" action="modals/settings.lp">\
  <div class="h3-content wifi-settings wifi-settings-padding-bottom vdf-table">\
     <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Wi-Fi Mode"); ngx.print('</span>\
        </div>\
        <div class="rel right no-margin-right padding-left-right-mobile">\
            <select chosen="" id="wifiset-sel-lowmode">\
              ');  for _, mode in ipairs(wifiLowModes) do
                  if pageInfo and mode[1] == pageInfo.wifiLowMode then
                    ngx.print(format("<option selected='selected' value='%s'>%s</option>", mode[1], mode[2]))
                  else
                    ngx.print(format("<option value='%s'>%s</option>", mode[1], mode[2]))
                  end
                end  ngx.print('\
            </select>\
	    </div>\
      </div>\
\
     <div class="vdf-row">\
       <div class="left">\
         <span>');  ngx.print(T"Bandwidth"); ngx.print('</span>\
       </div>\
       <div class="rel right no-margin-right padding-left-right-mobile">\
         <select  id="wifiset-sel-lowband">\
           ');  for _, band in ipairs(wifiLowBandwidth) do
             if pageInfo and band[1] == pageInfo.wifiLowBand then
               ngx.print(format("<option selected='selected' value='%s'>%s</option>", band[1], band[2]))
             else
               ngx.print(format("<option value='%s'>%s</option>", band[1], band[2]))
             end
           end  ngx.print('\
         </select>\
       </div>\
     </div>\
     <div class="vdf-row">\
       <div class="left">\
         <span>');  ngx.print(T"Encryption Type"); ngx.print('</span>\
       </div>\
       <div class="rel right no-margin-right padding-left-right-mobile">\
		<select id="wifiset-sel-encryption">\
            <option ');  if pageInfo["wifiLowEncryption"] == "" or pageInfo["wifiLowEncryption"] == "aes" then  ngx.print(' selected ');  end  ngx.print(' value = "aes">');  ngx.print(T"AESEncryption"); ngx.print('</option>\
            <option ');  if pageInfo["wifiLowEncryption"] == "tkipaes" then  ngx.print(' selected ');  end  ngx.print(' value = "tkipaes">');  ngx.print(T"TKIPandAESEncryption"); ngx.print('</option>\
        </select>\
       </div>\
     </div>\
    <!--TODO\
    <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 padding-bottom-20 full-width-mobile">\
          <p class="language-string "><span class="language-string light-font" name="PAGE_SETTINGS_POWER_SIGNAL" title="alias: PAGE_SETTINGS_POWER_SIGNAL">Power of Signal</span></p>\
           <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-right-small no-margin-right padding-left-right-mobile">\
			<select chosen="" id="signalStrength">\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_HIGH">high</option>\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_MEDIUM">medium</option>\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_LOW">low</option>\
            </select>\
		</div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	  <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 padding-bottom-20 full-width-mobile">\
          <p class="language-string"><span class="language-string light-font" name="PAGE_SETTINGS_ENCRYPTION_TYPE" title="alias: PAGE_SETTINGS_ENCRYPTION_TYPE">Encryption Type</span></p>\
           <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-right-small no-margin-right padding-left-right-mobile">\
			<select  chosen="" id="encrypthion">\
                <option>AESEncryption</option>\
                <option>TKIPEncryption</option>\
                <option>TKIPandAESEncryption</option>\
            </select>\
		</div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
      <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="language-string padding-top-bottom"><span class="language-string light-font" name="PAGE_SETTINGS_KEY_UPDATE_INTERVAL" title="alias: PAGE_SETTINGS_KEY_UPDATE_INTERVAL">Key Update Interval</span></p>\
          <input value="900" type="text" class="col-md-12 col-sm-12 col-lg-12">\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
    </div>\
    -->\
     <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Beacon Interval (ms)"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <span id="wifiset-span-lowbeacon" >');  ngx.print(pageGetParams and pageGetParams["wifiLowBeacon"]); ngx.print('</span>\
        </div>\
      </div>\
\
	 <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"DTIM Interval (ms)"); ngx.print('</span>\
        </div>\
        <div class="right">\
           <span id="wifiset-span-lowdtim">');  ngx.print(pageGetParams and pageGetParams["wifiLowDTIM"]); ngx.print('</span>\
        </div>\
      </div>\
    <!--\
    <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="padding-top-bottom"><span class="light-font">');  ngx.print(T"Fragmentation Treshold"); ngx.print('</span></p>\
          <span id="wifiset-lbl-lowfrag">2346</span>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	   <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="padding-top-bottom"><span class="light-font">');  ngx.print(T"RTS Treshold"); ngx.print('</span></p>\
          <span id="wifiset-span-lowrts">');  ngx.print(pageGetParams and pageGetParams["wifiLowRTS"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	  <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
		  <div class="row">\
			<div class="col-xs-6 col-md-6 col-sm-6">\
			  <p class="language-string"><span class="language-string light-font" name="PAGE_SETTINGS_WMM_ENABLED" title="alias: PAGE_SETTINGS_WMM_ENABLED">WMM Enabled</span></p>\
			</div>\
			<div class="col-xs-6 col-md-6 col-sm-6 text-right">\
			  <div class="button button-on" id="WMMEnabled"></div>\
			</div>\
		  </div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
    </div>\
    -->\
	  <div class="vdf-row">\
			<div class="left">\
			  <span>');  ngx.print(T"Enable Auto Rescan"); ngx.print('</span>\
			</div>\
			<div class="right">\
        <div class="button ');  ngx.print((pageInfo and pageInfo['wifiLowChnSel'] == '0') and 'button-off' or 'button-on'); ngx.print('" id="wifiset-btn-lowchnsel"></div>\
			</div>\
		  </div>\
        </div>\
\
  <h3>');  ngx.print(T"5 GHz"); ngx.print('</h3>\
    <div class="h3-content wifi-settings wifi-settings-padding-bottom vdf-table">\
	   <div class="vdf-row">\
        <div class="left">\
           <span>');  ngx.print(T"Wi-Fi Mode"); ngx.print('</span>\
        </div>\
        <div class="rel right no-margin-right padding-left-right-mobile">\
            <select chosen="" id="wifiset-sel-highmode">\
              ');  for _, mode in ipairs(wifiHighModes) do
                  if pageInfo and mode[1] == pageInfo.wifiHighMode then
                    ngx.print(format("<option selected='selected' value='%s'>%s</option>", mode[1], mode[2]))
                  else
                    ngx.print(format("<option value='%s'>%s</option>", mode[1], mode[2]))
                  end
                end  ngx.print('\
            </select>\
        </div>\
      </div>\
\
     <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Bandwidth"); ngx.print('</span>\
        </div>\
        <div class="rel right no-margin-right padding-left-right-mobile">\
         <select id="wifiset-sel-highband">\
              ');  for _, band in ipairs(wifiHighBandwidth) do
             if pageInfo and band[1] == pageInfo.wifiHighBand then
               ngx.print(format("<option selected='selected' value='%s'>%s</option>", band[1], band[2]))
             else
               ngx.print(format("<option value='%s'>%s</option>", band[1], band[2]))
             end
           end  ngx.print('\
         </select>\
        </div>\
        </div>\
    <!--\
    <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 padding-bottom-20 full-width-mobile">\
          <p class="language-string "><span class="language-string light-font" name="PAGE_SETTINGS_POWER_SIGNAL" title="alias: PAGE_SETTINGS_POWER_SIGNAL">Power of Signal</span></p>\
          <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-right-small no-margin-right padding-left-right-mobile">\
			<select chosen="" id="signalStrength">\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_HIGH">high</option>\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_MEDIUM">medium</option>\
                <option title="PAGE_SETTINGS_POWER_SIGNAL_LOW">low</option>\
            </select>\
		</div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
      <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="language-string padding-top-bottom"><span class="language-string light-font" name="PAGE_SETTINGS_ENCRYPTION_TYPE" title="alias: PAGE_SETTINGS_ENCRYPTION_TYPE">Encryption Type</span></p>\
          <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-right-small no-margin-right padding-left-right-mobile">\
			<select  chosen="" id="encrypthion">\
                <option>AESEncryption</option>\
                <option>TKIPEncryption</option>\
                <option>TKIPandAESEncryption</option>\
            </select>\
		</div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	  <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="language-string padding-top-bottom"><span class="language-string light-font" name="PAGE_SETTINGS_KEY_UPDATE_INTERVAL" title="alias: PAGE_SETTINGS_KEY_UPDATE_INTERVAL">Key Update Interval</span></p>\
          <input value="900" type="text" class="col-md-12 col-sm-12 col-lg-12">\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
    </div>\
    -->\
	  <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Beacon Interval (ms)"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <span id="wifiset-span-highbeacon">');  ngx.print(pageGetParams and pageGetParams["wifiHighBeacon"]); ngx.print('</span>\
        </div>\
      </div>\
\
	  <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"DTIM Interval (ms)"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <span id="wifiset-span-highdtim">');  ngx.print(pageGetParams and pageGetParams["wifiHighDTIM"]); ngx.print('</span>\
        </div>\
      </div>\
    <!--\
    <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="padding-top-bottom"><span class="light-font">');  ngx.print(T"Fragmentation Treshold"); ngx.print('</span></p>\
          <span id="wifiset-lbl-highfrag">2346</span>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	   <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
          <p class="padding-top-bottom"><span class="light-font" >');  ngx.print(T"RTS Treshold"); ngx.print('</span></p>\
          <span id="wifiset-span-highrts">');  ngx.print(pageGetParams and pageGetParams["wifiHighRTS"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
      </div>\
	   <div class="row padding-left padding-left-mobile">\
        <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile">\
		  <div class="row">\
			<div class="col-xs-6 col-md-6 col-sm-6">\
			  <p class="language-string"><span class="language-string light-font" name="PAGE_SETTINGS_WMM_ENABLED" title="alias: PAGE_SETTINGS_WMM_ENABLED">WMM Enabled</span></p>\
			</div>\
			<div class="col-xs-6 col-md-6 col-sm-6 text-right">\
			  <div class="button button-on" id="WMMEnabled"></div>\
			</div>\
		  </div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12 padding-top-bottom-20">\
          <hr/>\
        </div>\
    </div>\
    -->\
	<div class="vdf-row">\
	  <div class="left">\
        <span>');  ngx.print(T"Enable Auto Rescan"); ngx.print('</span>\
	  </div>\
	  <div class="right">\
        <div class="button ');  ngx.print((pageInfo and pageInfo['wifiHighChnSel'] == '0') and 'button-off' or 'button-on'); ngx.print('" id="wifiset-btn-highchnsel"></div>\
	  </div>\
    </div>\
  </div>\
</form>\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
<!--\
<div class="row apply-cancel-hr">\
  <div class="col-md-12 col-sm-6 col-xs-12 pull-right text-right">\
    <div class="articlediv hide">\
      <div class="message-arrowbox-applied">\
        <div class="message-arrowbox-applied-right">\
          <p class="language-string success-info" name="PAGE_FIREWALL_CONFIRMATION_CHANGES_APPLIED" title="alias: PAGE_FIREWALL_CONFIRMATION_CHANGES_APPLIED"></p>\
        </div>\
      </div>\
    </div>\
    <input class="button button-apply mob-button-width" value="Apply" type="button" />\
    <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button" />\
  </div>\
</div>\
-->\
\
<script>\
$(function(){\
  var wifiLowFrag = "');  ngx.print(pageInfo and pageInfo["wifiLowFrag"]); ngx.print('";\
  var wifiHighFrag = "');  ngx.print(pageInfo and pageInfo["wifiHighFrag"]); ngx.print('";\
  $("#wifiset-txt-lowfrag").val(wifiLowFrag);\
  $("#wifiset-txt-highfrag").val(wifiHighFrag);\
\
  $("#global-apply").click(function(){\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    var params = [];\
    var wifiLowChnSel, wifiHighChnSel\
    var target = $("#wifiSetForm").attr("action");\
    var wifiLowMode = $("#wifiset-sel-lowmode").children("option").filter(":selected").val();\
    var wifiLowEncryption = $("#wifiset-sel-encryption").children("option").filter(":selected").val();\
    var wifiLowBand = $("#wifiset-sel-lowband").children("option").filter(":selected").val();\
    var wifiLowFrag = $("#wifiset-txt-lowfrag").val();\
    wifiLowChnSel = $("#wifiset-btn-lowchnsel").hasClass("button-off") ? "0" : "3600";\
    wifiHighChnSel = $("#wifiset-btn-highchnsel").hasClass("button-off") ? "0" : "3600";\
    var wifiHighMode = $("#wifiset-sel-highmode").children("option").filter(":selected").val();\
    var wifiHighBand = $("#wifiset-sel-highband").children("option").filter(":selected").val();\
    var wifiHighFrag = $("#wifiset-txt-highfrag").val();\
    params.push({\
      name  : "wifiLowMode",\
      value : wifiLowMode\
    },{\
      name  : "wifiLowBand",\
      value : wifiLowBand\
    },{\
      name  : "wifiLowFrag",\
      value : wifiLowFrag\
    },{\
      name  : "wifiLowChnSel",\
      value : wifiLowChnSel\
    },{\
      name  : "wifiHighMode",\
      value : wifiHighMode\
    },{\
      name  : "wifiHighBand",\
      value : wifiHighBand\
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
      name : "action",\
      value : "SAVE"\
    },{\
      name : "CSRFtoken",\
      value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    });postHandler(target, params);\
  });\
\
  $("#global-cancel").click(function(){\
    $("#content").load("/modals/settings.lp");\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  $("#wifiset-sel-lowmode").val("');  ngx.print(resetsettings["reset_wifi_low_mode"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-lowband").val("');  ngx.print("20/40"); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-encryption").val("');  ngx.print(resetsettings["reset_wifi_low_encryption_type"]); ngx.print('".split(",")).trigger("chosen:updated");\
  $("#wifiset-sel-highmode").val("');  ngx.print(resetsettings["reset_wifi_high_mode"]); ngx.print('").trigger("chosen:updated");\
  $("#wifiset-sel-highband").val("');  ngx.print(resetsettings["reset_wifi_high_bandwidth"]); ngx.print('").trigger("chosen:updated");\
\
  function changeButton(id, value) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
    } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
    }\
  }\
  changeButton("#wifiset-btn-lowchnsel", ');  ngx.print(resetsettings["reset_wifi_low_auto_channel_selection"]); ngx.print(');\
  changeButton("#wifiset-btn-highchnsel", ');  ngx.print(resetsettings["reset_wifi_high_auto_channel_selection"]); ngx.print(');\
});\
</script>\
'); 