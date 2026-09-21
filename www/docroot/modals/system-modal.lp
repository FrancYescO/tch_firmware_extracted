<%
--[[
Version 1.0 Relf modifications included

  - Debug System page first feature BOOTP button
  - Add System log configuration

]]
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub,untaint = string.format, string.find, string.sub, string.untaint
local floor, ipairs = math.floor, ipairs
local env = {
      factory                = "uci.env.rip.factory_id",
      serial                 = "uci.env.rip.serial",
      
}
content_helper.getExactContent(env)
local serial_num = format("%s%s",env.factory,env.serial)





syslog_present, syslog_filter_sw = "0", "0"

local Syslog_IGD = proxy.get("InternetGatewayDevice.X_000E50_Syslog.LogIP","InternetGatewayDevice.X_000E50_Syslog.LogFilterIP")

if Syslog_IGD[1].value ~= "" or Syslog_IGD[2].value ~= "" then 
   syslog_present = "1"
   if Syslog_IGD[2].value ~= "" then
      syslog_filter_sw = "1"
   end
end


if ngx.var.request_method == "POST" then
    local vars = ngx.req.get_post_args()
    if vars["action"] == "SAVE" then
      syslog_present = vars["syslog_present"]
      syslog_filter_sw = vars["syslog_filter_sw"]
      --if syslog_filter_sw == "0" then 
      --   proxy.set("InternetGatewayDevice.X_000E50_Syslog.LogFilter","daemon.notice")
      --end
      proxy.set("InternetGatewayDevice.X_000E50_Syslog.LogIP","")
      proxy.set("InternetGatewayDevice.X_000E50_Syslog.LogFilterIP","")
      proxy.apply()  
    end
end
local syslog_Params = {
      syslog_ip                 = "InternetGatewayDevice.X_000E50_Syslog.LogIP",
      syslog_port               = "InternetGatewayDevice.X_000E50_Syslog.LogPort",
      --syslog_prefix             = "InternetGatewayDevice.X_000E50_Syslog.LogPrefix",
      --syslog_size               = "InternetGatewayDevice.X_000E50_Syslog.LogSize",
      syslog_filter_ip          = "InternetGatewayDevice.X_000E50_Syslog.LogFilterIP",
      syslog_filter             = "InternetGatewayDevice.X_000E50_Syslog.LogFilter",  
}

local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vB = post_helper.validateBoolean
local vSIPR = post_helper.validateStringIsPortRange
local gOV = post_helper.getOptionalValidation
local gVNR = post_helper.getValidateNumberInRange
local vNES = post_helper.validateNonEmptyString
local gVBS = valid_basic_string

local function valid_basic_string(value)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if string.match(value, "[^%w _%-]") then
    return nil, T"Only alphanumeric, space, underscore and dash characters allowed"
  end
  return true
end

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
      syslog_present            = vB,
      syslog_filter_sw          = vB,
      syslog_ip                 = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"0"}), "syslog_present", {"1"}),
      syslog_filter_ip          = gVIPIL(gVIPIL(gOV(vSII), "syslog_filter_sw", {"1"}), "syslog_present", {"1"}),
      syslog_port               = gVIPIL(vSIPR, "syslog_present", {"1"}),
      --syslog_prefix             = gVIPIL(gOV(valid_basic_string), "syslog_present", {"1"}),
      --syslog_size               = gVIPIL(gVNR(16,100), "syslog_present", {"1"}), 
      syslog_filter             = gVIPIL(gVIPIL(valid_comma_string, "syslog_filter_sw", {"1"}), "syslog_present", {"1"}),     
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
  -- now process non-file POSTs
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
          local Sysloginputip_no_fltr = {
                group = {
                    class ="monitor-syslog_filter_sw monitor-0",
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
          
          local SyslogReadonly = {
          group = {
                    class ="monitor-syslog_present monitor-1",
                },
                input = {
                maxlength= "12",
                class = "span2",
                readonly="true",
              },
             
          }
          html[#html+1] = [[<div class="monitor-syslog_filter_sw monitor-0 monitor-hide-syslog_filter_sw">]]
          html[#html+1] = ui_helper.createInputText(T"IP",               "syslog_ip",              syslog_Params["syslog_ip"],        Sysloginput,             helpmsg["syslog_ip"])
          html[#html+1] = [[</div>]]
          html[#html+1] = ui_helper.createInputText(T"Filter IP",        "syslog_filter_ip",       syslog_Params["syslog_filter_ip"], Sysloginputip_fltr,      helpmsg["syslog_filter_ip"])
          html[#html+1] = ui_helper.createSwitch(T"Enable Filter",       "syslog_filter_sw",       syslog_filter_sw,                  switch_class_filter)
          html[#html+1] = ui_helper.createInputText(T"Filter",           "syslog_filter",          syslog_Params["syslog_filter"],    Sysloginputip_fltr_fltr, helpmsg["syslog_filter"])
          local filter_warning = {
              alert = {
                  class = "alert-info monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1"
              },
          }
          html[#html + 1] = ui_helper.createAlertBlock(T"Filter is a comma seperated string", filter_warning)
          html[#html+1] = ui_helper.createInputText(T"Port",             "syslog_port",            syslog_Params["syslog_port"],      Sysloginput,        helpmsg["syslog_port"])
          
          --html[#html+1] = [[<div class="control-group monitor-syslog_present monitor-1 monitor-show-syslog_present" style=""><label class="control-label">]]
          --html[#html+1] = T"Log Prefix"
          --html[#html+1] = [[</label>]]
          --html[#html+1] = [[<div class="controls"><input type="text" name="syslog_prefix" value="]]
          --html[#html+1] = syslog_Params["syslog_prefix"]
          --html[#html+1] = [["" class="edit-input  span2" maxlength="15"><div id="btn-serial" class="btn custom-handler">]]
          --html[#html+1] = T"Serial"
          --html[#html+1] = [[</div></div></div>]]
      
          --html[#html+1] = ui_helper.createInputText(T"Log Size (KB)",    "syslog_size",             syslog_Params["syslog_size"],     SyslogReadonly,     helpmsg["syslog_size"] )
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
         Popup("<%=T"Entering BOOTP Mode, please wait..."%>");
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
      }else{
            $("[name=syslog_filter_ip]").val($("[name=syslog_ip]").val());
            $("[name=syslog_ip]").val("");
            $("[name=syslog_filter]").val("daemon");
      }
      
      
  });

}());
</script>
<% ngx.print(ui_helper.createFooter()) %>
