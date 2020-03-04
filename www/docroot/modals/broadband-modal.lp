--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber

local content_wan = {
    proto = "uci.network.interface.@wan.proto",
    wans_enable = "uci.wansensing.global.enable",
    variant = "uci.env.var.iinet_variant",
}

content_helper.getExactContent(content_wan)

local bmh = require("broadbandmode_helper").get(content_wan.proto)
tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options
if content_wan.proto ~= "pppoe" and content_wan.proto ~= "" then
    table.remove(mode_options, 5)
    table.remove(mode_options, 3)
end

local function validatePvc(value, object, key)
    if content_wan.wans_enable == "0" then
        local pattern = "^(%d+)%/(%d+)$"
        local data = { string.match(value, pattern) }
        if #data == 2 then
            local intf = string.match(key, "^vpi_(.*)$")
            local vpi = "vpi_" .. intf
            local vci = "vci_" .. intf
            object[vpi] = data[1]
            object[vci] = data[2]

            if intf == "wan" and content_wan.proto == "pppoa" then
                object["wan_vpi"] = object[vpi]
                object["wan_vci"] = object[vci]
            end

            return true
        else
            return nil, T"Invalid VPI/VCI, it must be of the form 0/00"
        end
    else
        local intf = string.match(key, "^vpi_(.*)$")
        local vpi = "vpi_" .. intf
        local vci = "vci_" .. intf
        object[vpi] = nil
        object[vci] = nil
    end
    return true
end

local function validateVlanID(value, object, key)
    if content_wan.wans_enable == "0" then
        local intf = string.match(key, "^id_(.*)$")
        local pattern = "^(%d+)$"
        local number = { string.match(value, pattern) }
        if #number == 1 and tonumber(number[1]) >= 2 and tonumber(number[1]) <= 4094 then
            return true
        else
            return nil, T"Invalid VLAN ID, it must be a number on the range 2-4094"
        end
    end
    return true
end
local cType = "PVC"
if mode_current == "ethernet" or mode_current == "vdsl" or mode_current == "vdslvlan" or mode_current == "ethernetvlan" then
    cType = "VLAN"
    mapParams = {
        id_wan = "uci.network.device.@vlan_ppp.vid",
        id_hfc = "uci.network.device.@vlan_hfc.vid",
    }

    if content_wan.variant == "novas" then
        mapParams.id_voip = "uci.network.device.@vlan_voip.vid"
        mapParams.id_wan = nil
    end

    mapValid = {
        id_wan = validateVlanID,
        id_hfc = validateVlanID,
        id_voip = validateVlanID,
    }
else
    cType = "PVC"
    mapParams = {
        wan_vpi = "uci.network.interface.@wan.vpi",
        wan_vci = "uci.network.interface.@wan.vci",
        vpi_wan = "uci.xtm.atmdevice.@atm_ppp.vpi",
        vci_wan = "uci.xtm.atmdevice.@atm_ppp.vci",
        vpi_ipoe = "uci.xtm.atmdevice.@atm_ipoe.vpi",
        vci_ipoe = "uci.xtm.atmdevice.@atm_ipoe.vci",
    }

    if content_wan.variant == "novas" then
        mapParams.vpi_ipoe = nil
        mapParams.vci_ipoe = nil
    end

    mapValid = {
        vpi_wan = validatePvc,
        vci_wan = function (val, object)
            return true
        end,
        vpi_ipoe = validatePvc,
        vci_ipoe = function (val, object)
            return true
        end,
        wan_vpi = function (val, object)
            return true
        end,
        wan_vci = function (val, object)
            return true
        end
    }
end

local mapParams_mtu = {
    wan_mtu = "uci.network.device.@eth4.mtu",
    atm_ppp_mtu = "uci.network.device.@atm_ppp.mtu",
    atm_ipoe_mtu = "uci.network.device.@atm_ipoe.mtu",
    ptm0_mtu = "uci.network.device.@ptm0.mtu",
}

local function validateMTU (value)
    local num = tonumber (value)
    if (num >= 1280 and num <= 1500) then
        return true
    end
    return nil, T"MTU is invalid. It should be between 1280 and 1500"
end

