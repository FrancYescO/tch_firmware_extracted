<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local table = table
local logdata = proxy.get("sys.log.connections")
logdata = logdata[1].value

local log_columns = {
    {
        header = T"Proto",
        name = "proto",
        param = "proto",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Source Address",
        name = "source address",
        param = "source address",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Destination Address",
        name  = "destination address",
        param = "destination address",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"State",
        name  = "state",
        param = "state",
        type = "text",
        attr = { select = { class="span1" } },
    },
}

local log_options = {
    tableid = "connections",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local log_array = {}
local pattern = "[^%s]+%s+[^%s]+%s+([%w]+)%s+[^%s]+%s+[^%s]+%s+([^\n]+)"
local tcpPattern = "([^%s]+)%s+src=([%w:.]+)%s+dst=([%w:.]+)%s+sport=(%d+)%s+dport=(%d+).+"
local udpPattern = "src=([%w:.]+)%s+dst=([%w:.+]+)%s+sport=(%d+)%s+dport=(%d+).+(%[%w+%]).+"

logdata:gsub(pattern, function(proto, subString)
  local srcAddr, srcPort, dstAddr, dstPort, state
  local source, destination

  if proto == "tcp" then
    subString:gsub(tcpPattern,function(state_, srcAddr_, dstAddr_, srcPort_, dstPort_)
      state = state_
      source =  srcAddr_..":"..srcPort_
      destination = dstAddr_..":"..dstPort_
    end)
    if source and destination and state then
      log_array[#log_array+1] = {proto, source, destination, state}
    end
  elseif proto == "udp" then
    subString:gsub(udpPattern,function(srcAddr_, dstAddr_, srcPort_, dstPort_, state_)
      state = state_
      source =  srcAddr_..":"..srcPort_
      destination = dstAddr_..":"..dstPort_
    end)
    if source and destination and state then
      log_array[#log_array+1] = {proto, source, destination, state}
    end
  end
end)

-- sort protocol tcp/udp
table.sort(log_array, function(a, b)
   return a[1] < b[1]
end)
%>

<% ngx.print(ui_helper.createHeader(T"Management", false, true, 15)) %>

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
        target = "modals/log-routingtable-modal.lp",
    },
    {
        desc = T"Connections",
        active = "active",
        target = "modals/log-connections-modal.lp",
    },
}
ngx.print(ui_helper.createModalTabs(tabs))
%>

<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<legend><%= T"System Log - Active Connections" %></legend>

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
