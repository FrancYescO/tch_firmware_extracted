--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local state = assistant:enabled() and "1" or "0"
local error

if ngx.var.request_method == "POST" then
  local content = ngx.req.get_post_args()
  if content["action"]=="SAVE" then
    local newstate = content["assistanceenabled"] or state
    local ok, err = assistant:enable(newstate=="1")
    state = assistant:enabled() and "1" or "0"
    if not ok then  ngx.print('\
     <input type="hidden" id="post_status" value="error">\
    ');  else  ngx.print('\
     <input type="hidden" id="post_status" value="success">\
    ');  end
  end
end
  ngx.print('\
\
<form id="assistance-form" class="form-horizontal" method="post" action="modals/settings/assistance.lp">\
  <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name="action" id="action" value="SAVE"></input>\
  <h1><span>');  ngx.print(T"Assistance"); ngx.print('</span></h1>\
  <div class="h3-content vdf-table mobile-padding-bottom-lg">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Remote Assistance"); ngx.print('</span> </div>\
      <div class="right">\
        <input type="hidden" name= "assistanceenabled" id="assistanceenabled" value = "');  ngx.print(state); ngx.print('">\
        </input>\
        <div class="button pin-enable pull-right ');  if state == "0" then  ngx.print('button-off');  else  ngx.print('button-on');  end  ngx.print('" id="assistance-btn-enable"> </div>\
      </div>\
    </div>\
    <div class="vdf-row assitance-content">\
      <div class="left"><span>');  ngx.print(T"URL"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id="assistance-lbl-url">');  ngx.print(assistant:URL() or "Not connected to the Internet"); ngx.print('</span>\
      </div>\
    </div>\
    <div class="vdf-row assitance-content">\
      <div class="left"><span>');  ngx.print(T"Username"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id="assistance-lbl-username">');  ngx.print(assistant:username()); ngx.print('</span>\
      </div>\
    </div>\
    <div class="vdf-row assitance-content">\
      <div class="left"><span>');  ngx.print(T"Password"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <span id="assistance-lbl-password">');  ngx.print(assistant:password()); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
</form>\
');  
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
  ngx.print('\
<script src="/js/global-min.js"> </script>\
<script>\
$(document).ready(function(){\
  $("#assistance-btn-enable").val("');  ngx.print(state); ngx.print('");\
  if("');  ngx.print(state); ngx.print('" == "0") {\
    $(".assitance-content").hide();\
  } else {\
    $(".assitance-content").css("display","table-row");\
  }\
  $("#assistance-btn-enable").click(function() {\
    if ($(\'#assistance-btn-enable\').hasClass(\'button-off\')) {\
      $("#assistanceenabled").val("0");\
    } else {\
      $("#assistanceenabled").val("1");\
    }\
  });\
  $("#global-apply, #modal-apply").click(function() {\
    var assistanceenabled = $("#assistance-btn-enable").hasClass("button-on") ? 1 : 0;\
    $("#assistanceenabled").val(assistanceenabled);\
    postHandler("/modals/settings/assistance.lp", $("#assistance-form").serializeArray());\
  });\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/settings/assistance.lp");\
  });\
});\
\
</script>\
'); 