<%
-- Enable localization
gettext.textdomain('webui-voice')

local ngx = ngx
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local uimessage_helper = require("web.uimessage_helper")
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

local sipnet_valid = {
    primaryRegistrarPort = post_helper.validateStringIsPort,
    primaryRegistrar = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxy = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxyPort = post_helper.getValidateNumberInRange(0,65535),
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
