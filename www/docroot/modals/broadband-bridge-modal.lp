<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local bridged = require("bridgedmode_helper")
local tonumber = tonumber

local content_wan = {
    wans_enable = "uci.wansensing.global.enable",
}

content_helper.getExactContent(content_wan)
%>

<% ngx.print(ui_helper.createHeader(T"Broadband", true, true)) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/broadband-bridge-modal.lp">
<%
    lp.setpath("/www/snippets/")
    lp.include("broadband-xdsl.lp")
    lp.include("broadband-ethernet.lp")
%>

</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>