local mapValid_mtu = {
    wan_mtu = validateMTU,
    ptm0_mtu = function(value,object)
        object["ptm0_mtu"]=object["wan_mtu"]
        return true
    end,
    atm_ppp_mtu = function(value,object)
        object["atm_ppp_mtu"]=object["wan_mtu"]
        return true
    end,
    atm_ipoe_mtu = function(value,object)
        object["atm_ipoe_mtu"]=object["wan_mtu"]
        return true
    end,
}

for k,v in pairs(mapParams_mtu) do
    mapParams[k] = v
    mapValid[k] = mapValid_mtu[k]
end

local mapParams_wansensing = {
    wans_enable = "uci.wansensing.global.enable",
    wans_l2type = "uci.wansensing.global.l2type",
    wans_l3type = "uci.wansensing.global.l3type",
    ipoe_auto = "uci.network.interface.@ipoe.auto",
    ppp_auto = "uci.network.interface.@ppp.auto",
    pppv_auto = "uci.network.interface.@pppv.auto",
    ipoe_ifname = "uci.network.interface.@ipoe.ifname",
    ppp_ifname = "uci.network.interface.@ppp.ifname",
    pppv_ifname = "uci.network.interface.@pppv.ifname",
    atm_ulp = "uci.xtm.atmdevice.@atm_ppp.ulp",
    atm_enc = "uci.xtm.atmdevice.@atm_ppp.enc",
    wan_ifname = "uci.network.interface.@wan.ifname",
    wan_proto = "uci.network.interface.@wan.proto",
    wan_metric = "uci.network.interface.@wan.metric",
    wan_username = "uci.network.interface.@wan.username",
    wan_password = "uci.network.interface.@wan.password",
    wan_keepalive = "uci.network.interface.@wan.keepalive",
    pppv_username = "uci.network.interface.@pppv.username",
    pppv_password = "uci.network.interface.@pppv.password",
}

if content_wan.variant == "novas" then
    mapParams_wansensing.pppv_auto = nil
    mapParams_wansensing.pppv_ifname = nil
    mapParams_wansensing.pppv_username = nil
    mapParams_wansensing.pppv_password = nil
end

local function getValidateAuto(value, object, key)
    if(object.wans_enable == '1') then
        object[key] = nil
    else
        object[key] = "0"
    end
    return true
end
local function getValidateIfname(value, object, key)
    if(object.wans_enable == '1') then
        object[key] = nil
    else
        object[key] = ""
    end
    return true
end

local function validateL2L3type(value, object, key)
    if(object.wans_enable == '1') then
        object[key] = nil
    else
        object[key] = ""
    end
    return true
end

local wan_ppp = {
  username = "uci.network.interface.@ppp.username",
  password = "uci.network.interface.@ppp.password",
}

content_helper.getExactContent(wan_ppp)

local mapValid_wansensing = {
    wans_enable = post_helper.validateBoolean,
    wans_l2type = validateL2L3type,
    wans_l3type = validateL2L3type,
    ipoe_auto = getValidateAuto,
    ppp_auto = getValidateAuto,
    pppv_auto = getValidateAuto,
    ipoe_ifname = getValidateIfname,
    ppp_ifname = getValidateIfname,
    pppv_ifname = getValidateIfname,
    atm_ulp = function(value, object, key)
        if(object.wans_enable == '1') then
            object[key] = "eth"
        else
            object[key] = nil
        end
        return true
    end,
    atm_enc = function(value, object, key)
        if(object.wans_enable == '1') then
            object[key] = "llc"
        else
            object[key] = nil
        end
        return true
    end,
    wan_proto = function(value, object, key)
        if (object.wans_enable == '0') then
            if object[key] == "" then
                object[key] = "pppoe"
                object.wan_metric = "10"
                object.wan_keepalive = "4,20"
                object.wan_username = wan_ppp.username
                object.wan_password = wan_ppp.password
                object.pppv_username = wan_ppp.username
                object.pppv_password = wan_ppp.password
            end
            if object.wan_ifname == "" then
                object.wan_ifname = "atm_ppp"
            end
        end
        return true
    end,
}

