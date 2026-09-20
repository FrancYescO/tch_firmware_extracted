--pretranslated: do not change this file
 --Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local string = string
local ngx = ngx
local format = string.format
local tonumber = tonumber
local json = require("dkjson")
local secondsToUptime = vdf_helper.secondsToUptime
local variant = vdf_helper.getVariant()
local ui_helper = require("vdf_ui_helper")
local mobileData
local pin_state = {
  ["enabled_verified"] = T"PIN verified",
  ["not_initialized"] = T"PIN not initialized",
  ["enabled_not_verified"] = T"PIN not verified",
  ["blocked"]   =    T"SIM Blocked. Awaiting PUK",
  ["permanently_blocked"] = T"PIN permanently Blocked",
  ["disabled"] = T"Disabled",
}

local mobile_status = {
  ["no_device"] = T"No Device",
  ["configuring_device"] = T"Configuring Device",
  ["initializing_sim"] = T"Initializing Sim",
  ["connecting"] = T"Connecting",
  ["scanning_network"] = T"Scanning Network",
  ["upgrading_firmware"] = T"Upgrading Firmware",
  ["disabled"] = T"Disabled",
  ["error"] = T"Error",
  ["connected"] = T"Connected",
  ["disconnected"] = T"Disconnected",
}

-- Common get method for all parameters related to mobile status page.
-- return mobileInfo(table)
local function getFromTransformer()
  local mobileInfo = {
    connection     = "rpc.mobiled.device.@1.radio.signal_quality.radio_interface",
    network        = "rpc.mobiled.device.@1.network.serving_system.network_desc",
    signalStrength = "rpc.mobiled.device.@1.leds.bars",
    snr            = "rpc.mobiled.device.@1.radio.signal_quality.snr",
    sinr           = "rpc.mobiled.device.@1.radio.signal_quality.sinr",
    rssi           = "rpc.mobiled.device.@1.radio.signal_quality.rssi",
    connectionTime = "rpc.network.interface.@wwan.uptime",
    ipAddress      = "rpc.network.interface.@wwan.ipaddr",
    automaticDNS   = "rpc.network.interface.@wwan.dnsservers",
    staticDNS      = "rpc.network.interface.@wwan.static_dns_servers",
    macfacturer    = "rpc.mobiled.device.@1.info.manufacturer",
    model          = "rpc.mobiled.device.@1.info.model",
    imei           = "rpc.mobiled.device.@1.info.imei",
    swVersion      = "rpc.mobiled.device.@1.info.software_version",
    displayStatus  = "rpc.mobiled.device.@1.display_status",
    imsi           = "rpc.mobiled.device.@1.sim.imsi",
    pinStatus      = "rpc.mobiled.device.@1.sim.pin.pin_state",
    mcc            = "rpc.mobiled.device.@1.network.serving_system.mcc",
    mnc            = "rpc.mobiled.device.@1.network.serving_system.mnc"
  }
  content_helper.getExactContent(mobileInfo)
  return mobileInfo
end

-- When no dongle connected to gateway for few parameters need to be displayed with
-- default values. For parameter Connection time needs to be converted to Days and hours
-- and minutes from seconds.
-- return data(table)
local function dataManipulation(data)
  data["snr"] = data["snr"] ~= "" and data["snr"] or 0
  data["sinr"] = data["sinr"] ~= "" and data["sinr"] or 0
  if data["snr"] == 0 then
    data["snr"] = "snr_nilvalue"
  end
  data["rssi"] = data["rssi"] ~= "" and data["rssi"] or 0
  if data.connectionTime ~= "" then
    local uptime_days, uptime_hours, uptime_minutes = secondsToUptime(tonumber(data.connectionTime))
    local time = format("%s %s, %s %s %s %s %s", uptime_days, T"days", uptime_hours, T"hours", T"and", uptime_minutes, T"minutes")
    data["connectionTime"] = time
  else
    data["connectionTime"] = "0s"
  end
  data["ipAddress"] = data["ipAddress"] ~= "" and data["ipAddress"] or "0.0.0.0"
  if data["staticDNS"] == "" and data["automaticDNS"] == "" then
    data["dns"] = "0.0.0.0"
  else
    data["dns"] = data["staticDNS"] ~= "" and data["staticDNS"] or data["automaticDNS"]
  end
  data["swVersion"] = data["swVersion"] ~= "" and string.match(data["swVersion"], "([^%s]+)") or ""
  data["displayStatus"] = data["displayStatus"] ~= "" and mobile_status[string.untaint(data["displayStatus"])] or T"Offline"
  data["pinStatus"] = data["pinStatus"] ~= "" and pin_state[string.untaint(data.pinStatus)] or T"N/A"
  data["plmnName"] = (data["mcc"] ~= "" and data["mnc"] ~= "") and (data["mcc"] .. data["mnc"]) or ""
  return data
end

-- Ajax operation for dynamically display of result.
if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "mobileStatus" then
  mobileData = dataManipulation(getFromTransformer())
  ngx.header.content_type = "application/json"
  ngx.print(json.encode(mobileData))
  ngx.exit(ngx.OK)
else
  -- Intial get operation, When page is opened.
  mobileData = dataManipulation(getFromTransformer())
