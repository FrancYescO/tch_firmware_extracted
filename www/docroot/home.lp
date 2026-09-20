--pretranslated: do not change this file
 -- Enable localization
local ngx = ngx
local session = ngx.ctx.session
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local content_helper = require("web.content_helper")
local userCount = session:getUserCount()
local string, ipairs, tonumber = string, ipairs, tonumber
local loginrole = session:getrole()
gettext.textdomain('webui-core')
local vdf_helper = require("vodafone_helper")
local json = require("dkjson")
local wifischeduleParam

if vdf_helper.getVariant() == "VF-UK" then
  local wifiFlag = false
  wifischeduleParam = content_helper.convertResultToObject("rpc.wifitod.", proxy.get("rpc.wifitod."))
end

local getwanSyncStatus = proxy.get("uci.wansensing.state.wanSyncStatus")[1].value

local gatewayName, expertModeName = vdf_helper.productName(), T"Expert Mode"
if vdf_helper.getVariant() == "NZ" then
    expertModeName = T"Advanced Mode"
end

local isVodafoneUser = not (loginrole == "admin" or loginrole == "support")
local getUser = content_helper.getMatchedContent("uci.web.rule.@vfwifinetwork.roles.", {value = "user"})
local get_from_transformer = {
  ["firmware-version"] = "rpc.system.SoftwareVersion",
  ["wanipv4"] = "rpc.network.interface.@wan.ipaddr",
  ["wanipv6"] = "rpc.network.interface.@lan.ip6addr",
  ["defaultPassword"] = "uci.env.var.default_key_r0_s0",
  ["expertMode"] = "uci.web.uiconfig.@uidefault.expert",
  ["settingsVisibilityMsg"] = "uci.web.uiconfig.@uidefault.expertMode_globalMsg",
  ["activationStatus"] = "uci.env.var.activationStatus",
  ["provisioningCode"] = "uci.env.var.provisioning_code",
  ["dslStatus"] = "sys.class.xdsl.@line0.Status",
  ["ethStatus"] = "sys.class.net.@eth4.operstate",
  ["wwanStatus"] = "rpc.network.interface.@wwan.up",
  ["wwanIpv4"] = "rpc.network.interface.@wwan.ipaddr",
  ["wwanIpv6"] = "rpc.network.interface.@wwan.ip6addr",
  ["ipv6status"] = "rpc.network.ipv6_enable",
  ["tracingStatus"] = "rpc.packetcapture.startCapture",
}
if vdf_helper.getVariant() == "NZ" then
  get_from_transformer.remoteUser = "uci.web.assistance.@remote.user"
end
content_helper.getExactContent(get_from_transformer)

local pinState = {
  state = "rpc.mobiled.device.@1.sim.pin.pin_state",
  mobileDevice = "rpc.mobiled.DeviceNumberOfEntries",
  networkType = "uci.mobiled.device.@1.radio_pref",
}
local iccid = {
  device_iccid = "rpc.mobiled.device.@1.sim.iccid",
  sim_iccid = "uci.mobiled.sim.@0.iccid",
}
content_helper.getExactContent(pinState)
content_helper.getExactContent(iccid)

local passwordReminder = {}
if vdf_helper.getVariant() == "VF-UK" then
  passwordReminder = {
    status = string.format("uci.web.user.@usr_%s.password_reminder", loginrole),
  }
end
content_helper.getExactContent(passwordReminder)

local usbState = {
  device = "rpc.mobiled.DeviceNumberOfEntries",
  l2type = "uci.wansensing.global.l2type",
  allowedVidpid = "uci.mobiled.device.@1.allowed_vidpid",
  vid = "rpc.mobiled.device.@1.info.vid",
  pid = "rpc.mobiled.device.@1.info.pid",
}
local vidpid = usbState.vid..":"..usbState.pid
content_helper.getExactContent(usbState)

-- WAN IP Address is populated from rpc.network.interface.@wwan.ipaddr parameter
-- When the DSL and ETH WAN Connections are not available and Mobile connection is up
if string.upper(get_from_transformer["dslStatus"]) ~= "UP" and
  string.upper(get_from_transformer["ethStatus"]) ~= "UP" and
  get_from_transformer["wwanStatus"] == "1" then
  get_from_transformer["wanipv4"] = get_from_transformer["wwanIpv4"]
  get_from_transformer["wanipv6"] = get_from_transformer["wwanIpv6"]
