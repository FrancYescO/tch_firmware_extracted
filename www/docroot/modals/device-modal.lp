<%
-- Enable localization
-- NG60620
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table, string = table, string
local tonumber = tonumber
local format, match = string.format, string.match

-- devices forwarding rules
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Hostname",
    name = "hostname",
    param = "HostName",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"IP address",
    name = "ipaddress",
    param = "IPAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[4]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[5]
    header = T"Type",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[6]
    header = T"Port",
    name = "port",
    param = "Port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
    {--[7]
    header = T"SSID",
    name = "ssid",
    param = "SSID",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
}

local device_valid = {}
local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}

--wifi content
local uciwire = proxy.get("uci.wireless.wifi-ap.")
uciwire = content_helper.convertResultToObject("uci.wireless.wifi-ap.",uciwire)

--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
    -- Do not display devices not in the LAN bridge
if(data["HostName"]=="") then
   data["HostName"]="unknown-"..data["MACAddress"]
end
	--filter to display SSID
	for i,v in ipairs(uciwire) do
		if data["L2Interface"] == v.iface then
			if v.display_connected_devices and v.display_connected_devices ~= "1" then
				return false
			end
		end
	end
	
    if data["FirewallZone"] == "LAN" then
        if data["InterfaceType"] == "wireless" then
             if match(data["L2Interface"], "^wl0") then
                data["InterfaceType"] = data["InterfaceType"].." - 2.4GHz"
             elseif match(data["L2Interface"], "^wl1") then
                data["InterfaceType"] = data["InterfaceType"].." - 5GHz"
            end
        end
        return true
    else
        return false
    end
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , device_valid)

for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5]:gsub("^%l", string.upper))
end
%>

<%= ui_helper.createHeader(T"Devices", false, true) %>
<div class="modal-body update no-save">
<%
if ngx.ctx.session:hasAccess("/modals/hostmap-modal.lp") then
    local tabs = {
        {
            desc = T"Devices List",
            active = "active",
            target = "modals/device-modal.lp",
        },
        {
            desc = T"Devices Map",
            target = "modals/hostmap-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
end
%>
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">
    <%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset>
      <legend><%= T"Devices" %></legend>
      <%= ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) %>
    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>
