<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gVSLIR = post_helper.getValidateStringLengthInRange

local mapParams = {
  ssid = "rpc.wireless.ssid.@wl0.ssid"
}

local mapValid = {
  ssid = gVSLIR(1,32),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader("Guided View") %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <div class="span4">
      <%
       local lp = require("web.lp")
       lp.setpath("/www/snippets/")
       lp.include("nav-basicview-actions.lp")
     %>
    </div>
    <div class="span7">
      <fieldset>
        <legend><%= T"Manage my wireless network" %></legend>
        <%
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
          local labelclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            span = {
              class = "span4"
            }
          }
          local html={}
          html[#html + 1] = ui_helper.createAlertBlock(T"Action 2A: Personlize the name of my wireless network (WiFi SSID)", infoclass)
          html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
          html[#html + 1] = ui_helper.createLabel(T"Current wireless network name", content["ssid"], labelclass)
          html[#html + 1] = '<div class="btn btn-primary btn-large" id="advshow">Change wireless network name</div>'
          ngx.print(html)
        %>
        <div id="adv" class="hide">
          <%
          local inputclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            input = {
              pattern= "[!-~][ -~]{0,30}[!-~]",
              maxlength= "32",
              class= "span4",
            }
          }
          html = {}
          html[#html + 1] = ui_helper.createInputText("New wireless network name", "ssid", content["ssid"], inputclass, helpmsg["ssid"])
          ngx.print(html)
          %>
          <div class="pull-left">
            <a href="/" class="btn btn-large"><%= T"Cancel" %></a>
            &nbsp;
            <div id="save-config" class="btn btn-primary btn-large"><%= T"Confirm" %></div>
          </div>
        </div>
    </fieldset>
  </form>
</div>
<script>
    $(document).ready(function() {
        if ($(".alert-error").length > 0) {
            $('#adv').show();
            $('#advshow').hide();
        };

        $('#advshow').click(function(){
            $('#adv').show();
            $('#advshow').hide();
            $(".alert-success").hide();
        });
    });
</script>
