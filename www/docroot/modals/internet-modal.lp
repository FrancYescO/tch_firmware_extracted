<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")

local imh = require("internetmode_helper")
local tabdata = dyntab_helper.process(imh)

%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>
<%
local role = ngx.ctx.session:getrole()
ngx.print(ui_helper.createHeader(T"Internet Access", ((role == "superuser") or (role == "telia")), true))
%>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>

<%
    if #imh > 1 then
    -- Only included if there are 2 or more connection modes
%>
<fieldset id="conn_mode" class="advanced hide">
<legend><%= T"Connection mode" %></legend>

<%
    local html = {}
    html[#html+1] = ui_helper.createLabel(T"Mode", "DHCP routed mode")

    ngx.print(html)
%>
</fieldset>

<% end %>

<% end %>
<%
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>

</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>

<% end %>
