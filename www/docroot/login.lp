--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")

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
  ngx.print('\
<!DOCTYPE html>\
<html lang="en" class="no-js">\
<head>\
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
  <meta name="description" content="">\
  <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
  <title>');  ngx.print(T"Login"); ngx.print('</title>\
  <link href="img/favicon.png" type="/image/png" rel="icon" />\
  <link href="img/favicon.png" type="/image/png" rel="shortcut icon" />\
  <link rel="stylesheet" type="text/css" href="/css/bootstrap.min.css" />\
  <link rel="stylesheet" type="text/css" href="/css/login.css" />\
  <link rel="stylesheet" type="text/css" href="/css/vodafoneFont.css" />\
  <script src="/js/jquery-min.js"></script>\
  <script src="/js/bootstrap.min.js"></script>\
  <script src="/js/jquery-ui.min.js"></script>\
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
    $(function(){\
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
    <div class="container-fluid mobile-padding-left-right-none no-margin-left-right">\
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
          <div id="activation-content">\
            ');  if ip == ngx.var.server_addr then  ngx.print('\
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
                        <img src="/img/look_4/activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router">\
                        </div>\
                        <div id="activation-content-right">\
                        <div class="description">\
                        <div class="left">\
                                 <span>\
                    ');  ngx.print(T"Enter your username and password to access your configuration settings."); ngx.print('\
                      </span>\
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
                <span>\
                                ');  ngx.print(T"The username or password you entered are wrong. Please try again."); ngx.print('\
                </span>\
              </div>\
          </div>\
        </div>\
                </form>\
        </div>\
</div>\
          ');  else  ngx.print('\
            <div id="activation-top" class="remote-access">\
              <div id="activation-top-left"> &nbsp;\
              </div>\
              <div id="activation-top-right">\
                <h1 class="no-margin-top">\
                  <span>');  ngx.print(T"Remote Access to your router"); ngx.print('</span>\
                </h1>\
              </div>\
            </div>\
            <div id="activation-content-inner" class="clearfix">\
              <div id="activation-content-left">\
                <img src="/img/look_4/activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router">\
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
');  end  ngx.print('\
<!--<input type="button" class="step1back" data-step-id=\'1\' style="display:none;">-->\
<div class="blackBackground" style="display:none;">&nbsp;</div>\
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
              <span>');  ngx.print(T"Please activate Cookies in the Browser settings and refresh the page for the best experience."); ngx.print('</span>\
            </div>\
          </div>\
                  <div id="activation-content-right" style="float:none; margin:0px auto; display:none" class="login-old-browsers">\
            <div style="width:auto; margin-top: 90px;" class="message message-info">\
              <span>');  ngx.print(T"The Browser is not supported."); ngx.print('</span><br><br>\
              <span>');  ngx.print(T"This Website is best viewed using internet Explorer version 10 or higher and/or latest Chrome version or Firefox version 4.0 or higher"); ngx.print('</span>\
          </div>\
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
                    <a href="#"onclick = "lang_change(\'en-us\')">English</a>\
                  </li>\
                <li class="language-switcher" data-language-id="15">\
                    <a href="#" onclick = "lang_change(\'spn\')">Spanish</a>\
                  </li>\
              </ul>\
            </div>\
            <div class="col-xs-12 col-sm-3 col-md-3">\
        <div class="row">\
        <div class="col-xs-12 hidden-lg hidden-md hidden-sm">\
          <hr class="footer-spain-bdr"/>\
        </div>\
        </div>\
            </div>\
            <div class="col-xs-12 col-sm-5 col-md-5 footer-wanipv6">\
              <p>\
              </p>\
              <p>\
              </p>\
              <p>\
              </p>\
            </div>\
          </div>\
        </div>\
       </div>\
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
              <label for="inputPassword" class="control-label">');  ngx.print(T"You are trying to login with wrong password for"); ngx.print(' <span id="pwdCount"></span> ');  ngx.print(T"times, please"); ngx.print('<br/> ');  ngx.print(T"wait"); ngx.print(' <span id="timerSec"></span> ');  ngx.print(T"seconds to enter new password."); ngx.print('</p></label>\
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
    $(function(){\
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
    (function($)\
     {\
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
            timeSecond = err.waitTime;\
            wrongPwdCount = err.wrongCount;\
            if(timeSecond > 0 )\
            {\
              $("#timerSec").text(timeSecond);\
              $("#pwdCount").text(wrongPwdCount);\
             $(\'#loginfailure\').modal(\'show\');\
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
               $("#timerSec").text(--timeSecond);\
               if (timeSecond == 0 || timeSecond < 0) {\
                 clearInterval(timeInterval);\
                 $(\'#loginfailure\').modal(\'hide\');\
                 $("#login-btn-logIn").removeAttr("disabled");\
               };\
           }, 1000);\
        }\
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