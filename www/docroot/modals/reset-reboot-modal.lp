--pretranslated: do not change this file

--[[
Version 1.1 Relf modifications included

  -Debug System page fst feature BOOPT button
  -17.2 changes
  	ngx.print



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
local session = ngx.ctx.session

local function resetreboot(path,value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
local URL = session:retrieve("URL")
session:store("URL",nil)
session:store("modal2load",nil)
if not URL then 
   URL = "/"
else 
   URL = format("http://%s",URL)
end



if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  end
  if action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
end


local title = T"System Extras"

ngx.print(ui_helper.createHeader(title, false, false), '\
<div class="modal-body update">',
ui_helper.createMessages(message_helper.popMessages()), '\
<fieldset>\
  <legend>', T"Quick Links", '</legend>\
    <form class="form-horizontal" method="post" action="modals/reset-reboot-modal.lp">');
      local wait_for_reboot = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-reboot",
          class = "custom-handler"
        }
      }

      local wait_for_reset = {
        group = {
          class = "wait-for-reset"
        },
        button = {
          id = "btn-system-reset",
          class = "custom-handler"
        }
      }

      
      
      local html = {}
      local reboot_warning = {
              alert = {
                  class = "alert-warning"
              },
          }
          
        
      
      html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
      html[#html + 1] = ui_helper.createAlertBlock(format("%s<br><br>%s",T"Restart or Reboot, this is the same as turning the power off and on again.", T"The purpose of this is to reinitialise the system and clear any errors on the device or the Network."), reboot_warning)
      
      
      html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)   
      html[#html + 1] = ui_helper.createAlertBlock(format("%s",T"Factory Defaults, or Reset will clear all the changes you have made to the device and restore the out of the box configuration."), reboot_warning)
        
      ngx.print(html, '\
    </form>\
  </fieldset>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 10000;\
  var target = $(".modal form").attr("action");\
\
  function wait_for_webserver_running() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"} })\
    .done(function(data) {       \
      window.location.href = "', URL, '";\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"}  })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function resetreboot(msg, msg_dst, action) {\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
  $("#btn-system-reboot").click(function() {\
     var heading = "', T'Restart Device', '";\
     var processMsg = "', T'Rebooting', '";\
     confirmationDialogue(\'', T"Do you want to continue?", '\',heading);\
     $(document).on("click", ".Restart", function() {\
          tch.removeProgress();\
          tch.showProgress(processMsg);\
          return resetreboot($("#rebooting-msg"), $(this), "system_reboot" );\
     });\
  });
\
  $("#btn-system-reset").click(function() {
      var heading = "', T'Factory Defaults', '";\
      var processMsg = "', T'Resetting', '";\
      confirmationDialogue(\'', T"Do you want to continue? ", '\',heading);\
      $(document).on("click", ".Factory", function() {\
          tch.removeProgress();\
          tch.showProgress(processMsg);\
          return resetreboot($("#resetting-msg"), $(this), "system_reset");\
      });\
  });\
\
\
  $(document).on("click", "#cancel", function() {\
      tch.removeProgress();\
  });\
\
\
}());\
</script>',
ui_helper.createFooter());
