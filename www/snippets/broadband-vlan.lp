--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local wan = {
    iface = "uci.network.interface.@wan.ifname",
}
content_helper.getExactContent(wan)
local iface = string.match(wan.iface, "([^%.]+)")

local vVLANID = post_helper.getValidateNumberInRange(0,4095)

local intf_vlan
local intf_vlanid

local mapValid = {
    intf_vlanid = function(value, object, key)
        intf_vlan = ngx.req.get_post_args().intf_vlan
        intf_vlanid = value
        if intf_vlan == "1" then
            local res, help = vVLANID(value)
            if not res then
                return res, help
            end
            object.intf_vlanid = iface .. '.' .. value
        else
            object.intf_vlanid = iface
        end
        return true
    end,
}

local mapParams = {
    intf_vlanid = "uci.network.interface.@wan.ifname",
}
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local vid = string.match(content.intf_vlanid, "%.(%d+)$")
content.intf_vlan = vid and "1" or "0"
content.intf_vlanid = intf_vlanid or vid

  ngx.print('\
<fieldset>',
    ui_helper.createMessages(message_helper.popMessages()), '\
  <legend>', T"Internet channel", '</legend>');  
    local html = {}
    local vlanswitchclass = {
        input = {
            class = "monitor-changes"
        }
    }
    local vlanidclass = {
        group = {
            class ="monitor-intf_vlan monitor-1",
        },
    }
    html[#html + 1] = ui_helper.createSwitch(T"Using VLAN", "intf_vlan", content["intf_vlan"], vlanswitchclass)
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID", "intf_vlanid", content["intf_vlanid"], vlanidclass, helpmsg["intf_vlanid"])
    ngx.print(html, '\
</fieldset>');