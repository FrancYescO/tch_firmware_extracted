--pretranslated: do not change this file
 
  --Enable localization
  gettext.textdomain('webui-core')
  local content_helper = require("web.content_helper")
  local post_helper = require("web.post_helper")
  local ngx = ngx
  local format = string.format
  local ui_helper = require("vdf_ui_helper")
  local vdf_helper = require("vodafone_helper")

  local upnp_enable = {
  enable = "uci.upnpd.config.enable_upnp"
  }
  local upnp_valid = {
  enable = post_helper.validateBoolean
  }
  local params = vdf_helper.handlePOST(post_helper.handleQuery, {upnp_enable, upnp_valid})

  local resetupnp = {
    reset_upnp_btn_status = "uci.uci-defaults.upnp.upnp"
  }
  content_helper.getExactContent(resetupnp)

  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("reset-wrap.lp")
  ngx.print('\
<form method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('" id="upnpform" class="form-horizontal">\
  <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('"></input>\
  <input type="hidden" name= "action" value="SAVE"></input>\
  <h1>');  ngx.print(T"UPnP"); ngx.print('</h1>\
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
          ');  if resetupnp["reset_upnp_btn_status"] == "1" then  ngx.print('\
            ');  ngx.print(T"Remember that this service is default enabled. We recommend you, for security reasons, to deactivate these services when you are not using them" ); ngx.print('\
          ');  else  ngx.print('\
            ');  ngx.print(T"Remember that this service is default disabled. We recommend you, for security reasons, to deactivate these services when you are not using them" ); ngx.print('\
          ');  end  ngx.print('\
        </div>\
      </div>\
    </div>\
    ');  
      local row = {
        label = "UPnP",
        element = format('%s %s',ui_helper.createHiddenField("enable", "enable", params.enable), ui_helper.createButton({
          id="upnp-btn-status",
          class=tonumber(params.enable) == 1 and "button-change button button-on" or "button-change button button-off"
          })),
        rowClass = "row",
        colLeftClass = "col-md-6 col-xs-6 padding-top-bottom-20",
        colRightClass = "col-md-6 col-xs-6 padding-top-bottom-20 text-right"
      }
      ngx.print(ui_helper.createRow(row))
      ngx.print('\
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
<script src= js/global-min.js></script>\
<script>\
   $(document).ready(function(){\
    $("#upnp-btn-status").click(function() {\
      if ($(\'#upnp-btn-status\').hasClass(\'button-off\') ) {\
        $("#enable").val("0");\
      }else{\
        $("#enable").val("1");\
      }\
    });\
    $("#global-apply, #modal-apply").click(function() {\
       var target = "/modals/internet/upnp.lp";\
       var params = $("#upnpform").serializeArray();\
       postHandler(target, params);\
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