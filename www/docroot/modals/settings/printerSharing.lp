--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()

local content = {
  variantParam = "uci.env.var.vodafone_variant",
  fileSharing = "uci.samba.samba.filesharing",
}
content_helper.getExactContent(content)

local printerParams = {
  printerEnabled = "uci.samba.sambashare.@printers.enabled",
  printersharingEnabled = "uci.printersharing.config.enabled",
  printerName = "uci.samba.sambashare.@printers.name"
}
local validations = {
  printerEnabled = post_helper.validateBoolean,
  printersharingEnabled = post_helper.validateBoolean,
  printerName = post_helper.getValidateStringLengthInRange(1,63)
}

if vdf_helper.getVariant() == "NZ" then
  printerParams.sambaEnabled = "uci.samba.samba.enabled"
  validations.sambaEnabled = function(value, object, key)
    object[key] = object.printerEnabled
    if object.printerEnabled == "0" and content.fileSharing == "1" then
        object[key] = "1"
    end
    return true
  end
end

local content, error_msg = post_helper.handleQuery(printerParams, validations)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  ngx.header.content_type = "application/json"
  if not next(error_msg) then   ngx.print('\
  <input type="hidden" id="post_status" value="success">\
  ');  else  ngx.print('\
  <input type="hidden" id="post_status" value="error">\
  ');  end
end

local content_samba = {
  hostname        = "uci.samba.samba.name",
  localdevIP      = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(content_samba)
  ngx.print('\
\
<form id="printer-sharing-form" class="form-horizontal" method="post" action="modals/settings/printerSharing.lp">\
<input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name="action" id="action" value="SAVE"></input>\
<h1><span>');  ngx.print(T"Printer Sharing"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"You can share your printer and make it accessible to other users on your local network."); ngx.print('</span></h2>\
\
<div class="message message-info">\
    ');  if vdf_helper.getVariant() ~= "NZ" then  ngx.print('\
    ');  ngx.print(T"Remember that this service is by default disabled. We recommend you, for security reasons, to deactivate these services when you are not using them."); ngx.print('\
    ');  else   ngx.print('\
    ');  ngx.print(T"Remember that this service is by default disabled. For security reasons, we recommend that you deactivate these services when you are not using them."); ngx.print('\
    ');  end   ngx.print('\
</div>\
\
<div class="h3-content vdf-table mobile-padding-bottom-lg">\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"Enable printer sharing"); ngx.print('</span> </div>\
        <div class="right">\
          <input type="hidden" name= "printerEnabled" id="printerEnabled" value = "');  ngx.print(content.printerEnabled); ngx.print('">\
          <input type="hidden" name= "printersharingEnabled" id="printersharingEnabled" value = "');  ngx.print(content.printersharingEnabled); ngx.print('">\
          </input>\
          <div class="button pin-enable pull-right ');  if content.printerEnabled == "0" and content.printersharingEnabled == "0" then  ngx.print('button-off');  else  ngx.print('button-on');  end  ngx.print('" id="printer-btn-enable"> </div>\
        </div>\
    </div>\
</div>\
');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
  <h2><span>After connecting your USB printer, use file explorer and type \\\\');  ngx.print(content_samba["localdevIP"]); ngx.print('\\  or  \\\\');  ngx.print(content_samba["hostname"]); ngx.print('\\ into the search bar, then select/open the printer. You can also "Browse" in the Add Printer Wizard on your PC and in Network, select Vodafone to list your printer.\
  </span></h2>\
');  end   ngx.print('\
</form>\
');  
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
  ngx.print('\
<script src="/js/global-min.js"> </script>\
<script>\
$(document).ready(function(){\
  $("#printer-btn-enable").click(function() {\
    if ($(\'#printer-btn-enable\').hasClass(\'button-off\') ) {\
      $("#printerEnabled").val("0");\
      $("#printersharingEnabled").val("0");\
      $("#printer-name-info").hide();\
    }else{\
      $("#printerEnabled").val("1");\
      $("#printersharingEnabled").val("1");\
      $("#printer-name-info").css("display","table-row");\
    }\
  });\
  var elements = {\
    text: "#printerName"\
  }\
  var validations = {\
    text: validateStringLength(1,63)\
  }\
  $("#global-apply, #modal-apply").click(function() {\
    if(!validateElements(elements, validations)) return false;\
    var printerEnabled = $("#printer-btn-enable").hasClass("button-on") ? 1 : 0;\
    var printersharingEnabled = $("#printer-btn-enable").hasClass("button-on") ? 1 : 0;\
    $("#printerEnabled").val(printerEnabled);\
    $("#printersharingEnabled").val(printersharingEnabled);\
    postHandler("/modals/settings/printerSharing.lp", $("#printer-sharing-form").serializeArray());\
  });\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/settings/printerSharing.lp");\
  });\
});\
\
</script>\
'); 