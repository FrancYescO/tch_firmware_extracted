--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local match, format = string.match, string.format

local tod = require("parental_helper").getTod()
local tod_columns, tod_default, tod_valid, tod_sort_func, tod_mac_to_hostname =
      tod.columns, tod.default, tod.valid, tod.sort_func, tod.mac_to_hostname

local tod_options = {
    tableid     = "tod",
    basepath    = "uci.tod.host.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    sorted      = tod_sort_func,
}

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
tod_mac_to_hostname(tod_data)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Time of Day") ); ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-tod.lp")
    gettext.textdomain('webui-core')
  ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="/modals/tod-modal.lp">\
    <legend>');  ngx.print( T"Time of day access control" ); ngx.print('</legend>\
    ');  ngx.print(
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    ); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('</span></div></div>\';\
        $(\'#stoptime\').parent().parent().after(warning);\
      </script>\
    ');  end  ngx.print('\
  </form>\
</div>\
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
        $(\'select[name="id"]\').on("change", function() {\
            if(this.value == "any")\
            {\
                var id_input = $(\'<input name="id" class="span2 edit-input" type="text" maxlength="17">\');\
                $(this).after(id_input);\
                $(this).remove();\
            }\
        });\
    });\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 