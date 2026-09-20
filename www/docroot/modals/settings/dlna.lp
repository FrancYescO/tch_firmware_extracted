--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local proxy = require("datamodel")

local paramMap = {
  dlnaStatus = "uci.dlnad.config.enabled",
  dlnaFriendlyName = "uci.dlnad.config.friendly_name",
}

local validateMap = {
  dlnaStatus = post_helper.validateBoolean ,
  dlnaFriendlyName = post_helper.validateNonEmptyString,
}

local content = {
  gatewayAddress = "uci.network.interface.@lan.ipaddr",
  USBDeviceCount = "sys.usb.DeviceNumberOfEntries",
  variantParam = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(content)

local env = {
  variantParam = "uci.env.var.vodafone_variant",
  model = "uci.env.var.embedded_mobile"
}
content_helper.getExactContent(env)

local device_info = {
  model = "rpc.mobiled.device.@1.info.model",
  vid = "rpc.mobiled.device.@1.info.vid",
  pid = "rpc.mobiled.device.@1.info.pid",
}

content_helper.getExactContent(device_info)

local usbName = content_helper.convertResultToObject("sys.usb.device.", proxy.get("sys.usb.device."))
local usbcount = tonumber(content["USBDeviceCount"])
local dlnaInfo, errMsg = post_helper.handleQuery(paramMap, validateMap)
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
\
<script src="js/global-min.js"></script>\
<div id = "content" class="dlna-content">\
<form id="dlna-form" class="form-horizontal" method="post" action="modals/settings/dlna.lp">\
<input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name="action" id="action" value="SAVE"></input>\
\
<h1><span>');  ngx.print(T"DLNA Streaming"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"The DLNA Digital Media Server provides streaming capabillity for music, video and photo contents."); ngx.print('</span></h2>\
\
<div class="message message-info">\
    ');  if content.variantParam ~= "NZ" then  ngx.print('\
    ');  ngx.print(T "Remember that this service is by default disabled. We recommend you, for security reasons, to deactivate these services when you are not using them."); ngx.print('\
    ');  else   ngx.print('\
    ');  ngx.print(T "Remember that this service is by default disabled. For security reasons, we recommend that you deactivate these services when you are not using them."); ngx.print('\
    ');  end   ngx.print('\
</div>\
\
<div class="h3-content vdf-table mobile-padding-bottom-lg content-dlna">\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"Enable DLNA Digital Media Server"); ngx.print('</span> </div>\
        <div class="right">\
            <input type="hidden" name="dlnaStatus" id="dlnaStatus" value="');  ngx.print(dlnaInfo.dlnaStatus); ngx.print('" />\
            <div id="dln-btn-status" class="button ');  ngx.print(dlnaInfo.dlnaStatus == "1" and "button-on" or "button-off"); ngx.print(' pull-right toggle-content-button"></div>\
        </div>\
    </div>\
   <!--Not Supported Parameters-->\
   <!-- <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"DLNA Digital Media Server Langauge"); ngx.print('</span> </div>\
        <div class="right">\
            <div id="top-info-mode" class="rel">\
                <select name="" id="">\
                    <option value="">\
                        ');  ngx.print(T "English"); ngx.print('\
                    </option>\
                    <option value="">\
                        ');  ngx.print(T "Spanish"); ngx.print('\
                    </option>\
                </select>\
            </div>\
        </div>\
    </div>-->\
    <div class="vdf-row">\
        <div class="left">\
            <span>');  ngx.print(T"DLNA Digital Server Friendly Name"); ngx.print('</span> </div>\
        <div class="right">\
            <input name="dlnaFriendlyName" id="dlnaFriendlyName" value="');  ngx.print(dlnaInfo.dlnaFriendlyName); ngx.print('" type="text"/>\
        </div>\
    </div>\
</div>\
<div id="dln-usb-info" ');  if dlnaInfo.dlnaStatus == "0" then  ngx.print('style="display:none"');  end  ngx.print('>\
  <div class="dlna">\
   ');  if usbcount and usbcount > 0 then  ngx.print('\
     ');  for _,v in ipairs(usbName) do  ngx.print('\
	');  if device_info.model ~= env["model"] or v.idVendor ~= device_info.vid or v.idProduct ~= device_info.pid then  ngx.print('\
         <h3><span>');  if v.product ~= "" then  ngx.print('\
                     ');  ngx.print(v.product); ngx.print('\
                   ');  elseif v.manufacturer ~= "" then  ngx.print('\
                     ');  ngx.print(v.manufacturer); ngx.print('\
                   ');  end  ngx.print('\
             </span>\
         </h3>\
         <div class="h3-content vdf-table mobile-padding-bottom-lg">\
           <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"DLNA Server IP Address"); ngx.print('</span> </div>\
              <div class="right">\
                ');  ngx.print(content.gatewayAddress); ngx.print('\
              </div>\
           </div>\
        <!--Not Supported Parameters-->\
        <!--div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Enable DLNA Sharing"); ngx.print('</span> </div>\
            <div class="right">\
                <div class="button button-on"></div>\
            </div>\
        </div>\
        <div class="vdf-row">\
            <div class="left">\
                <span>');  ngx.print(T"Share all folders"); ngx.print('</span> </div>\
            <div class="right">\
                <div class="button button-on"></div>\
            </div>\
        </div> -->\
       </div>\
       ');  end  ngx.print('\
    ');  end  ngx.print('\
  ');  end  ngx.print('\
 </div>\
</div>\
');  
    lp.include("apply-cancel.lp")
  ngx.print('\
</form>\
</div>\
<script src="/js/global-min.js"> </script>\
<script>\
$(\'select\').chosen({\
  disable_search_threshold: 100000,\
  allow_single_deselect: true\
});\
\
$(function(){\
    $("#dln-btn-status").click(function() {\
       if ($(this).hasClass(\'button-on\')) {\
         $("#dln-usb-info").hide();\
         $("#dlnaStatus").val("0");\
       } else {\
         $("#dln-usb-info").show();\
         $("#dlnaStatus").val("1");\
       }\
       $(this).toggleClass("button-on button-off")\
    });\
    var elements = {\
      text: "#dlnaFriendlyName"\
    }\
    var validations = {\
      text: notAnEmptyString\
    }\
    $("#global-apply, #modal-apply").click(function() {\
      if(!validateElements(elements, validations)) return false;\
      var dlnaStatus = $("#dln-btn-status").hasClass("button-on") ? 1 : 0;\
      $("#dlnaStatus").val(dlnaStatus);\
      postHandler("/modals/settings/dlna.lp", $("#dlna-form").serializeArray());\
    });\
    $("#global-cancel").click(function() {\
      $("#content").load("/modals/settings/dlna.lp");\
    });\
});\
\
</script>\
'); 