<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs, table = pairs, table

local ports = {"eth0", "eth1", "eth2", "eth3", "wl0"}
local first_column_txt = {"Port 1", "Port 2", "Port 3", "Port 4", "Wlan"}

local isEth4Included = false
if proxy.get("sys.class.net.@eth4.") then
    table.insert(ports, #ports, "eth4")
    table.insert(first_column_txt, #first_column_txt, "Port 5")
    isEth4Included = true
end
local param = {"rx_bytes", "rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}

local datarows ={}
for k,v in ipairs(ports) do
    datarows[k]={}
    local base_path = "sys.class.net.@" .. v .. ".statistics."
    for kk,vv in ipairs(param) do
        datarows[k][kk] = base_path .. vv
    end
    content_helper.getExactContent(datarows[k])
end

ports[#ports] = nil
local eth = {}
for k,v in ipairs(ports) do
    local base_path = "sys.class.net.@" .. v
    eth["op" .. v] = base_path .. ".operstate"
    eth["sp" .. v] = base_path .. ".speed"
end

content_helper.getExactContent(eth)

local portAttr = {
    socket = {
        class = "socket-form"
    }
}

--re-write the first column
for k,v in ipairs(first_column_txt) do
    datarows[k][1] = T(v)
end

local full_array={}
for i=1, 7 do
    full_array[i]={}
    for z=1, 7 do
        full_array[i][z]="data"..z
    end
end

--Column Names
local columns ={}
for i=1, 7 do
    columns[i]={}
end
columns[1]["header"] = T"Interface"
columns[2]["header"] = T"Rx Bytes"
columns[3]["header"] = T"Tx Bytes"
columns[4]["header"] = T"Rx Packets"
columns[5]["header"] = T"Tx Packets"
columns[6]["header"] = T"Rx Errors"
columns[7]["header"] = T"Tx Errors"

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>
<%=ui_helper.createHeader("Diagnostics", false, false, 2, help_link) %>
<div class="modal-body update">

<%
    local tabs = {
        {
            desc = T"xDSL",
            target = "modals/diagnostics-xdsl-modal.lp",
        },
        {
            desc = T"Ping & Traceroute",
            target = "modals/diagnostics-ping-modal.lp",
        },
        {
            desc = T"Connection",
            target = "modals/diagnostics-connection-modal.lp",
        },
        {
            desc = T"Network",
            active = "active",
            target = "modals/diagnostics-network-modal.lp",
        },
        {
            desc = T"Log viewer",
            target = "modals/logviewer-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
%>

        <%
            -- dummy form so that refresh button knows which page to reload, keep it
        %>
        <form class="form-horizontal" method="post" action="modals/diagnostics-network-modal.lp">
        </form>

        <fieldset id="diagnostics-network-tab">
            <legend><%= T"Ports state" %></legend>
              <div class="control-group">
                <label class="control-label"><%= T"Type supported" %></label>
                <div class="controls">
                    <%for k,v in ipairs(ports) do%>
                        <div class="span2 simple-desc">
                           <%
                            if isEth4Included and k == #ports then
                                portAttr.socket.class = "red socket-form"
                            end
                            ngx.print(ui_helper.createSwitchPort(tostring(k), eth["op" .. v], eth["sp" .. v], portAttr))
                            -- todo replace speed with actual speed
                            if eth["op" .. v] == "up" then
                           %>
                           <p class="socket-legend">Connected<p>
                           <% else %>
                           <p class="socket-legend grayLight">Not connected<p>
                           <% end %>
                        </div>
                    <% end %>
                </div>
              </div>

            <legend>Network Statistics</legend>
            <%
              local options = { tableid = "networkstats", canEdit = false, editing = false, minEntries = 5, maxEntries = 7, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
              -- table that shows the Statistics data
              ngx.print(ui_helper.createTable(columns, datarows, options))
             %>
        </fieldset>

</div>
<%=ui_helper.createFooter() %>
