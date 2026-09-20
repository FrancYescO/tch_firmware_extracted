--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format
local version = proxy.get("uci.version.version.@version[0].marketing_version")
if version then
    version = version[1].value
else
    version = ""
end
local name = proxy.get("uci.version.version.@version[0].marketing_name")
if name then
    name = name[1].value
else
    name = ""
end
local CPEname = format("%s", proxy.get("uci.env.var.prod_friendly_name")[1].value)

local session = ngx.ctx.session
if session:hasAccess("/modals/gateway-modal.lp") then

local headerAttr = {
    icon = {
        class = "icon-info-sign"
    }
}
ngx.print('\
<div class="span3">\
  <div class="smallcard">',
    ui_helper.createCardHeader(T"Gateway", "modals/gateway-modal.lp", nil, nil, headerAttr),'\
    <div class="content card_bg" data-bg-text="&#xf129;">\
      <div class="divtable">\
      <div class="light green" id="Gateway_=LED_Id"></div>\
      <p><strong id = "Version_Id">', T"Version ", name .. " (" .. version .. ")", '</strong></p>\
        <div data-toggle="modal" data-remote="modals/gateway-modal.lp" data-id="gateway-modal">\
          <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="', CPEname, '" src="/img/gateway.png" alt="gateway">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>');
end
