--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')
local ipairs, string = ipairs, string
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "tabs")
local items = {}

if post_helper.getVariantValue(variantHelper, "wifiNurse") then
  items = {
    {"wireless-modal.lp", T"Wireless "},
    {"tod_wireless-modal.lp", T"Wireless Control"},
    {"wifi-nurse-modal.lp", T"Wifi Nurse"}
  }
else
  items = {
    {"wireless-modal.lp", T"Wireless "},
    {"tod_wireless-modal.lp", T"Wireless Control"}
  }
end

local tabs = {}
local session = ngx.ctx.session

for _,value_items in pairs(items) do
  if session:hasAccess("/modals/" .. value_items[1]) then
    tabs[#tabs+1] = value_items
  end
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

for _,value_tabs in ipairs(tabs) do
  local active = ""
    if uri == ("/modals/" .. value_tabs[1]) then
      active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, value_tabs[2], value_tabs[1], value_tabs[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 