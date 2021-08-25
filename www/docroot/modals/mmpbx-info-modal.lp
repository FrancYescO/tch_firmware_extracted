<%
-- Enable localization
gettext.textdomain("webui-voice")

local proxy = require ("datamodel")
local content_helper = require ("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local format = string.format

local sipnet_options={}
for i,v in ipairs(proxy.getPN("uci.mmpbxrvsipnet.network.", true)) do
    local sipnet = string.match(v.path, "uci%.mmpbxrvsipnet%.network%.@([^%.]+)%.")
    if sipnet then
        local sipnet_name = proxy.get(v.path .. "user_friendly_name")[1].value
        sipnet_options[#sipnet_options+1]={sipnet, sipnet_name}
    end
end

local devMap={}
local port_options = {}
local dev_config = { "mmpbxbrcmfxsdev", "mmpbxbrcmdectdev", "mmpbxrvsipdev",}

local function getDeviceFriendlyNames()
    local devpattern = "([^%._@]+_dev_%d+)"
    for _,v in pairs(dev_config) do
        local results = proxy.get("uci." .. v .. ".device.")
        if results then
            for _,vv in ipairs(results) do
                if vv.param == "user_friendly_name" then
                    local dev = vv.path:match(devpattern)
                    devMap[dev] = string.format("%s",vv.value)
                    port_options[#port_options + 1] = {dev, vv.value}
                end
            end
        end
    end
end
getDeviceFriendlyNames()

local order = {
    f = 1,
    d = 2,
    s = 3,
}

table.sort(port_options, function(a,b)
    local order_a = order[a[1]:sub(1,1)]
    local order_b = order[b[1]:sub(1,1)]
    if order_a < order_b or (order_a == order_b and a[1] < b[1]) then
        return true
    else
        return false
    end
end)

-- profile table columns define
local sip_columns = {
  { --[1]
    header = T"SIP Profile",
    name = "sip_profile",
    param = "paramindex",
    type = "label",
  },
  { --[2]
    header = T"UserName",
    name = "username",
    param = "user_name",
    type = "label",
  },
  { --[3]
    header = T"URI",
    name = "uri",
    param = "uri",
    type = "label",
  },
  { --[4]
    header = T"DisplayName",
    name = "displayName",
    param = "display_name",
    type = "label",
  },
  { --[5]
    header = T"SIP Network",
    name = "network",
    param = "network",
    type = "select",
    values = sipnet_options,
    attr = { select = { class="span2" } },
  },
  { --[6]
    header = T"Port",
    name = "port",
    param = "port",
    type = "select",
    values = port_options,
    attr = { select = { class="span2" } },
  },
  { --[7]
    header = T"Registered",
    name = "registerStatus",
    type = "light"
  },
  { --[8]
    header = T"Line Status",
    name = "callStatus",
    type = "label",
  }
}

-- Identify sip table column number
local scns = {
    ["profile"] = 1,
    ["port"] = 6,
    ["register"] = 7,
    ["call"] = 8,
}

local pattern = "(([^%._@]+)_profile_(%d+))"
local function sort_func(a, b)
    local _, _, a_num = a.paramindex:match(pattern)
    local _, _, b_num = b.paramindex:match(pattern)
    if tonumber(a_num) < tonumber(b_num) then
       return true
    else
       return false
    end
end

local sip_options = {
    tableid = "sip_profile",
    basepath = "rpc.mmpbx.sip_profile.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
    sorted = sort_func,
}

local sip_valid = {
}

local sip_data, sip_helpmsg = post_helper.handleTableQuery(sip_columns, sip_options, nil, nil, sip_valid)

for _,v in pairs(sip_data) do
    local ports = string.format("%s", v[scns["port"]])
    if string.find(ports, "%,") then
        ports = string.gsub(ports, "([^%,]+)", devMap)
        ports = string.gsub(ports, "(%,)", ", ")
        v[scns["port"]] = ports
    end

    local name = v[scns["profile"]]
    local states = {
        regstate  = "rpc.mmpbx.profile.@" .. name .. ".sipRegisterState",
        callstate  = "rpc.mmpbx.profile.@" .. name .. ".callState"
    }
    content_helper.getExactContent(states)

    local regstate, callstate = "0", "Idle"
    if states.regstate == "Registered" then
        regstate = "1"
    elseif states.regstate == "Registering" then
        regstate = "2"
    end

    if (regstate == "1") then
        if (states.callstate == "MMPBX_CALLSTATE_IDLE") then
            callstate = "On hook"
        else
            callstate = "Off hook"
        end
    end

    v[scns["register"]] = regstate
    v[scns["call"]] = callstate
end



local content_global = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
}
content_helper.getExactContent(content_global)

if content_global["mmpbx_enabled"] == '1' then
    content_global["mmpbx_enabled"] = 'Yes'
else
    content_global["mmpbx_enabled"] = 'No'
end

-- SIP Networks
local sipnet_columns = {
  {
    header = T"Name",
    name = "user_friendly_name",
    param = "user_friendly_name",
    type = "label",
  },
  {
    header = T"Primary Registrar",
    name = "primaryRegistrar",
    param = "primary_registrar",
    type = "label",
  },
  {
    header = T"Primary RegistrarPort",
    name = "primaryRegistrarPort",
    param = "primary_registrar_port",
    type = "label",
  },
  {
    header = T"Primary Proxy",
    name = "primaryProxy",
    param = "primary_proxy",
    type = "label",
  },
  {
    header = T"Primary ProxyPort",
    name = "primaryProxyPort",
    param = "primary_proxy_port",
    type = "label",
  },
  {
    header = T"Expire Time",
    name = "regExpire",
    param = "reg_expire",
    type = "label",
  },
}

local sipnet_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.",
    sorted = "user_friendly_name",
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
%>

<%= ui_helper.createHeader(T"Telephony", false, true, nil, help_link) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal">
    <fieldset id="mmpbx-info-tab">
      <legend><%= T"Service Configuration" %></legend>
      <%= ui_helper.createLabel(T"Enable Telephony", content_global["mmpbx_enabled"]) %>
      <legend><%= T"Telephone Numbers" %></legend>
      <%= ui_helper.createTable(sip_columns, sip_data, sip_options, nil, sip_helpmsg) %>
      <legend><%= T"SIP Network" %></legend>
      <%=ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)%>
    </fieldset>
  </form>
</div>
<%= ui_helper.createFooter() %>

<script>
  $(function(){
    $('#sip_profile tbody tr').each (function() {
      var regstate_column = 6;
      //Toolbox for column Registered
      var reg = $(this).find("td").eq(regstate_column).find("div");
      var reg_class = reg.attr("class");
      var reg_hint = "Unregistered";
      if (reg_class == "light green") {
        reg_hint = "Registered";
      }
      else if (reg_class == "light orange") {
        reg_hint = "Registering";
      }
      reg.attr({"class": "someInfos " + reg_class, "rel": "tooltip", "data-placement": "top", "data-original-title": reg_hint});
    })
    $('.someInfos').tooltip();
  });
</script>
