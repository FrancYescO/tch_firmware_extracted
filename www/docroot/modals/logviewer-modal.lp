--pretranslated: do not change this file
 
-- Localization
-- NG-105177 [Workaround] TI [GUI] - Some of the tabs throws Internal server error
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local logdownload_helper = require("logdownload_helper")
local logviewer = require 'log.viewer'
local format = string.format
local proxy = require("datamodel")
local role = ngx.ctx.session:getrole()

if ngx.req.get_method() == "POST" then
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_log" then
    return logdownload_helper.export_log("logread")
  end
end

local log_columns = {
  {
    header = T"Date",
    name = "date",
    param = "date",
    type = "text",
    attr = { input = {  class="span1" } },
  },{
      header = T"Facility",
      name = "facility",
      param = "facility",
      type = "text",
      attr = { input = { class="span1" } },
  },{
      header = T"Process",
      name = "process",
      param = "process",
      type = "text",
      attr = { select = { class="span1" } },
  },{
      header = T"Message",
      name = "message",
      param = "message",
      type = "text",
      attr = { select = { class="span6" } },
  },
}

local log_options = {
  tableid = "logviewer",
  basepath = "sys.log.",
  canAdd = false,
  canEdit = false,
  canDelete = false,
}

local getargs = ngx.req.get_uri_args()
local current_process = getargs["process"]
if current_process == "" then
  current_process = nil
end

local logs, processes = logviewer.load(current_process, {"", T"Everything"})

ngx.print(ui_helper.createHeader(T"Management", false, true, 5))

local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-management.lp")
  ngx.print('\
\
<div class="modal-body update no-save">\
  <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
    ');  if role == "engineer" then   ngx.print('\
    <div class="span2">\
      <ul class="nav nav-list">\
      ');  
        local html = {}
        local tab2 = {
        {
          desc = T"Log Viewer",
          active = "active",
            target = "modals/logviewer-modal.lp",
        },{
          desc = T"Connections",
          target = "modals/log-connections-modal.lp",
        },
        }
        html[#html + 1] = format('<li class="nav-header">%s</li>', T"Index")
        for i,v in ipairs(tab2) do
          if v.active == "active" then
            html[#html+1] = format('<li class="%s"><a  id = "Logmodal_%s" href="#" data-remote="%s">%s</a></li>', "active", i, v.target, v.desc)
          else
            html[#html+1] = format('<li class="%s"><a  id = "Logmodal_%s" href="#" data-remote="%s">%s</a></li>', "", i, v.target, v.desc)
          end
        end
        ngx.print(html)
        ngx.print('\
      </ul>\
    </div>\
    ');  end   ngx.print('\
    <div>\
    ');  
      local filterclass = {
        span = {
          style = "float:left;",
        },
      }
      local exporting_alert = {
        alert = {
          class = "alert-info hide",
          id = "exporting-msg"
        }
      }
      local exporting_fail = {
        alert = {
          class = "alert-error hide",
          id = "export-failed-msg"
        }
      }
      local html = {}
      html[#html + 1] = "<table><tr><td>"
      html[#html + 1] = ui_helper.createInputSelect(T"Filter", "process", processes, current_process or "", filterclass)
      html[#html + 1] = "</td><td>&nbsp;&nbsp;</td><td>"
      html[#html + 1] = "<div id='Export' class='btn export-conntracklog custom-handler' style='margin-bottom:8px;'><i class='icon-download-alt'></i>Export All</div>"
      html[#html + 1] = "</td></tr></table>"
      ngx.print(html)
      ngx.print(ui_helper.createAlertBlock(T"Exporting log, please wait ...", exporting_alert))
      ngx.print(ui_helper.createAlertBlock(T"Exporting failed; please try again.", exporting_fail))
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
      <fieldset>\
        ');  ngx.print(ui_helper.createTable(log_columns, logs, log_options, nil, nil))   ngx.print('\
      </fieldset>\
    </div>\
  </form>\
</div>\
\
<div class="modal-footer">\
  <div id="modal-no-change">\
    <div class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print( T"Close" ); ngx.print('</div>\
  </div>\
</div>\
\
<script type="text/javascript">\
    var target = $(".modal form").attr("action");\
\
    $(".export-conntracklog").click(function() {\
      $.fileDownload(target, {\
        httpMethod: "POST",\
        data: new Array({ name : "action", value : "export_log" },\
                        { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }),\
        prepareCallback: function() {\
          $("#export-failed-msg").addClass("hide");\
          var exporting_msg = $("#exporting-msg");\
          exporting_msg.removeClass("hide");\
          exporting_msg[0].scrollIntoView();\
        },\
        successCallback: function() {\
          $("#exporting-msg").addClass("hide");\
        },\
        failCallback: function() {\
          var export_failed_msg = $("#export-failed-msg");\
          export_failed_msg.removeClass("hide");\
          export_failed_msg[0].scrollIntoView();\
          $("#exporting-msg").addClass("hide");\
        }\
      });\
      return false;\
    });\
    $(\'select[name="process"]\').on("change", function() {\
        var process = $(this).val()\
        tch.loadModal("/modals/logviewer-modal.lp?process=" + process)\
    });\
</script>\
'); 