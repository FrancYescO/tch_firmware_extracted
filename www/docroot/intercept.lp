--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local getargs = ngx.req.get_uri_args()
local vdf_helper = require("vodafone_helper")

local look_4 = vdf_helper.look4()
local wanColour = vdf_helper.wanColour()

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
    <title>');  ngx.print(T "Gateways"); ngx.print(' </title>\
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
                            <img src="');  ngx.print(look_4); ngx.print('activation/boxes/160705_back_side_router_og.jpg" alt="Router" class="ads-troubleshoot">\
                        </div>\
\
                        <!-- Right Column -->\
                        <div id="activation-content-right" class="no-padding-left-right">\
\
                            <!-- No Internet Cable -->\
                            <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"1. Please insert the ADSL cable into the grey port if you have a ADSL or VDSL connection, otherwise insert the Ethernet cable into the ");ngx.print(wanColour);ngx.print(T" WAN port if you have a Fibre or FibreX connection."); ngx.print('</span><br>\
                                </div>\
                            </div>\
                            <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"2. Remove any extension cables, plugs or filters and connect the modem directly to the wall jack."); ngx.print('</span><br>\
                                </div>\
                            </div>\
                            <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"3. If this is a new connection, check that you have received confirmation by email or TXT from Vodafone that your Broadband connection is activated. If you haven\'t, then your services may not be activated yet."); ngx.print('</span><br>\
                                </div>\
                            </div>\
                            <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"4. Then click the Retry button."); ngx.print('</span><br>\
                                </div>\
                            </div>\
                           <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"5. Still having problems?"); ngx.print('</span><br>\
                                </div>\
                            </div>\
                            <div class="row_wizard description">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Our teams are here to help you, simply give us a call on:"); ngx.print('</span><br>\
                                    <span class="padding-left-20">');  ngx.print(T"Personal customers"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"ADSL / VDSL service - 0800 438 448"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"Fibre broadband service - 0800 806 106"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"FibreX / Fibre service - 0508 888 800"); ngx.print('</span><br>\
                                    <span class="padding-left-20">');  ngx.print(T"Business customers"); ngx.print('</span><br>\
                                    <span class="padding-left-40">');  ngx.print(T"All Service - 0800 400 888"); ngx.print('</span><br>\
                                </div>\
                            </div>\
                            <div class="row_wizard">\
                                <div class="right">\
                                    <input class="button button-cancel" id="intercept-btn-retry" value="');  ngx.print(T"Continue"); ngx.print('" type="button">\
                                    <input class="button button-cancel" id="intercept-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
                                </div>\
                            </div>\
                        </div>\
                    </div>\
                </div>\
            </div>\
        </div>\
    </div>\
\
    <script>\
       $(document).ready(function(){\
          $("#intercept-btn-retry").click(function() {\
             var prevUrl = "');  ngx.print(getargs.url); ngx.print('";\
             var redirectURL = location.protocol+"//"+prevUrl;\
             location.href = redirectURL;\
          });\
          $("#intercept-btn-skip").click(function() {\
             window.location = "/";\
          });\
       });\
    </script>\
</body>\
</html>\
'); 