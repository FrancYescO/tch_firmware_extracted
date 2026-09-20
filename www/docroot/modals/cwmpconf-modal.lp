<%
gettext.textdomain('webui-core')

local format = string.format

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")


local mapParams = {
      cwmp_url              = "uci.cwmpd.cwmpd_config.acs_url",
      cwmp_state            = "uci.cwmpd.cwmpd_config.state",
      cwmp_periodic         = "uci.cwmpd.cwmpd_config.periodicinform_interval",
      connectionrequest_auth= "uci.cwmpd.cwmpd_config.connectionrequest_auth",
      ip_preference         = "uci.cwmpd.cwmpd_config.ip_preference",
}

local conreqauth_select = {
      { "0", T'None'},
      { "1", T'Basic'},
      { "2", T'Digest'},
}

local ip_preference_select = {
      { "v4_only", T'IPv4 Only'},
      { "v6_only", T'IPv6 Only'},
      { "prefer_v4", T'Prefer IPv4'},
      { "prefer_v6", T'Prefer IPv6'},
}

local mapvalid = {
      cwmp_url                    = post_helper.getValidateStringLengthInRange(1,255),
      cwmp_state                  = post_helper.validateBoolean,
      cwmp_periodic               = post_helper.getValidateNumberInRange(10, 300000),
      connectionrequest_auth      = post_helper.getValidateInEnumSelect(conreqauth_select),
      ip_preference               = post_helper.getValidateInEnumSelect(ip_preference_select),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)

%>

<%= ui_helper.createHeader(T"CWMP Settings", false, true) %>
<div class="modal-body update">
    <form class="form-horizontal" method="post" action="modals/cwmpconf-modal.lp">
        <fieldset>
            <% local numbersOnly = {
                  input = {
                      pattern = "[0-9]{2,6}",
                      maxlength = "6",
                  }
              }
              ngx.print(
                ui_helper.createMessages(message_helper.popMessages()),
                ui_helper.createSwitch(T"Enabled", "cwmp_state", content["cwmp_state"]),
                ui_helper.createInputText(T"ACS URL", "cwmp_url", content["cwmp_url"],{},helpmsg["cwmp_url"]),
                ui_helper.createInputText(T"Periodic Interval", "cwmp_periodic", content["cwmp_periodic"],numbersOnly,helpmsg["cwmp_periodic"]),
                ui_helper.createInputSelect(T"Connection Request Auth", "connectionrequest_auth", conreqauth_select, content["connectionrequest_auth"]),
                ui_helper.createInputSelect(T"IPv4/IPv6", "ip_preference", ip_preference_select, content["ip_preference"])
              )
            %>
        </fieldset>
    </form>
</div>
<%= ui_helper.createFooter() %>
