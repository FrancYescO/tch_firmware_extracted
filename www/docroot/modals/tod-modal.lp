--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local parental_helper = require("parental_helper")
local tod = parental_helper.getTod()
local todColumns, todDefault, todValid, todSortfunc, todMacToHostname, hosts_ac =
      tod.columns, tod.default, tod.valid, tod.sort_func, tod.mac_to_hostname, tod.host_values
local uniqueKey = post_helper.getRandomKey()
local session = ngx.ctx.session


local todOptions = {
  tableid        = "tod",
  basepath       = "uci.tod.host.@.",
  createMsg      = T"Add New Rule",
  canAdd         = true,
  canDelete      = true,
  canApply       = true,
  canEdit        = true,
  sorted         = todSortfunc,
  objectName     = uniqueKey,
  addNamedObject = true
}

-- function that can be used to validate tod rule
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @return #boolean or nil+error message
local function todRuleVerification(value, object, key)
  if object.action == "TABLE-MODIFY" or object.action == "TABLE-EDIT" then
    local currentIndex = tonumber(object.index) or -1
    local allowedIndexes = session:retrieve(todOptions.tableid .. ".allowedindexes") or {}
    currentIndex = allowedIndexes[currentIndex] and allowedIndexes[currentIndex].paramindex or -1
    if currentIndex ~= -1 then
      object.index = currentIndex
    end
  end
  local retVal, errorMsg = parental_helper.validateTodRule(value, object, key, "AccessControl")
  if not retVal then
    message_helper.pushMessage(format("%s",errorMsg), "error")
  end
  return retVal
end

todValid["weekdays"] = todRuleVerification

local todData, todHelpmsg = post_helper.handleTableQuery(todColumns, todOptions, nil, todDefault, todValid)
todMacToHostname(todData)

if ngx.var.request_method == "POST" then
local post_data = ngx.req.get_post_args()
  if ( (post_data.tableid == "tod") and (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") )then
      local index = tonumber(post_data.index)
      local text_hostName = todData[index][7][2]
      local isSameHostName = true
      if not hosts_ac then return nil end
      for _, hostName in ipairs(hosts_ac) do
         if text_hostName == hostName[1] then
           isSameHostName = false
           break
         end
      end
      if isSameHostName then
      	todColumns[7].subcolumns[2] = {
 		header = T"MAC address",
                name = "id",
                param = "id",
                type = "text",
                attr = { input = { class="span2", value = text_hostName, id = "macAddressInput" }},
      	}
      end
  end
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Time of Day") ); ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
\
<div class="modal-body update">\
\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-tod.lp")
  ngx.print('\
\
  <form class="form-horizontal" method="post" action="/modals/tod-modal.lp">\
    <legend>');  ngx.print( T"Time of day access control" ); ngx.print('</legend>\
    ');  ngx.print(
      ui_helper.createTable(todColumns, todData, todOptions, nil, todHelpmsg)
    ); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('</span></div></div>\';\
        $(\'#stoptime\').parent().parent().after(warning);\
        $(".additional-edit .checkbox input").each(function(index) {\
            $(this).attr("id", "tod-day"+index);\
        });\
      </script>\
    ');  end  ngx.print('\
  </form>\
</div>\
\
<script src="/js/tod-modal.js"></script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 