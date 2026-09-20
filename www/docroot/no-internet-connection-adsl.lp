--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local getargs = ngx.req.get_uri_args()

local look_4 = vdf_helper.look4()

local gatewayName = vdf_helper.productName()

if ngx.req.get_uri_args().action == "getPingStatus" then
  local pingStatus = {
    State          = "uci.ipping.@diagping.DiagnosticsState",
    SuccessCount   = "uci.ipping.@diagping.SuccessCount",
    FailureCount   = "uci.ipping.@diagping.FailureCount",
  }
  content_helper.getExactContent(pingStatus)
  if pingStatus.State == "Requested" then
    ngx.print("progress")
    elseif pingStatus.State == "Complete" and (pingStatus.SuccessCount ~= "0" or pingStatus.FailureCount ~= "0") then
    local pingResult    = {
      IP          = "uci.ipping.@diagping.Trace.@1.IP",
      SuccessRate = "uci.ipping.@diagping.SuccessCount",
      PacketSize  = "uci.ipping.@diagping.DataBlockSize",
      AverageRTT  = "uci.ipping.@diagping.AverageResponseTime",
    }
    content_helper.getExactContent(pingResult)
    pingResult.status = "success"
    ngx.print("success")
  else
    ngx.print("error")
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_uri_args().action == "ping" then
  local pingStatus = proxy.get("uci.ipping.@diagping.DiagnosticsState")
  if pingStatus then
    pingStatus = pingStatus[1].value
  end
  if pingStatus ~= "Requested" then
    if not proxy.getPN("uci.ipping.@diagping.", true) then
      proxy.add("uci.ipping.","diagping")
    end
    proxy.set({
      ["uci.ipping.@diagping.Host"]                 = "www.google.com",
      ["uci.ipping.@diagping.NumberOfRepetitions"] = "5",
      ["uci.ipping.@diagping.DiagnosticsState"]     = "Requested",
    })
    proxy.apply()
    ngx.print("progress")
  else
    ngx.print("error")
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_uri_args().action == "connect" and vdf_helper.getVariant() == "NZ" then
  proxy.set("uci.network.interface.@wwan.auto","1")
  proxy.apply()
  conn:call("network.interface.wwan", "up", { })
  ngx.exit(ngx.HTTP_OK)
end

