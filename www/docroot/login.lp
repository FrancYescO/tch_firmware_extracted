--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local content_helper = require("web.content_helper")
local vodafone_helper = require("vodafone_helper")
local json = require("dkjson")
local format = string.format
local gatewayName = vodafone_helper.productName()
local ngx = ngx
local getArgs = ngx.req.get_uri_args()
local string = string
if ngx.var.request_method == "GET" and getArgs.action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end
if ngx.var.request_method == "GET" and getArgs.action == "getLangCode" then
local getRole = ngx.ctx.session:getrole()
local currentLang = proxy.get(string.format("uci.web.user.@usr_%s.language",getRole))[1].value
  ngx.print(currentLang)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "GET" and getArgs.getSessionStatus == "true" then
  ngx.header.content_type = "application/json"
  local wanIPAddress = proxy.get("rpc.network.interface.@wan.ipaddr") or {}
  wanIPAddress = wanIPAddress[1] and wanIPAddress[1].value or ""
  ngx.print(json.encode({status = 'alive', wanIPAddress = wanIPAddress}))
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().assistantState == "false" then
   assistant:enable(false)
end

if (getArgs.rb == "1") then
  local headers = ngx.req.get_headers()
  ngx.header["Access-Control-Allow-Origin"] = headers["Origin"]
  ngx.exit(ngx.HTTP_OK)
