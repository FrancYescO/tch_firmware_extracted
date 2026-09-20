--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx, string, table = ngx, string, table
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local format = string.format
local maxWPSWaitTime = 120 -- seconds to wait for WPS Pairing
local maxWaitTime = 60 -- seconds to wait for Wifi device Binding
local newWifiDevice, status
local vdf_helper = require("vodafone_helper")

local look_4 = vdf_helper.look4()
local wanColour = vdf_helper.wanColour()
local gatewayName = vdf_helper.productName()

-- Three possible actions available
-- 1. getInternetStatus - Returns the value of l2type, WAN Protocol and
--                        WAN IP Address in json format
-- 2. getWifiDevices    - Returns last Wireless device connected within 1 Minute
--                        window in json format
-- 3. Pairing           - Triggers WPS and returns the result in json format
local action = {
    getInternetStatus = function()
        status = {
            l2type = "uci.wansensing.global.l2type",
            proto  = "rpc.network.interface.@wan.proto",
            wanIP  = "rpc.network.interface.@wan.ipaddr"
        }
        content_helper.getExactContent(status)
        return json.encode(status)
    end,
    getWifiDevices = function(self, waitTime, totalDevices)
        waitTime = waitTime or 0
        local hostPath = "rpc.hosts.host."
        local devices = content_helper.convertResultToObject(hostPath, proxy.get(hostPath))
        local deleteIndex = {}
        for i = 1, #devices do
          if devices[i].State == "0" or not string.match(devices[i].L2Interface, "^wl%d+$") then
            deleteIndex[#deleteIndex+1] = i
          end
        end
        table.sort(deleteIndex, function(a, b) return a > b end)
        for i = 1, #deleteIndex do
          table.remove(devices, deleteIndex[i])
        end
        totalDevices = totalDevices or #devices
        if #devices > totalDevices then
            newWifiDevice = devices[#devices].FriendlyName
            return
        else
            newWifiDevice = ""
        end
        if waitTime > maxWaitTime then
            return
        end
        ngx.sleep(1)
        self:getWifiDevices(waitTime+1, #devices)
        return format('{"newDevice":"%s"}', newWifiDevice)
    end,
    pairing = function(self, waitTime, set)
        waitTime = waitTime or 0
        if not set then
            proxy.set("rpc.wireless.wps_button", "1")
            proxy.apply()
        end
        ngx.sleep(1)
        waitTime = waitTime + 1
        local wpsState = {
          ["2.4GHz"] = "rpc.wireless.ap.@ap0.wps.last_session_state",
          ["5GHz"]   = "rpc.wireless.ap.@ap1.wps.last_session_state",
        }
        content_helper.getExactContent(wpsState)
        if wpsState["2.4GHz"] == "success" or wpsState["5GHz"] == "success" then
            status = "success"
            return
        elseif wpsState["2.4GHz"] ~= "inprogress" and wpsState["5GHz"] ~= "inprogress" then
            status = "error"
            return
        else
            status = "inprogress"
        end
        if waitTime > maxWPSWaitTime then
            return
        end
        self:pairing(waitTime, true)
        return format('{"wpsStatus":"%s"}', status)
    end
}

-- Triggered during 3 scenarios
-- when User sets PPPoE Username and Password (action=SAVE)
-- when User starts the wizard (action=Start)
-- when User finishes the wizard (action=Finish)
if ngx.req.get_method() == "POST" then
    local path = "uci.env.var.activationStatus"
    local postargs = ngx.req.get_post_args()
    ngx.header.content_type = "application/json"
    if postargs.action == "SAVE" then
        local params = {
            uname = postargs.username,
            passwd = postargs.password
        }
        local valids = {
            uname = post_helper.getValidateStringLengthInRange(1, 63),
            passwd = post_helper.getValidateStringLengthInRange(1, 63)
        }
        if content_helper.validateObject(params, valids) then
            params.wansensing_restart = "1"
            local paths = {
                uname = "uci.network.interface.@adsl_wholesales.username",
                passwd = "uci.network.interface.@adsl_wholesales.password",
                wansensing_restart = "rpc.wansensing.restart"
            }
            if vodafone.variant == "NZ" then
                params.wansensing_restart = nil
                paths.wansensing_restart = nil
                paths.uname = "uci.network.interface.@wan.username"
                paths.passwd = "uci.network.interface.@wan.password"
            end
            content_helper.setObject(params, paths)
        end
        ngx.print('{"status":"success"}')
    elseif postargs.action == "Start" then
        status = proxy.get(path)
        status = status and status[1].value
        if status == "Not_Activated" then
            proxy.set(path, "In_Progress")
        end
        ngx.print(format('{"activationStatus":"%s"}', status))
    elseif postargs.action == "Finish" then
        proxy.set(path, "Completed")
        ngx.print(format('{"activationStatus":"%s"}', "Completed"))
    end
    proxy.apply()
    ngx.exit(ngx.HTTP_OK)
end

-- getParam - Query string parameter having 3 possible values
-- getInternetStatus, getWifiDevices, pairing
local getParam = string.untaint(ngx.req.get_uri_args().action)
if getParam then
  ngx.header.content_type = "application/json"
  local result = ""
  if action[getParam] then
      result = action[getParam](action)
  end
  ngx.print(result)
  ngx.exit(ngx.HTTP_OK)
end

local params = {
    ssid = "uci.wireless.wifi-iface.@wl0.ssid",
    wpa  = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
    activationStatus = "uci.env.var.activationStatus"
}
content_helper.getExactContent(params)

if params.activationStatus == "In_Progress" then
    ngx.redirect("/activation-inprogress.lp")
end
  ngx.print('\
\
<!DOCTYPE html>\
<html lang="en" class="no-js">\
\
<head>\
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
    <meta name="description" content="">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <title>\
        ');  ngx.print(T"Gateways"); ngx.print('\
    </title>\
    <link href="img/vdf-icon.png" type="/image/png" rel="icon" />\
    <link href="img/vdf-icon.png" type="/image/png" rel="shortcut icon" />\
    <link rel="stylesheet" type="text/css" href="/css/bootstrap.min.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation-wizard.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation-wizard-responsive.css" />\
    <link rel="stylesheet" type="text/css" href="/css/vodafoneFont.css" />\
    <script src="/js/srp-min.js"></script>\
    <script src="/js/main-min.js"></script>\
    <script type="text/javascript" src="js/footer.js"></script>\
    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->\
    <!-- WARNING: Respond.js doesn\'t work if you view the page via file:// -->\
    <!--[if lt IE 9]>\
    <script src="/js/html5shiv.min.js"></script>\
    <script src="/js/respond.min.js"></script>\
    <![endif]-->\
\
</head>\
\
<body>\
    <div class="section">\
        <div class="container-fluid mobile-padding-left-right-none no-margin-left-right">\
            <div class="row mobile-logo-align mobile-margin-left-right-none">\
                <div class="col-md-12">\
                    <div id="page-rhombus-wrap">\
                        <div id="rhombus-wrap">\
                            <div id="rhombus-logo">\
                                <div id="box-logo">\
                                </div>\
                            </div>\
                        </div>\
                    </div>\
                </div>\
            </div>\
            <div id="activation-content-wrap">\
                <div id="activation-content">\
\
                    <!-- Top Header Container -->\
                    <div id="activation-top">\
                        <!-- Header left column -->\
                        <div id="activation-top-left">\
                            <span class="txt-space">&nbsp;</span><!-- Wizard Title None -->\
                            <h1 class="topbar-steps-content">\
                                  <span class="topbar-steps-states hide">');  ngx.print(T"Start"); ngx.print('</span> <!-- Start -->\
                                  <span class="topbar-steps-connect-cable hide">');  ngx.print(T"Connect the network cable"); ngx.print('</span> <!-- Connect the network cable -->\
                                  <span class="topbar-steps-connect-adsl hide">');  ngx.print(T"Connected to ADSL"); ngx.print('</span>\
                                  <span class="topbar-steps-internet-connect hide">');  ngx.print(T"Internet connection"); ngx.print('</span> <!-- Internet connection -->\
                                  <span class="topbar-steps-wifi-setup hide">');  ngx.print(T"WiFi Setup"); ngx.print('</span> <!-- Wifi Setup -->\
                                  <span class="topbar-steps-wps-pairing hide">');  ngx.print(T"WPS Pairing"); ngx.print('</span> <!-- WPS Pairing -->\
                                  <span class="topbar-steps-connect-phone hide">');  ngx.print(T"Connect your phone"); ngx.print('</span> <!-- Connect Phone -->\
                                  <span class="topbar-steps-finish hide">');  ngx.print(T"Finish"); ngx.print('</span> <!-- Finish -->\
                                </h1>\
                        </div>\
                        <!-- Header Right Column -->\
                        <div id="activation-top-right">\
                            <!-- Header Welcome Text  -->\
                            <h1 class="welcome-text"><span>');  ngx.print(T"Welcome to the installation wizard"); ngx.print('</span></h1>\
                            <!-- Header Start Menu Bar -->\
                            <div id="topBarRightSteps" class="clearfix topbar-steps-start hide">\
                                <div class="fL actv"><span>');  ngx.print(T"Start"); ngx.print('</span>\
                                </div>\
                                <div class="fL"><span>');  ngx.print(T"Internet"); ngx.print('</span>\
                                </div>\
                                <div class="fL"><span>');  ngx.print(T"WiFi"); ngx.print('</span>\
                                </div>\
                                <div class="fL"><span>');  ngx.print(T"Phone"); ngx.print('</span>\
                                </div>\
                                <div class="fL"><span>');  ngx.print(T"Finish"); ngx.print('</span>\
                                </div>\
                            </div>\
                        </div>\
                    </div>\
\
\
                    <!-- Column Container  -->\
\
                    <div id="activation-content-inner" class="clearfix">\
\
                        <!-- Left Column -->\
                        <div id="activation-content-left">\
\
                            <!-- Left column correspondant images -->\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_back_side_router_og.jpg" alt="Router" class="ads-troubleshoot">\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router" class="vdf-box">\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/easybox-2.5_technic_fiber_internet.jpg" alt="Router" class="fiber-internet hide">\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/easybox-2.5_technic_internet.jpg" alt="Router" class="adsl-internet hide">\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/easybox-2.5_technic_wps.jpg" alt="Router" class="wps-pairing hide">\
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/easybox-2.5_technic_phone.jpg" alt="Router" class="connect-phone hide">\
\
                            <!-- Wifi setup -->\
                            <div class="row_wizard wifi-setup hide">\
                                <div class="left hundred">\
                                    <span>');  ngx.print(T"WiFi Name (SSID)"); ngx.print('</span>:\
                                </div>\
                                <br>\
                                <div class="left bold hundred">\
                                    <span id="act-info-ssid">');  ngx.print(params.ssid); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard wifi-setup hide">\
                                <div class="left hundred">\
                                    <span>');  ngx.print(T"WiFi Password (WPA)"); ngx.print('</span>:\
                                </div>\
                                <br>\
                                <div class="left hundred">\
                                    <span class="pw1 pw" id="aw-info-wpa" style="display:none">');  ngx.print(params.wpa); ngx.print('</span>\
                                    <span class="pw1 pw" id="aw-info-wpaMasked">');  ngx.print(string.rep("*", #params.wpa)); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row_wizard wifi-setup hide" style="text-align: right;">\
                                <span>');  ngx.print(T"display characters"); ngx.print('</span>\
                                <input id="aw-chk-showPasswd" class="checkbox show-hide-pw" type="checkbox">\
                                <label for="aw-chk-showPasswd" style="margin-left: 10px;"></label>\
                            </div>\
\
                        </div>\
\
\
                        <!-- Right Column -->\
                        <div id="activation-content-right" class="no-padding-left-right">\
\
                            <!--  Wizard Status and description -->\
                            <div class="row_wizard description wizard-states">\
                                <div class="left">\
                                    <span class="press-start">');  ngx.print(T"Press Start to begin the installation wizard."); ngx.print('</span>\
                                    <span class="check-internet hide">');  ngx.print(T"Checking the setup of your internet connection..."); ngx.print('</span>\
                                    <span class="connection-type hide">');  ngx.print(T"What type of connection do you have?"); ngx.print('</span>\
                                    <span class="check-wifi-binding hide">');  ngx.print(T"Checking WiFi binding"); ngx.print('</span>\
                                    <span class="wps-pairing-ok hide">');  ngx.print(T"WPS Pairing..."); ngx.print('</span>\
                                </div>\
                            </div>\
\
                            <!-- Fibre Connection Detected -->\
                            <div id="conn-err-Fibre" class="hide">\
                                <div class="row_wizard description margin20top">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"Instead of a ADSL Broadband connection we have detected a Fibre connection."); ngx.print('</span>\
                                    </div>\
                                </div>\
                                <div class="row_wizard description">\
                                    <div class="left">\
                                        <input id="err-fibre" class="radio radio-checked" data-id="1" checked="checked" type="radio">\
                                        <label for="err-fibre"></label> <span>');  ngx.print(T"Fibre"); ngx.print('</span>\
                                    </div>\
                                    <div class="left">\
                                        <img src="/img/look_4/icons/icon-error.png" alt="Router"> <span>');  ngx.print(T"ADSL"); ngx.print('</span>\
                                    </div>\
                                </div>\
                                <div class="row_wizard description">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"To proceed Fibre connection select Fibre and next."); ngx.print('</span>\
                                    </div>\
                                </div>\
                            </div>\
\
                            <!-- ADSL Connection Detected -->\
                            <div id="conn-err-ADSL" class="hide">\
                                <div class="row_wizard description margin20top">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"Instead of a Fibre Broadband connection we have detected a ADSL connection."); ngx.print('</span>\
                                    </div>\
                                </div>\
                                <div class="row_wizard description">\
                                    <div class="left">\
                                        <img src="/img/look_4/icons/icon-error.png" alt="Router"> <span>');  ngx.print(T"Fibre"); ngx.print('</span>\
                                    </div>\
                                    <div class="left">\
                                        <input id="err-adsl" class="radio radio-checked" checked="checked" type="radio">\
                                        <label for="err-adsl"></label> <span>');  ngx.print(T"ADSL"); ngx.print('</span>\
                                    </div>\
                                </div>\
                                <div class="row_wizard description">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"To proceed ADSL connection select ADSL and next."); ngx.print('</span>\
                                    </div>\
                                </div>\
                            </div>\
\
                            <!-- Connection Type -->\
                            <div class="row_wizard description connection-type hide">\
                                <div class="left">\
                                    <input id="aw-rad-fibre" class="radio radio-unchecked" value="Fibre" name="connection" type="radio">\
                                    <label for="aw-rad-fibre"></label> <span>');  ngx.print(T"Fibre"); ngx.print('</span> </div>\
                                <div class="left">\
                                    <input id="aw-rad-adsl" class="radio radio-unchecked" value="ADSL" name="connection" type="radio">\
                                    <label for="aw-rad-adsl"></label> <span>');  ngx.print(T"ADSL"); ngx.print('</span> </div>\
                            </div>\
\
                            <!-- Connect the Network Cable -->\
                            <div class="row_wizard description connect-cable hide">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T("Connect one end of the supplied white cable with LAN tags into the FIBRE  port on your " .. gatewayName .. ", as shown in the picture on the left.")); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row_wizard description connect-cable hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T"Connect the other end into the GE port on the Fibre connection point."); ngx.print('</span>\
                                </div>\
                            </div>\
\
                            <!-- Connect the Network to ADSL -->\
                            <div class="row_wizard description connect-adsl hide">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T"Connect the supplied white cable with gray ADSL tags into the gray ADSL port on your Router and then into the ADSL port on the white line filter box, as shown in the picture on the left."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description connect-adsl hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T"Connect the white line filter box to the telephone wall jack."); ngx.print('</span> </div>\
                            </div>\
\
                            <!-- PPPoE connection detected -->\
                            <div id="conn-pppoe" class="hide">\
                                <div class="row_wizard description pppoe-connection">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"Enter below your user name and password to complete the activation of your ADSL lines. You must use the username and password that was sent in a letter and / or SMS."); ngx.print('</span> </div>\
                                </div>\
                                <div class="row_wizard description pppoe-connection">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"Username:"); ngx.print('</span> </div>\
                                    <div class="right">\
                                        <input name="username" id="aw-txt-username" type="text">\
                                    </div>\
                                </div>\
                                <div class="row_wizard description pppoe-connection">\
                                    <div class="left">\
                                        <span>');  ngx.print(T"Password:"); ngx.print('</span> </div>\
                                    <div class="right">\
                                        <input name="password" id="aw-txt-password" type="password">\
                                    </div>\
                                </div>\
                            </div>\
\
                            <!-- Connect the Network Cable OK -->\
                            <div class="row_wizard description connect-cable-ok hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"You have now completed the steps you need to set up your connection."); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row_wizard description connect-cable-ok hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"When you finish the activation wizard your interest services will activate shortly after."); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row_wizard description connect-cable-ok hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"To set up your WiFi connection click Next."); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row_wizard tC connect-cable-ok hide">\
                                <img src="/img/look_4/icons/successful.png" alt="successful">\
                            </div>\
\
                            <!-- wifi setup -->\
                            <div class="row_wizard description wifi-setup-description hide">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T"Please check your bottom of the device. There is WiFi network name and password for your connection on the lable."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-setup-description hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T("Use your device's wireless software to find and conncect to your " .. gatewayName ..". It will appear on your device using the WiFi Network name(SSID) displayed on the lable. Select your WiFi network from the list. You will thenbe prompted to enter the WiFi Password (WPA key)to secure your connection.")); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-setup-description hide">\
                                <div class="left">\
                                    3. <span>');  ngx.print(T"You'll now be able to access your vodafone Broadband connection wirelessly."); ngx.print('</span> </div>\
                            </div>\
\
                            <!-- Wifi Device Detect -->\
                            <div class="row_wizard description wifi-device-detect hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"WiFi Device detected"); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-device-detect hide">\
                                <div class="left">\
                                    <span>');  ngx.print(format(T"The device %s is now connected to your WiFi network. Click Setup more to configure a new WiFi device or Next to continue to setup your phone.", "<span class='aw-info-wifiDevice'></span>")); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description tC wifi-device-detect hide">\
                                <div class="left"><img src="/img/look_4/icons/successful.png" alt="successful">\
                                </div>\
                            </div>\
                            <div class="row_wizard description tC wifi-device-detect hide">\
                                <div class="left"><span>');  ngx.print(T"Wifi connection configured"); ngx.print('</span>\
                                </div>\
                            </div>\
\
                            <!-- Wifi Device Detected Ok -->\
                            <div class="row_wizard description wifi-device-detect-ok hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"WiFi Device detected"); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-device-detect-ok hide">\
                                <div class="left">\
                                    <span>');  ngx.print(format(T"The device %s is now connected to your WiFi network. Click Setup more to configure a new WiFi device or Next to continue to setup your phone.", "<span class='aw-info-wifiDevice'></span>")); ngx.print('</div>\
                            </div>\
                            <div class="row_wizard description tC wifi-device-detect-ok hide">\
                                <div class="left"><img src="/img/look_4/icons/successful.png" alt="successful">\
                                </div>\
                            </div>\
                            <div class="row_wizard description tC wifi-device-detect-ok hide">\
                                <div class="left"><span>');  ngx.print(T"Wifi connection configured"); ngx.print('</span>\
                                </div>\
                            </div>\
\
                            <!-- Wifi Setup for ADSL -->\
                            <div class="row_wizard description wifi-setup-adsl hide">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T"Please check your bottom of the device. There is WiFi network name and password for your connection on the lable."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-setup-adsl hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T"Use your device's wireless software to find and conncect to your " .. gatewayName .. ". It will appear on your device using the WiFi Network name(SSID) displayed on the lable. Select your WiFi network from the list. You will thenbe prompted to enter the WiFi Password (WPA key)to secure your connection."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wifi-setup-adsl hide">\
                                <div class="left">\
                                    5. <span>');  ngx.print(T"You'll now be able to access your vodafone Broadband connection wirelessly."); ngx.print('</span> </div>\
                            </div>\
\
\
                            <!-- WPS Pairing -->\
                            <div class="row_wizard description wps-pairing-description hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Within 120 seconds please push the pairing button on the device you want to pair with."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-description hide">\
                                <div class="left">\
                                    <span>1. ');  ngx.print(T"Click Connect button"); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-description hide">\
                                <div class="left">\
                                    <span>2. ');  ngx.print(T"Enable inthe WiFi device the searching of WiFi networks using WPS"); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-description hide">\
                                <div class="left">\
                                    <span>3. ');  ngx.print(T"The connection will be done when the device appears as connected"); ngx.print('</span> </div>\
                            </div>\
\
                            <!-- Connect Your Phone  -->\
                            <div class="row_wizard description connect-phone hide padding-top-20">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T"You can leave your phones as they are connected now, just connecting a microfilter between phone a phone plug."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description connect-phone hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T"You can connect a phone to the PHONE port of the router. In this case the microfilter is not required."); ngx.print('</span> </div>\
                            </div>\
\
                            <!-- Finish -->\
                            <div class="row_wizard description finish hide padding-top-20">\
                                <div class="left">\
                                    1. <span>');  ngx.print(T"You have successfully activated your Router."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description finish hide">\
                                <div class="left">\
                                    2. <span>');  ngx.print(T"You are now ready to use the full functionality of the Vodafone Fibre Router."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard tC finish hide">\
                                <img src="/img/look_4/icons/successful.png" alt="successful"> </div>\
\
\
                            <!-- Internet Check Timedout -->\
                            <div class="aw-err-timedout clearfix hide">\
                                <div class="no-padding-left-right">\
                                <div class="row_wizard description conn-timedout">\
          <div class="left">\
             ');  ngx.print(T"1."); ngx.print(' <span>');  ngx.print(T"Please insert the ADSL cable into the grey port if you have a ADSL or VDSL connection, otherwise the Ethernet cable into the ");ngx.print(wanColour);ngx.print(T" WAN port if you have a FIBRE connection."); ngx.print('</span>\
          </div>\
        </div>\
        <div class="row_wizard description conn-timedout">\
           <div class="left">\
              ');  ngx.print(T"2."); ngx.print(' <span>');  ngx.print(T"Remove any extension cables, plugs or filters and connect the modem directly to the wall jack."); ngx.print('</span>\
           </div>\
        </div>\
        <div class="row_wizard description conn-timedout">\
           <div class="left">\
              ');  ngx.print(T"3."); ngx.print(' <span>');  ngx.print(T"Check that you have received confirmation by email or TXT from Vodafone that your Broadband connection is activated. If you haven't, then your services may not be activated yet."); ngx.print('</span>\
                 </div>\
        </div>\
        <div class="row_wizard description conn-timedout">\
           <div class="left">\
              ');  ngx.print(T"4."); ngx.print(' <span>');  ngx.print(T"Then click the Retry button."); ngx.print('</span>\
           </div>\
        </div>\
        <div class="row_wizard description conn-timedout">\
           <div class="left">\
              ');  ngx.print(T"5."); ngx.print(' <span>');  ngx.print(T"Still having problems?"); ngx.print('</span>\
           </div>\
        </div>\
        <div class="row_wizard description conn-timedout">\
           <div class="left">\
              <span>');  ngx.print(T"Our teams are here to help you, simply give us a call on:"); ngx.print('</span><br>\
              ');  if vodafone.variant == "NZ" then   ngx.print('\
              <span class="padding-left-20">');  ngx.print(T"Personal customers"); ngx.print('</span><br>\
              <span class="padding-left-40">');  ngx.print(T"ADSL / VDSL service - 0800 438 448"); ngx.print('</span><br>\
              <span class="padding-left-40">');  ngx.print(T"Fibre broadband service - 0800 806 106"); ngx.print('</span><br>\
              <span class="padding-left-40">');  ngx.print(T"FibreX / Fibre service - 0508 888 800"); ngx.print('</span><br>\
              <span class="padding-left-20">');  ngx.print(T"Business customers"); ngx.print('</span><br>\
              <span class="padding-left-40">');  ngx.print(T"All Service - 0800 400 888"); ngx.print('</span><br>\
              ');  else  ngx.print('\
              <span>');  ngx.print(T"123 - for residential support."); ngx.print('</span><br>\
              <span>');  ngx.print(T"122 - for business support."); ngx.print('</span>\
              ');  end  ngx.print('\
           </div>\
        </div>\
                              </div>\
                            </div>\
\
                            <!-- WiFi Pairing Failed -->\
                            <div class="aw-info-wifiFail" class="clearfix hide">\
                                <div id="activation-content-right" class="no-padding-left-right">\
                                    <div class="row_wizard description retry-description">\
                                        <div class="left">\
                                            <span>');  ngx.print(T"Please try again or skip"); ngx.print('</span>\
                                        </div>\
                                    </div>\
                                </div>\
                            </div>\
\
                            <!-- WPS Pairing OK -->\
                            <div class="row_wizard description wps-pairing-success hide padding-top-20">\
                                <div class="left">\
                                    <span>');  ngx.print(T("Your " .. gatewayName .. " has successfully paired with another device.")); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-success hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"To connect more WiFi device click the setup more button."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-success hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"To continue the setup wizard click next."); ngx.print('</span> </div>\
                            </div>\
                            <div class="row_wizard description wps-pairing-success tC hide">\
                                <img src="/img/look_4/icons/successful.png" alt="successful"> </div>\
                            <div class="row_wizard description wps-pairing-success tC hide">\
                                <span>');  ngx.print(T"Pairing Successful"); ngx.print('</span> </div>\
\
                            <div class="row_wizard tC icon-loading no-border-top hide">\
                                <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading...">\
                            </div>\
                        </div>\
                        <!-- Page action buttons -->\
                        <div id="activation-content-bottom">\
                            <input class="button button-apply" id="aw-btn-start" value="');  ngx.print(T"Start"); ngx.print('" type="button">\
                            <input class="button button-cancel back-btn hide" value="');  ngx.print(T"Back"); ngx.print('" type="button">\
                            <input class="button button-cancel skip-btn hide" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                            <input class="button button-cancel wps-btn hide" value="');  ngx.print(T"WPS"); ngx.print('" type="button">\
                            <input class="button button-cancel setup-more-btn hide" value="');  ngx.print(T"Setup More"); ngx.print('" type="button">\
                            <input class="button button-apply next-btn hide" id="aw-btn-next" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                            <input class="button button-apply next-btn-skip hide" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                            <input class="button button-apply next-btn-pairing hide" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                            <input class="button button-apply next-btn-phone hide" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                            <input class="button button-cancel back-btn-wps hide" value="');  ngx.print(T"Back"); ngx.print('" type="button">\
                            <input class="button button-apply pairing-btn hide" value="');  ngx.print(T"Pairing"); ngx.print('" type="button">\
                            <input class="button button-apply done-btn hide" value="');  ngx.print(T"Done"); ngx.print('" type="button">\
                            <input class="button button-cancel aw-info-wifiFail hide" id="aw-btn-wifiRetry" value="');  ngx.print(T"Retry"); ngx.print('" type="button">\
                            <input class="button button-cancel aw-info-wifiFail hide" id="aw-btn-wifiSkip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                            <input class="button button-cancel retry-internet hide" value="');  ngx.print(T"Retry"); ngx.print('" type="button">\
                            <input class="button button-cancel skip-internet hide" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                        </div>\
                    </div>\
                    <!--<input type="button" class="step1back" data-step-id=\'1\' style="display:none;">-->\
                </div>\
            </div>\
            <div class="container-fluid no-padding" id="footer-bg">\
              <div class="language-info clearfix" id="language-info">\
                <div class="mobile-icon">\
                </div>\
                <div class="row no-margin-left-right padding-bottom-20">\
                  <div class="col-xs-12 col-sm-4 col-md-4">\
                    <ul id="language-switcher-list">\
                      <li class="language-switcher" data-language-id="14">\
                        <a href="#" onclick="lang_change(\'en-us\')">English</a>\
                      </li>\
                      <li class="language-switcher" data-language-id="15">\
                        <a href="#" onclick="lang_change(\'spn\')">Spanish</a>\
                      </li>\
                    </ul>\
                  </div>\
                <div class="col-xs-12 col-sm-3 col-md-3">\
                  <div class="row">\
                    <div class="col-xs-12 hidden-lg hidden-md hidden-sm">\
                      <hr class="footer-spain-bdr">\
                    </div>\
                  </div>\
                </div>\
                <div class="col-xs-12 col-sm-5 col-md-5 footer-wanipv6">\
                  <p></p>\
                  <p></p>\
                  <p></p>\
                </div>\
             </div>\
           </div>\
          </div>\
        </div>\
    </div>\
\
    <script src="/js/activation-wizard.js"></script>\
</body>\
\
</html>\
'); 