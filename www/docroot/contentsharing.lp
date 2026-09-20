--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Localization
gettext.textdomain('webui-telstra')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string = string
local format = string.format
local floor = math.floor
local tonumber = tonumber

-- Process POST query
local post_helper = require("web.post_helper")

local function valid_samba_dlna_string(value) 
  local rc, msg = post_helper.validateNonEmptyString(value)                 
  if not rc then                              
    return rc, msg                            
  end                                         
  if string.match(value, "[^%w _%-]") then          
    return nil, T"Only alphanumeric, space, underscore and dash characters allowed"
  end                                                                              
  return true                                                                      
end

local mapParams = {
    dlna_enable = "uci.dlnad.config.enabled",
    media_server_name = "uci.dlnad.config.friendly_name",
    name = "uci.samba.samba.name",
}
local mapValid = {
    dlna_enable = post_helper.getValidateCheckboxSwitch(),
    media_server_name = valid_samba_dlna_string,
    name = valid_samba_dlna_string
}
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local content_intf_lan = {
    ipaddr = "rpc.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(content_intf_lan)

--local content_ftpd = {
--    enable = "uci.pure-ftpd.pure-ftpd.1.enabled",
--}
--content_helper.getExactContent(content_ftpd)

--str_ftp_server_enable = "Disabled";
--if (content_ftpd.enable ~= nil and content_ftpd.enable == "1") then
--    str_ftp_server_enable  = "Enabled";
--end

  ngx.print('\
\
<div class="container toplevel">\
<div class="row">\
<div class="span11">\
<form class="form-horizontal" method="post" action="contentsharing.lp">\
');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Content Sharing" ); ngx.print('</legend>\
');  

  local attributes = {
    input = {
        class = "monitor-changes",
        maxlength = "32" 
    }
  }

  local html = {}
  html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enable DLNA Server", "dlna_enable", content["dlna_enable"], attributes)
  html[#html + 1] = ui_helper.createInputText(T"Media Server Name", "media_server_name", content["media_server_name"], attributes)
  html[#html + 1] = ui_helper.createLabel(T"Media Server IP", content_intf_lan.ipaddr)
--  html[#html + 1] = ui_helper.createLabel(T"FTP Server State", str_ftp_server_enable)
  html[#html + 1] = ui_helper.createLabel(T"Network Folder Name", content.name)
  ngx.print(html)
  ngx.print('\
</fieldset>\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
\
<script src="/js/srp-min.js" ></script>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 