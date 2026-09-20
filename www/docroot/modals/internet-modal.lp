<%
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

local igmp_options = {
      {"2", T"IGMPv2"},
      {"3", T"IGMPv3"},
}

local mapParams = {
    wans_enable = "uci.wansensing.global.enable",
    wans_l2type = "uci.wansensing.global.l2type",
    wans_l3type = "uci.wansensing.global.l3type",
    ipoe_auto = "uci.network.interface.@ipoe.auto",
    ppp_auto = "uci.network.interface.@ppp.auto",
    atm_ulp = "uci.xtm.atmdevice.@atm_ppp.ulp",
    atm_enc = "uci.xtm.atmdevice.@atm_ppp.enc",
    igmp_version = "uci.network.interface.@video.igmpversion",
    igmp_version_2= "uci.network.interface.@video2.igmpversion",
}

local function getValidateAuto(value, object, key)
    if(object.wans_enable == '1') then
        object[key] = nil
    else
        object[key] = "0"
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

local function validateIGMPversion(value, object, key)
     local success, msg = gVIES(igmp_options)
     if success then
          object["igmp_version_2"] =object[key]
          return true
      else
          return nil, msg
      end
end

local mapValid = {
    wans_enable = post_helper.validateBoolean,
    wans_l2type = validateL2L3type,
    wans_l3type = validateL2L3type,
    ipoe_auto = getValidateAuto,
    ppp_auto = getValidateAuto,
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
	igmp_version = validateIGMPversion,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if content["igmp_version"]=="" then
   content["igmp_version"]="3"
end

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

%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>
<% ngx.print(ui_helper.createHeader(T"Internet Access", true, true)) %>

<div class="modal-body update">
<%
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
%>
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">

<fieldset class="advanced hide">
<legend><%= T"WAN sensing configuration" %></legend>
<%=ui_helper.createMessages(message_helper.popMessages())%>
<%=ui_helper.createSwitch(T"Auto WAN sensing","wans_enable",content["wans_enable"])%>
</fieldset>
<%
    if #imh > 1 then
    -- Only included if there are 2 or more connection modes
%>
<fieldset id="conn_mode" class="advanced hide">
<legend><%= T"Connection mode" %></legend>

<%
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
%>
</fieldset>

<fieldset id="igmp_version" class="advanced hide">
   <legend><%= T"IGMP version" %></legend>
   <%= ui_helper.createInputRadio(T"IGMP version", "igmp_version", igmp_options, content["igmp_version"])%>
</fieldset>

<% end %>

<% end %>
<%
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
%>

<%
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
%>

</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>

<% end %>
