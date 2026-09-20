--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local getargs = ngx.req.get_uri_args()

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

if ngx.req.get_uri_args().action == "connect" then
  proxy.set("uci.network.interface.@wwan.auto","1")
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end

local mobiled = {
	DeviceNumberOfEntries = "rpc.mobiled.DeviceNumberOfEntries",
}
content_helper.getExactContent(mobiled)
  ngx.print('\
\
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
    <link href="img/favicon.png" type="/image/png" rel="icon" />\
    <link href="img/favicon.png" type="/image/png" rel="shortcut icon" />\
    <link rel="stylesheet" type="text/css" href="/css/bootstrap.min.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation-wizard.css" />\
    <link rel="stylesheet" type="text/css" href="/css/activation-wizard-responsive.css" />\
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
                            <!-- Left column correspondant images -->\
                            <img src="/img/look_4/activation/boxes/160705_back_side_router_og.jpg" alt="Router" class="ads-troubleshoot hide">\
                            <img src="/img/look_4/activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router" class="vdf-box">\
                            <img src="/img/look_4/activation/01-VodafoneH500-t01.jpg" alt="Router" class="vodafone-h500-t01 hide">\
                            <img src="/img/look_4/activation/02-VodafoneH500-t02.jpg" alt="Router" class="vodafone-h500-t02 hide">\
                            <img src="/img/look_4/activation/03-VodafoneH500-t03.jpg" alt="Router" class="vodafone-h500-t03 hide">\
                            <img src="/img/look_4/activation/04-VodafoneH500-t04.jpg" alt="Router" class="vodafone-h500-t04 hide">\
                            <img src="/img/look_4/activation/06-VodafoneH500-t06.jpg" alt="Router" class="vodafone-h500-t06 hide">\
                        </div>\
\
                        <!-- Right Column -->\
                        <div id="activation-content-right" class="no-padding-left-right">\
\
                            <!-- No Internet Connection - FTTH-->\
                            <div class="row_wizard description no-internet-desc">\
                                <div class="left">\
                                    <span>');  ngx.print(T"The router doesn't have an Internet connection. We recommend performing the following actions before contacting your Vodafone Technical Support."); ngx.print('</span><br>\
                                    <span class="padding-left-20">');  ngx.print(T"Personal customers"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"ADSL / VDSL service - 0800 438 448"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"Fibre broadband service - 0800 806 106"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"FibreX / Fibre service - 0508 888 800"); ngx.print('</span><br>\
                                    <span class="padding-left-20">');  ngx.print(T"Business customers"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"All Service - 0800 400 888"); ngx.print('</span>\
								</div>\
                            </div>\
                               <div class="row_wizard description no-internet-desc">\
                                <div class="left">\
                                    <span>');  ngx.print(T"After each step check if the service has recovered. It's important to pay attention to loose wires and connectors."); ngx.print('</span>\
								</div>\
                            </div>\
                            <div class="row_wizard no-internet-desc">\
                                <div class="right">\
                                    <input class="button button-apply continue-btn" value="');  ngx.print(T"Continue"); ngx.print('" type="button">\
                                    <input class="button button-cancel btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
\
                            <!-- No Internet Connection Check - FTTH-->\
                            <div class="row_wizard description no-internet-cable-desc no-border-top hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Check the cabling and the connections between Vodafone Ultra Hub and the ONT."); ngx.print('</span>\
								</div>\
                            </div>\
                            <div class="row_wizard no-internet-cable-desc hide">\
                                <div class="right">\
                                    <input class="button button-cancel cable-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
                                    <input class="button button-apply cable-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                                    <input class="button button-cancel cable-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
\
                            <!-- No Internet Connection Check ONT b/w Router - FTTH -->\
                            <div class="row_wizard description no-internet-ont-desc no-border-top hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Check the cabling and the connections between the ONT and the Vodafone Ultra Hub."); ngx.print('</span>\
								</div>\
                            </div>\
                            <div class="row_wizard no-internet-ont-desc hide">\
                                <div class="right">\
                                    <input class="button button-cancel ont-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
                                    <input class="button button-apply ont-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                                    <input class="button button-cancel ont-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
\
                            <!-- No Internet Connection ONT Connect/Disconnect -FTTH -->\
                            <div class="row_wizard description ont-conn-desc no-border-top hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Disconnect and connect the power supply of the ONT."); ngx.print('</span>\
								</div>\
                            </div>\
                            <div class="row_wizard ont-conn-desc hide">\
                                <div class="right">\
                                    <input class="button button-cancel ont-conn-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
                                    <input class="button button-apply ont-conn-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
                                    <input class="button button-cancel ont-conn-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
\
                            <!-- No Internet Connection Disconnect and connect the power supply of the router. -FTTH -->\
                            <div class="row_wizard description router-desc no-border-top hide">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Disconnect and connect the power supply of the router."); ngx.print('</span>\
								</div>\
                            </div>\
                            <div class="row_wizard router-desc hide">\
                                <div class="right">\
                                    <input class="button button-cancel router-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
				 				    ');  if mobiled.DeviceNumberOfEntries == '1' then ngx.print('\
										<input class="button button-apply router-next-btn" value="');  ngx.print(T"Next"); ngx.print('" type="button">\
								    ');  end ngx.print('\
                                    <input class="button button-cancel router-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
\
							<!-- No Internet Disconnect and connect via LTE backup -->\
						    <div class="row_wizard description lte-backup no-border-top hide">\
			                  <div class="left">\
			                    <span>');  ngx.print(T"To connect via the Vodem Stick, click connect. Mobile charges will apply."); ngx.print('</span>\
			                 </div>\
						    </div>\
						    <div class="row_wizard lte-backup hide">\
							  <div class="right">\
							    <input class="button button-cancel lte-try-btn" value="');  ngx.print(T"Try Again"); ngx.print('" type="button">\
							    <input class="button button-apply lte-backup-btn" value="');  ngx.print(T"Connect"); ngx.print('" type="button">\
			                    <input class="button button-cancel lte-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
							  </div>\
						    </div>\
\
                        </div>\
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
    <script>\
        var target = "/no-internet-connection-ftth.lp";\
        $(document).ready(function() {\
            // Add smooth scrolling to all links\
            $(\'input:radio[name=connection]\').removeClass("radio-checked").addClass("radio-unchecked");\
            $("html, body").animate({\
                scrollTop: 0\
            }, "slow");\
            //No Internet Continue Function\
            $(".continue-btn").click(function() {\
                $(".no-internet-desc, .vdf-box").addClass("hide");\
                $(".no-internet-cable-desc, .vodafone-h500-t01").removeClass("hide");\
            });\
            //No Internet Cable Next Function\
            $(".cable-next-btn").click(function() {\
                $(".vodafone-h500-t01, .no-internet-cable-desc").addClass("hide");\
                $(".vodafone-h500-t04, .router-desc").removeClass("hide");\
            });\
            $(".router-next-btn").click(function() {\
                $(".vodafone-h500-t04, .router-desc").addClass("hide");\
                $(".vodafone-h500-t06, .lte-backup").removeClass("hide");\
            });\
		    //No Internet Disconnect and connect via LTE backup Function\
            $(".lte-backup-btn").click(function() {\
              $.get(target+"?action=connect", function(responseTxt) {\
              });\
              $.get(target+"?action=ping", function(responseTxt) {\
                if (responseTxt == "progress") {\
                  window.setTimeout(function(){\
                    getStatus(target);\
                  }, 5000);\
                }else {\
                }\
              });\
            });\
            //Try Finish button function for redirect to login page\
            $(".router-try-btn, .cable-try-btn, .ont-conn-try-btn, .ont-try-btn, .lte-try-btn").click(function() {\
              $.get(target+"?action=ping", function(responseTxt) {\
                if (responseTxt == "progress") {\
                  window.setTimeout(function(){\
                    getStatus(target);\
                  }, 5000);\
                }else {\
                }\
              });\
            });\
		    //Cancel button function for redirect to login page\
            $(".btn-skip, .cable-btn-skip, .router-btn-skip, .lte-btn-skip").click(function() {\
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
        var redirectURL = "http://"+prevUrl;\
        location.href = redirectURL;\
      } else if (responseTxt == "progress") {\
        window.setTimeout(function() {\
          xhr.abort();\
          getStatus(target);\
          return true;\
        }, 5000);\
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
</html>\
'); 