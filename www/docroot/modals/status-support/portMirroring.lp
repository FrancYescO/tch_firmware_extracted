--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local content_helper = require("web.content_helper")
local string = string
local cmd,srcIntf
local ui_helper = require("vdf_ui_helper")
local mirrorData = {
  mirrorState = "uci.portmirror.portmirror.@dev1.start",
  srcInterface = "uci.portmirror.portmirror.@dev1.srcintf"
}
content_helper.getExactContent(mirrorData)

-- Validates empty input, command, Interface Name and State
-- @function validateCommand
-- @param errMsg
-- #boolean  - returns true if valid, errMsg if validation fails
local function validateCommand(command)
  if command ~= "" then
    cmd,srcIntf = string.match(command,"(.+)%s(.+)")
    if cmd == "-i" then
      local supportedInterfaces = proxy.getPN("uci.xtm.atmdevice.", true)
      local ptmDevices = proxy.getPN("uci.xtm.ptmdevice.", true)
      for increment = 1, #supportedInterfaces do
        supportedInterfaces[#supportedInterfaces+1] = ptmDevices[increment]
      end
      local isSupportedInterface
      for _, v in pairs(supportedInterfaces) do
        if (srcIntf == string.match(v.path, "uci.xtm.atmdevice.@(.+)%.")) or (srcIntf == string.match(v.path, "uci.xtm.ptmdevice.@(.+)%.")) then
          isSupportedInterface = true
          break
        end
      end
      -- The destination interface name is always "eth0"
      -- As Source Interface name cannot be same as the destination Interface name, the check for eth0 has been added below
      if isSupportedInterface and srcIntf ~= "eth0" then
        return true, ""
      else
        return false, T"Invalid Interface Name."
      end
    else
      return false, T"Invalid Command."
    end
  else
    return false, T"Command cannot be empty."
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "start" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  local isValidCommand, errMsg = validateCommand(postArgs.srcIntf)
  if isValidCommand then
    local start = {
      ["uci.portmirror.portmirror.@dev1.direction"] = "any",
      ["uci.portmirror.portmirror.@dev1.dstintf"] = "eth0",
      ["uci.portmirror.portmirror.@dev1.srcintf"] = srcIntf,
      ["uci.portmirror.portmirror.@dev1.start"] = "1"
    }
    if proxy.set(start) then
      proxy.apply()
      ngx.print('{"status":"true"}')
    else
      ngx.print('{"status":"false"}')
    end
  else
    ngx.print('{"status":"false", "error":"1", "errorMsg":"' ..errMsg.. '"}')
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "stop" then
  ngx.header.content_type = "application/json"
  local stop = {
    ["uci.portmirror.portmirror.@dev1.dstintf"] = "",
    ["uci.portmirror.portmirror.@dev1.start"] = "0",
  }
  if proxy.set(stop) then
    proxy.apply()
    ngx.print('{"status":"true"}')
  else
    ngx.print('{"status":"false"}')
  end
  ngx.exit(ngx.HTTP_OK)
end

  ngx.print('\
 <h1>');  ngx.print(T"Port Mirroring"); ngx.print('</h1>\
 <h2>');  ngx.print(T"With port mirroring you can dump all packets of selected interface to LAN1 (Ex: -i atm_wan)"); ngx.print('</h2>\
<h3>');  ngx.print(T"Port Mirroring"); ngx.print('</h3>\
<div class="h3-content h3-content-mobile">\
  ');  
    local row = {
      label = T"Command",
      element = ui_helper.createTextField({
        type="text",
        id="portMirror-txt-srcIntf",
        value = mirrorData.srcInterface ~= "" and "-i "..mirrorData.srcInterface or nil,
        disabled= mirrorData.mirrorState == "1" and "disabled" or nil
      }),
      rowClass = "row padding-top-bottom-20",
      colLeftClass = "col-md-6 col-sm-6 col-xs-12",
      labelClass = "font-bold mobile-padding-bottom-10",
      colRightClass = "col-xs-12 no-padding-left-right pull-right text-right"
    }
    ngx.print(ui_helper.createRow(row))

    row = {
      label = ui_helper.createClickButton({
        id="portMirror-btn-start",
        class="button button-cancel mob-button-width mob-apply-cancel",
        value= mirrorData.mirrorState == "1" and T"Stop" or T"Start",
        type="button"
        }),
      rowClass = "row no-margin-right padding-top-bottom-20",
      colClass = "col-md-12 col-sm-12 col-xs-12 no-padding-right text-right"
    }
    ngx.print(ui_helper.createSingleRow(row))
    ngx.print('\
  <div class="form-group">\
    <div class="col-sm-12 no-padding-left-right">\
      <div class="table-wrapper">\
        <div class="message message-info message-error no-padding-right hide"  id = "portMirror-msg-errCommandSyntax">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!-- Modal -->\
<div class="modal fade" id="portMirror-popup-warning" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
       <div class="modal-header hidden-md hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
       </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="padding-bottom-20 title">');  ngx.print(T"Warning"); ngx.print('</p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="padding-bottom-20"><span>');  ngx.print(T"Please don't forget to stop the capture."); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="portMirror-btn-ok" value=');  ngx.print(T"OK"); ngx.print(' class="button button-apply mob-button-width" type="button">\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<script src="/js/global-min.js" ></script>\
<script>\
\
var element = {\
  command: "#portMirror-txt-srcIntf"\
}\
var validation = {\
  command: /^\\-i .+$/\
}\
\
$(function()\
{\
  $("#portMirror-btn-start").click(function() {\
    if (!validateElements(element, validation)) return false;\
    if($(this).val() == "');  ngx.print(T"Start"); ngx.print('")\
    {\
      var postParams = [];\
      postParams.push( {\
        name : "CSRFtoken",\
        value : "');  ngx.print(CSRFtoken); ngx.print('"\
        }, {\
        name : "srcIntf",\
        value : $("#portMirror-txt-srcIntf").val()\
        }, {\
        name : "action",\
        value : "start"\
      });\
      $.post("/modals/status-support/portMirroring.lp", postParams, function(responseText, status, xhr){\
        if(responseText.status == "true") {\
          $(\'#portMirror-msg-errCommandSyntax\').addClass("hide").removeClass("show");\
          $(\'#portMirror-popup-warning\').modal();\
        } else {\
            if(responseText.error == "1") {\
              $(\'#portMirror-msg-errCommandSyntax\').addClass("show").removeClass("hide").text(responseText.errorMsg);\
            }\
          }\
      });\
    }\
    else {\
      var postParams = [];\
      postParams.push( {\
        name : "CSRFtoken",\
        value : "');  ngx.print(CSRFtoken); ngx.print('"\
        }, {\
        name : "action",\
        value : "stop"\
      });\
      $.post("/modals/status-support/portMirroring.lp", postParams, function(responseText, status, xhr){\
      $("#portMirror-btn-start").val("');  ngx.print(T'Start'); ngx.print('")\
      $("#content").load("/modals/status-support/portMirroring.lp");\
    });\
  }\
});\
\
$("#portMirror-btn-ok").click(function(){\
  $(\'#portMirror-popup-warning \').modal(\'hide\');\
  $("#portMirror-btn-start").val("');  ngx.print(T'Stop'); ngx.print('");\
  $("#portMirror-txt-srcIntf").prop("disabled",true);\
});\
});\
</script>\
'); 