--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local format = string.format
local ngx = ngx

-- POST Action triggered when the wizard is In_Progress for more than 15 Minutes
-- activationStatus will be reset to Not_Activated in this case
if ngx.req.get_method() == "POST" then
    if ngx.req.get_post_args().action == "Reset" then
        ngx.header.content_type = "application/json"
        proxy.set("uci.env.var.activationStatus", "Not_Activated")
        proxy.apply()
        ngx.print(format('{"reset":true}'))
        ngx.exit(ngx.HTTP_OK)
    end
end

-- GET Action triggered through AJAX
-- Responds with current activationStatus in json format
if ngx.req.get_uri_args().action == "getActivationStatus" then
    ngx.header.content_type = "application/json"
    local status = proxy.get("uci.env.var.activationStatus")
    status = status and status[1].value
    ngx.print(format('{"status":"%s"}', status))
    ngx.exit(ngx.HTTP_OK)
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
                            <span class="txt-space">&nbsp;</span>\
                        </div>\
                        <!-- Header Right Column -->\
                        <div id="activation-top-right">\
                            <!-- Header Welcome Text  -->\
                            <h1 class="welcome-text"><span>');  ngx.print(T"Activation in progress..."); ngx.print('</span></h1>\
                        </div>\
                    </div>\
\
                    <!-- Column Container  -->\
                    <div id="activation-content-inner" class="clearfix">\
\
                        <!-- Left Column -->\
                        <div id="activation-content-left">\
                            <!-- Left column correspondant images -->\
                            <img src="/img/look_4/activation/boxes/160705_VFH-500-s_1.115_front-right_corrected.jpg" alt="Router" class="vdf-box">\
                        </div>\
\
                        <!-- Right Column -->\
                        <div id="activation-content-right" class="no-padding-left-right">\
                            <!-- Activation In Progress -->\
                            <div class="description tC">\
                                <div class="left">\
                                    <span>');  ngx.print(T"Please do not turn off the device..."); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="row tC">\
                                <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading...">\
                            </div>\
                        </div>\
\
                    </div>\
                </div>\
            </div>\
        </div>\
    </div>\
\
</body>\
\
<script>\
    var maxActivationTimeout = 10; // Minutes\
    var timeout = 0;\
    var activationInterval = setInterval(function() {\
        timeout++;\
        if (timeout > maxActivationTimeout) {\
            $.post("/activation-inprogress.lp", {\
                action: "Reset",\
                CSRFtoken: $("[name=CSRFtoken]").attr("content")\
            }, function(data) {\
                if (data.reset) {\
                    window.location = "/";\
                }\
            });\
        } else {\
            $.get("/activation-inprogress.lp?action=getActivationStatus", function(data) {\
                if (data.status != "In_Progress") {\
                    window.location = "/";\
                }\
            });\
        }\
    }, 60000);\
</script>\
\
</html>\
'); 