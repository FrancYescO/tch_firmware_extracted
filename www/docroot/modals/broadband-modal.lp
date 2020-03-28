<%
-- NG.... hide manual switching if wansensing is enabled
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require("web.content_helper")

local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

mapParam = { 
				wsens = "uci.wansensing.global.enable",
				iface = "uci.network.interface.@wan.ifname",
				dsl_status = "sys.class.xdsl.@line0.Status",
			}
			
content_helper.getExactContent(mapParam)

%>
<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>
<% 
	if mapParam.wsens == "1" and (mapParam.dsl_status ~= "Up" or string.match(mapParam.iface,"eth4")) then
		ngx.print(ui_helper.createHeader(T"Broadband", false, true)) 
	else
		ngx.print(ui_helper.createHeader(T"Broadband", true, true))
	end
%>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<%
    if #bmh > 1 then
    -- Only included if there are 2 or more connection modes
	if mapParam.wsens == "0" then
%>
<fieldset id="conn_mode" class="advanced hide">
<legend><%= T"Broadband type" %></legend>

<%
    local html = {}

    local mode_attributes = {
        radio = {
            class = "inline"
        },
        input = {
            class = "no-save",
            ["data-for"] = "SWITCH_MODE",
        }
    }
    local mode_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "SWITCH_MODE",
        }
    }

    html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
    html[#html+1] = ui_helper.createButton("", "Switch connection mode", "icon-cog", mode_button)

    ngx.print(html)
%>
</fieldset>

<% 
end
end 
%>

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

