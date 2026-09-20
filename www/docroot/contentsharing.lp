<%
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
%>

<%
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
local mapParams = {
    dlna_enable = "uci.minidlna.config.enabled",
    media_server_name = "uci.minidlna.config.friendly_name",
}
local mapValid = {
    dlna_enable = post_helper.getValidateCheckboxSwitch(), 
    media_server_name = post_helper.validateNonEmptyString,
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

local content_samba = {
    name = "uci.samba.samba.@samba[0].name",
}
content_helper.getExactContent(content_samba)

--str_ftp_server_enable = "Disabled";
--if (content_ftpd.enable ~= nil and content_ftpd.enable == "1") then
--    str_ftp_server_enable  = "Enabled";
--end

%>

<div class="container toplevel">
<div class="row">
<div class="span11">
<form class="form-horizontal" method="post" action="contentsharing.lp">
<%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
<legend><%= T"Content Sharing" %></legend>
<%

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
  html[#html + 1] = ui_helper.createLabel(T"Network Folder Name", content_samba.name)
  ngx.print(html)
%>
</fieldset>
</form>

<%
lp.include("save.lp")
%>

</div>
</div>
</div>

<script src="/js/srp-min.js" ></script>

<%
lp.include("footer.lp")
%>
