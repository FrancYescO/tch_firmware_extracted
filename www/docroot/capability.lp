<%
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local table, format, match, len, sub, find = table, string.format, string.match, string.len, string.sub, string.find
local json = require("dkjson")

ngx.header.content_type = "application/json;charset=UTF-8"
local buffer = {}
local success = {}

local content = {
    FirmwareVersion = "uci.version.version.@version[0].version",
    SerialNumber = "uci.env.rip.serial",
    Mode = "rpc.mmpbx.mode",
    fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
    fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
    fwversion_override = "uci.versioncusto.override.fwversion_override",
    Model = "uci.env.var.prod_friendly_name",
    PushNotification = "uci.mmpbxrvsipdev.sip_server.push_notification_support",
}
content_helper.getExactContent(content)
if content["FirmwareVersion"] then
    local version = content["FirmwareVersion"]
    content["FirmwareVersion"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-[^-]*$") - 1) .. content.fwversion_suffix
    if content.fwversion_override and content.fwversion_override == "override1" then
        content["FirmwareVersion"] = content.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. content.fwversion_suffix
    end
end
content.fwversion_prefix = nil
content.fwversion_suffix = nil
content.fwversion_override = nil

content["BulkAdd"] = proxy.get("rpc.mmpbx.phonebook.bulkadd") and "yes" or "no"
content["PushNotification"] = content["PushNotification"] == "1" and "yes" or "no"

success = json.encode (content, { indent = true, buffer = buffer })
if success then
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK )
else
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end
%>
