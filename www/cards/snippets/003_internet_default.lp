<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
%>

<%= ui_helper.createSimpleLight(nil, "Trying to connect", { light = { class = "orange"} }) %>
