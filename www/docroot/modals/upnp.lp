--pretranslated: do not change this file
 
   --Enable localization
   gettext.textdomain('webui-core')
   local content_helper = require("web.content_helper")
   local post_helper = require("web.post_helper")
   local ngx = ngx
   local untaint_mt = require("web.taint").untaint_mt
   local setmetatable = setmetatable
   local upnp_enable = {
   enable = "uci.upnpd.config.enable_upnp"
   }
   local upnp_valid = {
   enable = post_helper.validateBoolean
   }
   local upnp_content, upnp_errmsg = post_helper.handleQuery(upnp_enable, upnp_valid)
   local resetupnp = {
     reset_upnp_btn_status = "uci.uci-defaults.upnp.upnp"
   }
   content_helper.getExactContent(resetupnp)
   local resetstate_map = setmetatable({
     ["0"] = T"disabled",
     ["1"] = T"enabled",
   }, untaint_mt)
   if ngx.req.get_method() == "POST" then
     if not next(upnp_errmsg) then
       ngx.print('<input type="hidden" id="post_status" value="success">')
     else
       ngx.print('<input type="hidden" id="post_status" value="error">')
     end
   end
   local lp = require("web.lp")
   lp.setpath("/www/docroot/")
   lp.include("reset-wrap.lp")
     ngx.print('\
  <form method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('" id="upnpform" class="form-horizontal">\
    <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    </input>\
  <input type="hidden" name= "action" value="SAVE">\
  </input>\
    <h1>');  ngx.print(T"UPnP"); ngx.print('\
    </h1>\
<div class="row">\
  <div class="col-md-12">\
    <h2>');  ngx.print(T"Enable IGD UPnP to allow any local UPnP control point to perform a variety of actions, include retrieving the external IP address of the device, enumerate existing port mappings, and add or remove port mappings."); ngx.print('\
    </h2>\
  </div>\
</div>\
<div class="h3-content h3-content-mobile">\
  <div class="row no-margin-right">\
    <div class="col-md-11 col-xs-12 dmz-message-info">\
      <div class="message message-info">\
        ');  local upnp_note = "Remember that this service is default " .. (resetstate_map[resetupnp["reset_upnp_btn_status"]] or "disabled") .. ". For security reasons we recommend that you deactivate these services when you are not using them"   ngx.print('\
        ');  ngx.print(T(upnp_note)); ngx.print('\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-6 col-xs-6 padding-top-bottom-20">\
      <span>');  ngx.print(T"UPnP"); ngx.print('\
      </span>\
    </div>\
      <div class="col-md-6 col-xs-6 padding-top-bottom-20 text-right">\
        <input type="hidden" name= "enable" id="enable" value = "');  ngx.print(upnp_content.enable); ngx.print('">\
        </input>\
      <div id="upnp-btn-status" class=" button-change button ');  if tonumber(upnp_content.enable)== 1 then   ngx.print(' button-on ');  else   ngx.print('  button-off ');  end   ngx.print('">\
    </div>\
  </div>\
</div>\
</div>\
</form>\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
<div class="row">\
  <!-- Modal -->\
  <div class="modal fade" id="myModel" role="dialog">\
    <div class="modal-dialog">\
      <!-- Modal content-->\
      <div class="modal-content">\
        <div class="modal-body">\
          <p class="success" style="display: none;">Successfully Updated\
          </p>\
          <p class="error" style="display: none;">Updated failed\
          </p>\
        </div>\
        <div class="modal-footer">\
          <button type="button" class="btn btn-default" data-dismiss="modal" style="color:#333;">Ok\
          </button>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<script src= js/global.js></script>\
<script>\
   $(document).ready(function(){\
    $("#upnp-btn-status").click(function() {\
      if ($(\'#upnp-btn-status\').hasClass(\'button-off\') ) {\
        $("#enable").val("0");\
      }else{\
        $("#enable").val("1");\
      }\
    });\
    $("#global-apply").click(function() {\
       var target = "/modals/upnp.lp";\
       var params = $("#upnpform").serializeArray();\
       postHandler(target, params);\
    });\
 $("#global-cancel").click(function() {\
    $("#content").load("/modals/upnp.lp");\
  });\
  });\
\
$("#resetR, .resetR").click(function(){\
  $("#upnp-btn-status").val("');  ngx.print(resetupnp["reset_upnp_btn_status"]); ngx.print('");\
  if ("');  ngx.print(resetupnp["reset_upnp_btn_status"]); ngx.print('" == "1") {\
    $(\'#upnp-btn-status\').addClass(\'button-on\').removeClass(\'button-off\');\
    $("#enable").val("1");\
  }\
  else\
  {\
    $(\'#upnp-btn-status\').addClass(\'button-off\').removeClass(\'button-on\');\
    $("#enable").val("0");\
  }\
});\
</script>\
'); 