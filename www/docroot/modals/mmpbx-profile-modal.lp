<%
-- Enable localization
gettext.textdomain("webui-voice")

local proxy = require ("datamodel")
local content_helper = require ("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs

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

port_options[#port_options + 1] = {"common", "COMMON"}

-- sip columns
local sip_columns = {
    { --[1]
        header = "",
        name = "enable",
        param = "enabled",
        type = "switch",
        default = "1",
        attr = { switch = { ["data-placement"] = "right" } },
    },
    { --[2]
        header = T"SIP Profile",
        name = "profile",
        param = "paramindex",
        type = "label",
        readonly = true,
        attr = { input = { class="span1" } },
    },
    { --[3]
        header = T"UserName",
        name = "username",
        param = "user_name",
        type = "text",
        attr = { input = { class="span1" } },
    },
    { --[4]
        header = T"URI",
        name = "uri",
        param = "uri",
        type = "text",
        attr = { input = { class="span1" } },
    },
    { --[5]
        header = T"Password",
        name = "password",
        param = "password",
        type = "password",
        attr = { input = { class="span1" } },
    },
    { --[6]
        header = T"DisplayName",
        name = "displayName",
        param = "display_name",
        type = "text",
        attr = { input = { class="span1"} },
    },
    { --[7]
        header = T"SIP Network",
        name = "network",
        param = "network",
        type = "select",
        values = sipnet_options,
        attr = { select = { class="span2" } },
    },
    { --[8]
        header = T"Port",
        name = "port",
        param = "port",
        type = "select",
        values = port_options,
        attr = { select = { class="span2" } },
    },
    { --[9]
        header = T"Registered",
        name = "registerStatus",
        type = "light",
    },
    { --[10]
        header = T"Line Status",
        name = "callStatus",
        type = "label",
        readonly = true,
        attr = { input = { class="span1" } },
    },
}

local internal_columns = {
    { --[1]
        header = T"Internal Profile",
        name = "profile",
        param = "paramindex",
    },
    { --[2]
        header = T"Number",
        name = "number",
        param = "number",
    },
    { --[3]
        header = T"Port",
        name = "port",
        param = "port",
    },
    { --[4]
        header = T"Enabled",
        name = "enable",
        param = "enabled",
    },
}

-- Identify sip table column number
local scns = {
    ["profile"] = 2,
    ["password"] = 5,
    ["port"] = 8,
    ["register"] = 9,
    ["call"] = 10,
}

-- Identify internal table column number
local icns = {
    ["port"] = 3,
    ["enable"] = 4,
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
    createMsg = T"Create new",
    sorted = sort_func,
}

local function validateUri(value, object, key)
    local post_args = ngx.req.get_post_args()
    local action = post_args.action
    local uri = string.format("%s", value)
    if #uri == 0 then
        return nil, T"Please set URI."
    end
    if string.find(uri, "%s") then
        return nil, "Invalid URI, space not allowed"
    end
    if action == "TABLE-ADD" or action == "TABLE-MODIFY" then
        local pattern = "(([^%._@]+)_profile_(%d+))"
        local results = proxy.get("uci.mmpbxrvsipnet.profile.")
        if results then
            for _,v in ipairs(results) do
                if v.param == "uri" and v.value == uri and v.path:match(pattern) ~= sip_options.changesessionindex then
                    return nil, T"This URI has already existed, please input one not existed."
                end
            end
        end
    end
    return true
end

local function validateNonspaceString(value, object, key)
    if value == "" then
        return nil, T"Please set value."
    end
    if string.find(string.format("%s", value), "%s") then
        return nil, T"Invalid value, space not allowed"
    end
    return true
end

local mask_password = "********"
local function validatePassword(value, object, key)
    local password = string.format("%s", value)
    if #password == 0 then
        return nil, T"Please set password."
    end
    if string.find(password, "%s") then
        return nil, "Invalid password, space not allowed"
    end
    if password == mask_password then
        object[key] = nil
    end
    return true
end

local sip_valid = {
    enable = post_helper.validateBoolean,
    uri = validateUri,
    username = validateNonspaceString,
    password = validatePassword,
    displayName = validateNonspaceString,
    profile = function(value, object, key)
        -- remove profile as paramindex is not a real parameter in uci data model
        object[key] = nil
        return true
    end,
    port = function(value, object, key)
       if string.find(value, ",") then
           object[key] = "common"
       end
        return true
    end,
}

local sip_data, sip_helpmsg = post_helper.handleTableQuery(sip_columns, sip_options, nil, nil, sip_valid)

local internal_options = {
    tableid = "internal_profile",
    basepath = "rpc.mmpbx.internal_profile.@.",
    canEdit = false,
    canAdd = false,
    canDelete = false,
    sorted = sort_func,
}

local internal_data, internal_helpmsg = post_helper.handleTableQuery(internal_columns, internal_options)

for _,v in pairs(internal_data) do
    v[icns["enable"]] = (v[icns["enable"]] == "1" and "Enabled") or "Disabled"
    local ports = string.format("%s", v[icns["port"]])
    ports = string.gsub(ports, "([^%,]+)", devMap)
    ports = string.gsub(ports, "(%,)", "<br>")
    v[icns["port"]] = ports
end

for _,v in pairs(sip_data) do
    v[scns["password"]] = mask_password
    local ports = string.format("%s", v[scns["port"]])
    if string.find(ports, "%,") then
        ports = string.gsub(ports, "([^%,]+)", devMap)
        ports = string.gsub(ports, "(%,)", "<br>")
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

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <fieldset id="mmpbx-profile-tab">
      <legend><%= T"Telephone Numbers" %></legend>
      <%= ui_helper.createTable(sip_columns, sip_data, sip_options, nil, sip_helpmsg) %>
    </fieldset>
    <fieldset>
      <legend><%= T"Internal Telephone Numbers" %></legend>
      <%= ui_helper.createTable(internal_columns, internal_data, internal_options, nil, internal_helpmsg) %>
    </fieldset>
  </form>
</div>

<div class="modal-footer">
  <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal"><%= T"Close" %></div>
</div>

<script>
  $(function(){
    $('#sip_profile tbody tr').each (function() {
      var regstate_column = 8;
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

