--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Enable localization
gettext.textdomain('webui-telstra')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local parental_helper = require("parental_helper")
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1
local symbolv2 = telstra_helper.symbolnamev2
local session = ngx.ctx.session
local tod = parental_helper.getTod()
local tod_columns, tod_default, tod_valid, tod_sort_func, tod_mac_to_hostname =
      tod.columns, tod.default, tod.valid, tod.sort_func, tod.mac_to_hostname

local uniqueKey = post_helper.getRandomKey()
local tod_options = {
    tableid     = "tod",
    basepath    = "uci.tod.host.@.",
    createMsg   = T"Create New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    sorted      = tod_sort_func,
    objectName = uniqueKey,
    addNamedObject = true,
}

local pageValid = true
local function todRuleVerification(value, object, key)
  if object.action == "TABLE-MODIFY" or object.action == "TABLE-EDIT" then
    local current_index = tonumber(object.index) or -1
    local allowedIndexes = session:retrieve(tod_options.tableid .. ".allowedindexes") or {}
    current_index = allowedIndexes[current_index] and allowedIndexes[current_index].paramindex or -1
    if current_index ~= -1 then
      object.index = current_index
    end
  end
  local retVal, errorMsg = parental_helper.validateTodRule(value, object, key, "AccessControl")
  if not retVal then
    message_helper.pushMessage(format("%s",errorMsg), "error")
    pageValid = false
  end
  return retVal
end

tod_valid["weekdays"] = todRuleVerification

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
tod_mac_to_hostname(tod_data)
if type(tod_helpmsg) == "table" and next(tod_helpmsg) ~= nil then
  pageValid = false
end
  ngx.print('\
\
<script type="text/javascript">\
    $(function () {\
        var opt = {\
            theme: \'android-ics light\',\
            display: \'bubble\',\
            mode: \'scroller\',\
            headerText: false,\
            timeFormat: \'HH:ii\',\
            stepMinute: 15\
        };\
        $("#starttime").mobiscroll().time(opt);\
        $("#stoptime").mobiscroll().time(opt);\
    });\
</script>\
\
<div class="container">\
');  lp.include("tabs-parental.lp")   ngx.print('\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="/tod.lp">\
\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
');  ngx.print( ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg) ); ngx.print('\
');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
 <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 5px; padding-bottom: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T("Enter the host name, MAC address or IP address of the device.") ); ngx.print('</span></div></div>\';\
        $(\'#device\').parent().parent().after(warning);\
 </script>\
 <script type="text/javascript">\
    var warning = \'<div class="control-group"><div style="padding-top: 0px; padding-bottom: 10px;" class="controls"><span class="alert">\'\
                  +\'');  ngx.print( T("The " .. symbolv1 .. " will block/allow all the time if none of the days are selected") ); ngx.print('</span></div></div>\';\
    $(\'#dayofwork\').parent().parent().after(warning);\
 </script>\
');  end  ngx.print('\
<div style="padding-top: 0px; padding-left: 20px;" >\
     <table cellspacing="5" >\
        <tr><td><div>');  ngx.print( T("Legend") ); ngx.print('</div></td></tr>\
    <tr><td><div class="light off"></div></td>\
    <td>');  ngx.print( T("Disabled rule exists for the device") ); ngx.print('</td></tr>\
    <tr><td><div class="light green"></div></td>\
    <td>');  ngx.print( T("Enabled rule exists for the device") ); ngx.print('</td></tr>\
     </table>\
</div>\
</fieldset>\
</form>\
\
</div>\
</div>\
</div>\
');  
lp.include("footer.lp")
  ngx.print('\
');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action ~= "TABLE-NEW" and ngx.req.get_post_args().action ~= "TABLE-EDIT") and pageValid then  ngx.print('\
  <script type="text/javascript">\
    location.replace(location.href);\
  </script>\
');  end  ngx.print('\
'); 