--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local vdf_helper = require("vodafone_helper")
local splitIP = vdf_helper.splitIP
local string = string
local format, tonumber, untaint, match = string.format, tonumber, string.untaint, string.match
local ngx = ngx
local pairs, ipairs, next = pairs, ipairs, next
local iconType, profileList, profileActiveCount

local dhcpStaticList = content_helper.convertResultToObject("uci.dhcp.host.", proxy.get("uci.dhcp.host."))

if ngx.var.request_method == "POST" and ngx.req.get_post_args().action == "edit-devices" then
  local devTypes = {
    {"console",true},
    {"laptop", true},
    {"smartphone", true},
    {"playstation", true},
    {"printer", true},
    {"router", true},
    {"tablet",true},
    {"tv", true}
  }

  local postargs = ngx.req.get_post_args()
  local gVSLIR = post_helper.getValidateStringLengthInRange(1, 63)
  local gVEnum = post_helper.getValidateInEnumSelect(devTypes)
  local error_msg = {}
  local success, msg = gVSLIR(postargs.deviceName)
  if not success then
    error_msg["deviceName"] = msg
  end
  success, msg = gVEnum(postargs.iconType)
  if not success then
    error_msg["iconType"] = msg
  end
  if next(error_msg) then
    local json = require("dkjson")
    ngx.header.content_type = "application/json"
    local buffer = {}
    success = json.encode(error_msg, {indent = false, buffer = buffer})
    if success then
      ngx.print(buffer)
      ngx.exit(ngx.HTTP_OK)
    end
  end
  local reply = content_helper.getMatchedContent("rpc.hosts.host.", {MACAddress=postargs.mac})
  local deviceName
  if reply and #reply > 0 then
    deviceName = postargs.deviceName
    if deviceName and deviceName:match(":") then
      deviceName = deviceName:gsub(":", "")
    end
    local setParams = {
      [reply[1].path.."FriendlyName"] = deviceName,
      [reply[1].path.."DeviceType"] = postargs.iconType ~= "" and postargs.iconType or "tv"
    }
    for _, host in ipairs (dhcpStaticList) do
      if string.lower(postargs.mac) == string.lower(host["mac"]) then
        setParams[format("uci.dhcp.host.%s.name",host["paramindex"])] =  postargs.deviceName
      end
    end
    if proxy.set(setParams) then
      proxy.apply()
    end
  end
end

-- Sorting the list by status, active then deactive devices
local function sortList(a,b)
  return a.State > b.State
end
local overviewlinkParam = {
  wps24State = "uci.wireless.wifi-ap.@ap0.wps_state",
  wps5State  = "uci.wireless.wifi-ap.@ap1.wps_state",
  ringingScheduleStatus = "uci.tod.todvoicednd.enabled",
  scheduleRuleON = "uci.tod.action.@wifischedactionON.enabled",
  scheduleRuleOFF = "uci.tod.action.@wifischedactionOFF.enabled",
}
content_helper.getExactContent(overviewlinkParam)
local look_4 = vdf_helper.look4()
local stbParam = {
  stbOption = "uci.dhcp.match.@match.match",
}
content_helper.getExactContent(stbParam)
overviewlinkParam.stbOption = stbParam.stbOption

local ringSchedule = "Schedule"
if vdf_helper.getVariant() == "NZ" then
  ringSchedule = "Ring schedule"
end

local icon
local look_4 = vdf_helper.look4()
local wanColour = vdf_helper.wanColour()
local device_picture = vdf_helper.devicepicture()
if vdf_helper.getVariant() == "VF-UK" then
  icon = "img/look_4/overview/vox3.0.png"
elseif vdf_helper.board() == "VBNT-Z" then
  icon = "img/vbnt-z/overview/DNA0130VDF.png"
else
  icon = "img/look_4/overview/slack-imgs.com.jpg"
end

-- function to classify stbdevice from other connected device
-- differentation is based on hostname and last octet of IPAddress
-- return boolean
local function isSTBDevice(name, ipaddress)
  local isStbRange = {
    ["251"] = true,
    ["252"] = true,
    ["253"] = true,
  }
  if name == overviewlinkParam["stbOption"]:match("^12,(.*)$") and isStbRange[untaint((ipaddress:match("%d+.%d+.%d+.(%d+)")))] then
    return true
  end
  return nil
end

