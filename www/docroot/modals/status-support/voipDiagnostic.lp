--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local io, ngx, next = io, ngx, next
local untaint = string.untaint
local valEnumSel = post_helper.getValidateInEnumSelect
local ui_helper = require("vdf_ui_helper")
local actionStates = {
  {"request"},
  {"idle"}
}
local logLevelStates = {
  {"low", T"Low"},
  {"high", T"High"}
}
local isDownloaded

--For getting and setting the value for param action
local voipDiagParams = {
  action_State = "rpc.mmpbx.voipdiagnostics.action",
  logLevel_State = "rpc.mmpbx.voipdiagnostics.log_level",
  file_name = "rpc.mmpbx.voipdiagnostics.filename",
  file_path = "rpc.mmpbx.voipdiagnostics.path"
}
local voipDiagvalidation = {
  action_State = valEnumSel(actionStates),
  logLevel_State = valEnumSel(logLevelStates)
}
local voipDiagnostic, errMsg = post_helper.handleQuery(voipDiagParams, voipDiagvalidation)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().diagonisticStatus == "completed" then
  isDownloaded = true
  ngx.header.content_disposition = "attachment; filename=voip_diagnostics.txt"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JQuery download code requires this cookie

  local fileName = "/tmp/voip_diagnostics.txt"
  if (voipDiagnostic["file_path"] ~= '') and (voipDiagnostic["file_name"] ~= '') then
      fileName = untaint(voipDiagnostic["file_path"]) .. "/" .. untaint(voipDiagnostic["file_name"])
  elseif (voipDiagnostic["file_path"] == '') and (voipDiagnostic["file_name"] ~= '') then
      fileName = "/tmp/" .. untaint(voipDiagnostic["file_name"])
  elseif (voipDiagnostic["file_path"]~= '') and (voipDiagnostic["file_name"] == '') then
      fileName = untaint(voipDiagnostic["file_path"]) .. "/voip_diagnostics.txt"
  end

  local file = io.open(fileName)
  if file then
    ngx.print(file:read("*all"))
    local logdata = proxy.get("sys.log.")
    local pattern = "([%S]+%s+%d+) (%d+:%d+:%d+) (%d+) ([%S]+) ([%S]+): ([^\n]+)"
    for i, v in ipairs(logdata) do
      local logdata_line = v.value or ""
      logdata_line:gsub(pattern, function(date, time, year, type, category, message)
        if category:match("mmpbx") or message:match("mmpbx") then
          ngx.print("\n")
          ngx.print(message)
        end
      end)
    end
    file:close()
  else
    ngx.print(T"Error - Diagnostics data is currently not available")
  end
end

if (ngx.req.get_method() == "POST") then
  if isDownloaded then
    ngx.exit(ngx.OK)
  elseif not next(errMsg) then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  elseif next(errMsg) then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
elseif ngx.req.get_uri_args().action == "getDiagTestStatus" then
  ngx.header.content_type = "application/json"
  if not next(errMsg) and voipDiagnostic["action_State"] ~= "" and voipDiagnostic["logLevel_State"] ~= "" then
    ngx.print('{"status":"'..untaint(voipDiagnostic["action_State"])..'"}')
  else
    ngx.print('{"status":"failed"}')
  end
  ngx.exit(ngx.OK)
