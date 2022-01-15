--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local find, sub = string.find, string.sub

local version = proxy.get("uci.versioncusto.override.fwversion_override")
if version then
    version = version[1].value
else
    version = ""
end

local productVendor = proxy.get("uci.env.var.company_name")
if productVendor then productVendor = productVendor[1].value else productVendor = "" end

local productName = proxy.get("uci.env.var.prod_friendly_name")
if productName then productName = productName[1].value else productName = "" end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session

if session:hasAccess("/modals/gateway-modal.lp") then
   modalPath = "/modals/gateway-modal.lp"
elseif not session:isdefaultuser() then
   return
end

  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Gateway", modalPath, switchName, nil, nil) ); ngx.print('\
    <div class="content">\
      <p><strong id = "ProductVendor_Id">');  ngx.print( string.format(T"Product Vendor: %s", productVendor) ); ngx.print('</strong></p>\
      <p><strong id = "ProductName_Id">');  ngx.print( string.format(T"Product Name: %s", productName) ); ngx.print('</strong></p>\
      <p><strong id = "Version_Id">');  ngx.print( string.format(T"Version: %s", version) ); ngx.print('</strong></p>\
    </div>\
  </div>\
</div>\
'); 