--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
  ngx.print('\
\
<script>\
    $(function() {\
        $(\'select\').chosen({\
            disable_search_threshold: 100000,\
            allow_single_deselect: true\
        });\
    });\
</script>\
<div class="row no-margin-right">\
    <div id="resetBar" class="resetBar resetContainer" style="display:none">\
        <div class="col-md-7 col-xs-12">\
            Do you want to reset this page to default settings?\
        </div>\
        <div class="col-md-5 col-xs-12 text-right no-padding-right">\
            <input value="Reset" title="XXX" class="resetR button button-apply" id="resetR" type="button" />\
            <input value="Cancel" title="XXX" class="cancelR button button-cancel" id="cancelR" type="button" />\
        </div>\
    </div>\
</div>\
\
<div class="row no-margin-right">\
    <div class="col-md-8 col-sm-8">\
        <h1><span>Energy Settings</span></h1>\
    </div>\
    <div class="col-md-4 col-sm-4 hidden-xs no-padding-right">\
        <div id="resetButtonsShort" class="resetButtons resetButtonShort pull-right"></div>\
    </div>\
</div>\
\
<h2>Reduce power consumption by switching off unused functionality.</h2>\
<div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>USB Port</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <div class=" pull-right">\
                <div id="toggle-content-pin" class="button button-on"></div>\
            </div>\
        </div>\
    </div>\
    <div class="col-md-12 no-padding-left-right">\
        <hr>\
    </div>\
    <div class="row padding-top-bottom-20">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>Status-LED</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <div class=" pull-right">\
                <div id="toggle-content-pin" class="button button-on"></div>\
            </div>\
        </div>\
    </div>\
    <div class="col-md-12 no-padding-left-right">\
        <hr>\
    </div>\
    <div class="row padding-top-bottom-20 margin-bottom-lg">\
        <div class="col-xs-12 col-md-4 col-sm-4 mobile-padding-top-bottom-10">\
            <span>Status-LED Brightness</span>\
        </div>\
        <div class="col-xs-12 col-md-8 col-sm-8 text-right">\
            <div>\
                <div class="router-led-bar clearfix">\
                    <div class="button-arrow-left-small mobile-pull-left"></div>\
                    <div style="background: #fbd9ca;" class="led-glow-block"> </div>\
                    <div style="background: #f6af94;" class="led-glow-block hide-led"> </div>\
                    <div style="background: #f08262;" class="led-glow-block hide-led"> </div>\
                    <div style="background: #e95035;" class="led-glow-block hide-led"> </div>\
                    <div style="background: #e60000;" class="led-glow-block hide-led"> </div>\
                    <div class="button-arrow-right-small mobile-pull-right"></div>\
                </div>\
            </div>\
        </div>\
    </div>\
\
    <div class="row apply-cancel-hr no-margin-right">\
        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
            <div class="articlediv hide">\
                <div class="message-arrowbox-applied">\
                    <div class="message-arrowbox-applied-right">\
                        <p class="success-info"></p>\
                    </div>\
                </div>\
            </div>\
            <input class="button button-apply mob-button-width" value="Apply" type="button" />\
            <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button" />\
        </div>\
    </div>\
    <div class="row no-margin-right">\
        <div class="col-xs-12 visibile-xs hidden-sm hidden-md hidden-lg padding-top-bottom-20">\
            <div id="resetWrapMobile">\
                <div class="resetButtons resetButtonsShort">\
                    Reset to default Settings\
                </div>\
            </div>\
        </div>\
    </div>\
    <!-- Modal -->\
    <div id="mobile-popup" class="mobile-reset hidden-md hidden-sm hidden-lg">\
        <div class="row padding-bottom-lg">\
            <div class="col-xs-12">\
                <div class="close-icon cancelR"></div>\
            </div>\
        </div>\
        <div class="row padding-top-bottom-20">\
            <div class="col-xs-12">\
                <h3>Energy Settings</h3>\
            </div>\
        </div>\
        <div class="row margin-top-bottom-20">\
            <div class="col-xs-12">\
                Do you want to reset this page to default settings?\
            </div>\
            <div class="col-xs-12 padding-top-bottom-20">\
                <input id="resetR" class="button button-apply mob-button-width" value="Reset" type="button">\
                <input id="cancelR" class="button button-cancel mob-button-width mob-apply-cancel cancelR" value="Cancel" type="button">\
            </div>\
        </div>\
    </div>\
    <!-- End -->\
    <script src="js/global.js"></script>\
    <script>\
        $(function() {\
\
            $(".toggle-row-enbledble").click(function() {\
                if ($(this).hasClass(\'button-on\')) {\
                    $(this).removeClass(\'button-on\');\
                    $(this).toggleClass(\'button-off\');\
                    if ($(window).width() <= 360) {\
                        console.log("if loop")\
                        $(this).closest(\'div.row\').find(\'p.pr-col\').addClass("op50");\
                    } else {\
                        $(this).closest(\'div.row\').find(\'p.pr-col:last-child\').addClass("op40");\
                    }\
\
                } else {\
                    $(this).removeClass(\'button-off\');\
                    $(this).toggleClass(\'button-on\');\
                    //$(this).closest(\'div.row\').find(\'p.pr-col\').removeClass("op50");\
                    if ($(window).width() <= 360) {\
                        $(this).closest(\'div.row\').find(\'p.pr-col\').removeClass("op50");\
                    } else {\
                        $(this).closest(\'div.row\').find(\'p.pr-col:last-child\').removeClass("op40");\
                    }\
                }\
            });\
\
            $(\'.button-delete\').click(function() {\
                //var rowCount = $(\'.access-control\').length;\
                var screen_size = $(window).width();\
                var index = $(".button-delete").index(this);\
                if (index > 0) {\
                    $(this).closest("div.access-control:not(.access-header)").hide();\
                } else {\
                    if (screen_size <= 360) {\
                        $(\'.access-header\').hide();\
                    } else {\
                        $(this).closest(\'div.access-control\').find(\'p.pr-col:last-child\').hide();\
                        $(\'.row-enbledble\').hide();\
                    }\
\
                }\
            });\
\
            //led brightness\
            var led = 3;\
\
            function setLED() {\
                $(\'.led-glow-block\').addClass(\'hide-led\');\
                for (var i = 0; i < led; i++) {\
                    $(\'.led-glow-block\').eq(i).removeClass(\'hide-led\');\
                }\
            }\
\
            $(\'.button-arrow-left-small\').click(function() {\
                led--;\
                if (led <= 1) {\
                    led = 1;\
                }\
                setLED();\
            });\
\
            $(\'.button-arrow-right-small\').click(function() {\
                led++;\
                if (led >= $(\'.led-glow-block\').length) {\
                    led = $(\'.led-glow-block\').length;\
                }\
                setLED();\
            });\
            setLED();\
        });\
    </script>\
'); 