end
  ngx.print('\
\
<h1><span>');  ngx.print(T"VOIP Diagnostics"); ngx.print('</span></h1>\
<h2>&nbsp;</h2>\
');  
  local row = {
    {
      label =  T"Select Log Level",
      element = ui_helper.createDropDown({
        id="voipDiagnostic-sel-logLevel",
        class="dropdown",
        style="width: 165px;"
        }, logLevelStates, voipDiagnostic.logLevel_State),
      rowClass = "vdf-row no-border-bottom",
      colRightClass = "rel right",
      colRightId = "top-info-mode"
    },
    {
      label = "",
      element = ui_helper.createClickButton({
        id="voipDiagnostic-btn-diagnose",
        class="button button-cancel mob-button-width",
        value=T"Diagnose",
        type="button"
        })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table h3-content-mobile no-border"))

  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<div class="modal fade" id="voipDiagnostic-modal-inprogress" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <button type="button" class="close" data-dismiss="modal">&times;</button>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12 col-md-12 col-lg-12">\
              <p class="padding-top-bottom-20"><img src="/img/look_4/icons/icon-thinking.gif" alt="');  ngx.print(T"Downloading..."); ngx.print('" /></p>\
              <p class="title">');  ngx.print(T"Diagnosis in Progress"); ngx.print('</p>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<div class="modal fade" id="voipDiagnostic-modal-diagnosisSuccess" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-lg">\
        <button type="button" class="close" data-dismiss="modal">&times;</button>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title">');  ngx.print(T"Diagnosis Completed"); ngx.print('</p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="padding-bottom-20"><span>');  ngx.print(T"Diagnosis was successful. Click the Download button to see the details.."); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12 text-right">\
            <input id="voipDiagnostic-btn-download" class="button button-cancel mob-button-width"\
              value="');  ngx.print(T"Download"); ngx.print('" type="button" style="width: auto" />\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="voipDiagnostic-btn-ok" value=');  ngx.print(T"OK"); ngx.print(' class="button button-apply mob-button-width" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<div class="modal fade" id="voipDiagnostic-modal-diagnosisFailed" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-lg">\
        <button type="button" class="close" data-dismiss="modal">&times;</button>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title">');  ngx.print(T"Error"); ngx.print('</p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="padding-bottom-20"><span>');  ngx.print(T"Diagnosis failed. Please try again."); ngx.print('</span></p>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="voipDiagnostic-btn-failedOk" value=');  ngx.print(T"OK"); ngx.print(' class="button button-apply mob-button-width" type="button" />\
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
var target = "modals/status-support/voipDiagnostic.lp";\
$(function()\
{\
  $("#voipDiagnostic-btn-diagnose").click(function(){\
    $.post(target, { "CSRFtoken" : $("meta[name=CSRFtoken]").attr("content"), "action" : "SAVE", "action_State" : "request"}, function(responseTxt) {\
      var waitCount = 1;\
      $("#voipDiagnostic-modal-inprogress").modal();\
      var requestinterval = setInterval(function(){\
        $.get(target+"?action=getDiagTestStatus",function(responseTxt, statusTxt, xhr){\
          if (responseTxt.status == "completed"){\
            $(\'#voipDiagnostic-modal-inprogress\').modal(\'hide\');\
            $("#voipDiagnostic-modal-diagnosisSuccess").modal(\'show\');\
            clearInterval(requestinterval);\
          }\
          else if (responseTxt.status == "failed" || responseTxt.status == "undefined" || waitCount > 8){\
            $.post(target, { "CSRFtoken" : $("meta[name=CSRFtoken]").attr("content"), "action" : "SAVE", "action_State" : "idle"}, function(responseTxt) {\
              showFailedPopup();\
              clearInterval(requestinterval);\
            });\
          }\
        });\
        waitCount++;\
      },2000);\
    });\
  });\
\
  $("#voipDiagnostic-btn-download").click(function(){\
    var params = new Array(\
      { name : "action", value : "SAVE" },\
      { name : "diagonisticStatus", value : "completed" },\
      { name : "action_State", value : "idle" },\
      { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") });\
    downloadFile(target, params);\
    $("#voipDiagnostic-modal-diagnosisSuccess").modal(\'hide\');\
  });\
\
  // To set the value of log level on clicking Apply button\
  $("#global-apply, #modal-apply").click(function() {\
    var params = [];\
    params.push({\
      name  : "CSRFtoken",\
      value : $("meta[name=CSRFtoken]").attr("content")\
    },{\
      name  : "action",\
      value : "SAVE"\
    },{\
      name  : "action_State",\
      value : "idle"\
    },{\
      name  : "logLevel_State",\
      value : $("#voipDiagnostic-sel-logLevel").val().toLowerCase()\
    });\
    postHandler(target, params);\
  });\
\
  $("#voipDiagnostic-btn-ok").click(function(){\
    $.post(target, { "CSRFtoken" : $("meta[name=CSRFtoken]").attr("content"), "action" : "SAVE", "action_State" : "idle"}, function(responseTxt) {\
      $("#voipDiagnostic-modal-diagnosisFailed, #voipDiagnostic-modal-diagnosisSuccess").modal(\'hide\');\
    });\
  });\
\
  $("#voipDiagnostic-btn-failedOk").click(function(){\
    $("#voipDiagnostic-modal-diagnosisFailed, #voipDiagnostic-modal-diagnosisSuccess").modal(\'hide\');\
  });\
});\
\
function showFailedPopup() {\
  $(\'#voipDiagnostic-modal-inprogress\').modal(\'hide\');\
  $("#voipDiagnostic-modal-diagnosisFailed").modal(\'show\');\
}\
</script>\
'); 