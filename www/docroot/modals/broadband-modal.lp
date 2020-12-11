<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber

local mapParams = {
    proto = "uci.network.interface.@wan.proto",
    wans_enable = "uci.wansensing.global.enable",
}

local mapValid = {
    wans_enable = post_helper.validateBoolean,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
local bmh = require("broadbandmode_helper").get(content["proto"])
tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

%>
<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>
<% ngx.print(ui_helper.createHeader(T"Broadband", true, true)) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">
<fieldset class="advanced hide">
<legend><%= T"WAN sensing configuration" %></legend>
<%=ui_helper.createMessages(message_helper.popMessages())%>
<%=ui_helper.createSwitch(T"Auto WAN sensing","wans_enable", content["wans_enable"])
%>
</fieldset>

<%
    if #bmh > 1 then
    -- Only included if there are 2 or more connection modes
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

    if(content["wans_enable"] == '0') then
      html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
      html[#html+1] = ui_helper.createButton("", "Switch connection mode", "icon-cog", mode_button)
    else
      html[#html+1] = ui_helper.createLabel(T"Mode",tabdata.current.description)
    end

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

