--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')
local getargs = ngx.req.get_uri_args()
  ngx.print('\
<!DOCTYPE html>\
<html lang="en" class="no-js">\
<head>\
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />\
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">\
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">\
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />\
  <meta http-equiv="Pragma" content="no-cache" />\
  <meta name="description" content="">\
  <title>');  ngx.print(T"Gateways"); ngx.print('</title>\
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
<script>\
$(document).ready(function(){\
$("#intercept-btn-retry").click(function() {\
var prevUrl = \'');  ngx.print(getargs.url); ngx.print('\';\
var redirectURL = "http://"+prevUrl;\
  location.href = redirectURL;\
});\
$("#intercept-btn-skip").click(function() {\
window.location = "/";\
});\
});\
</script>\
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
    <div id="activation-content-wrap" class="clearfix rel">\
      <div id="activation-content">\
        <div id="activation-top">\
        </div>\
        <div id="activation-content-inner" class="clearfix">\
          <div id="activation-content-left">\
            <img src="/img/look_4/activation/boxes/160705_back_side_router_og.jpg" alt="Router">\
          </div>\
          <div id="activation-content-right">\
            <div class="vdf-row description">\
              <div class="left">\
                1.\
                <span>');  ngx.print(T"Please insert the ADSL cable into the grey port if you have a ADSL or VDSL connection, otherwise insert the Ethernet cable into the yellow WAN port if you have a Fibre or FibreX connection."); ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row description">\
              <div class="left">\
                2.\
                <span>');  ngx.print(T"Remove any extension cables, plugs or filters and connect the modem directly to the wall jack."); ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row description">\
              <div class="left">\
                3.\
                <span>');  ngx.print(T"If this is a new connection, check that you have received confirmation by email or TXT from Vodafone that your Broadband connection is activated. If you haven\'t, then your services may not be activated yet."); ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row description">\
              <div class="left">\
                4.\
                <span>');  ngx.print(T"Then click the Retry button."); ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row description">\
              <div class="left">\
                5.\
                <span>');  ngx.print(T"Still having problems?"); ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row description">\
              <div class="left">\
                <span>');  ngx.print(T"Our teams are here to help you, simply give us a call on:"); ngx.print('</span><br>\
                <span class="padding-left-20">');  ngx.print(T"Personal customers"); ngx.print('</span><br>\
                <span class="padding-left-40">');  ngx.print(T"ADSL / VDSL service - 0800 438 448"); ngx.print('</span><br>\
                <span class="padding-left-40">');  ngx.print(T"Fibre broadband service - 0800 806 106"); ngx.print('</span><br>\
                <span class="padding-left-40">');  ngx.print(T"FibreX / Fibre service - 0508 888 800"); ngx.print('</span><br>\
                <span class="padding-left-20">');  ngx.print(T"Business customers"); ngx.print('</span><br>\
                <span class="padding-left-40">');  ngx.print(T"All Service - 0800 400 888"); ngx.print('</span>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="right text-right">\
                <input class="button button-cancel" id="intercept-btn-retry" value="');  ngx.print(T"Retry"); ngx.print('" type="button">\
                <input class="button button-cancel" id="intercept-btn-skip" value="');  ngx.print(T"Skip"); ngx.print('" type="button">\
              </div>\
            </div>\
          </div>\
        </div>\
        <!--<input type="button" class="step1back" data-step-id=\'1\' style="display:none;">-->\
        <div class="blackBackground" style="display:none;">&nbsp;\
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
                <a href="#"onclick = "lang_change(\'en-us\')">English\
                </a>\
              </li>\
              <li class="language-switcher" data-language-id="15">\
                <a href="#" onclick = "lang_change(\'spn\')">Spanish\
                </a>\
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
<script src="/js/global.js" ></script>\
</body>\
</html>\
'); 