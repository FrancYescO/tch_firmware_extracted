--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local logdownload_helper = require("logdownload_helper")
local logviewer = require 'log.viewer'
local format = string.format
local proxy = require("datamodel")
local role = ngx.ctx.session:getrole()
local post_helper = require("web.post_helper")

if ngx.req.get_method() == "POST" then
  -- now process non-file POSTs
  local action = ngx.req.get_post_args().action
  if action == "export_log" then
    return logdownload_helper.export_log("logread")
  end
end


local logColumns = {
  {
    header =  T"Date",
    name = "date",
    param = "date",
    type = "text",
    attr = { input = {  class="span1" } }
  },
  {
    header = T"Facility",
    name = "facility",
    param = "facility",
    type = "text",
    attr = { input = { class="span1" } }
  },
  {
    header = T"Process",
    name = "process",
    param = "process",
    type = "text",
    attr = { select = { class="span1" } }
  },
  {
    header = T"Message",
    name = "message",
    param = "message",
    type = "text",
    attr = { select = { class="span6" } }
  }
}

local logOptions = {
  tableid = "logviewer",
  basepath = "sys.log.",
  canAdd = false,
  canEdit = false,
  canDelete = false
}

local getargs = ngx.req.get_uri_args()
local current_process = getargs["process"]
if current_process == "" then
  current_process = nil
end

local logs, processes = logviewer.load(current_process, {"", T"Everything"})
local currentLogProcess = {}
if post_helper.isFeatureEnabled("logViewer", role) then
  currentLogProcess = {
    { "processes", T"All Events" },
    { "warning_processes", T"Only error and warning" }
  }
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, true, 5))   ngx.print('\
\
<div class="modal-body update no-save">\
\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-management.lp")
  ngx.print('\
\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
  ');  if post_helper.isFeatureEnabled("logViewerTab" , role) then  ngx.print('\
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
  ');  
    local filterClass = {
      span = {
        style = "float:left;"
      }
    }
    local exportingAlert = {
      alert = {
        class = "alert-info hide",
        id = "exporting-msg"
      }
    }
    local exportingFail = {
      alert = {
        class = "alert-error hide",
        id = "export-failed-msg"
      }
    }
    local html = {}
    html[#html + 1] = "<table><tr><td>"
    html[#html + 1] = ui_helper.createInputSelect(T"Filter", "process", processes, current_process or "", filterClass)
    html[#html + 1] = "</td><td>&ensp;</td><td>"
    html[#html + 1] = "<div id='Export' class='btn export-conntracklog custom-handler' style='margin-bottom:8px;'><i class='icon-download-alt'></i>"..T"Export All".."</div>"
    html[#html + 1] = "</td></tr></table>"
    if post_helper.isFeatureEnabled("logViewer" , role) then
      html[#html + 1] = ui_helper.createInputSelect(T"Log Level", "facility", currentLogProcess, "", filterClass)
    end
    ngx.print(html)
    ngx.print(ui_helper.createAlertBlock( T"Exporting log, please wait ...", exportingAlert))
    ngx.print(ui_helper.createAlertBlock(T"Exporting failed; please try again.", exportingFail))
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
\
  <fieldset>\
\
  ');  
    ngx.print(ui_helper.createTable(logColumns, logs, logOptions, nil, nil))
    ngx.print('\
\
  </fieldset>\
</form>\
</div>\
<div class="modal-footer">\
  <div id="modal-no-change">\
    <div class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print( T"Close" ); ngx.print('</div>\
  </div>\
</div>\
<script type="text/javascript">\
  var isFeatureLogViewerFlag = false;\
  ');  if not post_helper.isFeatureEnabled("logViewer" , role) then  ngx.print('\
    isFeatureLogViewerFlag = true;\
  ');  end   ngx.print('\
  if (!$("#LogViewer").parent().hasClass("active")) {\
    $("#LogViewer").parent().addClass("active")\
  }\
</script>\
<script src="/js/logviewer.js"></script>\
'); 
