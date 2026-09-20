--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
if session:hasAccess("/modals/firewall-modal.lp") then

local content = {
    mode = "rpc.network.firewall.mode",
    numrules = "rpc.network.firewall.UserRuleNumberOfEntries",
    numrules_v6 = "rpc.network.firewall.UserRuleV6NumberOfEntries",
}

content_helper.getExactContent(content)

local modes = setmetatable({
    lax = T"low",
    normal = T"normal",
    high = T"high",
    user = T"user"
    }, untaint_mt)

  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Firewall", "modals/firewall-modal.lp") ); ngx.print('\
    <div class="content">\
      <p class="subinfos">\
        ');  
            local html = {}
            html[#html+1] = format(T"Firewall level: <strong>%s</strong><br>", modes[content.mode] or "")
            if content.mode == "user" then
                html[#html+1] = format(T"<strong>%d</strong> IPv4 rules defined<br>", content.numrules)
                html[#html+1] = format(T"<strong>%d</strong> IPv6 rules defined", content.numrules_v6)
            end
            ngx.print(html)
          ngx.print('\
      </p>\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 