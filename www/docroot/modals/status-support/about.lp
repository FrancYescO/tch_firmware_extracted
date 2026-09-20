--pretranslated: do not change this file
 
-- Enable localization^M
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local string = string
local vdf_helper = require("vodafone_helper")
local get_from_transformer = {
  ["firmware-version"] = "rpc.system.SoftwareVersion",
  ["open_sw_link"] = "uci.web.uiconfig.@uidefault.open_sw_link",
  ["variant"] = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(get_from_transformer)

local gatewayName = vdf_helper.productName()

   ngx.print('\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-12 col-sm-12">\
    <h1>\
      <span>');  ngx.print(T"Notice regarding Open Source software"); ngx.print('\
      </span>\
    </h1>\
  </div>\
</div>\
\
<div class="about-container">\
  <div class="desktop hidden-xs">\
    <p style="font-size: 14px; line-height: 20px;font-weight: normal;"><span>');  ngx.print(T"Firmware-Version"); ngx.print(':</span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ');  ngx.print(get_from_transformer["firmware-version"]); ngx.print('</p>\
     <p style="font-size: 14px; line-height: 20px;font-weight: normal;" ><span>');  ngx.print(T"Productname"); ngx.print(':</span> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ');  ngx.print(T(gatewayName)); ngx.print('</p>\
  </div>\
  <div class="mobile">\
    <p class="padding-bottom-normal" style="font-size: 14px; line-height: 20px;font-weight: normal;"><span>');  ngx.print(T"Firmware-Version"); ngx.print(':</span><br>');  ngx.print(string.match(get_from_transformer["firmware-version"],"[^-]+")); ngx.print('</p>\
    <p style="font-size: 14px; line-height: 20px; font-weight: normal;"><span>');  ngx.print(T"Productname"); ngx.print(':</span><br>');  ngx.print(T(gatewayName)); ngx.print('</p>\
  </div>\
</div>\
<p>&nbsp;</p>\
<p>\
 ');  ngx.print(T"The product contains Open Source software. The resulting need license information's are listed in following link."); ngx.print('\
</p>\
<div class="h3-content h3-content-mobile">\
  <h3 class="mobile-line-height text-center">\
    <a class="about" href="');  ngx.print(get_from_transformer["open_sw_link"]); ngx.print('" target="_blank">');  ngx.print(T"Open Software Licenses"); ngx.print('\
    </a>\
  </h3>\
</div>\
\
\
'); 