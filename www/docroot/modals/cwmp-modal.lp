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
}

local mapvalid = {
      cwmp_url                    = post_helper.validateNonEmptyString,
      cwmp_state                  = post_helper.validateBoolean,
      cwmp_periodic               = post_helper.getValidateNumberInRange(60, 300000),
      connectionrequest_auth      = post_helper.validateNonEmptyString(),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)

local CWMP_en = format("%s", content.cwmp_state) -- untaint 
local CWMP_State = "Disabled"
if CWMP_en == "1" then
   CWMP_State = "Enabled"
end

local state_map = {
    Disabled = T"Disabled",
    Enabled = T"Enabled",
}

local light_map = {
  Disabled = "off",
  Enabled = "green",
}

local conreqauth_select = {
      { "0", T'None'},
      { "1", T'Basic'},
      { "2", T'Digest'},
}

%>

<%= ui_helper.createHeader(T"CWMP Settings", false, true) %>
<div class="modal-body update">
    <form class="form-horizontal" method="post" action="modals/cwmp-modal.lp">
        <fieldset>
            
            
            <%
            
            local numbersOnly = {
                input = {
                    class = "numbersOnly"
                }  
            }
            
            
            ngx.print(ui_helper.createMessages(message_helper.popMessages()))
            
                local html = {}
                html[#html + 1] = ui_helper.createLight(T"Status", nil, state_map[CWMP_State], { light = { class = light_map[CWMP_State] } })
                html[#html + 1] = ui_helper.createSwitch(T"Enabled", "cwmp_state", content["cwmp_state"])
                html[#html + 1] = ui_helper.createInputText(T"ACS URL", "cwmp_url", content["cwmp_url"],{},helpmsg["cwmp_url"])
                html[#html + 1] = ui_helper.createInputText(T"Periodic Interval", "cwmp_periodic", content["cwmp_periodic"],{},helpmsg["cwmp_periodic"])
                html[#html + 1] = ui_helper.createInputSelect(T"Connection Request Auth", "connectionrequest_auth", conreqauth_select, content["connectionrequest_auth"], stdattributes)
                ngx.print(html)
            %>
        </fieldset>
    </form>
</div>

<script type='text/javascript'>
//Force numbers only to inputs
$(function() {
  $('.numbersOnly').keyup(function () { 
      this.value = this.value.replace(/[^0-9\.]/g,'');

      if (this.value.length > 5){
      	this.value = this.value.substring(0,this.value.length-1);
      }
  });
  
  $('form').bind("keypress", function(e) {
    if (e.keyCode == 13) {               
      e.preventDefault();
      return false;
    }
  });
});
</script>
<%= ui_helper.createFooter() %>
