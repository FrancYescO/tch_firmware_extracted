--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local ui_helper = require("vdf_ui_helper")
local bridged = require("bridgedmode_helper")
local content_helper = require("web.content_helper")
local valNumLen = post_helper.getValidateNumberInRange
local format, pairs = string.format, pairs
local proxy = require("datamodel")

local mapParams = {
  vdsl_vid = "uci.network.device.@vlanptm0.vid",
  eth_vid = "uci.network.device.@vlanwan.vid"
}

local mapValids = {
  vdsl_vid = valNumLen(0, 65535),
  eth_vid = valNumLen(0, 65535)
}
local getContent, errmsg = post_helper.handleQuery(mapParams, mapValids)

local ifname = {
  vdslIfname = "uci.network.interface.@vdsl.ifname",
  ethIfname = "uci.network.interface.@ewan.ifname",
  wanIfname = "uci.network.interface.@wan.ifname"
}
content_helper.getExactContent(ifname)

if ngx.var.request_method == "POST" then
  local setTable = {}
  local success = false
  local postargs = ngx.req.get_post_args()
  if ngx.req.get_post_args().action == "SAVE" then
    bridged.configBridgedMode(postargs.vdsl_vid, postargs.eth_vid)
    setTable["uci.wireless.wifi-ap.@ap0.state"] = '0'
    setTable["uci.wireless.wifi-ap.@ap1.state"] = '0'
    setTable["uci.network.interface.@lan.ipaddr"] = ''
    setTable["uci.network.interface.@lan.netmask"] = ''
    setTable["uci.network.interface.@lan.ifname"] = ''
    setTable["uci.network.interface.@lan.auto"] = '0'
    setTable["rpc.system.reboot"] = "GUI"
    success = proxy.set(setTable)
  end
  ngx.timer.at(0, function()
    if success then
      proxy.apply()
    end
  end)
  if success and not next(errmsg) then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end  ngx.print('\
  <html>\
    <head>\
      <script src="/js/main-min.js"></script>\
    </head>\
    <body>\
      <div class="row">\
        <div class="modal install-update-popup-5" id="install-update-popup-5" role="dialog" data-backdrop = "static">\
          <div class="modal-dialog" style="margin-top: 18%;">\
            <div class="modal-content">\
              <div class="modal-body">\
                <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
                <p class="modal-title tL">\
                  <span>');  ngx.print(T"Entering into Bridge Mode"); ngx.print('\
                  </span>\
                </p>\
                <p class="big">\
                  <span>');  ngx.print(T"Please do not switch off your gateway."); ngx.print('</span>\
                </p>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </body>\
    <script>\
      $(\'#install-update-popup-5\').modal();\
      window.setTimeout(function() { window.location = "/"; }, 100000);\
    </script>\
  </html>\
');  end  ngx.print('\
<form id="bridgeModeForm" class="form-horizontal">\
  <h1><span>');  ngx.print(T"Bridge Mode"); ngx.print('</span></h1>\
  ');  local row = {
    {
    label = T"Bridge Mode",
    element = ui_helper.createButton({
      id = "bridge-mode-enable-button",
      class = "pull-right button button-off" or "pull-right button button-on"
    })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))  ngx.print('\
  <div id="bridge-mode-configs">\
  <h3><span>');  ngx.print(T"WAN VDSL"); ngx.print('</span></h3>\
  ');  
  local function vdslVlanId()
    if ifname.vdslIfname == "" then
      return ifname.wanIfname == "ptm0" and "0" or getContent.vdsl_vid
    else
      return ifname.vdslIfname == "ptm0" and "0" or getContent.vdsl_vid
    end
  end
  row = {
    {
      label = T"Vlan ID",
      element = ui_helper.createTextField({
        type = "text",
        id = "wan-vdsl-id",
        value = vdslVlanId()
      })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))  ngx.print('\
  <h3><span>');  ngx.print(T"WAN Fiber"); ngx.print('</span></h3>\
  ');  
  local function wanVlanId()
    if ifname.ethIfname == "" then
      return ifname.wanIfname == "eth4" and "0" or getContent.eth_vid
    else
      return ifname.ethIfname == "eth4" and "0" or getContent.eth_vid
    end
  end
  row = {
    {
      label = T"Vlan ID",
      element = ui_helper.createTextField({
        type = "text",
        id = "wan-fiber-id",
        value = wanVlanId()
      })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))  ngx.print('\
</div>\
<div class="modal fade config-modal" id="bridge-mode-enable" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  row = {
              label = format('<p class="title">%s</p>', T"Confirm change to Bridge Mode."),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))
            row = {
              label = ui_helper.createOnlyText({}, T("Enabling Bridge Mode will disable all Router and management functionality. Please ensure all interface setting are correct before clicking Apply. <br><br> After Bridge Mode is enabled, a factory reset via the reset button must be done to return to router mode. (To reset, press and hold the reset button until all lights have turned off, then release button)")),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))
            row = {
              label = format('%s %s', ui_helper.createClickButton({
                value = T"Apply",
                class = "button button-apply mob-button-width",
                id = "bridge-mode-apply",
                type= "button"
                }), ui_helper.createClickButton({
                id = "bridge-mode-cancel",
                class = "button button-cancel mob-button-width mob-apply-cancel",
                value = T"Cancel",
                type= "button",
                ["data-dismiss"] = "modal"
                })
              ),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))  ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
</form>\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<script src="/js/global-min.js"></script>\
<script>\
$(function() {\
  bindChosen();\
  var target = "/modals/settings/bridge.lp";\
  function isBridgeModeEnable() {\
    if ($("#bridge-mode-enable-button").hasClass("button-on")) {\
      $("#bridge-mode-configs").addClass("show").removeClass("hide");\
      $("#global-apply, #global-cancel").removeClass("op40");\
    } else {\
      $("#bridge-mode-configs").removeClass("show").addClass("hide");\
      $("#global-apply, #global-cancel").addClass("op40");\
    }\
  }\
  isBridgeModeEnable();\
  $("#bridge-mode-enable-button").click(function() {\
    btn_on_off($(this));\
    isBridgeModeEnable();\
  });\
  $("#bridge-mode-cancel").click(function() {\
    $("#bridge-mode-enable").modal("hide");\
    $("#bridge-mode").removeClass("button-on").addClass("button-off");\
    sessionStorage.setItem("user_interacted", "pristine");\
  });\
\
  function isNumberKey(e){\
    var charCode = (e.which) ? e.which : e.keyCode\
    if (charCode > 31 && (charCode < 48 || charCode > 57)) return false;\
    return true;\
  }\
\
  $("#wan-vdsl-id, #wan-fiber-id").keypress(function(e){\
    return isNumberKey(e);\
  });\
\
  $("#global-apply").click(function() {\
    var elements = {\
      vdsl_vid: "#wan-vdsl-id",\
      eth_vid: "#wan-fiber-id"\
    }\
    var validations = {\
      vdsl_vid: validateStringLength(1, 32),\
      eth_vid: validateStringLength(1, 32)\
    }\
\
    if (!validateElements(elements, validations)) return false;\
    $("#bridge-mode-enable").modal("show");\
  });\
\
  $("#bridge-mode-apply").click(function() {\
    $("#bridge-mode-enable").modal("hide");\
    var params = {\
      "action": "SAVE",\
      "CSRFtoken": $("meta[name=CSRFtoken]").attr("content"),\
      "vdsl_vid" : $("#wan-vdsl-id").val(),\
      "eth_vid" : $("#wan-fiber-id").val()\
    }\
    $("body").css("cursor", "progress");\
    postHandler(target, params);\
  });\
});\
</script>\
'); 