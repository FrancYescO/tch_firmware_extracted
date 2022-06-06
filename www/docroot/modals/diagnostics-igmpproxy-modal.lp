--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local datarows = {}
local k = 1
local switch_kk = {
  state = 2,
  querier = 3,
  address = 4,
  filter_mode = 5,
  hosts = 6,
}
local result = proxy.get("rpc.igmpproxy.interface.") or {}

for i,v in ipairs(result) do
  local intf = string.match(v.path, "rpc%.igmpproxy%.interface%.@([^%.]+)%.")
  if intf then
    datarows[k] = datarows[k] or {nil,"","","","",""}
    if datarows[k][1] == nil then --first interface
      datarows[k][1] = intf
    elseif datarows[k][1] ~= "" and datarows[k][1]~= intf then  --new interface
      k = k + 1
      datarows[k] = {intf,"","","","",""}
    end
    local group = string.match(v.path, "rpc%.igmpproxy%.interface%.@[^%.]+%.group.([^%.]+)%.")
    if group then
      if datarows[k][4] ~= "" and datarows[k][4] ~= group then -- new group
        k = k + 1
        datarows[k] = {intf,datarows[k-1][2],datarows[k-1][3],"","",""}
      end
    end
    datarows[k][switch_kk[v.param]] = v.value
  end
end

local columns ={}
for i=1, 6 do
    columns[i]={}
end

columns[1]["header"] = T"Interface"
columns[2]["header"] = T"State"
columns[3]["header"] = T"Querier"
columns[4]["header"] = T"Group"
columns[5]["header"] = T"Filter_mode"
columns[6]["header"] = T"Hosts"

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Diagnostics Igmpproxy", false, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
\
    <form class="form-horizontal" method="post" action= "modals/diagnostics-igmpproxy-modal.lp">\
    </form>\
\
    <fieldset id="diagnostics-igmpproxy-tab">\
      <legend>');  ngx.print( T"Igmpproxy Statistics" ); ngx.print('</legend>\
      ');  
        local options = { tableid = "igmpproxystatistics", canEdit = false, editing = false, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
        -- table that shows the Statistics data
        ngx.print(ui_helper.createTable(columns, datarows, options))
        ngx.print('\
    </fieldset>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 