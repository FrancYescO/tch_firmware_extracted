<%

-- Enable localization
gettext.textdomain('webui-fon')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require ("web.content_helper")

local fonpath = "uci.hotspotd.wifi-iface."
local fonifaces = content_helper.convertResultToObject(fonpath .. "@.", proxy.get(fonpath))

local ssidMap = {}
for i,v in ipairs(fonifaces) do
	if v.enable == '1' then
		local iface = string.format("%s", v.iface)
		ssidMap[iface] = v.paramindex
	end
end

local content_fon = {
    fonstatus = "uci.hotspotd.state.status",
--    tunnelstatus = "uci.hotspotd.tunnel.enabled",
    foniface = "uci.hotspotd.main.iface",
}
content_helper.getExactContent(content_fon)

--local cvtBoolean = {
--    ["true"] = "1",
--    ["false"] = "0",
--    ["1"] = "true",
--    ["0"] = "false",
--}
--
--local tunnelstatus = string.format("%s", content_fon["tunnelstatus"])
--content_fon["tunnelstatus"] = cvtBoolean[tunnelstatus]

for iface,_ in pairs(ssidMap) do
    content_fon[iface] = 0
end

local hostpath = "sys.hosts.host."
local hosts = content_helper.convertResultToObject(hostpath, proxy.get(hostpath))
for i,v in ipairs(hosts) do
    if v.L3Interface == content_fon["foniface"] and v.State == "1" then
        local iface = string.format("%s", v.L2Interface)
        if ssidMap[iface] then
            content_fon[iface] = content_fon[iface] + 1
        end
    end
end

local fon_columns = {
    {--[1]
        header = T"SSID",
        name = "ssid",
        param = "ssid",
        type = "text",
        readonly = true,
    },
    {--[2]
        header = "SSID Status",
        name = "enable",
        param = "state",
        type = "light",
        readonly = true,
    },
    {--[3]
        header = T"Number of Connected Users",
        name = "number",
        param = "number",
        type = "text",
        readonly = true,
    },
}

local fon_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "fon",
    basepath = "uci.wireless.wifi-iface.@.",
}

local fon_filter = function(data)
    if ssidMap[data.paramindex] then
        data["number"] = content_fon[data.paramindex]
        local statedata = proxy.get("rpc.wireless.ssid.@".. data.paramindex .. ".oper_state")
        local state = statedata and statedata[1] and statedata[1].value
        if state == "0" then
            data["state"] = state
        end
        return true
    else
        return false
    end
end

local fon_data, fon_helpmsg = post_helper.handleTableQuery(fon_columns, fon_options, fon_filter, nil, nil)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<%
  local header = ui_helper.createHeader(T"Telstra Air", false, true, nil, help_link)
  header[1] = header[1]:gsub("span4", "span6")
  ngx.print(header)
%>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="/modals/fon-modal.lp">
    <fieldset>
      <legend><%= T"Global Information" %></legend>
      <%
        local html = ui_helper.createLabel(T"Telstra Air Status", content_fon["fonstatus"])
        html[1] = html[1]:gsub("control%-label", "span3")
        html[1] = html[1]:gsub("simple%-desc", "")
        ngx.print(html)
      %>
    </fieldset>
    <fieldset>
      <legend><%= T"Wi-Fi Status" %></legend>
      <%= ui_helper.createTable(fon_columns, fon_data, fon_options, nil, fon_helpmsg) %>
    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>

<script>
$(function(){
    $('#fon tbody tr').each (function() {
        var status = $(this).find("td").eq(1).find("div");
        var status_class = status.attr("class");
        var status_hint = "Disabled";
        if (status_class == "light green") {
            status_hint = "Enabled";
        }
        status.attr({"class": "someInfos " + status_class, "rel": "tooltip", "data-placement": "top", "data-original-title": status_hint});
    })
    $('.someInfos').tooltip();
});
</script>
