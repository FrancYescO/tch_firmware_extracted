--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx           = ngx
local postHelper    = require("web.post_helper")
local CSRFtoken     = ngx.ctx.session:getCSRFtoken()
local contentHelper = require("web.content_helper")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")

local paramMap = {
  statusLEDState = "uci.ledfw.status_led.enable"
}
local validateMap = {
  statusLEDState = postHelper.validateBoolean
}
local pageInfo = vdf_helper.handlePOST(postHelper.handleQuery, {paramMap, validateMap})

local resetEnergySettings = {
  reset_statusLEDState = "uci.uci-defaults.energySettings.status_led_enable"
}
contentHelper.getExactContent(resetEnergySettings)

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<div class="content-energy-settings no-padding-bottom">\
  <h1><span>');  ngx.print(T"Energy Settings"); ngx.print('</span></h1>\
  <h2><span>');  ngx.print(T"Reduce power consumption by switching off unused functionality."); ngx.print('</span></h2>\
  <form id="energySettingsForm" class="form-horizontal" method="post" action="modals/settings/energySettings.lp">\
    <input type="hidden" name="statusLEDState" id="energySettings-txt-statusLed" value="');  ngx.print(pageInfo.statusLEDState); ngx.print('">\
    <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('">\
    <input type="hidden" name="action" id="action" value="SAVE">\
    ');  
    if pageInfo.statusLEDState == "" then
      pageInfo.statusLEDState = "0"
    end
    local row = {
      {
        label = T"Status-LEDs",
        element = ui_helper.createButton({
          id = "energySettings-btn-statusLED",
          class = pageInfo.statusLEDState == "0" and "pull-right button button-on" or "pull-right button button-off"
        })
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table led-padding-50"))
      ngx.print('\
  </form>\
</div>\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script src="js/global-min.js"></script>\
<script>\
$(function() {\
  $("#energySettings-btn-statusLED").click(function(){\
    $(this).hasClass(\'button-on\') ? $("#energySettings-txt-statusLed").val("1") : $("#energySettings-txt-statusLed").val("0");\
    $(this).toggleClass("button-on button-off");\
  });\
\
  $("#global-apply").click(function() {\
    postHandler("/modals/settings/energySettings.lp", $("#energySettingsForm").serializeArray());\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  function resetButtonState(id, value, hiddenId) {\
    $(id).val(value);\
    if (value == "0") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenId).val("0");\
    } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenId).val("1");\
    }\
  }\
  resetButtonState("#energySettings-btn-statusLED", ');  ngx.print(resetEnergySettings["reset_statusLEDState"]); ngx.print(', "#energySettings-txt-statusLed");\
});\
</script>\
'); 