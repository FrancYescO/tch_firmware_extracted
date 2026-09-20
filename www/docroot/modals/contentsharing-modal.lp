<%
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local format, remove, match, tostring = string.format, table.remove, string.match, tostring
local vNES = post_helper.validateNonEmptyString
local gVCS = post_helper.getValidateCheckboxSwitch()

local mapParams = {
    samba_enabled        = "uci.samba.samba.enabled",
    samba_name            = "uci.samba.samba.name",
    samba_workgroup        = "uci.samba.samba.workgroup",
    samba_description    = "uci.samba.samba.description",
    minidlna_enabled    = "uci.minidlna.config.enabled",
    minidlna_friendly_name = "uci.minidlna.config.friendly_name",
}

local mapValid = {
    samba_enabled = gVCS,
    samba_name = post_helper.validateString,
    samba_workgroup = post_helper.validateString,
    samba_description = post_helper.validateString,
    minidlna_enabled = gVCS,
    minidlna_friendly_name = post_helper.validateString,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)


-- usb Devices
local usbdev_columms = {
    {
        header = T"Port",
        type = "label",
        name = "port",
        param = "port",
        readonly = true,
    },
    {
        header = T"Product Name",
        name = "product",
        param = "product",
        type = "label",
        readonly = true,
    },
    {
        header = T"Manufacturer",
        name = "manufacturer",
        param = "manufacturer",
        type = "label",
        readonly = true,
    },
    {
        header = T"Power",
        type = "label",
        name = "Power",
        param = "Power",
        readonly = true,
    },
    {
        header = T"Version",
        name = "version",
        param = "version",
        type = "label",
        readonly = true,
    },
    {
        header = T"File System",
        name = "FileSystem",
        param = "FileSystem",
        type = "label",
        readonly = true,
    },
    {
        header = T"Total Space",
        name = "TotalSpace",
        param = "TotalSpace",
        type = "label",
        readonly = true,
    },
    {
        header = T"Used Space",
        name = "UsedSpace",
        param = "UsedSpace",
        type = "label",
        readonly = true,
    },
    {
        header = T"Free Space",
        name = "AvailableSpace",
        param = "AvailableSpace",
        type = "label",
        readonly = true,
    },
    {
        header = T"Volume",
        name = "Volume",
        param = "Volume",
        type = "label",
    },
}

local usbdev_options = {
    tableid = "usbDev",
    basepath = "sys.usb.partition.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

local function clearParam(value, object, key)
    object[key] = nil
    return true
end
local function toGetCheckBoxSwitchValue(value)
    if type(value) == "table" then
        return "1"
    end
    return "0"
end

--only show the mounted usb device.
local usbdev_filter = function(data)
    if data.product ~= "" then
        return true
    end
    return false
end

local usbdev_valid = {
    port = clearParam,
    product = clearParam,
    manufacturer = clearParam,
    Power = clearParam,
    version = clearParam,
    FileSystem = clearParam,
    TotalSpace = clearParam,
    UsedSpace = clearParam,
    AvailableSpace = clearParam,
}

local function to_string(v)
  if istainted and istainted(v) then
    return string.untaint(v)
  end
  return tostring(v)
end

local function getConnectedDevicesNum(usbdev_data)
    local devices = {}
    local count = 0
    for _,v in ipairs(usbdev_data) do
        local dev = to_string(v[10])
        dev = dev and (match(dev,"(USB%-[A-Z])[0-9]+") or match(dev,"(sd[a-z])[0-9]+"))
        if dev then
            devices[dev] = dev
        end
    end
    for k,v in pairs(devices) do
        count = count + 1
    end
    return count
end

local usbdev_data, umgr_helpmsg = post_helper.handleTableQuery(usbdev_columms, usbdev_options, usbdev_filter, nil, usbdev_valid)
local connecteddevices = getConnectedDevicesNum(usbdev_data)
local pageRefresh = nil

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
%>

<%= ui_helper.createHeader(T"Content Sharing", true, true, pageRefresh, help_link)%>

<div class="modal-body update">
    <form class="form-horizontal" method="post" action="modals/contentsharing-modal.lp">
        <%
            ngx.print(ui_helper.createMessages(message_helper.popMessages()))
            local html = {}
            tinsert(html, '<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>')
            tinsert(html, "<fieldset><legend>" .. T"General status" .. "</legend>")
            local advanced = {
                group = { class = "advanced hide"},
                span = { class = "span4" }
            }
            local advancedhide = {
                group = { class = "advanced show"},
                span = { class = "span4" }
            }
            tinsert(html, ui_helper.createCheckboxSwitch("File Server Enabled", "samba_enabled", content["samba_enabled"],attributes))
            --tinsert(html, ui_helper.createLabel(T"File Server name: ", content["samba_name"], advancedhide))
            tinsert(html, ui_helper.createInputText(T"File Server name: ", "samba_name", content["samba_name"], advanced))
            tinsert(html, ui_helper.createInputText(T"File Server workgroup: ", "samba_workgroup", content["samba_workgroup"], advanced))
            tinsert(html, ui_helper.createInputText(T"File Server description: ", "samba_description", content["samba_description"], advanced))
            tinsert(html, ui_helper.createCheckboxSwitch("DLNA Enabled", "minidlna_enabled", content["minidlna_enabled"],attributes))
            --tinsert(html, ui_helper.createLabel(T"DLNA name: ", content["minidlna_friendly_name"], advancedhide))
            tinsert(html, ui_helper.createInputText(T"DLNA name: ", "minidlna_friendly_name", content["minidlna_friendly_name"], advanced))
            tinsert(html, "</fieldset>")

            tinsert(html, "<fieldset><legend>" .. T"Hard Disk Information" .. "</legend><p>")
            if connecteddevices == 0 then
                tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', "no"))
            elseif connecteddevices == 1 then
                tinsert(html, format(T'Currently there is <strong>%s</strong> connected device', connecteddevices))
            else
                tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', connecteddevices))
            end
            tinsert(html, "</p></fieldset>")
            tinsert(html, ui_helper.createTable(usbdev_columms, usbdev_data, usbdev_options, nil, usbdev_helpmsg))
            ngx.print(html)
        %>

    </form>
</div>
<% ngx.print(ui_helper.createFooter()) %>
