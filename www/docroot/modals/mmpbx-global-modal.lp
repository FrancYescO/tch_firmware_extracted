<%
-- Enable localization
gettext.textdomain('webui-voice')

local ngx = ngx
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local uimessage_helper = require("web.uimessage_helper")
local format, match, floor = string.format, string.match, math.floor
local gOV = post_helper.getOrValidation
local gAV = post_helper.getAndValidation
local vSIDN = post_helper.validateStringIsDomainName

local mapValid = {
    mmpbx_enabled = post_helper.validateBoolean,
}

local mapParams = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
}

local content = post_helper.handleQuery(mapParams, mapValid)
-- SIP Networks
local sipnet_columns = {
  {
    header = T"Name",
    name = "user_friendly_name",
    param = "user_friendly_name",
    type = "label",
    readonly = true,
    attr = { input = { class="span2" }},
  },
  {
    header = T"Primary Registrar",
    name = "primaryRegistrar",
    param = "primary_registrar",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary RegistrarPort",
    name = "primaryRegistrarPort",
    param = "primary_registrar_port",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary Proxy",
    name = "primaryProxy",
    param = "primary_proxy",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary ProxyPort",
    name = "primaryProxyPort",
    param = "primary_proxy_port",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Expire Time",
    name = "regExpire",
    param = "reg_expire",
    type = "text",
    attr = { input = { class="span2" } },
  },
}

local function validateStringIsVoicePort(value, object, key)
    value = value and match(value, "^[%s0]*(%d+)%s*$")
    local port = value and tonumber(value)
    if port and (floor(port) == port) and (port == 0 or (port >=1024 and port < 65536)) then
        return true
    end
    return nil, T"Port is invalid. It should be 0 or between 1024 and 65535."
end

local function validateRegProxy(value, object, key)
    local validateStringIsIP = post_helper.validateStringIsIP()
    if validateStringIsIP(value) then
        local ipValid, broadcastIP, isRes, isQTNLXC, errorMsg
        ipValid, errorMsg = post_helper.validateRelay(value, object)
        if not ipValid then
            return nil, errorMsg
        end
        if post_helper.ipv42num(value) == 0 then
            return nil,  T"Cannot use an address in this address range."
        end
        --check if ip is not in the limited broadcast destination address 255.255.255.255/32
        if value == "255.255.255.255" then
            return nil, T"Cannot use the limited broadcast destination address."
        end
        isRes, errorMsg = post_helper.reservedIPValidation(value)
        if not isRes then
            return nil, errorMsg
        end
        isQTNLXC, errMsg = gAV(post_helper.validateQTN, post_helper.validateLXC)(value)
        if not isQTNLXC then
            return nil, errMsg
        end
    end
    return vSIDN(value)
end

local sipnet_valid = {
    primaryRegistrarPort = validateStringIsVoicePort,
    primaryRegistrar = validateRegProxy,
    primaryProxy = validateRegProxy,
    primaryProxyPort = validateStringIsVoicePort,
    regExpire = post_helper.validateRegExpire,
}

local sipnet_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.",
    sorted = "user_friendly_name",
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, nil, sipnet_valid)

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
  <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
	<fieldset id="mmpbx-global-tab">
	    <legend><%= T"Global Information" %></legend>
	    <%= ui_helper.createSwitch(T"Enabled", "mmpbx_enabled", content["mmpbx_enabled"]) %>
	</fieldset>
    <%if content and content["mmpbx_enabled"] == "1" then %>
        <fieldset>
            <legend><%= T"SIP Network" %></legend>
            <%=ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)%>
        </fieldset>
    <%end%>
    </form>
</div>

<%= ui_helper.createFooter() %>
<%if content and content["mmpbx_enabled"] == "0" then %>
  <style>
    .disabled{
       cursor:not-allowed !important;
       color:#666;
    }
  </style>
  <script>
    $(".nav li a").addClass("disabled");
  </script>
<%else%>
  <script>
    if($(".nav li a").hasClass("disabled")){
      $(".nav li a").removeClass("disabled");
    }
  </script>
<%end%>