local mobiled = {
  DeviceNumberOfEntries = "rpc.mobiled.DeviceNumberOfEntries",
}
content_helper.getExactContent(mobiled)
  ngx.print('\
\
<!DOCTYPE html>\
<html lang="en" class="no-js">\
\
<head>\
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />\
    <meta http-equiv="Pragma" content="no-cache" />\
    <meta name="description" content="">\
    <title>\
        ');  ngx.print(T "Gateways"); ngx.print('\
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
                            <h1>\
                               <span class="txt-space hide">&nbsp;</span><!-- Wizard Title None -->\
          </h1>\
                        </div>\
                        <!-- Header Right Column -->\
                        <div id="activation-top-right">\
                            <!-- Header Welcome Text  -->\
                            <h1 class="no-internet-title"><span>');  ngx.print(T"No internet connection"); ngx.print('</span></h1>\
                        </div>\
                    </div>\
\
                    <!-- Column Container  -->\
                    <div id="activation-content-inner" class="clearfix">\
\
                        <!-- Left Column -->\
                        <div id="activation-content-left">\
\
                            <!-- Left column correspondant images -->\
             <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_back_side_router_og.jpg" alt="Router" class="ads-troubleshoot hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router" class="vdf-box">\
             <img src="');  ngx.print(look_4); ngx.print('activation/01-VodafoneH500-t01.jpg" alt="Router" class="vodafone-h500-t01 hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/02-VodafoneH500-t02.jpg" alt="Router" class="vodafone-h500-t02 hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/03-VodafoneH500-t03.jpg" alt="Router" class="vodafone-h500-t03 hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/04-VodafoneH500-t04.jpg" alt="Router" class="vodafone-h500-t04 hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/05-VodafoneH500-t05.jpg" alt="Router" class="vodafone-h500-t05 hide">\
             <img src="');  ngx.print(look_4); ngx.print('activation/06-VodafoneH500-t06.jpg" alt="Router" class="vodafone-h500-t06 hide">\
                        </div>\
\
                        <!-- Right Column -->\
                        <div id="activation-content-right" class="no-padding-left-right">\
\
                        <!-- No Internet Connection - ADSL -->\
               <div class="row_wizard description no-internet-adsl-desc">\
        <div class="left">\
           <span>');  ngx.print(T"The router doesn't have an Internet connection. We recommend performing the following actions before contacting your Vodafone Technical Support."); ngx.print('</span><br>\
           ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
           <span class="padding-left-20">');  ngx.print(T"Personal customers"); ngx.print('</span><br>\
           <span class="padding-left-40">');  ngx.print(T"ADSL / VDSL service - 0800 438 448"); ngx.print('</span><br>\
           <span class="padding-left-40">');  ngx.print(T"Fibre broadband service - 0800 806 106"); ngx.print('</span><br>\
           <span class="padding-left-40">');  ngx.print(T"FibreX / Fibre service - 0508 888 800"); ngx.print('</span><br>\
           <span class="padding-left-20">');  ngx.print(T"Business customers"); ngx.print('</span><br>\
           <span class="padding-left-40">');  ngx.print(T"All Service - 0800 400 888"); ngx.print('</span><br>\
           ');  end  ngx.print('\
        </div>\
         </div>\
        <div class="row_wizard description no-internet-adsl-desc">\
                 <div class="left">\
               <span>');  ngx.print(T"After each step check if the service has recovered. It's important to pay attention to loose wires and connectors."); ngx.print('</span>\
                 </div>\
        </div>\
        <div class="row_wizard no-internet-adsl-desc">\
             <div class="right">\
          <input class="button button-apply adsl-continue-btn" value="');  ngx.print(T"Continue"); ngx.print('" type="button">\
           ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
          <input class="button button-cancel adsl-skip-btn" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
           ');  end  ngx.print('\
           </div>\
        </div>\
\
      <!-- No Internet Connection Check - ADSL -->\
          <div class="row_wizard description no-internet-cable-adsl-desc no-border-top hide">\
        <div class="left">\
           ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
            <span>');  ngx.print(T"Check the cabling and the connections between the telephone outlet and the " .. gatewayName .. "."); ngx.print('</span>\
           ');  else  ngx.print('\
            <span>');  ngx.print(T"Check the cabling and the connections between the PTR, the telephone outlet and the Router."); ngx.print('</span>\
           ');  end  ngx.print('\
        </div>\
          </div>\
          <div class="row_wizard no-internet-cable-adsl-desc hide">\
        <div class="right">\
            <input class="button button-cancel adsl-cable-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
            <input class="button button-apply adsl-cable-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
           ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
            <input class="button button-cancel adsl-cable-skip-btn" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
           ');  end  ngx.print('\
        </div>\
          </div>\
\
      <!-- No Internet Disconnect and connect the power supply of the router - ADSL -->\
          <div class="row_wizard description adsl-router-desc no-border-top hide">\
        <div class="left">\
           ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
            <span>');  ngx.print(T"Disconnect and connect the power supply of the " .. gatewayName .. "."); ngx.print('</span>\
           ');  else  ngx.print('\
            <span>');  ngx.print(T"Disconnect and connect the power supply of the router."); ngx.print('</span>\
           ');  end  ngx.print('\
        </div>\
          </div>\
          <div class="row_wizard adsl-router-desc hide">\
        <div class="right">\
            <input class="button button-cancel adsl-router-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
            ');  if vdf_helper.getVariant() == "NZ" and mobiled.DeviceNumberOfEntries == '1' then  ngx.print('\
            <input class="button button-cancel adsl-router-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
            <input class="button button-cancel adsl-router-skip-btn" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
            ');  end   ngx.print('\
        </div>\
          </div>\
\
      <!-- No Internet Disconnect and connect via LTE backup - ADSL -->\
          ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
          <div class="row_wizard description adsl-lte-backup no-border-top hide">\
        <div class="left">\
            <span>');  ngx.print(T"To connect via the cellular network insert SIM and click connect. Mobile charges will apply."); ngx.print('</span>\
        </div>\
          </div>\
          <div class="row_wizard adsl-lte-backup hide">\
        <div class="right">\
            <input class="button button-cancel adsl-lte-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
            <input class="button button-cancel adsl-lte-backup-btn" value="');  ngx.print(T"Connect"); ngx.print('" type="button">\
            <input class="button button-cancel adsl-lte-skip-btn" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
            <div class= "waiting-status activation-hide" style= "padding-right: 120px;">\
            <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
            </div>\
        </div>\
          </div>\
          ');  end   ngx.print('\
                        </div>\
                    </div>\
                </div>\
            </div>\
        ');  if vdf_helper.getVariant() ~= "NZ" then   ngx.print('\
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
            ');  end  ngx.print('\
        </div>\
    </div>\
\
    <script>\
        var target = "/no-internet-connection-adsl.lp";\
        $(document).ready(function() {\
            // Add smooth scrolling to all links\
            $(\'input:radio[name=connection]\').removeClass("radio-checked").addClass("radio-unchecked");\
            $("html, body").animate({\
                scrollTop: 0\
            }, "slow");\
            //No Internet Continue Function - ADSL\
            $(".adsl-continue-btn").click(function() {\
                $(".no-internet-adsl-desc, .vdf-box").addClass("hide");\
                $(".no-internet-cable-adsl-desc, .vodafone-h500-t05").removeClass("hide");\
            });\
            //No Internet Cable Next Function - ADSL\
            $(".adsl-cable-next-btn").click(function() {\
                $(".vodafone-h500-t05, .no-internet-cable-adsl-desc").addClass("hide");\
                $(".vodafone-h500-t04, .adsl-router-desc").removeClass("hide");\
            });\
            $(".adsl-router-next-btn").click(function() {\
                $(".vodafone-h500-t04, .adsl-router-desc").addClass("hide");\
                $(".vodafone-h500-t06, .adsl-lte-backup").removeClass("hide");\
            });\
      //No Internet ONT/Router Next Function\
            $(".ont-next-btn").click(function() {\
                $(".vodafone-h500-t02, .no-internet-ont-desc").addClass("hide");\
                $(".vodafone-h500-t03, .ont-conn-desc").removeClass("hide");\
            });\
      //No Internet ONT/Router Next Function\
            $(".ont-conn-next-btn").click(function() {\
                $(".vodafone-h500-t03, .ont-conn-desc").addClass("hide");\
                $(".vodafone-h500-t04, .router-desc").removeClass("hide");\
            });\
      //No Internet Disconnect and connect via LTE backup Function\
            $(".adsl-lte-backup-btn").click(function() {\
              $(".waiting-status").removeClass("activation-hide");\
              $.get(target+"?action=connect", function(responseTxt) {\
              });\
              $.get(target+"?action=ping", function(responseTxt) {\
                if (responseTxt == "progress") {\
                  window.setTimeout(function(){\
                    getStatus(target);\
                  }, 5000);\
                }\
              });\
            });\
      //Try Finish button function for redirect to login page\
            $(".adsl-router-try-btn, .adsl-cable-try-btn, .adsl-lte-try-btn").click(function() {\
              $.get(target+"?action=ping", function(responseTxt) {\
                if (responseTxt == "progress") {\
                  window.setTimeout(function(){\
                    getStatus(target);\
                  }, 5000);\
                }\
              });\
            });\
      //Cancel button function for redirect to login page\
            $(".adsl-skip-btn, .adsl-cable-skip-btn, .adsl-router-skip-btn, .adsl-lte-skip-btn").click(function() {\
              window.location = "/";\
            });\
   function getStatus(target) {\
    $.ajax({\
      url: target+"?action=getPingStatus",\
      timeout: 10000, // If a request takes more than 10 seconds, Show failed message\
      cache: false,\
      contentType: false,\
      processData: false,\
      type: \'get\'\
    })\
    .success(function(responseTxt, statusTxt, xhr) {\
      if (responseTxt == "success") {\
        var prevUrl = \'');  ngx.print(getargs.url); ngx.print('\';\
        var redirectURL = location.protocol+"//"+prevUrl;\
        location.href = redirectURL;\
      } else if (responseTxt == "progress") {\
        window.setTimeout(function() {\
          xhr.abort();\
          getStatus(target);\
          return true;\
        }, 5000);\
      } else if (responseTxt == "error") {\
        window.location = target+"?url=');  ngx.print(getargs.url); ngx.print('";\
      } else {\
        return false;\
      }\
    })\
    .error(function() {\
      return false;\
    });\
  }\
});\
    </script>\
</body>\
\
</html>\
'); 