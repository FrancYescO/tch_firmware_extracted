--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
-- local tprint = require("tch.tableprint")

local uci_tod_path = "uci.tod.host."
local tod_columns = {
  {
    header = T"Hostname",
    name = "id",
    param = "id",
    type = "text",
    attr = { input = { class="span2" } },
  },
}

local tod_options = {
  tableid  = "tod",
  basepath = uci_tod_path,
}

-- get an initial read from UCI
local tod_data = post_helper.handleTableQuery(tod_columns, tod_options)
local rulecount = (type(tod_data)=="table") and #tod_data or 0

if session:hasAccess("/modals/tod-modal.lp") then
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Time of Day", "modals/tod-modal.lp") ); ngx.print('\
\
    <div class="content">\
\
    ');  ngx.print(
            '<p></p>',
            '<p class="subinfos">',
            format(N("<strong %s>%d Time of Day</strong> rule is defined",
                     "<strong %s>%d Time of Day</strong> rules are defined", rulecount),
                   'class="modal-link" data-toggle="modal" data-remote="modals/tod-modal.lp" data-id="tod-modal"',
                   rulecount),
            '</p>')
      ngx.print('\
\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 