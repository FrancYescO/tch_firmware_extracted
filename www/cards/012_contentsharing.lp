--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local format, find, sub = string.format, string.find, string.sub
local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/contentsharing-modal.lp") then
    modalPath = "/modals/contentsharing-modal.lp"


local content = {
	samba_name          = "uci.samba.samba.name",
	samba_filesharing   = "uci.samba.samba.filesharing",
	dlna_name           = "uci.dlnad.config.friendly_name",
	dlna_enabled        = "uci.dlnad.config.enabled"
}
content_helper.getExactContent(content)
local sambastate, dlnastate
if content["samba_filesharing"] == "1" then
  sambastate = T"File Server enabled"
else
  sambastate = T"File Server disabled"
end
if content["dlna_enabled"] == "1" then
  dlnastate = T"DLNA enabled"
else
  dlnastate = T"DLNA disabled"
end

  ngx.print('\
\
\
<div class="span3">\
	<div class="smallcard">\
		');  ngx.print(ui_helper.createCardHeaderNoIcon(T"Content Sharing", modalPath, nil, nil) ); ngx.print('\
		<div class="content">\
			');  
				local html = {
					ui_helper.createSimpleLight(content["samba_filesharing"], sambastate, attributes)
				}
				tinsert(html, ui_helper.createSimpleLight(content["dlna_enabled"], dlnastate, attributes))
				ngx.print(html)
			  ngx.print('\
		</div>\
	</div>\
</div>\
\
');  
end
  ngx.print('\
'); 