<%
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, string = table, string
local tonumber = tonumber
local format, find, sub = string.format, string.find, string.sub

local function tod_aggregate(data)
    return ui_helper.createSimpleSwitch("tod.enabled", data[1], nil)
end

local todmodes = {
    { "allow", T"Allow" },
    { "block", T"Block" },
}

local weekdays = {
    { "Mon", T"Mon." },
    { "Tue", T"Tue." },
    { "Wed", T"Wed." },
    { "Thu", T"Thu." },
    { "Fri", T"Fri." },
    { "Sat", T"Sat." },
    { "Sun", T"Sun." },
}

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
    header = T"IP Address",
    name = "ipaddress",
    param = "IPAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[4]
    header = T"MAC Address",
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
    header = T"ToD",
    legend = T"Time of day access control",
    name = "timeofday",
    param = "tod.mode",
    type = "aggregate",
    synthesis = tod_aggregate,
    subcolumns = {
      {
        header = T"Enabled",
        name = "tod.enabled",
        param = "tod.enabled",
        type = "switch",
        default = "1",
        attr = { },
      },
      {
        header = T"Mode",
        name = "tod.mode",
        param = "tod.mode",
        type = "select",
        values = todmodes,
        default = "allow",
        attr = { select = { class="span2" } },
      },
      {
        header = T"Start Time",
        name = "tod.start_time",
        param = "tod.start_time",
        type = "text",
        default = "00:00",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Stop Time",
        name = "tod.stop_time",
        param = "tod.stop_time",
        type = "text",
        default = "23:59",
        attr = { input = { class="span2" } },
      },
      {
        header = T"Day of week",
        name = "tod.weekdays",
        param = "tod.weekdays",
        type = "checkboxgroup",
        values = weekdays,
        attr = { checkbox = { class="inline" } },
      },
    }
  },
}

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { string.match(value, timepattern) }
    if #time == 2 then
        local hour = tonumber(time[1])
        local min = tonumber(time[2])

        if hour < 0 or hour > 23 then
            return nil, T"Invalid hour, must be between 0 and 23"
        end
        if min < 0 or min > 59 then
            return nil, T"Invalid minutes, must be between 0 and 59"
        end
        return true
    else
        return nil, T"Invalid time (must be hh:mm)"
    end
end

local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local device_valid = {
    ["tod.mode"] = gVIES(todmodes),
    ["tod.start_time"] = validateTime,
    ["tod.stop_time"] = validateTime,
    ["tod.weekdays"] = gVIC(weekdays),
}

local devices_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}

local content_helper = require("web.content_helper")

--add a device filter to remove the table line in case we have a host with name TG233-AP and this wireless.radio is remotely_managed.
local devices_filter = function(data)
    -- Do not display devices not in the LAN bridge
    if data["L3Interface"] == "br-lan" then
        if data["InterfaceType"] == "wireless" then
            if data["L2Interface"] =="wl0" then
                data["InterfaceType"] = data["InterfaceType"].." - 2.4GHz"
            elseif data["L2Interface"] =="wl1" then
                data["InterfaceType"] = data["InterfaceType"].." - 5GHz"
            end
        end
        return true
    else
        return false
    end
end

local devices_default = {
    ["tod.type"] = "mac",
}

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , devices_default, device_valid)

for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5]:gsub("^%l", string.upper))
end 

%>

<%= ui_helper.createHeader(T"Devices", false, true) %>
<div class="modal-body update no-save">
<% 

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

%>

  <form class="form-horizontal" method="post" action="modals/device-modal.lp">
    <%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset>
      <%= ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) %>
    </fieldset>
  </form>
</div>

<%= ui_helper.createFooter() %>
