--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

ngx.ctx.session:store("network_interface_name", "wan")

local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require ("web.content_helper")
local post_helper = require("web.post_helper")
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean

local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)

local mapParams = {
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
}

local function validateWansEnabled(value, object, key)
    local success, msg = vB(value)
    if not success then
        return success, msg
    end
    local content_wans = {
        enable = "uci.wansensing.global.enable",
    }
    content_helper.getExactContent(content_wans)
    if content_wans.enable == value then
        object[key] = nil
    end
    if value == "1" then
        object["wans_l2type"] = nil
        object["wans_l3type"] = nil
        object["ipoe_auto"] = nil
        object["ppp_auto"] = nil
        object["pppv_auto"] = nil
        object["ipoe_ifname"] = nil
        object["ppp_ifname"] = nil
        object["pppv_ifname"] = nil
        object["atm_ulp"] = "eth"
        object["atm_enc"] = "llc"
    else
        object["wans_l2type"] = ""
        object["wans_l3type"] = ""
        object["ipoe_auto"] = "0"
        object["ppp_auto"] = "0"
        object["pppv_auto"] = "0"
        object["ipoe_ifname"] = ""
        object["ppp_ifname"] = ""
        object["pppv_ifname"] = ""
        object["atm_ulp"] = nil
        object["atm_enc"] = nil
    end
    return true
end

local function alwaysTrue()
    return true
end

local mapValid = {
    wans_enable = validateWansEnabled,
    wans_l2type = alwaysTrue,
    wans_l3type = alwaysTrue,
    ipoe_auto = alwaysTrue,
    ppp_auto = alwaysTrue,
    pppv_auto = alwaysTrue,
    ipoe_ifname = alwaysTrue,
    ppp_ifname = alwaysTrue,
    pppv_ifname = alwaysTrue,
    atm_ulp = alwaysTrue,
    atm_enc = alwaysTrue,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local bmh = require("broadbandmode_helper").get()
local tabdata = dyntab_helper.process(bmh)
local wan_type = tabdata.current.name
local imh = require("internetmode_helper").get(wan_type)

tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local mode_options = tabdata.options

if wan_type ~= "adsl" then
   for k,v in ipairs(mode_options) do
       if v[1] == "pppoa" then
           table.remove(mode_options, k)
           break
       end
   end
end

  ngx.print('\
\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Internet Access", true, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local tabs = {
        {
            desc = T"IPv4 Configuration",
            active = "active",
            target = "modals/internet-modal.lp",
        },
        {
            desc = T"IPv6 Configuration",
            target = "modals/internet-ex-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">\
\
<fieldset class="advanced hide">\
<legend>');  ngx.print( T"WAN sensing configuration" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
');  ngx.print(ui_helper.createSwitch(T"Auto WAN sensing","wans_enable",content["wans_enable"])); ngx.print('\
</fieldset>\
');  
    if #imh > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Connection mode" ); ngx.print('</legend>\
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
');  end   ngx.print('\
\
');  end   ngx.print('\
');  
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
  ngx.print('\
\
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
'); 