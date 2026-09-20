--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session

-- var val_selected is to store the wan intf name dynamically changed by user from the drop down list
local val_selected = ""

-- Fetching available wan interfaces
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local allWan_intfs = {}
for _, v in ipairs(firewall_zone_path) do
  if (v["wan"] == "1" and v["name"] ~= "mgmt") then
    allWan_intfs[#allWan_intfs + 1] = {v["name"], v["name"]}
  end
end

-- Getting posted interface name from drop down list via post method and storing it in session var for further operations
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SELECT" then
  val_selected = ngx.req.get_post_args().interface
  ngx.ctx.session:store("postedIntf_internet_modal", val_selected)
end

-- If other interfaces in drop down then show the selected interface else show the wan interface in default case
val_selected = session:retrieve("postedIntf_internet_modal") or "wan"

local imh = require("internetmode_helper")
local tabdata = dyntab_helper.process(imh)

  ngx.print('\
\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  
local role = ngx.ctx.session:getrole()
ngx.print(ui_helper.createHeader(T"Internet Access", ((role == "superuser") or (role == "telia")), true))
  ngx.print('\
\
<div class="modal-body update">\
<form id="interface-form" class="form-horizontal" method="post" action="modals/internet-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
');  
    if #imh > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Connection mode" ); ngx.print('</legend>\
\
');  
    local html = {}
    html[#html+1] = ui_helper.createLabel(T"Mode", "DHCP routed mode")

    ngx.print(html)
  ngx.print('\
</fieldset>\
');  ngx.print(ui_helper.createInputSelect(T"Available Interfaces", "interface", allWan_intfs, val_selected, {select={class="monitor-changes"}}))   ngx.print('\
\
');  end   ngx.print('\
\
');  end   ngx.print('\
');  
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
  ngx.print('\
\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
');  end   ngx.print('\
<script>\
$("select#interface").change(function(){\
  var params = [];\
  var intf = $(this).val();\
    params.push({\
      name : "interface",\
      value : intf\
    },\
    {\
      name : "CSRFtoken",\
      value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    },\
    {\
      name  : "action",\
      value :  "SELECT"\
    }\
    );\
  $.post($("#interface-form").attr("action"),params);\
});\
</script>\
'); 