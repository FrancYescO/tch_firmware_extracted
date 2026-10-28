<%
-- Enable localization
gettext.textdomain('webui-core')

local ngx, string = ngx, string
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format = string.format

local env = {
  factory = "uci.env.rip.factory_id",
  serial = "uci.env.rip.serial",
}
content_helper.getExactContent(env)

local serial_num = format("%s%s",env.factory,env.serial)
local syslog_present, syslog_filter_sw = "0", "0"

local Syslog = proxy.get("uci.system.system.@system[0].ip","uci.system.system.@system[0].filter_ip")
if Syslog[1].value ~= "" or Syslog[2].value ~= "" then
  syslog_present = "1"
  if Syslog[2].value ~= "" then
    syslog_filter_sw = "1"
  end
end

if ngx.var.request_method == "POST" then
  local vars = ngx.req.get_post_args()
  if vars["action"] == "SAVE" then
    syslog_present = vars["syslog_present"]
    syslog_filter_sw = vars["syslog_filter_sw"]
    proxy.set("uci.system.system.@system[0].ip","")
    proxy.set("uci.system.system.@system[0].filter_ip","")
    proxy.apply()
  end
end

local syslog_Params = {
  syslog_filter = "uci.system.system.@system[0].filter",
  syslog_filter_ip = "uci.system.system.@system[0].filter_ip",
  syslog_port = "uci.system.system.@system[0].port",
  syslog_ip = "uci.system.system.@system[0].ip",
}

local gVIPIL = post_helper.getValidationIfPropInList
local vSII = post_helper.validateStringIsIP
local vB = post_helper.validateBoolean
local vSIPR = post_helper.validateStringIsPortRange
local gOV = post_helper.getOptionalValidation
local vNES = post_helper.validateNonEmptyString

local function valid_comma_string(value)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if string.match(value, "[^%w,]") then
    return nil, T"Only alphanumeric characters, commas (,), full spots(.), underscores(_) and hiphens(-) are allowed, no spaces"
  end
    return true
end

local syslog_valid = {
  syslog_present = vB,
  syslog_filter_sw = vB,
  syslog_ip = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"0"}), "syslog_present", {"1"}),
  syslog_filter_ip = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"1"}), "syslog_present", {"1"}),
  syslog_port = gVIPIL(vSIPR, "syslog_present", {"1"}),
  syslog_filter = gVIPIL(gVIPIL(valid_comma_string, "syslog_filter_sw", {"1"}), "syslog_present", {"1"}),
}
local syslog_Params, helpmsg = post_helper.handleQuery(syslog_Params, syslog_valid)

local function resetreboot(path)
  proxy.set(path, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  if action == "system_bootp" then
    return resetreboot("sys.bootp.enable")
  end
end

local title = T"System Extras"
%>
<% ngx.print(ui_helper.createHeader(title, false, false)) %>
<div class="modal-body update">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<form class="form-horizontal" method="post" action="modals/system-modal.lp">
<fieldset>
  <legend><%= T"Global" %></legend>
    <%
      local bootp_alert = {
        alert = {
          class = "alert-info hide",
          id = "bootp-msg"
        }
      }
      local bootp = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-bootp",
          class = "custom-handler"
        }
      }
      local html = {}
      html[#html + 1] = ui_helper.createButton(T"LAN Upgrade", T"BOOTP", "icon-exchange", bootp)
      html[#html + 1] = ui_helper.createAlertBlock(T"Entering BOOTP, please wait...", bootp_alert)
      ngx.print(html)
    %>
</fieldset>
<fieldset>
  <legend><%= T"System Log" %></legend>
    <%
      local html = {}
      local switch_class_enable = {
        input = {
          class = "monitor-changes",
        }
      }
      html[#html + 1] = ui_helper.createSwitch(T"Enable Syslog", "syslog_present", syslog_present, switch_class_enable)
      local switch_class_filter = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          class = "monitor-changes",
        }
      }
      local Sysloginput = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "50",
          class = "span5",
         },
      }
      html[#html+1] = [[<div class="monitor-syslog_filter_sw monitor-0 monitor-hide-syslog_filter_sw">]]
      html[#html+1] = ui_helper.createInputText(T"IP", "syslog_ip", syslog_Params["syslog_ip"], Sysloginput, helpmsg["syslog_ip"])
      html[#html+1] = [[</div>]]
      html[#html+1] = ui_helper.createInputText(T"Filter IP", "syslog_filter_ip", syslog_Params["syslog_filter_ip"], Sysloginputip_fltr, helpmsg["syslog_filter_ip"])
      html[#html+1] = ui_helper.createSwitch(T"Enable Filter", "syslog_filter_sw", syslog_filter_sw, switch_class_filter)
      html[#html+1] = ui_helper.createInputText(T"Filter", "syslog_filter", syslog_Params["syslog_filter"], Sysloginputip_fltr_fltr, helpmsg["syslog_filter"])
      local filter_warning = {
        alert = {
          class = "alert-info monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Filter is a comma seperated string", filter_warning)
      html[#html+1] = ui_helper.createInputText(T"Port", "syslog_port", syslog_Params["syslog_port"], Sysloginput, helpmsg["syslog_port"])
      ngx.print(html)
    %>
</fieldset></form>
</div>
<script>
(function() {
  var refreshTimeOut = 5000;
  var refreshDelay = 3000;
  var target = $(".modal form").attr("action");

  function wait_for_webserver_running() {
    $.ajax({ url: "/", timeout: refreshTimeOut, data: { check: "1"} })
    .done(function(data) {
      document.open("text/html");
      document.write(data);
      document.close();
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function wait_for_webserver_down() {
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"}  })
    .done(function() {
      window.setTimeout(wait_for_webserver_down, refreshDelay);
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function resetreboot(msg, msg_dst, action) {
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    $.post(
      target,
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down,
      "json"
    );
    return false;
  }

  $("#btn-system-bootp").click(function() {
     if (confirm("<%=T"This will put your gateway into LAN Upgrade"%>")){
       tch.showProgress('<%=T"Rebooting..."%>');
       return resetreboot($("#bootp-msg"), $(this), "system_bootp");
     }
  });

  $("[name=syslog_present]").change(function(){
    $("[name=syslog_ip]").val("");
    $("[name=syslog_filter_ip]").val("");
  });

  $("#btn-serial").click(function(){
    $("[name=syslog_prefix]").val("<%=serial_num%>");
    $("#modal-no-change").slideUp();
    $("#modal-changes").slideDown();
  });

  $("[name=syslog_filter_sw]").change(function(){
     if ($( this ).val() == "0"){
       $("[name=syslog_ip]").val($("[name=syslog_filter_ip]").val());
       $("[name=syslog_filter_ip]").val("");
       $("[name=syslog_filter]").val("daemon");
     }
     else{
       $("[name=syslog_filter_ip]").val($("[name=syslog_ip]").val());
       $("[name=syslog_ip]").val("");
       $("[name=syslog_filter]").val("daemon");
     }
  });
}());
</script>
<% ngx.print(ui_helper.createFooter()) %>