end
local gatewayIP = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
local ip = {}
string.gsub(gatewayIP, "%d+", function(octet)
  ip[#ip+1] = tonumber(octet)
end)
ip = table.concat(ip, ".")


local look_4 = vodafone_helper.look4()
local wanColour = vodafone_helper.wanColour()
local device_picture = vodafone_helper.devicepicture()

local titleName = "Gateways"
if vodafone_helper.getVariant() == "NZ" then
    titleName = "Login"
end

local get_from_transformer = {
   ["wanipv4"] = "rpc.network.interface.@wan.ipaddr",
   ["firmware-version"] = "rpc.system.SoftwareVersion",
   ["wwan"] = "rpc.network.interface.@wwan.ipaddr",
}

content_helper.getExactContent(get_from_transformer)

  ngx.print('\
<!DOCTYPE html>\
<html lang="en" class="no-js">\
<head>\
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
  <meta name="description" content="">\
  <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
  <title>');  ngx.print(T(titleName)); ngx.print('</title>\
  <link href="img/vdf-icon.png" type="/image/png" rel="icon" />\
  <link href="img/vdf-icon.png" type="/image/png" rel="shortcut icon" />\
  <link rel="stylesheet" type="text/css" href="/css/bootstrap.min.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('" />\
  <link rel="stylesheet" type="text/css" href="/css/login.css?');  ngx.print(get_from_transformer['firmware-version']); ngx.print('" />\
  <link rel="stylesheet" type="text/css" href="/css/vodafoneFont.css" />\
  <script src="/js/main-min.js"></script>\
  <script src="/js/srp-min.js"></script>\
  <script type="text/javascript" src="js/footer.js"></script>\
  <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->\
  <!-- WARNING: Respond.js doesn\'t work if you view the page via file:// -->\
  <!--[if lt IE 9]>\
  <script src="/js/html5shiv.min.js"></script>\
  <script src="/js/respond.min.js"></script>\
  <![endif]-->\
  <script>\
    if($("#navigation").html() != undefined){\
      window.location = "/";\
    }\
    if (document.documentElement) {\
      var cn = document.documentElement.className;\
      document.documentElement.className = cn.replace(/no-js/,\'\');\
    }\
    var cookieCheck = function(){\
      var cookieEnabled = (navigator.cookieEnabled) ? true : false;\
      if (!cookieEnabled)\
      {\
        $("#activation-content").css("display","none");\
        $(".login-cookies-display").css("display","block");\
      }\
      else{\
        $("#activation-content").css("display","block");\
        $(".login-cookies-display").css("display","none");\
      }\
    }\
    $(function(){\
      $("#login-cookie-reconnect").click(function(){\
        cookieCheck();\
      });\
      cookieCheck();\
      var ms_ie = false;\
      var ua = window.navigator.userAgent;\
      if ((ua.indexOf(\'MSIE \') > -1) || (ua.indexOf(\'Trident/\') > -1)) {\
         ms_ie = true;\
     }\
      if ( ms_ie ) {\
        var version=navigator.sayswho.split(" ");\
        if(version[1]==9) {\
          $("#activation-content-left > img").css("left","0");\
        }\
      }\
          if ( ms_ie ) {\
                var version=navigator.sayswho.split(" ");\
                if(version[1]<9) {\
                  $("#activation-content").css("display","none");\
                  $(".login-old-browsers").css("display","block");\
                }\
                else{\
                  $("#activation-content").css("display","block");\
                  $(".login-old-browsers").css("display","none");\
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
</head>\
<body>\
  <div class="section">\
    <div class="container-fluid mobile-padding-left-right-none no-margin-left-right ');  ngx.print(vodafone_helper.getVariant() == "VF-UK" and "gateway-46" or ""); ngx.print(' " id="look_4_activation">\
      <div class="row mobile-logo-align mobile-margin-left-right-none">\
        <div class="col-md-12">\
          <div id="page-rhombus-wrap">\
            <div id="rhombus-wrap">\
              <div id="rhombus-logo">\
                <div id="box-logo">\
                </div>\
              </div>\
              <div id="rhombus">\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
      <div id="activation-content-wrap">\
        <div id="activation-content" class="login-div-hide">\
      ');  if vodafone_helper.getVariant() == "VF-UK" then   ngx.print('\
            <div id="activation-top">\
              <div id="activation-top-left">\
                &nbsp;\
              </div>\
              <div id="activation-top-right">\
                <h1>\
                  <span>');  ngx.print(T"Welcome"); ngx.print('</span>\
                </h1>\
              </div>\
            </div>\
            <div id="activation-content-inner" class="clearfix">\
              <div id="activation-content-left">\
                <img src="/img/look_4/activation/boxes/vox3.0.png" alt="Router">\
              </div>\
              <div id="activation-content-right">\
                <div class="description">\
                  <div class="left">\
                    <span id = "WelcomeText">\
                      ');  ngx.print(format(T"Enter your %s password.", gatewayName)); ngx.print('\
                    </span>\
                  </div>\
                </div>\
                <form id="loginfrm">\
                  <div class="vdf-row description">\
                   <div class="left" style="display:none">\
                      <input type="hidden" id="login-txt-uname" placeholder="');  ngx.print(T"Username"); ngx.print('" class="max4"  value="vodafone"/>\
                    </div>\
                    <div class="left">\
                      <input type="password" id="login-txt-pwd" class="max4 vox-text"  />\
                    </div>\
                    <div class="left vox-loginbtn">\
                      <input class="button button-apply-wide button-apply" id="login-btn-logIn" value="');  ngx.print(T"Log In"); ngx.print('" type="submit" />\
                    </div>\
                  </div>\
                  <div class="vdf-row" style="display:none">\
                    <div class="left"></div>\
                    <div class="right" style="display:table-cell;text-align:right">\
                      <input class="button button-cancel button-wide forgotten-password" id="start" value="Forgotten Password" type="button">\
                    </div>\
                  </div>\
                  <div class="row no-margin-left-right">\
                    <div class="col-xs-12 col-md-12 col-sm-12 no-padding-left mobile-padding-top">\
                      <div class="message message-error " style="display:none">\
                        <span style="font-weight: bold">');  ngx.print(T"Incorrect password. Please try again."); ngx.print('</span>\
                      </div>\
                    </div>\
                  </div>\
                </form>\
              </div>\
            </div>\
          ');  elseif ip == ngx.var.server_addr then  ngx.print('\
            <div id="activation-top">\
              <div id="activation-top-left">\
                &nbsp;\
              </div>\
              <div id="activation-top-right">\
                <h1>\
                  <span>');  ngx.print(T"Welcome"); ngx.print('</span>\
                </h1>\
              </div>\
            </div>\
            <div id="activation-content-inner" class="clearfix">\
              <div id="activation-content-left">\
                <img src="');  ngx.print(device_picture); ngx.print('" alt="Router">\
              </div>\
              <div id="activation-content-right">\
                <div class="description">\
                  <div class="left">\
                    <span>');  ngx.print(T"Enter your username and password to access your configuration settings."); ngx.print('</span>\
                  </div>\
                </div>\
                <form id="loginfrm">\
                  <div class="vdf-row description">\
                    <div class="left">\
                      <input type="text"  id="login-txt-uname" placeholder="');  ngx.print(T"Username"); ngx.print('" class="max4" />\
                    </div>\
                  </div>\
                  <div class="vdf-row description">\
                    <div class="left">\
                      <input type="password"  id="login-txt-pwd" placeholder="');  ngx.print(T"Password"); ngx.print('" class="max4" />\
                    </div>\
                    <div class="right">\
                      <input class="button button-apply-wide button-apply" id="login-btn-logIn" value="');  ngx.print(T"Log In"); ngx.print('" type="submit" />\
                    </div>\
                  </div>\
                  <div class="row no-margin-left-right">\
                    <div class="col-xs-12 col-md-12 col-sm-12 no-padding-left mobile-padding-top">\
                      <div class="message message-error " style="display:none">\
                        <span>');  ngx.print(T"The username or password you entered are wrong. Please try again."); ngx.print('</span>\
                      </div>\
                    </div>\
                  </div>\
                </form>\
              </div>\
            </div>\
          ');  elseif ip ~= ngx.var.server_addr then   ngx.print('\
            <div id="activation-top" class="remote-access">\
              <div id="activation-top-left">&nbsp;</div>\
              <div id="activation-top-right">\
                <h1 class="no-margin-top">\
                  <span>');  ngx.print(T"Remote Access to your router"); ngx.print('</span>\
                </h1>\
              </div>\
            </div>\
            <div id="activation-content-inner" class="clearfix">\
              <div id="activation-content-left">\
                <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router">\
              </div>\
              <div id="activation-content-right">\
                <div class="description">\
                  <div class="left">\
                    <span>');  ngx.print(T"Enter your username and password for remote management to access configuration settings."); ngx.print('\
                    </span>\
                  </div>\
                </div>\
                <form id="loginfrm">\
                  <div class="vdf-row description">\
                    <div class="left">\
                      <input type="text" id="login-txt-uname" placeholder="');  ngx.print(T"Username"); ngx.print('" class="max4" />\
                    </div>\
                  </div>\
                  <div class="vdf-row description">\
                    <div class="left">\
                      <input type="password" id="login-txt-pwd" placeholder="');  ngx.print(T"Password"); ngx.print('" class="max4" />\
                    </div>\
                    <div class="right login-btn">\
                      <input class="button button-apply-wide button-apply" id="login-btn-logIn" value="');  ngx.print(T"Log In"); ngx.print('" type="submit" />\
                    </div>\
                  </div>\
                  <div class="row no-margin-left-right">\
                    <div class="col-xs-12 col-md-12 col-sm-12 no-padding-left mobile-padding-top">\
                      <div class="message message-error " style="display:none">\
                        <span> ');  ngx.print(T"The username or password you entered are wrong. Please try again."); ngx.print('\
                        </span>\
                      </div>\
                    </div>\
                  </div>\
                </form>\
              </div>\
            </div>\
          ');  end   ngx.print('\
          <!--<input type="button" class="step1back" data-step-id=\'1\' style="display:none;">-->\
          <div class="blackBackground" style="display:none;">&nbsp;</div>\
        </div>\
        <div id="activation-content" class="error-div-vox" style="display: none">\
          <div id="activation-top">\
            <div id="activation-top-left">\
              &nbsp;\
            </div>\
            <div id="activation-top-right">\
              <h1>&nbsp;</h1>\
            </div>\
          </div>\
          <div id="activation-content-inner" class="clearfix">\
            <div id="activation-content-left">\
              <img src="/img/look_4/activation/boxes/vox3.0.png" alt="Router">\
            </div>\
            <div id="activation-content-right" class="vdf-table">\
              <h1>');  ngx.print(T"Login currently blocked"); ngx.print('</h1>\
              <div class="vdf-row description">\
                <div class="left">\
                  <span>');  ngx.print(T"Next try in "); ngx.print('<span id="vox-error-waitTime"></span> ');  ngx.print(" seconds possible."); ngx.print('</span>\
                </div>\
              </div>\
              <div class="vdf-row description">\
                <div class="right" style="display:table-cell; text-align:right">\
                  <input type="button" value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply" id="error-btn-vox" >\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
        <noscript>\
          <div id="activation-content-inner" class="clearfix error">\
            <div id="activation-content-right" style="float:none; margin:0px auto">\
              <div style="width:auto; margin-top: 90px;" class="message-info">\
                <span>');  ngx.print(T"You have Javascript disabled."); ngx.print('</span><br>\
                <span>');  ngx.print(T"Please activate Javascript in the Browser settings for the best experience."); ngx.print('</span>\
              </div>\
            </div>\
          </div>\
        </noscript>\
        <div id="activation-content-right" style="float:none; margin:0px auto; display:none;" class="login-cookies-display">\
          <div style="width:auto; margin-top: 90px;" class="message message-info">\
            <span>');  ngx.print(T"You have Cookies disabled."); ngx.print('</span><br>\
            ');  if vodafone_helper.getVariant() == "NZ" then   ngx.print('\
            <span>');  ngx.print(T"Please activate Cookies in the Browser settings and refresh the page for the best experience."); ngx.print('</span>\
            ');  else   ngx.print('\
            <span>');  ngx.print(T"Please activate Cookies in the Browser settings for the best experience."); ngx.print('</span>\
          </div>\
          <div class="row cookie-row no-margin-row">\
            <div class="text-right">\
              <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply auto-width" type="button" id="login-cookie-reconnect">\
            </div>\
            ');  end   ngx.print('\
          </div>\
        </div>\
        <div id="activation-content-right" style="float:none; margin:0px auto; display:none" class="login-old-browsers">\
          <div style="width:auto; margin-top: 90px;" class="message message-info">\
            <span>');  ngx.print(T"The Browser is not supported."); ngx.print('</span><br><br>\
            <span>');  ngx.print(T"This Website is best viewed using internet Explorer version 10 or higher and/or latest Chrome version or Firefox version 4.0 or higher"); ngx.print('</span>\
          </div>\
        </div>\
      </div>\
      ');  if vodafone_helper.getVariant() ~= "NZ" then   ngx.print('\
      <div class="container-fluid no-padding" id="footer-bg">\
        <div class="language-info clearfix" id="language-info">\
          <div class="mobile-icon"></div>\
          <p class="no-margin" style="float: right;">');  ngx.print(T"WAN IP Address"); ngx.print(':&nbsp;<span id="footer-wanip">');  ngx.print(get_from_transformer["wanipv4"] ~= "" and get_from_transformer["wanipv4"] or get_from_transformer["wwan"]  ); ngx.print('</span>\
          <div class="row no-margin-left-right padding-bottom-20">\
            <div class="col-xs-12 col-sm-4 col-md-4">\
              ');  if vodafone_helper.getVariant() == "ES" then   ngx.print('\
                <ul id="language-switcher-list">\
                  <li class="language-switcher" data-language-id="14">\
                    <a href="#"onclick = "lang_change(\'en-us\')">English</a>\
                  </li>\
                  <li class="language-switcher" data-language-id="15">\
                    <a href="#" onclick = "lang_change(\'spn\')">Spanish</a>\
                  </li>\
                </ul>\
              ');  end  ngx.print('\
            </div>\
            <div class="col-xs-12 col-sm-3 col-md-3">\
              <div class="row">\
                <div class="col-xs-12 hidden-lg hidden-md hidden-sm">\
                  <hr class="footer-spain-bdr"/>\
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
      ');  end   ngx.print('\
    </div>\
  </div>\
  <div class="modal fade" id="loginfailure" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
      <!-- Modal content-->\
      <div class="modal-content">\
        <div class="modal-body no-padding">\
          <form class="form-horizontal tC ">\
            <div class="vdf-table">\
              <div class="vdf-row">\
                <div class="left">\
                  <label for="inputPassword" class="control-label">');  ngx.print(T"You are trying to login with wrong password for"); ngx.print(' <span id="pwdCount"></span> ');  ngx.print(T"times, please"); ngx.print('<br/> ');  ngx.print(T"wait"); ngx.print(' <span id="timerSec"></span>');  ngx.print(T"seconds to enter new password."); ngx.print('</p></label>\
                </div>\
              </div>\
            </div>\
            <div class="col-sm-12 col-md-12 col-lg-12 loading-img">\
              <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
            </div>\
          </form>\
        </div>\
      </div>\
    </div>\
  </div>\
  <script>\
    var variant = "');  ngx.print(vodafone_helper.getVariant()); ngx.print('";\
    $(function(){\
      //The pageLoaded session variable determines if login page is loaded on opening the browser.\
      var pageLoaded = sessionStorage.getItem("pageLoaded");\
      //The langCode session variable determines the language selected.\
      var langCode = sessionStorage.getItem("langCode");\
      //The cookieExist session variable checks if cookies were removed in session from browser.\
      //On removing cookies, the webui language cookie need to be set to spanish by default.\
      var cookieExist = document.cookie;\
      if (!(pageLoaded) && !(langCode) || cookieExist.length === 0) {\
        //Change language to spanish by default on page load\
        if (variant == "NZ"){\
          lang_change("en-us", "login");\
        } else {\
 	  lang_change("spn", "login");\
	}\
      }\
\
      var sessionStatus = setInterval(getSessionStatus, 30000);\
      function getSessionStatus() {\
        $.get("/login.lp", { getSessionStatus : true }, function(data) {\
          $(\'#footer-wanip\').text(data.wanIPAddress); // Update footer WAN IP dynamically\
        });\
      }\
\
      //Login button function\
      $(\'input[type="password"]\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10)\
        {\
          if (!$("#loginfailure").is(":visible")) {\
            $("#login-btn-logIn").trigger(\'click\');\
            $("#login-btn-logIn").attr("disabled", "disabled");\
          }\
        }\
      });\
    });\
\
    (function($)\
     {\
    //Remove sessionstorage modeval data\
    sessionStorage.removeItem(\'modeVal\');\
    $("#look_4_activation").removeClass("gateway-46");\
    if (variant==="VF-UK"){\
      $("#look_4_activation").addClass("gateway-46");\
    }\
      // Save data to sessionStorage\
      sessionStorage.setItem(\'page_load_count\', \'0\');\
      var isValid = null;\
      var form = $(\'form\');\
      var submitButton = form.find(\'button[type="submit"]\')\
      var saveButton = submitButton.filter(\'[name="login-btn-logIn"]\');\
      var timeSecond, wrongPwdCount;\
      //submit form behavior\
      var submitForm = function(e)\
      {\
        //prevent form from submitting valid or invalid\
        var srp = new SRP();\
        srp.success = function() {\
          // If we showed the login page using an internal redirect (detected\
          // by checking if the URL ends with "/login.lp") then we simply\
          // have to reload the page to get the actual page content now that\
          // we\'re logged in.\
          // Otherwise we explicitly go back to the main page.\
          $.get("login.lp", { action:"getLangCode"}, function (data) {\
            setCookie("webui_language", data, 30);\
            if (window.location.pathname.search(/\\/login\\.lp$/) == -1)\
            {\
              var curl = window.location.href\
              window.location.href = curl.substring(0,curl.indexOf("#"));\
            }\
            else\
              window.location = "/";\
          });\
        };\
        srp.error_message = function(err) {\
          if(err == 403)\
          {\
            $.get("login.lp", { action:"getcsrf"}, function (data) {\
              $(\'meta[name=CSRFtoken]\').attr(\'content\', data);\
              if (!$("#loginfailure").is(":visible")) {\
                srp.identify("/authenticate", $("#login-txt-uname")[0].value, $("#login-txt-pwd")[0].value);\
              }\
            });\
          }else{\
            $(\'.message-error\').show();\
            if (variant == "VF-UK"){\
              $("#WelcomeText").text(\'');  ngx.print( T"Enter your Vodafone Broadband Router password to manage your settings."); ngx.print('\');\
            }\
            timeSecond = err.waitTime;\
            wrongPwdCount = err.wrongCount;\
            if(timeSecond > 0 )\
            {\
              $("#timerSec, #vox-error-waitTime").text(timeSecond);\
              $("#pwdCount").text(wrongPwdCount);\
              if (variant == "VF-UK"){\
                $(".login-div-hide").css("display","none");\
                $(".error-div-vox").css("display","block");\
                $("#error-btn-vox").attr("disabled", "disabled");\
              }else{\
              $(\'#loginfailure\').modal(\'show\');\
              }\
              callTimer();\
            } else {\
              $("#login-btn-logIn").removeAttr("disabled");\
            }\
            $("#sign-me-in").text(\'');  ngx.print( T"Sign in" ); ngx.print('\');\
            $(\'#login-btn-logIn\').parent().addClass("text-right");\
            $("#login-txt-uname").addClass("input-error");\
            $("#login-txt-pwd").addClass("input-error");\
          }\
        }\
        function callTimer() {\
           timeInterval = setInterval(function() {\
               $("#timerSec, #vox-error-waitTime").text(--timeSecond);\
               if (timeSecond == 0 || timeSecond < 0) {\
                 clearInterval(timeInterval);\
                if (variant == "VF-UK"){\
                  $("#error-btn-vox").removeAttr("disabled");\
                }else{\
                 $(\'#loginfailure\').modal(\'hide\');\
                }\
                 $("#login-btn-logIn").removeAttr("disabled");\
               };\
           }, 1000);\
        }\
        $("#error-btn-vox").click(function(){\
          $(".error-div-vox").css("display","none");\
          $(".login-div-hide").css("display","block");\
        })\
        if (!$("#loginfailure").is(":visible")) {\
          srp.identify("/authenticate", $("#login-txt-uname")[0].value, $("#login-txt-pwd")[0].value);\
        }\
        e.preventDefault();\
        //user clicked and the form was not valid\
        if(isValid === false)\
        {\
          isValid = null;\
          return false;\
        }\
        //user pressed enter, process as if they clicked save instead\
        saveButton.trigger(\'click\');\
      };\
      //override submit button behavior\
      var submitClick = function(e){\
        //Test form validitiy (HTML5) and store it in a global variable so both functions can use it\
        isValid = form[0].checkValidity();\
        if(false === isValid)\
        {\
          //allow the browser\'s default submit event behavior\
          return true;\
        }\
        //prevent default behavior\
        e.preventDefault();\
        //additional processing - $.ajax() etc\
      };\
      //override submit form event\
      form.submit(submitForm);\
      //override submit button click event\
      submitButton.click(submitClick);\
    }\
    )(jQuery);\
  </script>\
  <script>\
    $(document).ready(function(){\
        // Add smooth scrolling to all links\
        $("html, body").animate({\
        scrollTop: 0 }, "slow");\
    });\
\
  </script>\
  </body>\
</html>\
'); 