for k,v in pairs(mapParams_wansensing) do
    mapParams[k] = v
    mapValid[k] = mapValid_wansensing[k]
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print('\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Broadband", true, true))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
<fieldset class="advanced hide">\
<legend>');  ngx.print( T"WAN sensing configuration" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
');  ngx.print(ui_helper.createSwitch(T"Auto WAN sensing","wans_enable",content["wans_enable"])
); ngx.print('\
</fieldset>\
\
<fieldset class="advanced hide">\
<legend>');  ngx.print( T"MTU configuration" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createInputText(T"MTU", "wan_mtu", content["wan_mtu"], wan_mtu, helpmsg["wan_mtu"])
); ngx.print('\
</fieldset>\
\
');  
    if #bmh > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
\
');  
    local html = {}

    local mode_attributes = {
        radio = {
            class = "inline"
        },
        input = {
            class = "no-save",
            ["data-for"] = "SWITCH_MODE",
        }
    }
    local mode_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "SWITCH_MODE",
        }
    }

    if(content["wans_enable"] == '0') then
      html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
      html[#html+1] = ui_helper.createButton("", "Switch connection mode", "icon-cog", mode_button)
    else
      html[#html+1] = ui_helper.createLabel(T"Mode",tabdata.current.description)
    end

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
\
');  
local html = {}
local attributes = { span = { class = "span3" } }
if cType == "VLAN" and mode_current ~= "ethernet" and mode_current ~= "vdsl" then
    html[#html + 1] =  '<fieldset id="conn_mode" class="advanced hide">'
    html[#html + 1] = string.format([[<legend>%s</legend>]], T"VLAN configuration")
    if(content["wans_enable"] == '0') then
      if content_wan.variant == "novas" then
        if mode_current == "ethernetvlan" or mode_current == "vdslvlan" then
            html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_hfc", content["id_hfc"], attributes, helpmsg["id_hfc"])
            html[#html + 1] = ui_helper.createInputText(T"VLAN ID for VoIP", "id_voip", content["id_voip"], attributes, helpmsg["id_voip"])
        end
      else
        if mode_current == "vdslvlan" then
            html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_wan", content["id_wan"], attributes, helpmsg["id_wan"])
        end
        if mode_current == "ethernetvlan" then
            html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_hfc", content["id_hfc"], attributes, helpmsg["id_hfc"])
        end
      end
    else
      if content_wan.variant == "novas" then
        if mode_current == "ethernetvlan" or mode_current == "vdslvlan" then
            html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_hfc"])
            html[#html + 1] = ui_helper.createLabel(T"VLAN ID for VoIP", content["id_voip"])
        end
      else
        if mode_current == "vdslvlan" then
            html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_wan"])
        end
        if mode_current == "ethernetvlan" then
            html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_hfc"])
        end
      end
    end
    html[#html + 1] = '</fieldset>'
elseif cType == "PVC" then
    local pvc = {}
    local intfs_over_pvc = { "wan", "ipoe" }
    for _,v in ipairs(intfs_over_pvc) do
        local vpi = "vpi_" .. v
        local vci = "vci_" .. v
        if content[vpi] and content[vpi] ~= "" and content[vci] ~= "" then
            pvc[v] = content[vpi] .. "/" .. content[vci]
        end
    end
    html[#html + 1] =  '<fieldset id="conn_mode" class="advanced hide">'
    html[#html + 1] = string.format([[<legend>%s</legend>]], T"PVC configuration")
    if(content["wans_enable"] == '0') then
      if content_wan.variant ~= "novas" then
        html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for PPPoE/PPPoA", "vpi_wan", pvc["wan"], attributes, helpmsg["vpi_wan"])
        html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for IPoE", "vpi_ipoe", pvc["ipoe"], attributes, helpmsg["vpi_ipoe"])
      else
        html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for PPPoE/PPPoA/IPoE", "vpi_wan", pvc["wan"], attributes, helpmsg["vpi_wan"])
      end
    else
      if content_wan.variant ~= "novas" then
        html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for PPPoE/PPPoA", pvc["wan"])
        html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for IPoE", pvc["ipoe"])
      else
        html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for PPPoE/PPPoA/IPoE", pvc["wan"])
      end
    end
    html[#html + 1] = '</fieldset>'
end
ngx.print(html)
  ngx.print('\
\
\
');  end   ngx.print('\
\
');  end   ngx.print('\
');  
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
  ngx.print('\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
');  end   ngx.print('\
\
'); 