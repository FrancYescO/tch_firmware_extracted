--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()

local paramMap = {
  dlnaStatus = "uci.dlnad.config.enabled",
  sambaStatus = "uci.samba.samba.filesharing",
}

local validateMap = {
  dlnaStatus = post_helper.validateBoolean ,
  sambaStatus = post_helper.validateBoolean
}

local contentSharing, errMsg = post_helper.handleQuery(paramMap, validateMap)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
   if (next(errMsg)) then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  else
    ngx.print('<input type="hidden" id="post_status" value="success">')
   end
end

local lp = require("web.lp")
lp.setpath("/www/docroot/")
  ngx.print('\
<script src="js/global.js"></script>\
<div id = "content" class="content-sharing-content">\
<form id="content-sharing-form" class="form-horizontal" method="post" action="modals/content-sharing.lp">\
<input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name="action" id="action" value="SAVE"></input>\
<h1><span>');  ngx.print(T"Content Sharing"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"You can share the content from attached USB devices and make it accessible to other users on your local network."); ngx.print('</span></h2>\
<div class="h3-content vdf-table mobile-padding-bottom-lg">\
  <div class="vdf-row">\
    <div class="left">\
      <span>');  ngx.print(T"Enable Content Sharing"); ngx.print('</span> </div>\
      <div class="right">\
        <input type="hidden" name="dlnaStatus" id="dlnaStatus" value="');  ngx.print(contentSharing.dlnaStatus); ngx.print('" />\
	<div id="con-btn-status" class="button ');  if contentSharing.dlnaStatus == "1" or contentSharing.sambaStatus == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('pull-right toggle-content-button"></div>\
        <input type="hidden" name="sambaStatus" id="sambaStatus" value="');  ngx.print(contentSharing.sambaStatus); ngx.print('" />\
      </div>\
  </div>\
  <div class="message message-info">\
    ');  ngx.print(T"Remember that this service is by default disabled. For security reasons we recommend that you deactivate these services when you are not using them."); ngx.print('</div>\
</div>\
');  
    lp.include("apply-cancel.lp")
  ngx.print('\
</form>\
</div>\
<script src="/js/global.js"> </script>\
<script>\
  $(function(){\
    $("#con-btn-status").click(function() {\
       if ($(this).hasClass(\'button-on\')) {\
         $("#dlnaStatus, #sambaStatus").val("0");\
       } else {\
         $("#dlnaStatus, #sambaStatus").val("1");\
       }\
       $(this).toggleClass("button-on button-off")\
    });\
    $("#global-apply").click(function() {\
    postHandler("/modals/content-sharing.lp", $("#content-sharing-form").serializeArray());\
  });\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/content-sharing.lp");\
  });\
});\
\
</script>\
'); 