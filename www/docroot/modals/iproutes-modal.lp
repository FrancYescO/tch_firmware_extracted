<%
-- Localization
gettext.textdomain('webui-core')
local format = string.format
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs = table, ipairs
-- UPnP forwarding rules
local dyn_route_columns = {
    {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Destination",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Mask",
    name = "Mask",
    param = "Mask",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Gateway",
    name = "Gateway",
    param = "Gateway",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Source",
    name = "Source",
    param = "Source",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"Metric",
    name = "Metric",
    param = "Metric",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },

}

local dyn_route_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "dynamicroutes",
    basepath = "sys.class.iproutes.",
}

local dyn_route_attributes = {
}

local dyn_route_data, dyn_route_helpmsg = post_helper.handleTableQuery(dyn_route_columns, dyn_route_options, nil, nil, nil)


local dns_columns = {
  {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 1",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 2",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
  {
    header = T"DNS Server 3",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = { input = { class="span2 centered" } },
  },
}

local dns_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "dnsinfo",
    basepath = "rpc.network.interface.",
}

local dns_attributes = {
}

function split(x,sep)
        x = tostring(x)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end


local dns_data = {}
--local dns_data, dns_helpmsg = post_helper.handleTableQuery(dns_columns, dns_options, nil, nil, nil)
local dns_rpc_path = "rpc.network.interface."
local dns_rpc_content = content_helper.getMatchedContent (dns_rpc_path)
local dns_count = 1
for i, v in pairs (dns_rpc_content) do
   
   if v["dnsservers"] ~= "" then
      local path = split(split(format("%s",v["path"]),"@")[2],".")
      local subcount = split(format("%s",v["dnsservers"]),",")
      
           dns_data[dns_count] = {path[1],subcount[1] or "",subcount[2] or "",subcount[3] or ""}
           dns_count = dns_count +1
   
      --ngx.log(ngx.ERR, format("path=%s v=%s subcount=%s",v["path"],v["dnsservers"], #subcount)) 
      
   end
end
%>

<% ngx.print(ui_helper.createHeader(T"IP Extras", false, true)) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/iproutes-modal.lp">
    <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>
    <fieldset>
      <legend><%= T"IP4 Routes" %></legend>
      <%
        ngx.print(
          ui_helper.createTable(dyn_route_columns, dyn_route_data, dyn_route_options, dyn_route_attributes, dyn_route_helpmsg)
        )
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"DNS" %></legend>
      <%
        ngx.print(
          ui_helper.createTable(dns_columns, dns_data, dns_options, dns_attributes, dns_helpmsg)
        )
      %>
    </fieldset>

  </form>
</div>

<%= ui_helper.createFooter() %>

