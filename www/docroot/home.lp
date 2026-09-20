--pretranslated: do not change this file
 -- Enable localization
local ngx = ngx
local session = ngx.ctx.session
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local string = string
local ipairs = ipairs
local loginrole = session:getrole()
gettext.textdomain('webui-core')
local userCount = session:getUserCount()
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")

local vodafone = {
    variant = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(vodafone)

local isVodafoneUser = not (loginrole == "admin" or loginrole == "support")
local getUser = content_helper.getMatchedContent("uci.web.rule.@vfwifinetwork.roles.", {value = "user"})
local get_from_transformer = {
  ["firmware-version"] = "InternetGatewayDevice.DeviceInfo.SoftwareVersion",
  ["wanipv4"] = "rpc.network.interface.@wan.ipaddr",
  ["wanipv6"] = "rpc.network.interface.@lan.ip6addr",
  ["defaultPassword"] = "uci.env.var.default_key_r0_s0",
  ["expertMode"] = "uci.web.uiconfig.@uidefault.expert",
  ["activationStatus"] = "uci.env.var.activationStatus",
  ["provisioningCode"] = "uci.env.var.provisioning_code",
  ["dslStatus"] = "sys.class.xdsl.@line0.Status",
  ["ethStatus"] = "sys.class.net.@eth4.operstate",
  ["wwanStatus"] = "rpc.network.interface.@wwan.up",
  ["wwanIpv4"] = "rpc.network.interface.@wwan.ipaddr",
  ["wwanIpv6"] = "rpc.network.interface.@wwan.ip6addr",
}
if vodafone.variant == "NZ" then
  get_from_transformer.remoteUser = "uci.web.assistance.@remote.user"
end
content_helper.getExactContent(get_from_transformer)

local pinState = {
  state = "rpc.mobiled.device.@1.sim.pin.pin_state",
  mobileDevice = "rpc.mobiled.DeviceNumberOfEntries",
  networkType = "uci.mobiled.device.@0.radio_pref",
}
content_helper.getExactContent(pinState)

-- WAN IP Address is populated from rpc.network.interface.@wwan.ipaddr parameter
-- When the DSL and ETH WAN Connections are not available and Mobile connection is up
if string.upper(get_from_transformer["dslStatus"]) ~= "UP" and
   string.upper(get_from_transformer["ethStatus"]) ~= "UP" and
   get_from_transformer["wwanStatus"] == "1" then
  get_from_transformer["wanipv4"] = get_from_transformer["wwanIpv4"]
  get_from_transformer["wanipv6"] = get_from_transformer["wwanIpv6"]
end

if ngx.var.request_method == "POST" and ngx.req.get_post_args().action == "language" then
   proxy.set(string.format("uci.web.user.@usr_%s.language",loginrole), ngx.req.get_post_args().language)
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().getSessionStatus == "true" then
  ngx.header.content_type = "application/json"
  ngx.print('{ "status":"alive" }')
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  ngx.header.content_type = "application/json"
  if postArgs.action == "logout" then
    if vodafone.variant == "NZ" and session:getusername() == get_from_transformer["remoteUser"] then
      assistant:enable(false)
    end
   ngx.ctx.session:logout()
    if ngx.var.https and ngx.var.https ~= "" then
      ngx.redirect(string.format("https://%s/home.lp", ngx.var.http_host))
    else
      ngx.redirect(string.format("http://%s/home.lp", ngx.var.http_host))
    end
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

  ngx.print('\
\
<!DOCTYPE html>\
<html>\
  <head>\
 <title>');  ngx.print(T"Connecting.."); ngx.print('</title>\
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
  <title>');  ngx.print(T"Connecting.."); ngx.print('</title>\
  <link href="/img/favicon.png" type="/image/png" rel="icon" />\
  <link href="/img/favicon.png" type="/image/png" rel="shortcut icon" />\
  <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css">\
  <link rel="stylesheet" type="text/css" href="css/chosen.min.css" />\
    <link rel="stylesheet" type="text/css" href="css/vodafone.css">\
    <link rel="stylesheet" type="text/css" href="css/global.css">\
    <link rel="stylesheet" type="text/css" href="css/responsive.css">\
    <link rel="stylesheet" type="text/css" href="css/vodafoneFont.css" />\
    <script src="js/jquery-min.js"></script>\
    <script src="js/bootstrap.min.js"></script>\
    <!-- HTML5 shiv and Respond.js for IE8 support of HTML5 elements and media queries -->\
    <!-- WARNING: Respond.js doesn\'t work if you view the page via file:// -->\
    <!--[if lt IE 9]>\
    <script src="js/html5shiv.min.js"></script>\
    <script src="js/respond.min.js"></script>\
    <![endif]-->\
    <script>\
      var vdfVariant = "');  ngx.print(vodafone["variant"]); ngx.print('"\
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
        $("[id^=global-btn-change]").click(function() {\
          $("a#WiFi")[0].click();\
          $(this).closest(\'.warning-messages\').toggle();\
        });\
        $("[id^=global-btn-continue]").click(function() {\
          topMenu("Internet","modals/mobile.lp","Mobile");\
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
        navigator.sayswho= (function(){\
                 var ua= navigator.userAgent, tem,\
                 M= ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\\/))\\/?\\s*(\\d+)/i) || [];\
                 if(/trident/i.test(M[1])){\
                        tem=  /\\brv[ :]+(\\d+)/g.exec(ua) || [];\
                        return \'IE \'+(tem[1] || \'\');\
                }\
                if(M[1]=== \'Chrome\'){\
                        tem= ua.match(/\\b(OPR|Edge)\\/(\\d+)/);\
                        if(tem!= null) return tem.slice(1).join(\' \').replace(\'OPR\', \'Opera\');\
                }\
                M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, \'-?\'];\
                if((tem= ua.match(/version\\/(\\d+)/i))!= null) M.splice(1, 1, tem[1]);\
                return M.join(\' \');\
        })();\
    </script>\
    <script type="text/javascript" src="js/jquery.chosen.js"></script>\
    <script type="text/javascript" src="js/menu.js"></script>\
    <script src="js/jquery.fileDownload.js"></script>\
    <script src="js/jquery.fileUpload.js"></script>\
    <script src="js/global.js"></script>\
    <script src="js/FileSaver.js"></script>\
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
                      <div id="logo">');  ngx.print(T"Vodafone Ultra Hub"); ngx.print('</div>\
                    </a>\
                  <div id="top-info" class="clearfix">\
                    <div id="top-info-mode" class="rel desktop-chosen">\
                      <select class="dropdown" style="width: 165px; display: none;" id = "home-sel-mode">\
                        <option value="33" selected="selected">');  ngx.print(T"Basic Mode"); ngx.print('</option>\
                        <option value="34">');  ngx.print(T"Advanced Mode"); ngx.print('</option>\
                        ');  if((loginrole == "admin") or (loginrole == "support")) then   ngx.print('\
                        <option value="35">');  ngx.print(T"Admin Mode"); ngx.print('</option>\
                        ');  end   ngx.print('\
                        <option value="0">');  ngx.print(T"Logout"); ngx.print('</option>\
                      </select>\
                    </div>\
                    <div id="top-info-logged-user">\
                      <div id= "expert" class="page-loader-container load-once" data-page-alias="top-info" data-has-loaded="true" data-page-id="3619"> <span><strong id = "home-str-numofusr">');  ngx.print( userCount and userCount); ngx.print('</strong> ');  ngx.print(T"user(s) logged in ."); ngx.print('</span>\
                      ');  if tonumber(get_from_transformer["expertMode"]) == 1 then   ngx.print('\
                      <span>');  ngx.print(T"Some Advanced Mode settings in use"); ngx.print('</span>\
                      ');  end   ngx.print('\
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
            <ul class="clearfix topmenu">\
              <li class="active">\
                <a href="#" name="Overview" id="Overview">\
                  <span>');  ngx.print(T"Overview"); ngx.print('</span>\
                </a>\
              </li>\
              <li>\
                <a href="#" name="Call Log" data-src="modals/call-log.lp" id="Phone">\
                  <span>');  ngx.print(T"Phone"); ngx.print('</span>\
                </a>\
              </li>\
              <li>\
                <a href="#"  name="Mobile" data-src="modals/mobile.lp" id="Internet">\
                  <span>');  ngx.print(T"Internet"); ngx.print('</span>\
                </a>\
              </li>\
              <li>\
                <a href="#" name="General" data-src="modals/wifi-general.lp" id="WiFi">\
                  <span>');  ngx.print(T"Wi-Fi"); ngx.print('</span>\
                </a>\
              </li>\
              <li>\
                <a href="#" name="Password" data-src="modals/password.lp" id="Settings">\
                  <span>');  ngx.print(T"Settings"); ngx.print('</span>\
                </a>\
              </li>\
              <li>\
                <a href="#" name="Status" data-src="modals/status.lp" id="StatusSupport">\
                  <span>');  ngx.print(T"Status & Support"); ngx.print('</span>\
                </a>\
              </li>\
            </ul>\
          </div>\
        </div>\
      </div>\
      <!-- Mobile Menu -->\
      <div class="menubar-overlay hidden-md hidden-lg mobile-menu">\
        <p class="text-right">\
          <button aria-controls="collapseExample" aria-expanded="true"\
                  data-target="#collapseExample" data-toggle="collapse" type="button"\
                  class="btn btn-vodafone hidden-md hidden-lg" id = "home-btn-collapse">\
            <div>\
            </div>\
            <div>\
            </div>\
            <div>\
            </div>\
          </button>\
        </p>\
        <div id="collapseExample" class="collapse menubar-listgroup"\
             aria-expanded="true">\
          <div class="nopadding">\
            <ul class="menubar-ul">\
              <li class="header-li">Vodafone Ultra Hub\
                <h3 href="#" class="pull-right menubar-close" id="home-href-menuclose">\
                  <div class="btn-close">\
                  </div>\
                  <div class="btn-close">\
                  </div>\
                </h3>\
              </li>\
              <li class="dropdown">\
                <a class="active" href="#" id="Overview">');  ngx.print(T"Overview"); ngx.print('</a>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id = "Phone">');  ngx.print(T"Phone"); ngx.print('\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                </a>\
                <ul aria-labelledby="drop1" class="dropdown-menu">\
                </ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button" href="#" id = "Internet">');  ngx.print(T"Internet"); ngx.print('\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                </a>\
                <ul aria-labelledby="drop2" class="dropdown-menu">\
                </ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#" id ="WiFi">');  ngx.print(T"Wi-Fi"); ngx.print('\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                </a>\
                <ul aria-labelledby="drop3" class="dropdown-menu">\
                </ul>\
              </li>\
       <li class="dropdown">\
                <a aria-expanded="true"\
                   aria-haspopup="true" role="button"  href="#" id="Settings">');  ngx.print(T"Settings"); ngx.print('\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                </a>\
                <ul aria-labelledby="drop5" class="dropdown-menu">\
                </ul>\
              </li>\
              <li class="dropdown">\
                <a aria-expanded="true" aria-haspopup="true" role="button"  href="#"  id = "StatusSupport">');  ngx.print(T"Status & Support"); ngx.print('\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                  <div class="menu-arrow-down pull-right">\
                  </div>\
                </a>\
                <ul aria-labelledby="drop6" class="dropdown-menu">\
                </ul>\
              </li>\
            </ul>\
          </div>\
          <div class="bottom-overlay">\
            <div class="row">\
              <div class="col-xs-12 bottom-content">\
                <p>2 ');  ngx.print(T"users logged in. Some Expert Mode settings in use"); ngx.print('\
                </p>\
              </div>\
            </div>\
            <div class="row">\
              <div class="col-xs-12 bottom-info">\
                <div id="top-info-mode" class="rel">\
                  <select class="dropdown mobile" id = "home-sel-mobmode">\
                    <option value="33" selected="selected">');  ngx.print(T"Basic Mode"); ngx.print('</option>\
                    <option value="34">');  ngx.print(T"Advanced Mode"); ngx.print('</option>\
                    ');  if((loginrole == "admin") or (loginrole == "support")) then   ngx.print('\
                    <option value="35">');  ngx.print(T"Admin Mode"); ngx.print('</option>\
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
\
      ');  if get_from_transformer.activationStatus == "Not_Activated" then   ngx.print('\
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
\
      <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
        <div id="globalMessages">\
          <div class="rel">\
            <div class="global-wrap">\
\
              <div style="margin-top: -11px; padding-top: 17px; border-bottom-left-radius: 4px; border-bottom-right-radius: 4px;" class="head-message clearfix hide">\
                <div class="fL pull-left">\
                  <span>');  ngx.print(T"Your Vodafone Ultra Hub is now recording all connection events. You can press Stop at any time and view the results file."); ngx.print('</span>\
                </div>\
                <div class="head-button-message-wrap">\
                  <input value="');  ngx.print(T"Stop"); ngx.print('" id="refresh" class="button button-apply purple" type="button">\
                </div>\
              </div>\
              ');  -- If both 2.4Ghz and 5Ghz Wifi passwords are same as default and their protection mode is not none
                 if securityMode24 ~= "none" and
                    securityMode5 ~= "none" and
                    get_from_transformer.defaultPassword == currentPassword24 and
                    get_from_transformer.defaultPassword == currentPassword5 then
                ngx.print('\
                <div class="head-message clearfix" id="global-msg-wifi" style="margin-top: -11px;">\
                  <div class="fL pull-left">\
                    <span>');  ngx.print(T"You are still using the default Wi-Fi password. To prevent unwanted users connecting, you should change it."); ngx.print('</span>\
                  </div>\
                  <div class="head-button-message-wrap">\
                    <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change25GHz" class="button button-apply purple" type="button">\
                    <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss25GHz" class="button button-cancel cancel-btn" type="button">\
                  </div>\
                </div>\
              ');  -- If 2.4Ghz Wifi password is same as default and protection mode is not none
                elseif securityMode24 ~= "none" and
                       get_from_transformer.defaultPassword == currentPassword24 then
                ngx.print('\
                <div class="head-message clearfix" id="global-msg-wifi24" style="margin-top: -11px;">\
                  <div class="fL pull-left">\
                    <span>');  ngx.print(T"Please change the default 2.4GHz Password"); ngx.print('</span>\
                  </div>\
                  <div class="head-button-message-wrap">\
                    <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change2GHz" class="button button-apply purple" type="button">\
                    <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss2GHz" class="button button-cancel cancel-btn" type="button">\
                  </div>\
                </div>\
              ');  -- If 5Ghz Wifi password is same as default and protection mode is not none
                elseif securityMode5 ~= "none" and
                       get_from_transformer.defaultPassword == currentPassword5 then
                ngx.print('\
                <div class="head-message clearfix" id="global-msg-wifi5" style="margin-top: -11px;">\
                  <div class="fL pull-left">\
                    <span>');  ngx.print(T"Please change the default 5GHz Password"); ngx.print('</span>\
                  </div>\
                  <div class="head-button-message-wrap">\
                    <input value="');  ngx.print(T"Change"); ngx.print('" id="global-btn-change5GHz" class="button button-apply purple" type="button">\
                    <input value="');  ngx.print(T"Dismiss"); ngx.print('" id="global-btn-dismiss5GHz" class="button button-cancel cancel-btn" type="button">\
                  </div>\
                </div>\
              ');  end   ngx.print('\
            </div>\
          </div>\
        </div>\
      </div>\
      ');  if pinState.mobileDevice == "1" then
         if pinState.state== "enabled_not_verified" or pinState.state== "disabled" then  ngx.print('\
           <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
             <div id="globalMessages">\
               <div class="rel">\
                 <div class="global-wrap">\
                   <div class="head-message clearfix" id="global-msg-lte-umts" style="margin-top: -11px;">\
                     <div class="fL pull-left">\
                       <span id ="global-msg-lte">');  ngx.print(T"The LTE SIM-Card PIN has changed. Please continue to enter the LTE PIN."); ngx.print('</span>\
                       <span id ="global-msg-umts">');  ngx.print(T"The UMTS SIM-Card PIN has changed. Please continue to enter the UMTS PIN."); ngx.print('</span>\
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
         ');  end  ngx.print('\
      ');   end   ngx.print('\
      ');   if pinState.mobileDevice == "1" then
        if pinState.state == "enabled_not_verified" then   ngx.print('\
          <div data-page-id="3620" class="page-loader-container warning-messages" data-page-alias="warning-messages">\
            <div id="globalMessages">\
              <div class="rel">\
                ');   if vdf_helper.getVariant() ~= "NZ" then   ngx.print('\
                  <div class="global-wrap">\
                    <div class="head-message clearfix" id="global-msg-lte-umts" style="margin-top: -11px;">\
                      <div class="fL pull-left">\
			');   if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
			  <span id ="global-msg-mobile">');  ngx.print(T"The Mobile SIM-Card PIN has changed. Please continue to enter the Mobile PIN.");  ngx.print('\</span>\
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
                ');  end  ngx.print('\
              </div>\
            </div>\
          </div>\
        ');  end
      end   ngx.print('\
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
    <div class="container-fluid no-padding" id="footer-bg">\
      <div class="language-info clearfix" id="language-info">\
        <div class="mobile-icon">\
        </div>\
        <div class="row padding-bottom-20">\
          <div class="col-xs-12 col-sm-4 col-md-4">\
            <ul id="language-switcher-list">\
              <li class="language-switcher" data-language-id="14">\
                <a href="#" class="lang-change" data-lang="en-us">English</a>\
              </li>\
              <li class="language-switcher" data-language-id="15">\
                <a href="#" class="lang-change" data-lang="spn">EspaÃ±ol</a>\
              </li>\
            </ul>\
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
            <p class="no-margin">');  ngx.print(T"WAN IP Address"); ngx.print(':&nbsp;');  ngx.print(get_from_transformer["wanipv4"]); ngx.print('\
                </p>\
            <p class="no-margin">');  ngx.print(T"WAN IPv6 Address"); ngx.print(':&nbsp;');  ngx.print(get_from_transformer["wanipv6"]); ngx.print('\
                </p>\
          </div>\
        </div>\
      </div>\
    </div>\
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
if (vdfVariant == "NZ") {\
  $("#global-msg-umts").hide();\
  $("#global-msg-lte").hide();\
}\
if ("');  ngx.print(pinState.networkType); ngx.print('" == "lte") {\
  $("#global-msg-umts").hide();\
}\
else {\
  $("#global-msg-lte").hide();\
}\
</script>\
'); 