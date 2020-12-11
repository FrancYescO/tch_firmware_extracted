<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local sub, len = string.sub, string.len
local logdata = proxy.get("sys.log.routingtable")
logdata = logdata[1].value

local log_columns = {
    {
        header = T"Destination",
        name = "destination",
        param = "destination",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Gateway",
        name = "gateway",
        param = "gateway",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Genmask",
        name = "genmask",
        param = "genmask",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Flags",
        name = "flags",
        param = "flags",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Metric",
        name = "metric",
        param = "metric",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Ref",
        name = "ref",
        param = "ref",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Use",
        name = "use",
        param = "use",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Iface",
        name = "iface",
        param = "iface",
        type = "text",
        attr = { select = { class="span1" } },
    },
}

local log_options = {
    tableid = "routingtable",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local log_array = {}
local pattern = "([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)"

local skip_first_line = 1
logdata = sub(logdata, len("Kernel IP routing table") + 1)

logdata:gsub(pattern, function(destination, gateway, genmask, flags, metric, ref, use, iface)
    -- skip the first title line
   if #log_array == 0 and skip_first_line == 1 then
     skip_first_line = 0
   else
     log_array[#log_array+1] = {destination, gateway, genmask, flags, metric, ref, use, iface}
   end
end)


%>

<% ngx.print(ui_helper.createHeader(T"Management", false, true, 5)) %>

<div class="modal-body update no-save">

<%
local tabs = {
    {
        desc = T"User Manager",
        target = "modals/usermgr-modal.lp",
    },
    {
        desc = T"Log viewer",
        target = "modals/logviewer-modal.lp",
    },
    {
        desc = T"Routing Table",
        active = "active",
        target = "modals/log-routingtable-modal.lp",
    },
    {
        desc = T"Connections",
        target = "modals/log-connections-modal.lp",
    },

}
ngx.print(ui_helper.createModalTabs(tabs))
%>

<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<legend><%= T"System Log - Routing Table" %></legend>

<fieldset>

<%
ngx.print(ui_helper.createTable(log_columns, log_array, log_options, nil, nil))
%>

</fieldset>
</form>
</div>
<div class="modal-footer">
    <div id="modal-no-change">
        <div class="btn btn-primary btn-large" data-dismiss="modal"><%= T"Close" %></div>
    </div>
</div>