local host_list = content_helper.convertResultToObject("rpc.hosts.host.",proxy.get("rpc.hosts.host."),sortList)
local wifiList = {}
local ethList = {}
local wifiActiveCount = 0
local ethActiveCount = 0
local friendlyName
local qtnMac = {mac = "uci.env.var.qtn_eth_mac"}
content_helper.getExactContent(qtnMac)
qtnMac.mac = qtnMac.mac and qtnMac.mac:lower() or  ""
for _,v in pairs(host_list) do
  if isSTBDevice(v.FriendlyName, v.IPAddress) then
    v.DeviceType = "tv"
  end
  if qtnMac.mac ~= v.MACAddress:lower() then
    if v["L2Interface"] == "wl0" or v["L2Interface"] == "wl0_1" then
      wifiActiveCount =  v.State == "1" and wifiActiveCount + 1 or wifiActiveCount
      v.radio = "(2.4GHz)"
      v.radioSignalIcon = "signal_full.png"
      if vdf_helper.getVariant() == "NZ" then
        v.radio = ""
        v.radioSignalIcon = "signal_full_24.png"
      end
      wifiList[#wifiList+1] = v
    elseif v["L2Interface"] == "wl1" or v["L2Interface"] == "wl1_1" or v["L2Interface"] == "eth5" then
      wifiActiveCount =  v.State == "1" and wifiActiveCount + 1 or wifiActiveCount
      v.radio = "(5GHz)"
      v.radioSignalIcon = "signal_full.png"
      if vdf_helper.getVariant() == "NZ" then
        v.radio = ""
        v.radioSignalIcon = "signal_full_5.png"
      end
      wifiList[#wifiList+1] = v
    else
      ethActiveCount =  v.State == "1" and ethActiveCount + 1 or ethActiveCount
      friendlyName = v.FriendlyName
      if friendlyName and friendlyName:match(":") then
        v.FriendlyName = friendlyName:gsub(":", "")
      end
      ethList[#ethList+1] = v
    end
  end
end
if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().dslstatus == "true" then
  local wan_type = {
    wtype = "uci.wansensing.global.l2type",
    wwanStatus  = "rpc.network.interface.@wwan.up"
  }
  content_helper.getExactContent(wan_type)

  local wanStatus = {
    status = "sys.class.xdsl.@line0.Status",
    upspeed = "sys.class.xdsl.@line0.UpstreamCurrRate",
    downspeed = "sys.class.xdsl.@line0.DownstreamCurrRate",
    PPPState = "rpc.network.interface.@wan.ppp.state",
    wanIP = "rpc.network.interface.@wan.ipaddr",
    backupStatus = "uci.wansensing.state.backupStatus"
  }

  if wan_type["wtype"] == "ETH" then
    wanStatus.status = "sys.class.net.@eth4.operstate"
  end

  content_helper.getExactContent(wanStatus)

  local wwan_interface = {
    wwanMode = ""
  }
  if vdf_helper.getVariant() == "VF-UK" then
    local device_entries = proxy.get("rpc.mobiled.DeviceNumberOfEntries")
    if device_entries and tonumber(device_entries[1].value) > 0 then
      wwan_interface["wwanMode"] = "rpc.mobiled.device.@1.radio.signal_quality.radio_interface"
      content_helper.getExactContent(wwan_interface)
    end
  end

  if string.upper(wanStatus["status"]) ~= "UP" and  wan_type["wwanStatus"] == "1" then
    wan_type["wtype"] = "Mobile"
  end

  ngx.header.content_type = "application/json"
  ngx.print('{"status":"' ..untaint(wanStatus.status) .. '","upspeed":"'..untaint(wanStatus.upspeed) ..'", "downspeed":"'..untaint(wanStatus.downspeed)..'","type":"'..untaint(wan_type.wtype)..'", "PPPState":"'..untaint(wanStatus.PPPState) ..'", "wanIP":"'..untaint(wanStatus.wanIP) ..'","backupStatus":"'..untaint(wanStatus.backupStatus) ..'", "wwanMode":"'..untaint(wwan_interface.wwanMode) ..'"}')
  ngx.exit(ngx.HTTP_OK)
end

local wifiStatus = {
  wifi24stat = "uci.wireless.wifi-ap.@ap0.state",
  wifi5stat  = "uci.wireless.wifi-ap.@ap1.state",
}
content_helper.getExactContent(wifiStatus)

local USBDeviceDetails = {}
local USBHubDetected = false
local InternalUSBDevice = false

local USBData = {
  sharingEnabled = "uci.samba.samba.filesharing",
  USBDeviceCount = "sys.usb.DeviceNumberOfEntries",
}
content_helper.getExactContent(USBData)

if USBData["USBDeviceCount"] > "0" then
  local USBDevices = proxy.get("sys.usb.device.")
  if next(USBDevices) then
    for _, v in ipairs(USBDevices) do
      local parameter = v.param
      local path  = v.path
      local value = v.value
      if(parameter == "product") then
        USBDeviceDetails[#USBDeviceDetails + 1] = {}
        USBDeviceDetails[#USBDeviceDetails].Name = value
      elseif v.param == "idVendor" and v.value == "2c7c" then
        InternalUSBDevice = true
      elseif match(path, "sys.usb.device.%d+.interface.%d+.") then
        if parameter == "bInterfaceClass" then

          -- If interface class has 07, the device is a printer
          -- Only assign value of 07 to the key(Type), otherwise it is overwritten by value of ff later
          if value == "07" then
            USBDeviceDetails[#USBDeviceDetails].Type = value

          -- If interface class has 09, the device is a USB hub
          elseif value == "09" then
            USBHubDetected = true
            USBDeviceDetails[#USBDeviceDetails].Type = value

          -- If interface class has 08, the device is a USB stick/USB dongle
          elseif value == "08" then
            USBDeviceDetails[#USBDeviceDetails].Type = value
          end
        end
      end
    end
  end
end
  ngx.print('\
<link rel="stylesheet" href="css/overview.css" />\
<script>\
 $(document).ready(function() {\
    var variant = "');  ngx.print(vdf_helper.getVariant()); ngx.print('";\
    $("[id^=overview-btn-ethEdit]").click(function() {\
      $("#oviewmodal-txt-name").removeClass("input-error");\
    });\
    $(".foldable-container-title").click(function(){\
      if($(this).hasClass("smallArrow")){\
        $(this).removeClass("smallArrow");\
        $(this).addClass("smallArrowUp");\
        $(this).children().eq(0).css("display","none");\
        $(this).children().eq(1).css("display","block");\
        $(this).next().css("display","block");\
      }\
      else{\
        $(this).removeClass("smallArrowUp");\
        $(this).addClass("smallArrow");\
        $(this).children().eq(0).css("display","block");\
        $(this).children().eq(1).css("display","none");\
        $(this).next().css("display","none");\
      }\
    });\
    $(\'.info-button\').click(function(){\
    if ($(this).closest(".mobile-btn-row").length)\
    {\
    $(this).closest(\'.mobile-btn-row\').prevAll(\'.row-overview:first\').toggleClass(\'active-info\');\
    }\
    else{\
    $(this).closest(\'.edit-btn-row\').prevAll(\'.row-overview:first\').toggleClass(\'active-info\');\
    }\
    });\
\
    $(\'.edit-wifi-device\').click(function(){\
      $(\'#editDevice\').show();\
    });\
\
    $(\'#editDevice .button-apply\').click(function(){\
      $(\'#editDevice\').hide();\
    });\
\
   $(\'#editDevice .icon\').click(function(){\
      $(\'#editDevice .icon\').removeClass(\'active\');\
      $(this).toggleClass(\'active\');\
   });\
\
    var selectedMac;\
    var iconType;\
    $(".button-edit").click(function(){\
      selectedMac = $(this).attr("mac");\
      iconType = $(this).attr("dtype");\
      $(\'#editOverviewModal .icon\').removeClass("active");\
      $(\'.modal .icon[icon-name = "\'+iconType+\'"]\').addClass("active");\
      $("#oviewmodal-txt-name").val($(this).attr("dname"))\
    });\
    $(\'#editOverviewModal .icon\').click(function(){\
      $(\'#editOverviewModal .icon\').removeClass("active");\
      $(this).addClass("active");\
      iconType = $(this).attr("icon-name");\
    });\
\
    var elements = {\
      hostName: "#oviewmodal-txt-name"\
    }\
    var validations = {\
      hostName: validateHostName\
    }\
\
    $("#oviewmodal-btn-save").click(function(){\
      if (!validateElements(elements, validations)) return false;\
      $(this).attr("disabled", true);\
      var postData = [];\
      postData.push({\
        name : "mac",\
        value : selectedMac\
      },{\
        name : "iconType",\
        value : iconType\
      },\
      {\
        name : "deviceName",\
        value : $("#oviewmodal-txt-name").val()\
      },\
      {\
        name : "CSRFtoken",\
        value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      },\
      {\
        name : "action",\
        value : "edit-devices"\
      });\
      $.post("/modals/overview.lp", postData, function(res, status, xhr){\
        if(xhr.getResponseHeader("content-type") == "application/json"){\
           for(var k in res){\
             $("#overview_Error_Message p").html(res[k]);\
           }\
           $("#overview_Error_Message").removeClass("hide");\
           $("#oviewmodal-btn-save").removeAttr("disabled");\
        }else{\
          $("#oviewmodal-btn-cancel").click();\
          $(".modal-backdrop").remove();\
          $("body").removeClass("modal-open");\
          $("#overview-page").html(res);\
        }\
      });\
    });\
    $(".phonelist a").click(function(){\
        topMenu("Phone","modals/phone/callLog.lp","Call Log");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $(\'ul li.sub-navigation-item\').addClass("active");\
        $("#Phone").parent().addClass("active");\
    });\
    $("#overview-href-phone, #overview-href-mobphone").click(function(){\
        topMenu("Phone","modals/phone/callLog.lp","Call Log");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $("a#call-log").closest("li").addClass("active");\
        $("#Phone").parent().addClass("active");\
    });\
    $("#overview-href-wifi, #overview-href-mobwifi").click(function(){\
        topMenu("WiFi","modals/wifi/general.lp","General");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $("a#wifi-general").closest("li").addClass("active");\
        $("#WiFi").parent().addClass("active");\
    });\
    $("#overview-img-gateway, #overview-img-mobgateway").click(function(){\
        topMenu("StatusSupport","modals/status-support/status.lp","Status & Support");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $(\'ul li.sub-navigation-item\').addClass("active");\
        $("#StatusSupport").parent().addClass("active");\
    });\
    $("#overview-href-usb, #overview-href-mobusb").click(function(){\
        var allowed = true;\
        if (variant == "NZ") {\
          var selectMode;\
          if($(this).closest(".mob-row-overview").length)\
            selectMode =  $("#home-sel-mobmode").val();\
          else\
            selectMode = $("#home-sel-mode").val();\
          if (selectMode == 33) {\
            allowed = false;\
          };\
        }\
        if (allowed == true) {\
          topMenu("Settings","modals/settings/usb.lp","USB");\
          $("ul.topmenu").find("li.active").removeClass("active");\
          $("#usb").closest("li").addClass("active");\
          $("#Settings").parent().addClass("active");\
        }\
    });\
\
     $("#overview-href-wps, #overview-href-mobwps").click(function(){\
        topMenu("WiFi","modals/wifi/wps.lp","WPS");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $("a#wps").closest("li").addClass("active");\
        $("#WiFi").parent().addClass("active");\
\
    });\
     $("#overview-href-mobrngshd, #overview-href-rngshd").click(function(){\
        var allowed = true;\
        if (variant == "NZ") {\
          var selectMode;\
          if($(this).closest(".mob-row-overview").length)\
            selectMode =  $("#home-sel-mobmode").val();\
          else\
            selectMode = $("#home-sel-mode").val();\
          if (selectMode == 33) {\
            allowed = false;\
          };\
        }\
        if (allowed == true) {\
          topMenu("Phone","modals/phone/ringingSchedule.lp","Ringing Schedule");\
          $("ul.topmenu").find("li.active").removeClass("active");\
          $("a#ringing-schedule").closest("li").addClass("active");\
          $("#Phone").parent().addClass("active");\
       }\
    });\
    $("#overview-href-psm, #overview-href-mobpsm").click(function(){\
        topMenu("WiFi","modals/wifi/powerSaving.lp","Power Saving Mode");\
        $("ul.topmenu").find("li.active").removeClass("active");\
        $("a#power-saving-mode").closest("li").addClass("active");\
        $("#WiFi").parent().addClass("active");\
    });\
    $(\'.modal\').on(\'hidden.bs.modal\', function () {\
      $("#overview_Error_Message").addClass("hide");\
      if (typeof(Storage) !== "undefined") {\
      // Save data to sessionStorage\
        if (variant == "NZ") {\
          sessionStorage.setItem("user_interacted", "pristine");\
        } else {\
          sessionStorage.setItem(\'apply_changes\', "Y");\
        }\
      }\
    });\
    //up/down button toggle\
    $(".img-dropdown").click(function(){\
      var selectMode;\
      if($(this).closest(".mob-row-overview").length)\
	selectMode =  $("#home-sel-mobmode").val();\
      else\
	selectMode = $("#home-sel-mode").val();\
	$(this).toggleClass("sub-row-active");\
	$(this).closest(".new-row-overview").next(".info-row").toggleClass("hidden");\
	if(!$(this).hasClass("sub-row-active")){\
	  $(this).closest(".new-row-overview").removeClass("active-info");\
	}\
	$(".mac-btn-right").addClass("hidden");\
	if(selectMode == 34 && variant != "NZ")\
	  $(".mac-btn-right").removeClass("hidden");\
    });\
    //click function for right button in network\
    $(".mac-btn-right").click(function(){\
    topMenu("WiFi","modals/wifi/macFilter.lp","MAC Filter","3");\
    $("ul.topmenu").find("li.active").removeClass("active");\
    $("ul.sub-navigation li:eq(3)").addClass("active");\
    $("#WiFi").parent().addClass("active");\
    });\
\
  //Overview phone column add/remove depending on vodafone variant\
  var imgSrc = $(".overview-image-bottom-center img");\
  var overviewCols = $("div.columns div.column");\
  if ("');  ngx.print(vdf_helper.getVariant()); ngx.print('" == "VHA"){\
    imgSrc.attr("src", "img/look_4/overview/overview-background-bot-3.jpg");\
    overviewCols.removeClass("added-phone").addClass("removed-phone");\
    $(".c4of3").addClass("usblist overview-tab-view");\
    $("#overview-phone-mobile").hide();\
  }\
  else{\
    imgSrc.attr("src", "img/look_4/overview/overview-background-bot.jpg");\
    overviewCols.removeClass("removed-phone").addClass("added-phone");\
    $(".c4of3").removeClass("usblist overview-tab-view");\
    $("#overview-phone-mobile").show();\
  }\
  });\
</script>\
\
<div class="overview-image-container">\
  <div class="clearfix">\
    <div class="overview-image-top-left">\
      <div id ="overview-div-class" class="overview-top-left-status okay bad hide">\
        <span id="overview-btn-connection">');  ngx.print(T"No connection"); ngx.print('</span>\
        <div class="line okay no-mobile">\
          <img id= "overview-src-line" src="img/look_4/overview/red_line.png">\
        </div>\
      </div>\
      <div class="line line-vertical line-long okay mobile hidden-lg hidden-md hidden-sm"></div>\
      <div class="line line-horizontal line-long okay mobile hidden-xs"></div>\
      <div class="line-text okay overview-speed-div" style="display:none;">\
        <span class="downspeed" id="overview-lbl-downspeed"></span>\
        <span class="upspeed" id="overview-lbl-upspeed"></span>\
      </div>\
    </div>\
    <div class="overview-image-top-right" id="overview-img-gateway">\
      <a href="#">\
        <div class="router-rectangle"></div>\
      </a>\
      <img src="');  ngx.print(icon); ngx.print('" usemap="#routerBot" alt="Router">\
    </div>\
  </div>\
  <div class="overview-image-bottom-center">\
    <img src="">\
  </div>\
</div>\
\
<!-- START MOBILE-->\
<div class="row no-margin-left-right" id="overview">\
    <div class="col-xs-12 hidden-sm hidden-md hidden-lg col-md-4 col-sm-4 col-lg-4 no-padding-left overview-padding-right-lg wifi-list">\
        <div class="overview-headline-number oh3of3 hidden-xs">\
            <span class="number">');  ngx.print(wifiActiveCount); ngx.print('</span>\
        </div>\
    <div class="overview-headline oh1of3">\
        <a href="#" style="text-decoration: none;" id ="overview-href-mobwifi">\
            <span id="overview-span-mWificount" class="number hidden-md hidden-sm hidden-lg">');  ngx.print(wifiActiveCount); ngx.print('</span>\
            <!-- TODO wifi on/off has to be implemented NG-64200 -->\
            <img src="img/look_4/overview/wifi.png" alt="WiFI" />\
            <span>');  ngx.print(T"Wi-Fi"); ngx.print('</span>\
        </a>\
    </div>\
\
    <a href="#" id="overview-href-mobpsm">\
        <div class="row-overview greyBackground icon-schedule overview-text-wrap">\
        ');  if overviewlinkParam.scheduleRuleON == "1" or overviewlinkParam.scheduleRuleOFF == "1" then   ngx.print('\
        <span>');  ngx.print(T"Schedule is on"); ngx.print('</span>\
        ');  else   ngx.print('\
           <span>');  ngx.print(T"Schedule is off"); ngx.print('</span>\
        ');  end   ngx.print('\
        </div>\
    </a>\
    <a href="#" id="overview-href-mobwps">\
        <div class="row-overview greyBackground icon-wps overview-text-wrap">\
            ');  if tonumber(overviewlinkParam["wps24State"]) == 1 and  tonumber(overviewlinkParam["wps5State"]) == 1 then   ngx.print('\
            <p class="overview-text-wrap"><span>');  ngx.print(T"WPS is active"); ngx.print('</span></p>\
            ');  else  ngx.print('\
            <p class="overview-text-wrap"><span>');  ngx.print(T"WPS is Inactive"); ngx.print('</span></p>\
            ');  end   ngx.print('\
        </div>\
    </a>\
    ');  local ipv4, ipv6, MACAddress
    for i,v in pairs(wifiList) do
      if i > 3 then
        break
      end
      iconType = v.DeviceType ~= "" and v.DeviceType or "smartphone"
      if v.State == "1" then
        ipv4, ipv6 = splitIP(v.IPAddress)
        MACAddress = v.MACAddress:lower()
      ngx.print('\
\
    <div class="new-overview-row-wrap sub-row-active">\
      <div id = "overview-p-wifiActiveDevice');  ngx.print(i); ngx.print('">\
        <div class="row-overview mob-row-overview icon-');  ngx.print(iconType); ngx.print('-with-wifi new-row-overview">\
          <div class="text"><span class="overview-text-wrap overview-text-width overview-text-normal">');  ngx.print(v.FriendlyName); ngx.print('</span><span class="overview-text-normal">');  ngx.print(v.radio); ngx.print('</span></div>\
          <div class="img-signal"><img src="img/look_4/overview/');  ngx.print(v.radioSignalIcon); ngx.print('" alt=""></div>\
          <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
          <div class="arrow_box">\
            <p id = "overview-p-wifiDeviceName');  ngx.print(i); ngx.print('">');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(v.FriendlyName); ngx.print('</p>\
            ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
            <p id = "overview-p-wifiMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</p>\
            ');  end  ngx.print('\
            <p id = "overview-p-wifiIPvfour');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</p>\
            <p id = "overview-p-wifiIPvsix');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</p>\
          </div>\
       </div>\
       <div class="mobile-btn-row new-row-overview sub-row row-overview info-row hidden">\
         <div class="icon-wrap">\
           <div id="info-button" class="icon-sub-row info info-button"><img src="img/look_4/icons/button-info-desktop.png"></div>\
           <div class="icon-sub-row edit"> <input class="button button-edit edit-wifi-device" mac="');  ngx.print(v.MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(v.FriendlyName); ngx.print('" id = "overview-btn-wifiEdit');  ngx.print(i); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal"></div>\
           <div class="icon-sub-row link mac-btn-right hidden" id ="mob-btn-right');  ngx.print(i); ngx.print('"><img src="img/look_4/buttons/button-right.png"></div>\
         </div>\
       </div>\
     </div>\
    </div>\
\
    ');  else  ngx.print('\
    <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' op40 overview-text-wrap">');  ngx.print(v.FriendlyName); ngx.print('</div>\
    ');  end
    end
    if #wifiList > 3 then  ngx.print('\
    <div id="lang-string" class="foldable-container-title smallArrow">\
      <div style="display: block;" class="fold-title">\
        <p><span class="overview-text-wrap overview-text-normal">');  ngx.print(format("%s (%d %s)", T"Show more",#wifiList - 3, T"devices")); ngx.print('</span></p>\
      </div>\
      <div class="unfold-title" style="display: none;">\
        <p><span class="overview-text-wrap overview-text-normal" id = "overview-span-hidedevices">');  ngx.print(T"Hide Devices"); ngx.print('</span></p>\
      </div>\
    </div>\
    <div class="foldable-container-content" style="display: none;">\
    ');  
    for i=4, #wifiList do
      iconType = wifiList[i].DeviceType ~= "" and wifiList[i].DeviceType or "smartphone"
      if wifiList[i].State == "1" then
        ipv4, ipv6 = splitIP(wifiList[i].IPAddress)
        MACAddress = wifiList[i].MACAddress:lower()
      ngx.print('\
	<div class="new-overview-row-wrap sub-row-active">\
          <div id = "overview-p-ethActiveDevice');  ngx.print(i); ngx.print('">\
	    <div class="row-overview mob-row-overview icon-');  ngx.print(iconType); ngx.print('-with-wifi new-row-overview">\
	      <div class="text"><span class="overview-text-wrap overview-text-width overview-text-normal">');  ngx.print(wifiList[i].FriendlyName); ngx.print('</span><span class="overview-text-normal">');  ngx.print(wifiList[i].radio); ngx.print('</span></div>\
	      <div class="img-signal"><img src="img/look_4/overview/');  ngx.print(wifiList[i].radioSignalIcon); ngx.print('" alt=""></div>\
	      <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
	      <div class="arrow_box">\
	        <p id = "overview-p-wifiDeviceName');  ngx.print(i); ngx.print('" >');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(wifiList[i].FriendlyName); ngx.print('</p>\
	        ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
	        <p id = "overview-p-wifiMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</p>\
	        ');  end  ngx.print('\
	        <p id = "overview-p-wifiIPvfour');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</p>\
	        <p id = "overview-p-wifiIPvsix');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</p>\
	      </div>\
	   </div>\
	   <div class="mobile-btn-row new-row-overview sub-row row-overview info-row hidden">\
	     <div class="icon-wrap">\
	       <div id="info-button" class="icon-sub-row info info-button"><img src="img/look_4/icons/button-info-desktop.png" alt=""></div>\
	       <div class="icon-sub-row edit"> <input class="button button-edit edit-wifi-device" id = "overview-btn-wifiEdit');  ngx.print(i); ngx.print('" mac="');  ngx.print(wifiList[i].MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(wifiList[i].FriendlyName); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal"></div>\
               <div class="icon-sub-row link mac-btn-right hidden" id ="mob-wifibtn-right');  ngx.print(i); ngx.print('"><img src="img/look_4/buttons/button-right.png"></div>\
	   </div>\
	 </div>\
       </div>\
     </div>\
\
      ');  else  ngx.print('\
	<div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview op40 overview-text-wrap" id="overview-div-wifiDisconDevice');  ngx.print(i); ngx.print('">');  ngx.print(wifiList[i].FriendlyName); ngx.print('</div>\
      ');  end
     end  ngx.print('\
    </div>\
    ');  end  ngx.print('\
  </div>\
  <div class="col-xs-12 hidden-sm hidden-md hidden-lg col-md-4 col-sm-4 col-lg-4 overview-padding-left-right-lg">\
    <div class="overview-headline-number oh3of3 hidden-xs" style="padding-left: 15px;">\
      <span class="number" id="overview-span-ehtcount" >');  ngx.print(ethActiveCount); ngx.print('</span>\
    </div>\
    <div class="overview-headline oh2of3">\
      <span class="number hidden-md hidden-sm hidden-lg" id="overview-span-mEhtcount">');  ngx.print(ethActiveCount); ngx.print('</span>\
      <img src="img/look_4/overview/network.png" alt="');  ngx.print(T"Network"); ngx.print('" />\
      <span>');  ngx.print(T"Network"); ngx.print('</span>\
    </div>\
    ');  
    for i,v in pairs(ethList) do
      iconType = v.DeviceType ~= "" and v.DeviceType or "laptop"
      if v.State == "1" then
        ipv4, ipv6 = splitIP(v.IPAddress)
        MACAddress = v.MACAddress:lower()
      ngx.print('\
\
    <div class="new-overview-row-wrap sub-row-active">\
      <div id = "overview-p-ethActiveDevice');  ngx.print(i); ngx.print('">\
        <div class="row-overview mob-row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview">\
          <div class="text"><span class="overview-text-wrap overview-text-width overview-text-normal">');  ngx.print(v.FriendlyName); ngx.print('</span></div>\
          <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
          <div class="arrow_box">\
            <p id = "overview-p-ethDeviceName');  ngx.print(i); ngx.print('" >');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(v.FriendlyName); ngx.print('</p>\
            ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
            <p id = "overview-p-ethMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</p>\
            ');  end  ngx.print('\
            <p id = "overview-p-ethIPvfour');  ngx.print(i); ngx.print('" >');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</p>\
            <p id = "overview-p-ethIPvsix');  ngx.print(i); ngx.print('" >');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</p>\
          </div>\
        </div>\
        <div class="mobile-btn-row new-row-overview sub-row row-overview info-row hidden">\
          <div class="icon-wrap">\
            <div id="info-button" class="icon-sub-row info info-button"><img src="img/look_4/icons/button-info-desktop.png" alt=""></div>\
            <div class="icon-sub-row edit"> <input class="button button-edit edit-wifi-device" id = "overview-btn-ethEdit');  ngx.print(i); ngx.print('" mac="');  ngx.print(v.MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(v.FriendlyName); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal"></div>\
            <div class="icon-sub-row link mac-btn-right hidden" id ="mob-btn-right');  ngx.print(i); ngx.print('"><img src="img/look_4/buttons/button-right.png"></div>\
          </div>\
        </div>\
      </div>\
    </div>\
\
    ');  else  ngx.print('\
      <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview op40 overview-text-wrap" id = "overview-div-ethDisconDevice');  ngx.print(i); ngx.print('">');  ngx.print(v.FriendlyName); ngx.print('</div>\
    ');  end
    end
    if vdf_helper.getVariant() == "NZ" then
      profileList = content_helper.getMatchedContent("rpc.mmpbx.profile.", { networkName = "sip_net", sipRegisterState = "Registered" })
    else
      profileList = content_helper.convertResultToObject("uci.mmpbxrvsipnet.profile.",
                     proxy.get("uci.mmpbxrvsipnet.profile."))
    end
      ngx.print('\
  </div>\
          <div class="col-xs-12 hidden-sm hidden-md hidden-lg col-md-4 col-sm-4 col-lg-4 no-padding-right overview-padding-left-lg">\
    <div class="overview-headline-number oh3of3 hidden-xs" style="padding-left: 30px;">\
      <span class="number" id ="overview-span-phonecount">\
      ');  if InternalUSBDevice and USBHubDetected then  ngx.print('\
        ');  ngx.print((#USBDeviceDetails - 2)); ngx.print('\
      ');  elseif InternalUSBDevice or USBHubDetected then  ngx.print('\
        ');  ngx.print((#USBDeviceDetails - 1)); ngx.print('\
      ');  else  ngx.print('\
        ');  ngx.print(#USBDeviceDetails); ngx.print('\
      ');  end  ngx.print('\
      </span>\
    </div>\
    <div class="overview-headline oh3of3">\
      <a href="#" style="text-decoration: none;" id = "overview-href-mobusb">\
        <span class="number hidden-md hidden-sm hidden-lg" id ="overview-span-usbcount">\
        ');  if InternalUSBDevice and USBHubDetected then  ngx.print('\
          ');  ngx.print((#USBDeviceDetails - 2)); ngx.print('\
        ');  elseif InternalUSBDevice or USBHubDetected then  ngx.print('\
          ');  ngx.print((#USBDeviceDetails - 1)); ngx.print('\
        ');  else  ngx.print('\
          ');  ngx.print(#USBDeviceDetails); ngx.print('\
        ');  end  ngx.print('</span>\
          <img src="img/look_4/overview/usb.png" alt="Phone" height="30px"/>\
        <span>');  ngx.print(T"USB"); ngx.print('</span>\
      </a>\
    </div>\
    <a href="#" id= "overview-href-mobusb">\
      <div class="row-overview greyBackground icon-sharing overview-text-wrap">\
         ');  if USBData["sharingEnabled"] == "1" then   ngx.print('\
        <p class="overview-text-wrap"><span>');  ngx.print(T"Sharing is on"); ngx.print('</span></p>\
        ');  else   ngx.print('\
         <p class="overview-text-wrap"><span>');  ngx.print(T"Sharing is off"); ngx.print('</span></p>\
        ');  end   ngx.print('\
      </div>\
    </a>\
    ');  for _, v in ipairs(USBDeviceDetails) do

      -- Filtering out USB hub which has device class of 09.
      if v.Type ~= "09" then

        -- Check if device type is printer
        if v.Type == "07" then   ngx.print('\
          <div class="">\
            <div class="row-overview icon-printer new-row-overview overview-text-wrap">\
              <div class="text">');  ngx.print(v.Name); ngx.print('</div>\
            </div>\
          </div>\
        ');  
        -- Check if device is a USB stick
        elseif v.Type == "08" then  ngx.print('\
          <div class="last">\
            <div class="row-overview icon-hard-drive-new new-row-overview overview-text-wrap">\
              <div class="text">');  ngx.print(format("%s", v.Name)); ngx.print('</div>\
            </div>\
          </div>\
        ');  end  ngx.print('\
      ');  end  ngx.print('\
    ');  end  ngx.print('\
  </div>\
  <div class="col-xs-12 hidden-sm hidden-md hidden-lg col-md-4 col-sm-4 col-lg-4 no-padding-right overview-padding-left-lg" id="overview-phone-mobile">\
    <div class="overview-headline-number oh3of3 hidden-xs" style="padding-left: 30px;">\
      <span class="number" id ="overview-span-phonecount">');  ngx.print(#profileList); ngx.print('</span>\
    </div>\
    <div class="overview-headline oh3of3">\
      <a href="#" style="text-decoration: none;" id = "overview-href-mobphone">\
        <span class="number hidden-md hidden-sm hidden-lg" id ="overview-span-mphonecount">');  ngx.print(#profileList); ngx.print('</span>\
        <img src="img/look_4/overview/phone.png" alt="Phone" />\
        <span>');  ngx.print(T"Phone"); ngx.print('</span>\
      </a>\
    </div>\
    <a href="#" id= "overview-href-mobrngshd">\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
        <div class="row-overview greyBackground icon-schedule overview-text-wrap">\
         ');  if overviewlinkParam["ringingScheduleStatus"] == "1" then   ngx.print('\
           <p class="overview-text-wrap"><span>');  ngx.print(T(ringSchedule .. " is on")); ngx.print('</span></p>\
         ');  else   ngx.print('\
           <p class="overview-text-wrap"><span>');  ngx.print(T(ringSchedule .. " is off")); ngx.print('</span></p>\
        ');  end   ngx.print('\
      </div>\
    ');  end  ngx.print('\
    </a>\
    <div class="phonelist">\
        ');  for i,v in pairs(profileList) do  ngx.print('\
        <a href="#" style="text-decoration:none;">\
          <div class="row-overview icon-u');  ngx.print(i); ngx.print('" id = "overview-div-tprofile');  ngx.print(i); ngx.print('">');  ngx.print(v.uri); ngx.print('</div>\
        </a>\
        ');  end  ngx.print('\
      </div>\
      </div>\
    </div>\
<!-- END MOBILE-->\
\
<!-- START DESKTOP-->\
<div class="columns no-mobile">\
  <div class="clearfix">\
    <div class="column c1of3 column-wifi ">\
      <div class="overview-headline overview-number oh1of3">\
        <a style="text-decoration: none;"><span id="overview-mWificount-info" ');  if wifiStatus["wifi24stat"] == "0" and wifiStatus["wifi5stat"] == "0" then   ngx.print(' style="color:gray" ');  end  ngx.print(' >');  ngx.print(wifiActiveCount); ngx.print('</span></a>\
      </div>\
      <div class="overview-headline oh1of3">\
        <a href="#" style="text-decoration: none;" id="overview-href-wifi">\
        <img src="img/look_4/overview/wifi.png" alt="WiFI">\
        <span>');  ngx.print(T"Wi-Fi"); ngx.print('</span>\
        </a>\
      </div>\
      <a href="#" id="overview-href-psm">\
      <div class="row-overview greyBackground icon-schedule overview-text-wrap">\
          ');  if overviewlinkParam.scheduleRuleON == "1" or overviewlinkParam.scheduleRuleOFF == "1"  then  ngx.print('\
        <span>');  ngx.print(T"Schedule is on"); ngx.print('</span>\
         ');  else   ngx.print('\
          <span>');  ngx.print(T"Schedule is off"); ngx.print('</span>\
         ');  end   ngx.print('\
      </div>\
      </a>\
      <div class="divider-full"></div>\
      <a href="#" id="overview-href-wps">\
      <div class="row-overview greyBackground icon-wps overview-text-wrap">\
        ');  if tonumber(overviewlinkParam["wps24State"]) == 1 and  tonumber(overviewlinkParam["wps5State"]) == 1 then  ngx.print('\
          <span>');  ngx.print(T"WPS is active"); ngx.print('</span>\
        ');  else  ngx.print('\
          <span>');  ngx.print(T"WPS is Inactive"); ngx.print('</span>\
        ');  end  ngx.print('\
      </div>\
	  <div class="divider-full"></div>\
      </a>\
      ');  
        for i,v in pairs(wifiList) do
          if i > 3 then
            break
          end
          iconType = v.DeviceType ~= "" and v.DeviceType or "smartphone"
          if v.State == "1" then
            ipv4, ipv6 = splitIP(v.IPAddress)
            MACAddress = v.MACAddress:lower()
        ngx.print('\
        <div class="row-overview icon-');  ngx.print(iconType); ngx.print('-with-wifi halfLineHeight new-row-overview">\
          <div class="center-wrapper" id = "overview-p-wifiActiveDevice');  ngx.print(i); ngx.print('">\
            <div class="text small-text">');  ngx.print(v.FriendlyName); ngx.print(' <span class="overview-text-normal">');  ngx.print(v.radio); ngx.print('</span></div>\
            <div class="img-signal"><img src="img/look_4/overview/');  ngx.print(v.radioSignalIcon); ngx.print('" alt=""></div>\
            <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
          </div>\
          <div class="arrow_box">\
            <span id = "overview-p-wifiDeviceName');  ngx.print(i); ngx.print('">');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(v.FriendlyName); ngx.print('</span><br/>\
            ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
            <span id = "overview-p-wifiMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</span><br/>\
            ');  end  ngx.print('\
            <span id = "overview-p-wifiIPvfour');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</span><br/>\
            <span id = "overview-p-wifiIPvsix');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</span>\
          </div>\
        </div>\
\
	<div class="edit-btn-row info-row hidden">\
          <div class="info-button">\
          </div>\
	  <input class="button button-edit edit-wifi-device" mac="');  ngx.print(v.MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(v.FriendlyName); ngx.print('" id = "overview-btn-wifiEdit');  ngx.print(i); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal">\
	  <div id ="button-right');  ngx.print(i); ngx.print('" class="button-right mac-btn-right hidden"></div>\
	</div>\
	<div class="divider-full"></div>\
    ');  else  ngx.print('\
      <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview op40 overview-text-wrap">');  ngx.print(v.FriendlyName); ngx.print('</div>\
      <div class="divider-full"></div>\
    ');  end
    end
    if #wifiList > 3 then  ngx.print('\
    <div class="foldable-container-title smallArrow">\
      <div class="fold-title">\
        <span>');  ngx.print(format("%s (%d %s)", T"Show more",#wifiList - 3, T"devices")); ngx.print('</span>\
      </div>\
      <div class="unfold-title" style="display:none;">\
        <span id = "overview-span-hidedevices">');  ngx.print(T"Hide Devices"); ngx.print('</span>\
      </div>\
    </div>\
    <div class="foldable-container-content" style="display:none;">\
    ');  
    for i=4, #wifiList do
      iconType = wifiList[i].DeviceType ~= "" and wifiList[i].DeviceType or "smartphone"
      if wifiList[i].State == "1" then
      ipv4, ipv6 = splitIP(wifiList[i].IPAddress)
      MACAddress = wifiList[i].MACAddress:lower()
      ngx.print('\
    <div class="divider-full"></div>\
    <div class="row-overview icon-');  ngx.print(iconType); ngx.print('-with-wifi halfLineHeight new-row-overview">\
      <div class="center-wrapper" id = "overview-p-ethActiveDevice');  ngx.print(i); ngx.print('">\
        <div class="text small-text">');  ngx.print(wifiList[i].FriendlyName); ngx.print(' ');  ngx.print(wifiList[i].radio); ngx.print('</div>\
        <div class="img-signal"><img src="img/look_4/overview/');  ngx.print(wifiList[i].radioSignalIcon); ngx.print('" alt=""></div>\
        <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
      </div>\
      <div class="arrow_box">\
        <span id = "overview-p-wifiDeviceName');  ngx.print(i); ngx.print('" >');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(wifiList[i].FriendlyName); ngx.print('</span><br/>\
        ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
        <span id = "overview-p-wifiMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</span><br/>\
        ');  end  ngx.print('\
        <span id = "overview-p-wifiIPvfour');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</span><br/>\
        <span id = "overview-p-wifiIPvsix');  ngx.print(i); ngx.print('">');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</span>\
      </div>\
    </div>\
    <div class="edit-btn-row info-row hidden">\
      <div class="info-button">\
      </div>\
      <input class="button button-edit edit-wifi-device" id = "overview-btn-wifiEdit');  ngx.print(i); ngx.print('" mac="');  ngx.print(wifiList[i].MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(wifiList[i].FriendlyName); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal">\
      <div id ="button-right');  ngx.print(i); ngx.print('" class="button-right mac-btn-right hidden"></div>\
    </div>\
      ');  else  ngx.print('\
        <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview op40 overview-text-wrap" id="overview-div-wifiDisconDevice');  ngx.print(i); ngx.print('">\
          ');  ngx.print(wifiList[i].FriendlyName); ngx.print('\
        </div>\
      ');  end
      end  ngx.print('\
  </div>\
    ');  end  ngx.print('\
</div>\
<div class="column c2of3">\
  <div class="overview-headline overview-number oh2of3"><span id = "overview-span-mEhtcount" style="padding-left: 15px">');  ngx.print(ethActiveCount); ngx.print('</span></div>\
    <div class="overview-headline oh2of3">\
      <img src="img/look_4/overview/network.png" alt="Network">\
      <span>');  ngx.print(T"Network"); ngx.print('</span>\
    </div>\
    ');  
    for i,v in pairs(ethList) do
      iconType = v.DeviceType ~= "" and v.DeviceType or "laptop"
      if v.State == "1" then
        ipv4, ipv6 = splitIP(v.IPAddress)
        MACAddress = v.MACAddress:lower()
      ngx.print('\
\
    <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview">\
      <div class="center-wrapper" id = "overview-p-ethActiveDevice');  ngx.print(i); ngx.print('">\
        <div class="text small-text">');  ngx.print(v.FriendlyName); ngx.print('</div>\
        <div class="img-dropdown"><img src="img/look_4/icons/arrows/arrow-down.png" alt=""></div>\
      </div>\
      <div class="arrow_box">\
        <span id = "overview-p-ethDeviceName');  ngx.print(i); ngx.print('" >');  ngx.print(T"Name"); ngx.print(': ');  ngx.print(v.FriendlyName); ngx.print('</span><br/>\
        ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
        <span id = "overview-p-ethMACAddress');  ngx.print(i); ngx.print('">');  ngx.print(T"MAC"); ngx.print(': ');  ngx.print(MACAddress); ngx.print('</span><br/>\
        ');  end  ngx.print('\
        <span id = "overview-p-ethIPvfour');  ngx.print(i); ngx.print('" >');  ngx.print(T"IPv4"); ngx.print(': ');  ngx.print(ipv4); ngx.print('</span><br/>\
        <span id = "overview-p-ethIPvsix');  ngx.print(i); ngx.print('" >');  ngx.print(T"IPv6"); ngx.print(': ');  ngx.print(ipv6); ngx.print('</span>\
      </div>\
    </div>\
\
    <div class="edit-btn-row info-row hidden">\
      <div id = "info-button" class="info-button">\
      </div>\
      <div>\
        <input class="button button-edit edit-wifi-device" id = "overview-btn-ethEdit');  ngx.print(i); ngx.print('" mac="');  ngx.print(v.MACAddress); ngx.print('" dtype="');  ngx.print(iconType); ngx.print('" dname="');  ngx.print(v.FriendlyName); ngx.print('" type="button" data-toggle="modal" data-target="#editOverviewModal" />\
      </div>\
      <div id ="wifi-button-right');  ngx.print(i); ngx.print('" class="button-right mac-btn-right hidden">\
      </div>\
    </div>\
	<div class="divider-full"></div>\
  ');  else  ngx.print('\
    <div class="row-overview icon-');  ngx.print(iconType); ngx.print(' new-row-overview op40 overview-text-wrap" id = "overview-div-ethDisconDevice');  ngx.print(i); ngx.print('">');  ngx.print(v.FriendlyName); ngx.print('</div>\
  ');  end
    end
    if vdf_helper.getVariant() == "NZ" then
      profileList = content_helper.getMatchedContent("rpc.mmpbx.profile.", { networkName = "sip_net", sipRegisterState = "Registered" })
      profileActiveCount = #profileList
    else
      profileList = content_helper.convertResultToObject("uci.mmpbxrvsipnet.profile.",
                     proxy.get("uci.mmpbxrvsipnet.profile."))
      profileActiveCount = (tonumber(profileList[1].enabled) or 0 ) + (tonumber(profileList[2].enabled) or 0)
    end
    ngx.print('\
  </div>\
  <div class="column c4of3">\
    <div class="overview-headline overview-number oh3of3">\
      <a style="text-decoration: none;"><span id = "overview-span-usbcount">\
      ');  if InternalUSBDevice  and USBHubDetected then  ngx.print('\
        ');  ngx.print((#USBDeviceDetails - 2)); ngx.print('\
      ');  elseif InternalUSBDevice  or USBHubDetected then  ngx.print('\
        ');  ngx.print((#USBDeviceDetails - 1)); ngx.print('\
      ');  else  ngx.print('\
        ');  ngx.print(#USBDeviceDetails); ngx.print('\
      ');  end  ngx.print('\
      </span></a>\
    </div>\
    <div class="overview-headline oh3of3">\
      <a href="#" style="text-decoration: none;" id = "overview-href-usb">\
        <img src="img/look_4/overview/usb.png" alt="USB" width="30" height="30">\
        <span>');  ngx.print(T"USB"); ngx.print('</span>\
      </a>\
    </div>\
    <div class="row-overview greyBackground icon-sharing overview-text-wrap">\
    ');  if USBData["sharingEnabled"] == "1" then   ngx.print('\
      <span>');  ngx.print(T"Sharing is on"); ngx.print('</span>\
    ');  else   ngx.print('\
       <span>');  ngx.print(T"Sharing is off"); ngx.print('</span>\
    ');  end   ngx.print('\
    </div>\
    ');  for _, v in ipairs(USBDeviceDetails) do

      -- Filtering out USB hub which has device class of 09.
      if v.Type ~= "09" then

        -- Check if device type is printer
        if v.Type == "07" then  ngx.print('\
          <div class="">\
            <div class="row-overview icon-printer new-row-overview overview-text-wrap">\
              <div class="text">');  ngx.print(v.Name); ngx.print('</div>\
            </div>\
          </div>\
        ');  
        -- Check if device is a USB stick
        elseif v.Type == "08" then  ngx.print('\
          <div class="last">\
            <div class="row-overview icon-hard-drive-new new-row-overview overview-text-wrap">\
              <div class="text">');  ngx.print(format("%s", v.Name)); ngx.print('</div>\
            </div>\
          </div>\
        ');  end  ngx.print('\
      ');  end  ngx.print('\
    ');  end  ngx.print('\
  </div>\
  <div class="column c3of3">\
    <div class="overview-headline overview-number oh3of3">\
      <a style="text-decoration: none;"><span id = "overview-span-mphonecount" ');  if profileActiveCount == 0 then  ngx.print(' style = "color:gray" ');  end  ngx.print('>');  ngx.print(profileActiveCount); ngx.print('</span></a>\
    </div>\
    <div class="overview-headline oh3of3">\
      <a href="#" style="text-decoration: none;" id = "overview-href-phone">\
        <img src="img/look_4/overview/phone.png" alt="Phone">\
        <span>');  ngx.print(T"Phone"); ngx.print('</span>\
      </a>\
    </div>\
    ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
    <a href="#" id= "overview-href-rngshd">\
    ');  end  ngx.print('\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
      <div class="row-overview greyBackground icon-schedule overview-text-wrap">\
      ');  if overviewlinkParam["ringingScheduleStatus"] == "1" then   ngx.print('\
        <span>');  ngx.print(T(ringSchedule .. " is on")); ngx.print('</span>\
      ');  else   ngx.print('\
         <span>');  ngx.print(T(ringSchedule .. " is off")); ngx.print('</span>\
      ');  end   ngx.print('\
      </div>\
    ');  end  ngx.print('\
    ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
    </a>\
    ');  end  ngx.print('\
    <div class="divider-full phonelist">\
      ');  for i, v in pairs(profileList) do
        if v.enabled == "1" or v.enable == "true" then   ngx.print('\
          <a href="#">\
          ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
            <div class="row-overview icon-smartphone new-row-overview" id = "overview-div-tprofile');  ngx.print(i); ngx.print('">\
              ');  ngx.print(v.uri); ngx.print('\
            </div>\
          ');  else  ngx.print('\
            <div class="row-overview icon-u');  ngx.print(i); ngx.print(' new-row-overview" id = "overview-div-tprofile');  ngx.print(i); ngx.print('">\
              ');  ngx.print(v.uri); ngx.print('\
            </div>\
            </a>\
          ');  end  ngx.print('\
        ');  end  ngx.print('\
      ');  end  ngx.print('\
    </div>\
  </div>\
</div>\
<!-- END -->\
<script>\
var T = {\
   "ADSL" : "');  ngx.print(T"ADSL"); ngx.print('",\
   "VDSL" : "');  ngx.print(T"VDSL"); ngx.print('",\
   "DSL" : "');  ngx.print(T"DSL"); ngx.print('",\
   "Fiber" : "');  ngx.print(T"Fibre"); ngx.print('",\
   "Mobile" : "');  ngx.print(T"Mobile"); ngx.print('",\
   "3G / 4G" : "');  ngx.print(T"3G / 4G"); ngx.print('",\
   "3G - Vodafone" : "');  ngx.print(T"3G - Vodafone"); ngx.print('",\
   "4G - Vodafone" : "');  ngx.print(T"4G - Vodafone"); ngx.print('"\
 }\
var variant = "');  ngx.print(vdf_helper.getVariant()); ngx.print('"\
$.get("/modals/overview.lp?dslstatus=true",function(response, statusTxt, xhr) {\
  if (response.backupStatus === "BackUpActive") {\
    if(variant == "VF-UK") {\
      if(response.wwanMode == "umts") {\
        $("#overview-btn-connection").text(T["3G - Vodafone"]);\
      }\
      else if(response.wwanMode == "lte") {\
        $("#overview-btn-connection").text(T["4G - Vodafone"]);\
      }\
      else {\
        $("#overview-div-class").addClass("bad").removeClass("hide");\
      }\
    }\
    else if(variant == "VHA") {\
      $("#overview-btn-connection").text(T["3G / 4G"]);\
    }\
    else {\
      $("#overview-btn-connection").text(T["Mobile"]);\
    }\
    $("#overview-div-class").removeClass("bad hide");\
    $("#overview-src-line").attr("src", "img/look_4/overview/green_line.png");\
    $(".overview-speed-div").css("display", "none");\
  } else if ((response.type === "ADSL" || response.type === "VDSL") && (response.PPPState === "connected" || response.wanIP.length !== 0) && response.status === "Up") {\
    if (variant == "VF-UK") {\
      $("#overview-btn-connection").text(response.type);\
    }\
    else {\
      $("#overview-btn-connection").text(T["DSL"]);\
    }\
    $("#overview-div-class").removeClass("bad hide").addClass("dsl");\
    $("#overview-src-line").attr("src", "img/look_4/overview/green_line_long.png");\
    $(".overview-speed-div").css("display", "");\
    var downSpeed = parseFloat( response.downspeed/ 1000).toFixed(1);\
    var upSpeed =  parseFloat( response.upspeed/ 1000).toFixed(1);\
    $("#overview-lbl-downspeed").text(downSpeed + " Mbit/s");\
    $("#overview-lbl-upspeed").text(upSpeed + " Mbit/s");\
  } else if (response.type === "ETH"  && response.status === "up" && response.wanIP.length !== 0) {\
    $("#overview-btn-connection").text(T["Fiber"]);\
    $("#overview-div-class").removeClass("bad hide");\
    $("#overview-src-line").attr("src", "img/look_4/overview/green_line.png");\
    $(".overview-speed-div").css("display", "none");\
  } else {\
    $("#overview-div-class").addClass("bad").removeClass("hide");\
  }\
});\
</script>\
<!-- Edit Popup Modal-->\
<div class="modal fade" id="editOverviewModal" role="dialog" data-backdrop = "static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <!--<button type="button" class="close" data-dismiss="modal">&times;</button>-->\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">');  ngx.print(T"Edit"); ngx.print('</p>\
            </div>\
          </div>\
          <div class="form-group icon-row">\
            <div class="col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right">\
              <label for="select icon" class="control-label">');  ngx.print(T"Select Icon"); ngx.print('</label>\
            </div>\
            <div class="col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right btn-wrap-mobile">\
              <div class="icon-wrapper id="oviewmodal-icon-name" clearfix">\
                <div class="icon" icon-name="console">\
                  <div class="black"><img src="img/look_4/device-icons/game.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/game_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="laptop">\
                  <div class="black"><img src="img/look_4/device-icons/laptop.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/laptop_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="smartphone">\
                  <div class="black"><img src="img/look_4/device-icons/smartphone.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/smartphone_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="playstation">\
                  <div class="black"><img src="img/look_4/device-icons/playstation.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/playstation_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="printer">\
                  <div class="black"><img src="img/look_4/device-icons/printer.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/printer_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="router">\
                  <div class="black"><img src="img/look_4/device-icons/vox.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/vox_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="tablet">\
                  <div class="black"><img src="img/look_4/device-icons/tablet.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/tablet_active.png" alt=""></div>\
                </div>\
                <div class="icon" icon-name="tv">\
                  <div class="black"><img src="img/look_4/device-icons/tv.png" alt=""></div>\
                  <div class="red"><img src="img/look_4/device-icons/tv_active.png" alt=""></div>\
                </div>\
              </div>\
            </div>\
          </div>\
          <div class="form-group name-row">\
            <div class="col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right">\
              <label for="Name" class="control-label">');  ngx.print(T"Name"); ngx.print('</label>\
            </div>\
            <div class="col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right">\
              <input type="text" id = "oviewmodal-txt-name" name="device-name">\
            </div>\
          </div>\
          <div class="form-group modal-footer-overview">\
            <div class="col-sm-7 col-md-7">\
              <div class="modal-footer1">\
                <div class="articlediv hide" id="overview_Error_Message">\
                  <div class="message-arrowbox-overview">\
                      <p class="success-info"></p>\
                  </div>\
                </div>\
              </div>\
            </div>\
            <div class="col-sm-5 col-md-5">\
              <input class="button button-apply save mob-button-width" id="oviewmodal-btn-save" value="');  ngx.print(T"Save"); ngx.print('"  type="button" />\
               <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="oviewmodal-btn-cancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
'); 