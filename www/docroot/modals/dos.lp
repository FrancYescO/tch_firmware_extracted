--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
  ngx.print('\
\
<script src="js/global.js"></script>\
<script>\
    $(function() {\
        $(\'select\').chosen({\
            disable_search_threshold: 100000,\
            allow_single_deselect: true\
        });\
    });\
</script>\
<div class="row no-margin-right">\
    <div class="col-md-12 col-sm-12">\
        <h1><span>Denial of Service</span></h1>\
    </div>\
</div>\
<h2><span>Placeholder text for category description</span></h2>\
<div class="h3-content h3-content-mobile no-padding-bottom">\
    <div class="row padding-top-bottom-20">\
        <div class="col-xs-8 col-md-6 col-sm-6">\
            <span>Denial of Service</span>\
        </div>\
        <div class="col-xs-4 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on"></div>\
        </div>\
    </div>\
\
</div>\
\
<div class="h3-content dos">\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span>Whole System ICMP Flood</span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 wsif" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span> Per-Source IP ICMP Flood </span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 psisf" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span>Whole System TCP-SYN Flood</span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 psisf" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span>Per-Source IP TCP-SYN Flood</span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 psisf" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span>Whole System UDP Flood</span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 psisf" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-12 col-md-5 col-sm-5 mobile-padding-bottom-10 dos-prev-hide">\
            <span> Per-Source IP UDP Flood </span>\
        </div>\
        <div class="col-xs-12 col-md-2 col-sm-2 mobile-padding-bottom-10">\
            <input class="max4 psisf" id="pks" type="text">\
        </div>\
        <div class="col-xs-8 col-md-3 col-sm-3 text-right mob-txt-left no-padding-left">\
            <span>Packets per Second</span>\
        </div>\
        <div class="col-xs-4 col-md-2 col-sm-2 text-right pull-right">\
            <div id="dos" class="button button-on dos-btn-on-off "></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span>ICMP Smurf</span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span>IP Fragmentation</span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off" show-hide="N"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span>Incorrect username. Please try again.</span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off" show-hide="N"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span>IP Spoof</span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off" show-hide="N"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span> TCP UDP PortScan </span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off" show-hide="N"></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 status-para-title-bdr">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span>TCP SynWithData</span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off show-hide=" N ""></div>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
        <div class="col-xs-6 col-md-6 col-sm-6 mobile-padding-bottom-10">\
            <span> UDP Bomb </span>\
        </div>\
\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
            <div id="dos" class="button button-on dos-btn-on-off" show-hide="N"></div>\
        </div>\
    </div>\
</div>\
<div class="row apply-cancel-hr no-margin-right">\
    <div class="col-md-8 col-sm-8 col-xs-12 no-padding-right">\
        <div class="articlediv hide">\
            <div class="message-arrowbox-applied">\
                <div class="message-arrowbox-applied-right">\
                    <p class="success-info"></p>\
                </div>\
            </div>\
        </div>\
    </div>\
	<div class="col-md-4 col-sm-4 col-xs-12 no-padding-right text-right">\
        <input class="button button-apply mob-button-width" value="Apply" type="button" />\
        <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button" />\
	</div>\
</div>\
\
<script>\
    $(function() {\
        $("#dos").click(function() {\
            if ($(this).hasClass("button-on")) {\
                $(this).removeClass("button-on").addClass("button-off");\
                $("div.dos").slideUp();\
            } else {\
                $(this).removeClass("button-off").addClass("button-on");\
                $("div.dos").slideDown();\
            }\
\
        });\
        $(".dos-btn-on-off").click(function() {\
            if ($(this).hasClass("button-on")) {\
                $(this).removeClass("button-on").addClass("button-off");\
            } else {\
                $(this).removeClass("button-off").addClass("button-on");\
            }\
\
            if ($(this).attr(\'show-hide\') == "N") {} else {\
                $(this).parent().prevUntil(\'div.dos-prev-hide\').toggle("clip");\
            }\
        });\
\
    });\
</script>\
'); 