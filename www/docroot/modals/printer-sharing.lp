--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()

local printerParams = {
  sambaEnabled =  "uci.samba.samba.enabled",
  shareAll     =  "uci.samba.samba.filesharing",
  printerEnabled = "uci.samba.sambashare.@printers.enabled",
  printersharingEnabled = "uci.printersharing.config.enabled",
  printerName = "uci.samba.sambashare.@printers.name"
}
local validations = {
  sambaEnabled = post_helper.validateBoolean,
  shareAll     = post_helper.validateBoolean,
  printerEnabled = post_helper.validateBoolean,
  printersharingEnabled = post_helper.validateBoolean,
  printerName = post_helper.getValidateStringLengthInRange(1,63)
}
local content, error_msg = post_helper.handleQuery(printerParams, validations)

local content_samba = {
  hostname        = "uci.samba.samba.name",
  localdevIP      = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(content_samba)
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
<form id="printer-sharing-form" class="form-horizontal" method="post" action="modals/printer-sharing.lp">\
<input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name="action" id="action" value="SAVE"></input>\
<h1><span>');  ngx.print(T"Printer Sharing"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"You can share your printer and make it accessible to other users on your local network."); ngx.print('</span></h2>\
\
<div class="message message-info">\
    ');  ngx.print(T"Remember that this service is by default disabled. For security reasons we recommend that you deactivate these services when you are not using them."); ngx.print('\
</div>\
\
<div class="h3-content vdf-table mobile-padding-bottom-lg">\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"Enable printer sharing"); ngx.print('</span> </div>\
        <div class="right">\
          <input type="hidden" name= "sambaEnabled" id= "sambaEnabled" value = "');  ngx.print(content.sambaEnabled); ngx.print('"></input>\
          <input type="hidden" name= "shareAll" id= "shareAll" value = "');  ngx.print(content.shareAll); ngx.print('"></input>\
          <input type="hidden" name= "printerEnabled" id="printerEnabled" value = "');  ngx.print(content.printerEnabled); ngx.print('">\
          <input type="hidden" name= "printersharingEnabled" id="printersharingEnabled" value = "');  ngx.print(content.printersharingEnabled); ngx.print('">\
          </input>\
          <div class="button pin-enable pull-right ');  if (content.printerEnabled == "0" and content.printersharingEnabled == "0") or content.sambaEnabled ~= "1" then  ngx.print('button-off');  else  ngx.print('button-on');  end  ngx.print('" id="printer-btn-enable"> </div>\
        </div>\
    </div>\
    <div id="printer-name-info" class="vdf-row" ');  if (content.printerEnabled == "0" and content.printersharingEnabled == "0") or content.sambaEnabled ~= "1" then  ngx.print('style="display:none"');  end  ngx.print('>\
        <div class="left"><span>');  ngx.print(T"Printer name"); ngx.print('</span>\
        </div>\
        <div class="right">\
            <input id="printerName" class="op40" disabled="disabled" name = "printerName" value="');  ngx.print(content["printerName"]); ngx.print('" type="text" />\
        </div>\
    </div>\
</div>\
<h2><span>After connecting your USB printer, use file explorer and type \\\\');  ngx.print(content_samba["localdevIP"]); ngx.print('\\  or  \\\\');  ngx.print(content_samba["hostname"]); ngx.print('\\ into the search bar, then select/open the printer. You can also "Browse" in the Add Printer Wizard on your PC and in Network, select Vodafone to list your printer.\
</span></h2>\
</form>\
');  
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
  ngx.print('\
<script src="/js/global.js"> </script>\
<script>\
$(document).ready(function(){\
  $("#printer-btn-enable").click(function() {\
    var shareAll = $("#shareAll").val();\
    if ($(\'#printer-btn-enable\').hasClass(\'button-off\') ) {\
      if (shareAll == "0")\
        $("#sambaEnabled").val("0");\
      $("#printerEnabled").val("0");\
      $("#printersharingEnabled").val("0");\
      $("#printer-name-info").hide();\
    }else{\
      $("#sambaEnabled").val("1");\
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
  $("#global-apply").click(function() {\
    if(!validateElements(elements, validations)) return false;\
    var sambaEnabled = $("#printer-btn-enable").hasClass("button-on") ? 1 : 0;\
    var printerEnabled = $("#printer-btn-enable").hasClass("button-on") ? 1 : 0;\
    var printersharingEnabled = $("#printer-btn-enable").hasClass("button-on") ? 1 : 0;\
	if(sambaEnabled==1)$("#sambaEnabled").val(sambaEnabled);\
    $("#printerEnabled").val(printerEnabled);\
    $("#printersharingEnabled").val(printersharingEnabled);\
    postHandler("/modals/printer-sharing.lp", $("#printer-sharing-form").serializeArray());\
  });\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/printer-sharing.lp");\
  });\
});\
\
</script>\
'); 