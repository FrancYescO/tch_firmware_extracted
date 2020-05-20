<%
-- Enable localization
gettext.textdomain("webui-voice")

local content_helper = require ("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format

local content = {
  registration_status = "rpc.mobiled.device.@1.voice.info.volte.registration_status",
  cs_emergency = "rpc.mobiled.device.@1.voice.network_capabilities.cs.emergency",
  volte_emergency = "rpc.mobiled.device.@1.voice.network_capabilities.volte.emergency",
}
content_helper.getExactContent(content)

local status_message = ""
local apn = ""
if content["registration_status"] == "registered" then
  status_message = "Your phone service is connected and working normally."
  apn = "ims"
else
  if content["cs_emergency"] == "true" or content["volte_emergency"] == "true" then
    status_message = "Your phone service is available for emergency calls only."
    apn = "sos"
  else
    status_message = "No signal, your phone service is not connected."
  end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
%>

<%= ui_helper.createHeader(T"Telephony", false, true, nil, help_link) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal">
    <fieldset id="mmpbx-volte-tab">
      <legend><%= T"VoLTE Service" %></legend>
      <%= ui_helper.createLabel(T"VoLTE Service Status", status_message, { span = { class = "span5" } }) %>
      <%= ui_helper.createLabel(T"VoLTE APN", apn) %>
    </fieldset>
  </form>
</div>
<%= ui_helper.createFooter() %>