end
  ngx.print('\
\
<h1><span>');  ngx.print(T"Mobile Status"); ngx.print('</span></h1>\
');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
<h2><span>');  ngx.print(T"For usage on the Vodafone mobile network, please check your Vodafone account (either via My Vodafone app, or <a href='http://vodafone.co.uk/'>vodafone.co.uk</a> my account). For usage on a 3rd party's network, please check with them directly on your usage."); ngx.print('</span></h2>\
');  end   ngx.print('\
');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
<h3><span>');  ngx.print(T"Mobile Status Information"); ngx.print('</span></h3>\
');  else   ngx.print('\
<h3><span>');  ngx.print(T"Mobile Status"); ngx.print('</span></h3>\
');  end   ngx.print('\
');  
  local signalContainer = [[
    <div class="signal-container">
      <div class="nosignal" style="height:5px;margin-top:67px;">&nbsp;</div>
      <div class="nosignal" style="height:10px;margin-top:62px;">&nbsp;</div>
      <div class="nosignal" style="height:18px;margin-top:54px;">&nbsp;</div>
      <div class="nosignal" style="height:24px;margin-top:48px;">&nbsp;</div>
      <div class="nosignal" style="height:32px;margin-top:40px;">&nbsp;</div>
      <div class="nosignal" style="height:41px;margin-top:31px;">&nbsp;</div>
      <div class="nosignal" style="height:48px;margin-top:24px;">&nbsp;</div>
      <div class="nosignal" style="height:56px;margin-top:16px;">&nbsp;</div>
      <div class="nosignal" style="height:62px;margin-top:10px;">&nbsp;</div>
      <div class="nosignal" style="height:72px;margin-top:0px;">&nbsp;</div>
    </div>
  ]]

  local label_rssi = T"Power"
  if variant == "NZ" then
    label_rssi = T"Receive Level"
  end

  local row = {
    {
      label   = T"Connection",
      element = ui_helper.createOnlyText({id = "mobile-connection"})
    },
    {
      label   = T"Network Operator",
      element = ui_helper.createOnlyText({id = "mobile-network"})
    },
    {
      label   = T"Signal Strength",
      element = signalContainer
    },
    {
      label   = T"SNR",
      element = ui_helper.createOnlyText({id = "mobile-snr"})
    },
    {
      label   = T"SINR",
      element = ui_helper.createOnlyText({id = "mobile-sinr"})
    },
    {
      label   = label_rssi,
      element = ui_helper.createOnlyText({id = "mobile-rssi"})
    },
    {
      label   = T"Connection Time",
      element = ui_helper.createOnlyText({id = "mobile-connectionTime"})
    },
    {
      label   = T"IP Address",
      element = ui_helper.createOnlyText({id = "mobile-ipAddress"})
    },
    {
      label   = T"DNS",
      element = ui_helper.createOnlyText({id = "mobile-dns"})
    },
    {
      label   = T"Manufacturer",
      element = ui_helper.createOnlyText({id = "mobile-macfacturer"})
    },
    {
      label   = T"Model",
      element = ui_helper.createOnlyText({id = "mobile-model"})
    },
    {
      label   = T"IMEI",
      element = ui_helper.createOnlyText({id = "mobile-imei"})
    },
    {
      label   = T"Firmware Version",
      element = ui_helper.createOnlyText({id = "mobile-swVersion"})
    },
    {
      label   = T"Status",
      element = ui_helper.createOnlyText({id = "mobile-displayStatus"})
    },
    {
      label   = T"IMSI",
      element = ui_helper.createOnlyText({id = "mobile-imsi"})
    },
    {
      label   = T"PIN Status",
      element = ui_helper.createOnlyText({id = "mobile-pinStatus"})
    }
  }

  if variant == "NZ" then
    row[#row+1] = {
      label   = T"PLMN Name",
      element = ui_helper.createOnlyText({id = "mobile-plmnName"})
    }
  end

  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))
  ngx.print('\
\
<script>\
  var units = {\
    snr: "dB",\
    sinr: "dB",\
    rssi: "dBm"\
  }\
  var target = "modals/status-support/mobileStatus.lp";\
  //AJAX Request to get result dynamically.\
  function getstatus(target) {\
    $.get(target+"?action=mobileStatus",function(responseTxt, status, xhr) {\
      $.each(responseTxt, function(key, value) {\
        if(key != "signalStrength") {\
          $("#mobile-"+key).text(value + " " + (units[key ] || ""));\
        }else {\
          $(".signal-container > div:lt("+value+")").removeClass("nosignal").addClass("signal")\
        }\
        if(value == "snr_nilvalue") {\
          $("span#mobile-snr").closest("div.vdf-row").hide();\
        }\
      });\
    });\
  }\
\
  $(function() {\
    getstatus(target);\
    var barLength = "');  ngx.print(tonumber(mobileData.signalStrength)); ngx.print('"\
    $(".signal-container > div:lt("+barLength+")").removeClass("nosignal").addClass("signal")\
    var interval = setInterval(function(){ getstatus(target) }, 3000);\
    //To clear interval when user try navigate to other page.\
    $(document).on(\'click\', \'.sub-navigation > ul > li > a, .topmenu > li > a, .sub-sub-navigation > li> a, .dropdown li a, .menubar-ul li a\', function() {\
      clearInterval(interval);\
    });\
  });\
</script>\
'); 