end

if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  ngx.header.content_type = "application/json"
  if postArgs.action == "language" then
    proxy.set(string.format("uci.web.user.@usr_%s.language",loginrole), ngx.req.get_post_args().language)
  elseif postArgs.action == "dontShowMsg" then
    proxy.set("uci.web.uiconfig.@uidefault.expertMode_globalMsg", "0")
  end
  proxy.apply()
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().getSessionStatus == "true" then
  ngx.header.content_type = "application/json"
  local wanIPAddress = proxy.get("rpc.network.interface.@wan.ipaddr") or {}
  wanIPAddress = wanIPAddress[1] and wanIPAddress[1].value or ""
  local wwanIPAddress = proxy.get("rpc.network.interface.@wwan.ipaddr") or {}
  wwanIPAddress = wwanIPAddress[1] and wwanIPAddress[1].value or ""
  wanIPAddress = (wanIPAddress == "" and wwanIPAddress ~= "") and  wwanIPAddress or wanIPAddress
  ngx.print(json.encode({status = 'alive', wanIPAddress = wanIPAddress}))
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  ngx.header.content_type = "application/json"
  if postArgs.action == "logout" then
    if vdf_helper.getVariant() == "NZ" and session:getusername() == get_from_transformer["remoteUser"] then
      assistant:enable(false)
    end
    ngx.ctx.session:logout()
    ngx.redirect(string.format("%s://%s/login.lp",ngx.var.scheme, ngx.var.http_host))
  end
  -- To handle post action from expert mode pages.
  -- When apply button clicked in expert mode pages, It check for "expert" parameter
  -- value in uci config if not "1" then value will be set in config.
  if postArgs.expert and get_from_transformer["expertMode"] ~= "1" then
    proxy.set("uci.web.uiconfig.@uidefault.expert","1")
    proxy.apply()
    ngx.print('{ "status":"success" }')
  else
    ngx.print('{ "status":"updated" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

local securityMode24, currentPassword24, securityMode5, currentPassword5
local wifiDetails = content_helper.convertResultToObject("uci.wireless.wifi-ap.", proxy.get("uci.wireless.wifi-ap."))
for _, v in ipairs(wifiDetails) do
  if v.iface == "wl0" then
    securityMode24 = v.security_mode
    currentPassword24 = v.wpa_psk_key
  end
  if v.iface == "wl1" then
    securityMode5 = v.security_mode
    currentPassword5 = v.wpa_psk_key
  end
end
local fibreText = T"Fibre Status"
local mobileText = T"Mobile Status"
  ngx.print('\
\
<!DOCTYPE html>\
<html>\
  <head>\
    <title>');  ngx.print(T"Connecting.."); ngx.print('</title>\
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <title>');  ngx.print(T"Connecting.."); ngx.print('</title>\
    <link href="/img/vdf-icon.png" type="/image/png" rel="icon" />\
    <link href="/img/vdf-icon.png" type="/image/png" rel="shortcut icon" />\
    <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('">\
    <link rel="stylesheet" type="text/css" href="css/chosen.min.css" />\
    <link rel="stylesheet" type="text/css" href="css/vodafone.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('">\
    <link rel="stylesheet" type="text/css" href="css/global.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('">\
    <link rel="stylesheet" type="text/css" href="css/responsive.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('">\
    <link rel="stylesheet" type="text/css" href="css/vodafoneFont.css" />\
    <script src="/js/main-min.js?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('"></script>\
    <!-- HTML5 shiv and Respond.js for IE8 support of HTML5 elements and media queries -->\
    <!-- WARNING: Respond.js doesn\'t work if you view the page via file:// -->\
    <!--[if lt IE 9]>\
      <script src="js/html5shiv.min.js"></script>\
      <script src="js/respond.min.js"></script>\
    <![endif]-->\
    <script>\
      var vdfVariant = "');  ngx.print(vdf_helper.getVariant()); ngx.print('";\
      var wanSyncStatus = "');  ngx.print(getwanSyncStatus); ngx.print('";\
      var fibreText = "');  ngx.print(fibreText); ngx.print('";\
      var mobileText = "');  ngx.print(mobileText); ngx.print('";\
      var sessionStatus = setInterval(getSessionStatus, 30000);\
      if (vdfVariant == "NZ") {\
        var sessionUsername = "');  ngx.print(session:getusername()); ngx.print('"\
        var remoteUser = "');  ngx.print(get_from_transformer["remoteUser"]); ngx.print('"\
      }\
\
      function getSessionStatus() {\
        $.get("/home.lp", { getSessionStatus : true }, function(data) {\
          if (data.status != "alive") {\
            if (typeof sessionStatus !== "undefined") {\
              clearInterval(sessionStatus); // Stop checking sessionStatus further\
            }\
            $(".modal.in").modal("hide"); // Hide all visible popups\
            $(\'#session-popup-time\').modal(\'show\'); // Show timeout popup\
            if (vdfVariant == "NZ" && sessionUsername == remoteUser) {\
              $.get("/login.lp", {assistantState : false})\
            }\
          }\
          else {\
            $(\'#footer-wan-ip\').text(data.wanIPAddress); // Update footer WAN IP dynamically\
          }\
        });\
      }\
\
      $(function() {\
        $(\'select\').chosen({\
          disable_search_threshold : 100000,\
          allow_single_deselect : true\
        });\
\
        //The role of the user(admin/support/user) is later used to determine if it has access to particular Vodafone pages\
        sessionStorage.setItem(\'loginRole\', \'');  ngx.print(loginrole); ngx.print('\');\
        ');  if next(getUser) then  ngx.print('\
          sessionStorage.setItem(\'userRole\', \'');  ngx.print(getUser[1].value); ngx.print('\');\
        ');  else  ngx.print('\
          sessionStorage.setItem(\'userRole\', \'\');\
        ');  end  ngx.print('\
        $("[id^=global-btn-actv]").click(function() {\
          $(this).closest(\'.warning-messages\').toggle();\
          window.location = "/activation-wizard.lp";\
        })\
        $("[id^=global-btn-dismiss]").click(function() {\
          $(this).closest(\'.warning-messages\').toggle();\
        })\
        $("[id^=global-btn-dontShow]").click(function() {\
          var postParams = {\
            "CSRFtoken" : $("meta[name=CSRFtoken]").attr("content"),\
            "action" : "dontShowMsg"\
          }\
          $.post("/home.lp", postParams);\
          $(this).closest(\'.warning-messages\').toggle();\
        })\
        $("[id^=global-btn-change]").click(function() {\
          $("a#WiFi")[0].click();\
          $(this).closest(\'.warning-messages\').toggle();\
        });\
        $("[id^=global-btn-changed]").click(function() {\
          $("a#Settings")[0].click();\
          $(this).closest(\'.login-warning-messages\').toggle();\
        });\
        $("[id^=global-btn-continue]").click(function() {\
          topMenu("Internet","modals/internet/mobile.lp","Mobile");\
          $("ul.topmenu").find("li.active").removeClass("active");\
          $("#mobile").closest("li").addClass("active");\
          $("#Internet").parent().addClass("active");\
          $(this).closest(\'.warning-messages\').toggle();\
        });\
        var ms_ie = false;\
        var ua = window.navigator.userAgent;\
        if ((ua.indexOf(\'MSIE \') > -1) || (ua.indexOf(\'Trident/\') > -1)) {\
          ms_ie = true;\
        }\
        if ( ms_ie ) {\
          var version=navigator.sayswho.split(" ");\
          if(version[1]==9 || version[1]==10 ) {\
            $("#navigation ul.topmenu li a").addClass("ie9-ie10-menu");\
            $("#navigation ul.topmenu li").addClass("ie9-ie10-menubar");\
          }\
        }\
      });\
      navigator.sayswho = (function() {\
        var ua= navigator.userAgent, tem,\
        M= ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\\/))\\/?\\s*(\\d+)/i) || [];\
        if (/trident/i.test(M[1])) {\
          tem=  /\\brv[ :]+(\\d+)/g.exec(ua) || [];\
          return \'IE \'+(tem[1] || \'\');\
        }\
        if (M[1]=== \'Chrome\') {\
          tem= ua.match(/\\b(OPR|Edge)\\/(\\d+)/);\
          if(tem!= null) return tem.slice(1).join(\' \').replace(\'OPR\', \'Opera\');\
        }\
        M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, \'-?\'];\
        if((tem= ua.match(/version\\/(\\d+)/i))!= null) M.splice(1, 1, tem[1]);\
        return M.join(\' \');\
      })();\
\
    </script>\
		<script type="text/javascript" src="js/menu-min.js?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('"></script>\
		<script src="js/global-min.js?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('"></script>\
  </head>\
  <body>\
    <form id="home-form-logout" method="post" action="/home.lp">\
      <input type="hidden" name = "action" value="logout" />\
      <input type="hidden" name = "CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('" />\
    </form>\
    <div class="section">\
      <div class="container-fluid no-padding">\
        <div class="row no-margin">\
          <div id="header" class="hidden-xs hidden-sm">\
            <div id="top-bar">\
              <div id="top-bar-content">\
                <div class="rel">\
                  <a href="#">\
                    <div id="logo">');  ngx.print(gatewayName); ngx.print('</div>\
                  </a>\
                  <div id="top-info" class="clearfix">\
                    <div id="top-info-mode" class="rel desktop-chosen">\
                      <select class="dropdown" style="width: 165px; display: none;" id = "home-sel-mode">\
                        <option value="33" ');  ngx.print(isVodafoneUser and 'selected="selected"' or ''); ngx.print('>');  ngx.print(T"Basic Mode"); ngx.print('</option>\
                        <option value="34">');  ngx.print(T(expertModeName)); ngx.print('</option>\
                        ');  if not isVodafoneUser then   ngx.print('\
                          <option value="35" selected="selected">');  ngx.print(T"Admin Mode"); ngx.print('</option>\
                        ');  end   ngx.print('\
                        <option value="0">');  ngx.print(T"Logout"); ngx.print('</option>\
                      </select>\
                    </div>\
                    <div id="top-info-logged-user">\
                      <div id= "expert" class="page-loader-container load-once" data-page-alias="top-info" data-has-loaded="true" data-page-id="3619"> <span><strong id = "home-str-numofusr">');  ngx.print( userCount and userCount); ngx.print('</strong> ');  ngx.print(T"user(s) logged in ."); ngx.print('</span>\
                        <span ');  if tonumber(get_from_transformer["expertMode"]) ~= 1 then  ngx.print('class="hidden"');  end  ngx.print('>');  ngx.print(T("Some " .. expertModeName .. " settings in use")); ngx.print('</span>\
                      </div>\
                    </div>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
          <div class="row no-margin">\
            <div id="page-rhombus-wrap">\
              <div class="rel">\
                <div id="rhombus-wrap">\
                  <div id="rhombus-logo"></div>\
                  <div id="rhombus"></div>\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
      <div id="rhombus-navigation" class="clearfix hidden-xs hidden-sm">\
        <div class="rel">\
          <div id="navigation">\
          </div>\
        </div>\
      </div>\
      <!-- Mobile Menu -->\
      <div class="menubar-overlay hidden-md hidden-lg mobile-menu">\
        <p class="text-right">\
          <button aria-controls="collapseExample" aria-expanded="true"\
          data-target="#collapseExample" data-toggle="collapse" type="button"\
          class="btn btn-vodafone hidden-md hidden-lg" id = "home-btn-collapse">\
            <div></div>\
            <div></div>\
            <div></div>\
          </button>\
        </p>\
        <div id="collapseExample" class="collapse menubar-listgroup" aria-expanded="true">\
          <div class="nopadding">\
            <ul class="menubar-ul">\
              <li class="header-li">\
                <h3 href="#" class="pull-right menubar-close" id="home-href-menuclose">\
                  <div class="btn-close"></div>\
                  <div class="btn-close"></div>\
                </h3>\
                ');  if vdf_helper.getVariant() == "VF-UK" or vdf_helper.getVariant() == "NZ" then  ngx.print('\
                  <div class="header-li-text">');  ngx.print(gatewayName); ngx.print('</div>\
                ');  else  ngx.print('\
                  VFH 500\
                ');  end  ngx.print('\
              </li>\
              <li class="dropdown">\
                <a class="active" href="#" id="Overview">');  ngx.print(T"Overview"); ngx.print('</a>\
              </li>\
              ');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
                <li class="dropdown">\
                  <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id = "Phone">');  ngx.print(T"Phone"); ngx.print('\
                    <div class="menu-arrow-down pull-right"></div>\
                    <div class="menu-arrow-down pull-right"></div>\
                  </a>\
                  <ul aria-labelledby="drop1" class="dropdown-menu">\
                  </ul>\
                </li>\
              ');  end   ngx.print('\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button" href="#" id = "Internet">');  ngx.print(T"Internet"); ngx.print('\
                  <div class="menu-arrow-down pull-right"></div>\
                  <div class="menu-arrow-down pull-right"></div>\
                </a>\
                <ul aria-labelledby="drop2" class="dropdown-menu"></ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id ="WiFi">');  ngx.print(T"Wi-Fi"); ngx.print('\
                  <div class="menu-arrow-down pull-right"></div>\
                  <div class="menu-arrow-down pull-right"></div>\
                </a>\
                <ul aria-labelledby="drop3" class="dropdown-menu"></ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id ="Sharing">');  ngx.print(T"Sharing"); ngx.print('\
                  <div class="menu-arrow-down pull-right"></div>\
                  <div class="menu-arrow-down pull-right"></div>\
                </a>\
                <ul aria-labelledby="drop4" class="dropdown-menu"></ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id="Settings">');  ngx.print(T"Settings"); ngx.print('\
                  <div class="menu-arrow-down pull-right"></div>\
                  <div class="menu-arrow-down pull-right"></div>\
                </a>\
                <ul aria-labelledby="drop5" class="dropdown-menu"></ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#"  id = "StatusSupport">');  ngx.print(T"Status & Support"); ngx.print('\
                  <div class="menu-arrow-down pull-right"></div>\
                  <div class="menu-arrow-down pull-right"></div>\
                </a>\
                <ul aria-labelledby="drop6" class="dropdown-menu"></ul>\
              </li>\
            </ul>\
          </div>\
          <div class="bottom-overlay">\
            <div class="row">\
              <div class="col-xs-12 bottom-content">\
                <p>2 ');  ngx.print(T("users logged in. Some " .. expertModeName .." settings in use")); ngx.print('</p>\
              </div>\
            </div>\
            <div class="row">\
              <div class="col-xs-12 bottom-info">\
                <div id="top-info-mode" class="rel">\
                  <select class="dropdown mobile" id = "home-sel-mobmode">\
                    <option value="33" ');  ngx.print(isVodafoneUser and 'selected="selected"' or ''); ngx.print('>');  ngx.print(T"Basic Mode"); ngx.print('</option>\
                    <option value="34">');  ngx.print(T(expertModeName)); ngx.print('</option>\
                    ');  if not isVodafoneUser then   ngx.print('\
                      <option value="35" selected="selected">');  ngx.print(T"Admin Mode"); ngx.print('</option>\
                    ');  end   ngx.print('\
                  </select>\
                </div>\
              </div>\
            </div>\
            <div class="row">\
              <div class="col-xs-12">\
                <div class="logout">\
                  <a href="#" id = "home-href-mlogout">');  ngx.print(T"Logout"); ngx.print('</a>\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
      ');  if vdf_helper.getVariant() ~= "VF-UK" then  ngx.print('\
          ');  if get_from_transformer.activationStatus == "Not_Activated" and get_from_transformer.provisioningCode == "CNGF.DFLT" then   ngx.print('\
          <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
            <div id="globalMessages">\
              <div class="rel">\
                <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-actv" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"You have not completed the activation yet. The setup process only takes a couple of minutes."); ngx.print('</span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismissActv" class="button button-cancel cancel-btn" type="button">\
                      <input value="');  ngx.print(T"Activate"); ngx.print('" id="global-btn-actv" class="button button-apply purple" type="button">\
                    </div>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
        ');  end   ngx.print('\
      ');  end   ngx.print('\
      ');  if tonumber(get_from_transformer["expertMode"]) == 1 and get_from_transformer["settingsVisibilityMsg"] == "" then   ngx.print('\
        <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
          <div id="globalMessages">\
            <div class="rel">\
              <div class="global-wrap">\
                <div class="head-message clearfix" id="global-msg-settnChngeExprtMode" style="margin-top: -11px;">\
                  <div class="fL pull-left">\
                    <span>');  ngx.print(T"Some settings only visible in " .. expertModeName .. " have been changed. To edit these, select " .. expertModeName .."."); ngx.print('</span>\
                  </div>\
                  <div class="head-button-message-wrap">\
                    <input value="');  ngx.print(T"Don't show again"); ngx.print('" id="global-btn-dontShow" class="button button-apply" type="button">\
                    <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss" class="button button-cancel cancel-btn purple" type="button">\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  end   ngx.print('\
      ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
        <div class="modal fade" id="applyModal" role="dialog" data-backdrop = "static">\
          <div class="modal-dialog">\
            <div class="modal-content change-password-content">\
              <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
              </div>\
              <div class="modal-body no-padding mobile-modal-padding-top">\
                <form id="add-known-device" class="form-horizontal">\
                  <div class="form-group no-margin-bottom">\
                    <div class="col-sm-12">\
                      <p class="title tL">\
                        ');  ngx.print(T"You're attempting to change certain options which will cause the currently connected devices to be disconnected."); ngx.print('\
                      </p>\
                    </div>\
                  </div>\
                  <div class="form-group no-margin-bottom no-margin-right">\
                    <div class="col-sm-12">\
                      <div class="modal-footer">\
                        <input id="macfilter-btn-applypopupmac" class="button button-apply save mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('"  type="button">\
                        <input id="macfilter-btn-cancelmac" class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="reset">\
                      </div>\
                    </div>\
                  </div>\
                </form>\
              </div>\
            </div>\
          </div>\
        </div>\
        ');  for _, v in pairs(wifischeduleParam) do
         if string.untaint(v.wifiScheduleAffected) == "1" then
          wifiFlag = true
         end   ngx.print('\
        ');  end   ngx.print('\
        ');  if wifiFlag then   ngx.print('\
          <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
            <div id="globalMessages">\
              <div class="rel">\
                <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-scheduleAffected" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"The Wi-Fi schedule has been interrupted by hardware button."); ngx.print('\
                      </span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss" class="button button-cancel cancel-btn purple" type="button">\
                    </div>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
       ');  end   ngx.print('\
      ');  end   ngx.print('\
      ');  -- If both 2.4Ghz and 5Ghz Wifi passwords are same as default and their protection mode is not none
      if securityMode24 ~= "none" and securityMode5 ~= "none" and get_from_transformer.defaultPassword == currentPassword24 and
        get_from_transformer.defaultPassword == currentPassword5 then   ngx.print('\
        <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
          <div id="globalMessages">\
            <div class="rel">\
              <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-wifi" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"You are still using the default Wi-Fi password. To prevent unwanted users connecting, you should change it."); ngx.print('</span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change25GHz" class="button button-apply purple" type="button">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss25GHz" class="button button-cancel cancel-btn" type="button">\
                    </div>\
                  </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  -- If 2.4Ghz Wifi password is same as default and protection mode is not none
      elseif securityMode24 ~= "none" and get_from_transformer.defaultPassword == currentPassword24 then  ngx.print('\
        <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
          <div id="globalMessages">\
            <div class="rel">\
              <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-wifi24" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"Please change the default 2.4GHz Password"); ngx.print('</span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change2GHz" class="button button-apply purple" type="button">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss2GHz" class="button button-cancel cancel-btn" type="button">\
                    </div>\
                  </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  -- If 5Ghz Wifi password is same as default and protection mode is not none
      elseif securityMode5 ~= "none" and get_from_transformer.defaultPassword == currentPassword5 then  ngx.print('\
        <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
          <div id="globalMessages">\
            <div class="rel">\
              <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-wifi5" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"Please change the default 5GHz Password"); ngx.print('</span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change5GHz" class="button button-apply purple" type="button">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss5GHz" class="button button-cancel cancel-btn" type="button">\
                    </div>\
                  </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  end   ngx.print('\
      ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
        ');  if passwordReminder.status ~= "0" then   ngx.print('\
          <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="login-warning-messages">\
            <div id="globalMessages">\
              <div class="rel">\
                <div class="global-wrap">\
                  <div class="head-message clearfix" id="global-msg-login" style="margin-top: -11px;">\
                    <div class="fL pull-left">\
                      <span>');  ngx.print(T"You are still using the default login password. For security reasons, you should change it."); ngx.print('</span>\
                    </div>\
                    <div class="head-button-message-wrap">\
                      <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-changedlogGHz" class="button button-apply purple" type="button">\
                      <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismisslogGHz" class="button button-cancel cancel-btn" type="button">\
                    </div>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
        ');  end   ngx.print('\
        <div id="Alert-unplug-usb" class = "hidden">\
          <div class="rel">\
            <div id="globalMessages" class="global-wrap">\
              <div class="head-message clearfix" id="global-msg-actv" style="margin-top: -11px;">\
                <div class="fL pull-left">\
                  <span>');  ngx.print(T"Your Vox 3.0 is now recording all connection events. You can press Stop at any time. Please make sure to stop the capture before unplugging the USB device. After stopping the capture, unplug the USB device and insert into your PC to obtain the capture file."); ngx.print('\
                  </span>\
                </div>\
                <div class="head-button-message-wrap">\
                  <input autocomplete="off" value="Stop" id="global-btn-stop" class="button button-apply purple" type="button">\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  end   ngx.print('\
      ');  if iccid.device_iccid ~= iccid.sim_iccid and vdf_helper.getVariant() ~= "NZ" then  ngx.print('\
        <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
          <div id="globalMessages">\
            <div class="rel">\
              <div class="global-wrap">\
                <div class="head-message clearfix" id="global-msg-lte-umts" style="margin-top: -11px;">\
                  <div class="fL pull-left">\
                    ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
                      <span id ="global-msg-mobile">');  ngx.print(T"The Mobile SIM-Card PIN has changed. Please continue to enter the Mobile PIN."); ngx.print('</span>\
                    ');  else  ngx.print('\
                      <span id ="global-msg-lte">');  ngx.print(T"The LTE SIM-Card PIN has changed. Please continue to enter the LTE PIN."); ngx.print('</span>\
                      <span id ="global-msg-umts">');  ngx.print(T"The UMTS SIM-Card PIN has changed. Please continue to enter the UMTS PIN."); ngx.print('</span>\
                    ');  end  ngx.print('\
                  </div>\
                  <div class="head-button-message-wrap">\
                    <input value="');  ngx.print(T"Continue"); ngx.print('" id="global-btn-continueLTE" class="button button-apply purple" type="button">\
                    <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismissLTE" class="button button-cancel cancel-btn" type="button">\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      ');  end   ngx.print('\
      ');  if pinState.mobileDevice == "1" then
        if pinState.state == "enabled_not_verified" then   ngx.print('\
          <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
            <div id="globalMessages">\
              <div class="rel">\
                  <div class="global-wrap">\
                    <div class="head-message clearfix" id="global-msg-lte-umts" style="margin-top: -11px;">\
                      <div class="fL pull-left">\
			');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
			  <span id ="global-msg-mobile">');  ngx.print(T"The Mobile SIM-Card PIN has changed. Please continue to enter the Mobile PIN."); ngx.print('</span>\
			');  else  ngx.print('\
			  <span id ="global-msg-lte">');  ngx.print(T"The LTE SIM-Card PIN has changed. Please continue to enter the LTE PIN."); ngx.print('</span>\
			  <span id ="global-msg-umts">');  ngx.print(T"The UMTS SIM-Card PIN has changed. Please continue to enter the UMTS PIN."); ngx.print('</span>\
			');  end  ngx.print('\
		      </div>\
		      <div class="head-button-message-wrap">\
			<input value="');  ngx.print(T"Continue"); ngx.print('" id="global-btn-continueLTE" class="button button-apply purple" type="button">\
			<input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismissLTE" class="button button-cancel cancel-btn" type="button">\
		      </div>\
                    </div>\
                  </div>\
              </div>\
            </div>\
          </div>\
        ');  end
      end   ngx.print('\
      ');  if vdf_helper.getVariant() ~= "VF-UK" and vdf_helper.getVariant() ~= "NZ" then
        if usbState.device == "1" then
          if usbState.allowedVidpid ~= vidpid then  ngx.print('\
            <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
              <div id="globalMessages">\
                <div class= "rel">\
                  <div class="global-wrap">\
                    <div class="head-message clearfix" id="global-msg-usb" style="margin-top: -11px;">\
                      <div class="fL pull-left">\
                        <span id ="global-msg-usb">');  ngx.print(T"The inserted USB device is not supported."); ngx.print('</span>\
                      </div>\
                      <div class="head-button-message-wrap">\
                        <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismissUSB" class="button button-cancel cancel-btn" type="button">\
                      </div>\
                    </div>\
                  </div>\
                </div>\
              </div>\
            </div>\
          ');  end   ngx.print('\
        ');  end   ngx.print('\
      ');  end   ngx.print('\
      <!-- Mobile Menu  End -->\
      <!-- Left menu and content of right side -->\
      <div class="container mobile-padding-left-right">\
        <div id="content-wrap">\
          <div class="row" id="subnav-content">\
            <div class="col-md-3 hidden-xs hidden-sm visible-md visible-lg leftmenu">\
              <div id="subnavigation">\
                <ul class="sub-navigation">\
                </ul>\
              </div>\
            </div>\
            <div class="col-md-9 col-xs-12 col-sm-12 rightcontent">\
              <div id="content-reset-wrap">\
                <div id="content" class="padding-bottom-60">\
                </div>\
              </div>\
            </div>\
          </div>\
          <!-- Load the Overview Page -->\
          <div class="row no-margin-left-right">\
            <div class="col-md-12 col-xs-12 col-sm-12 col-lg-12 no-padding-left-right">\
              <div id="content-reset-wrap1">\
                <div id="overview-page" style="display: none">\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
    ');  if vdf_helper.getVariant() ~= "NZ" then  ngx.print('\
    <div class="container-fluid no-padding" id="footer-bg">\
      <div class="language-info clearfix" id="language-info">\
        <div class="mobile-icon">\
        </div>\
        <div class="row padding-bottom-20">\
          <div class="col-xs-12 col-sm-4 col-md-4">\
           ');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
            <ul id="language-switcher-list">\
              <li class="language-switcher" data-language-id="14">\
                <a href="#" class="lang-change" data-lang="en-us">English</a>\
              </li>\
              <li class="language-switcher" data-language-id="15">\
                <a href="#" class="lang-change" data-lang="spn">Spanish</a>\
              </li>\
            </ul>\
          ');  end  ngx.print('\
          </div>\
          <div class="col-xs-12 col-sm-4 col-md-4">\
            <div class="row">\
              <div class="col-xs-12 hidden-lg hidden-md hidden-sm">\
                <hr class="footer-spain-bdr"/>\
              </div>\
            </div>\
          </div>\
          <div class="col-xs-12 col-sm-4 col-md-4">\
            <p class="no-margin">');  ngx.print(T"Firmware Version"); ngx.print(':&nbsp;');  ngx.print(get_from_transformer["firmware-version"]); ngx.print('\
            </p>\
            <p class="no-margin">');  ngx.print(T"WAN IPv4 Address"); ngx.print(':&nbsp;<span id="footer-wan-ip">');  ngx.print(get_from_transformer["wanipv4"]); ngx.print('</span>\
            </p>\
            ');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
                 ');  if get_from_transformer["ipv6status"] == "1" then   ngx.print('\
                  <p class="no-margin">');  ngx.print(T"WAN IPv6 Address"); ngx.print(':&nbsp;');  ngx.print(get_from_transformer["wanipv6"]); ngx.print('</p>\
                 ');  end   ngx.print('\
            ');  end   ngx.print('\
          </div>\
        </div>\
      </div>\
    </div>\
    ');  end   ngx.print('\
    <div class="modal fade" id="session-popup-time" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body no-padding">\
            <form class="form-horizontal">\
              <div class="form-group">\
                <div class="col-sm-12">\
                  <p class="title tL">');  ngx.print(T"Session Timeout"); ngx.print('</p>\
                </div>\
              </div>\
              <div><span class="language-string" >');  ngx.print(T"You will be redirected to Login page"); ngx.print('</div>\
              <div class="form-group">\
                <div class="col-sm-12">\
                  <div class="modal-footer">\
                    <a href="/login.lp" style="">\
                      <input class="button button-apply save mob-button-width" id="home-btn-session" value=');  ngx.print(T"Ok"); ngx.print('  type="button">\
                    </a>\
                  </div>\
                </div>\
              </div>\
            </form>\
          </div>\
        </div>\
      </div>\
    </div>\
  </body>\
</html>\
<script>\
var vdfVariant = "');  ngx.print(vdf_helper.getVariant()); ngx.print('";\
if ("');  ngx.print(pinState.networkType); ngx.print('" == "4GPreferred" || "');  ngx.print(pinState.networkType); ngx.print('" == "4GOnly") {\
  $("#global-msg-umts").hide();\
}\
else {\
  $("#global-msg-lte").hide();\
}\
if ("');  ngx.print(usbState.device); ngx.print('" != "1") {\
  $("#global-msg-usb").hide();\
}\
\
</script>\
'); 
