--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"AirIQ Diagnostics", false, false) ); ngx.print('\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
    <form class="form-horizontal" method="post" action="modals/diagnostics-airiq-modal.lp">\
        <fieldset id="diagnostics-airiq-tab">\
            <legend>AirIQ Displays</legend>\
            <div class="control-group">\
                <label class="control-label">Channel Quality: </label>\
                <div class="controls">\
                    <input class="btn" type="button" value="Launch" onclick="window.open(\'diagnostics-airiq.lp?chart=channelquality\', \'_blank\', \'dependent=yes,resizable=yes,toolbar=no,status=no,menubar=no,height=800,width=1000,scrollbars=yes\'); return false">\
                </div>\
            </div>\
            <div class="control-group">\
                <label class="control-label">Spectrogram: </label>\
                <div class="controls">\
                    <input class="btn" type="button" value="Launch" onclick="window.open(\'diagnostics-airiq.lp?chart=spectrogram\', \'_blank\', \'dependent=yes,resizable=yes,toolbar=no,status=no,menubar=no,height=800,width=1000,scrollbars=yes\'); return false">\
                </div>\
            </div>\
            <div class="control-group">\
                <label class="control-label">Persistence: </label>\
                <div class="controls">\
                    <input class="btn" type="button" value="Launch" onclick="window.open(\'diagnostics-airiq.lp?chart=persistence\', \'_blank\', \'dependent=yes,resizable=yes,toolbar=no,status=no,menubar=no,height=800,width=1000,scrollbars=yes\'); return false">\
                </div>\
            </div>\
            <div class="control-group">\
                <label class="control-label">Equalizer: </label>\
                <div class="controls">\
                    <input class="btn" type="button" value="Launch" onclick="window.open(\'diagnostics-airiq.lp?chart=equalizer\', \'_blank\', \'dependent=yes,resizable=yes,toolbar=no,status=no,menubar=no,height=800,width=1000,scrollbars=yes\'); return false">\
                </div>\
            </div>\
        </fieldset>\
    </form>\
</div>\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
'); 