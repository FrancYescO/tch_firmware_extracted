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
local format, remove = string.format, table.remove
local vNES = post_helper.validateNonEmptyString
local gVCS = post_helper.getValidateCheckboxSwitch()
local stopErrMsg = ""
local activeDeviceNum = 0

-- Get the content_info
local content_info = {
    connecteddevices            = "sys.usb.DeviceNumberOfEntries",
}
content_helper.getExactContent(content_info)

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
    {
        header = T"DLNA Share",
        name = "Share",
        param = "Share",
        type = "checkboxswitch",
        default = "0",
    },
    {
        header = T"Device Stop",
        name = "Stop",
        param = "Stop",
        type = "checkboxswitch",
        default = "0",
    },
    {
        header = T"Path",
        name = "KeyPath",
        param = "KeyPath",
        type = "hidden",
    },
}

local usbdev_options = {
    tableid = "usbDev",
    basepath = "sys.usb.partition.@.",
    canEdit = true,
    canAdd = false,
    canDelete = false,
    canApply = true,
}

--only show the mounted usb device.
local usbdev_filter = function(data)
    if data.Stop == "0" then
        return true
    end
    return false
end

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

local function validateShareAndStopValue(value, object, key)
    stopErrMsg = ""
    local tmpStopValue = toGetCheckBoxSwitchValue(object["Stop"])
    local retStopValue = proxy.get("sys.usb.partition.@" .. object["KeyPath"] .. ".Stop")
    local tmpShareValue = toGetCheckBoxSwitchValue(object["Share"])
    local retShareValue = proxy.get("sys.usb.partition.@" .. object["KeyPath"] .. ".Share")
    local errState = false

    if not retStopValue then
        tmpStopValue = nil
        errState = true
    end

    if not retShareValue then
        tmpShareValue = nil
        errState = true
    end

    if not errState then
        if (retShareValue[1].value == tmpShareValue) then
            tmpShareValue = nil
        end

        if (retStopValue[1].value == tmpStopValue) then
            tmpStopValue = nil
        else
            if "1" == tmpStopValue then
                local ret = proxy.get("sys.usb.partition.@" .. object["KeyPath"] .. ".UsbBusy")
                if "1" == ret[1].value then
                    stopErrMsg = T"Volume(" .. object["Volume"] .. ") is busy now, cannot be stopped, please try later."
                    return nil
                end
                tmpShareValue = nil
            end
       end
    end

    object["Share"] = tmpShareValue
    object["Stop"] = tmpStopValue
    object["Volume"] = nil
    object["KeyPath"] = nil
    return true
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
    Stop = validateShareAndStopValue,
}

local function toDeleteKeyPathData(usbdev_data)
    for _, v in ipairs(usbdev_data) do
        remove(v, #v)
        activeDeviceNum = activeDeviceNum + 1
    end
end

local function toDeleteKeyPathHeader(usbdev_columms)
    remove(usbdev_columms, #usbdev_columms)
end

local usbdev_data, umgr_helpmsg = post_helper.handleTableQuery(usbdev_columms, usbdev_options, usbdev_filter, nil, usbdev_valid)
toDeleteKeyPathHeader(usbdev_columms)
toDeleteKeyPathData(usbdev_data)
local pageRefresh = nil

local changesconflictMsg = "Changes were made to this table which require you to start again."
if usbdev_options.errmsg == changesconflictMsg then
    usbdev_options.errmsg = T"Warnning: The last changing is being processing, please try later."
end

if ngx.var.request_method == "POST" then
  if (action == "TABLE-MODIFY") then
    ngx.sleep(4)
  end
end

local uri = ngx.var.uri
%>

<%= ui_helper.createHeader(T"Content Sharing", true, true, pageRefresh)%>

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
            if activeDeviceNum == 0 or content_info.connecteddevices == "0"  or content_info.connecteddevices == '' then
                tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', "no"))
            elseif content_info.connecteddevices == "1" then
                tinsert(html, format(T'Currently there is <strong>%s</strong> connected device', content_info.connecteddevices))
            else
                tinsert(html, format(T'Currently there are <strong>%s</strong> connected devices', content_info.connecteddevices))
            end
            if stopErrMsg ~= "" then
                local attrStopErrMsg = {
                    alert = {
                        class = "alert-info hide",
                        id = "stoperr-msg"
                    }
                }
                tinsert(html, ui_helper.createAlertBlock(T"Warning: ".. stopErrMsg, rebooting))
            end
            tinsert(html, "</p></fieldset>")
            tinsert(html, ui_helper.createTable(usbdev_columms, usbdev_data, usbdev_options, nil, usbdev_helpmsg))
            ngx.print(html)
        %>

    </form>
</div>
<% ngx.print(ui_helper.createFooter()) %>
<script>
 $(function(){
   function waiting_action(self) {
     var msg_dst = $(self);
     var busy_msg = $(".loading-wrapper");
     msg_dst.after(busy_msg);
     busy_msg.removeClass("hide");
     busy_msg[0].scrollIntoView();
     $(".modal-body").scrollLeft(0);
   };
   $(document).on("click", "#save-config", function () {
     waiting_action(this);
   });

   $(document).on("click", "table [class*='btn-table-']:not(.disabled)", function () {
     waiting_action(this);
   });

   $(document).on("change", 'table .switch input[type="hidden"]', function (e) {
     var table = $(this).closest("table");
     // Check that we're not editing a line, this is only for when the line is displayed
     if (table.find(".btn-table-cancel").length === 0) {
       waiting_action(this);
     }
   });
 });

</script>
