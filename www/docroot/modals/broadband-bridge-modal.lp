--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local bridged = require("bridgedmode_helper")
local tonumber = tonumber

local content_wan = {
    wans_enable = "uci.wansensing.global.enable",
}

content_helper.getExactContent(content_wan)

local function validatePvc(value, object, key)
        local pattern = "^(%d+)%/(%d+)$"
        local data = { string.match(value, pattern) }
        if #data == 2 then
            local intf = string.match(key, "^vpi_(.*)$")
            local vpi = "vpi_" .. intf
            local vci = "vci_" .. intf
            object[vpi] = data[1]
            object[vci] = data[2]
            return true
        else
            return nil, T"Invalid VPI/VCI, it must be of the form 0/00"
        end
    return true
end

local vlan_names = {
    ["id_wan"] = "uci.network.device.@vlan_ppp.name",
}

local function validateVlanID(value, object, key)
        local intf = string.match(key, "^id_(.*)$")
        local pattern = "^(%d+)$"
        local number = { string.match(value, pattern) }
        if #number ~= 1 or tonumber(number[1]) < 2 or tonumber(number[1]) > 4094 then
            return nil, T"Invalid VLAN ID, it must be a number on the range 2-4094"
        end
    return true
end

local mapParams = {
        id_wan = "uci.network.device.@vlan_ppp.vid",
        id_hfc = "uci.network.device.@vlan_hfc.vid",
        vpi_wan = "uci.xtm.atmdevice.@atm_ppp.vpi",
        vci_wan = "uci.xtm.atmdevice.@atm_ppp.vci",
}

local mapValid = {
        id_wan = validateVlanID,
        id_hfc = validateVlanID,
        vpi_wan = validatePvc,
        vci_wan = function (val, object)
            return true
        end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Broadband", true, true))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-bridge-modal.lp">\
\
<fieldset id="conn_mode" class="advanced hide">\
');  
local html = {}
local attributes = { span = { class = "span3" } }
    html[#html + 1] = string.format([[<legend>%s</legend>]], T"VLAN configuration")
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID for VDSL", "id_wan", content["id_wan"], attributes, helpmsg["id_wan"])
    html[#html + 1] = ui_helper.createInputText(T"VLAN ID for Ethernet", "id_hfc", content["id_hfc"], attributes, helpmsg["id_hfc"])
    local pvc = {}
    local vpi = "vpi_" .. "wan"
    local vci = "vci_" .. "wan"
    if content[vpi] ~= "" and content[vci] ~= "" then
        pvc["wan"] = content[vpi] .. "/" .. content[vci]
    end
    html[#html + 1] = string.format([[<legend>%s</legend>]], T"PVC configuration")
    html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for ADSL", "vpi_wan", pvc["wan"], attributes, helpmsg["vpi_wan"])
ngx.print(html)
  ngx.print('\
</fieldset>\
\
');  
    lp.setpath("/www/snippets/")
    lp.include("broadband-xdsl.lp")
    lp.include("broadband-ethernet.lp")
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
\
'); 