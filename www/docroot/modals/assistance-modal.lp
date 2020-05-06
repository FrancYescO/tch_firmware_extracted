<%
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

local state = assistant:enabled() and "1" or "0"
local error

if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        local newstate = content["ra_enabled"] or state
        local ok, err = assistant:enable(newstate=="1")
        state = assistant:enabled() and "1" or "0"
        if not ok then
            error = err
        else
            message_helper.pushMessage(T"Changes saved successfully", "success")
        end
    end
end
%>

<%= ui_helper.createHeader(T"Assistance") %>
<div class="modal-body-update">
<form class="form-horizontal" method="post" action="modals/assistance-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
  <%= ui_helper.createSwitch(T"Remote Assistance", "ra_enabled", state) %>
  <% if assistant:enabled() then
    ngx.print{
        ui_helper.createLabel(T"URL", assistant:URL() or T"Not connected to the Internet"),
        ui_helper.createLabel(T"Username", assistant:username()),
        ui_helper.createLabel(T"Password", assistant:password()),
        error and ui_helper.createLabel(T"Error", error) or '',
    } 
  end %>
</fieldset>
</form>
</div>
<%= ui_helper.createFooter() %>
