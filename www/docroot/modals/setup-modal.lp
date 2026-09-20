--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session

function processOperations(operations)
    if type(operations) ~= "table" then
        return
    end
    local success, msg
    for _,v in ipairs(operations) do
        local path = v[1]
        local val = v[2]
        local setdel = v[3]
        if setdel == "del" then
            success, msg = proxy.del(path)
        elseif setdel == "add" then
            success, msg = proxy.add(path, val)
        else
            success, msg = proxy.set(path, val)
        end
    end
    proxy.apply() 
end

-- Process POST query
local post_helper = require("web.post_helper")

-- Process the selected mode if any
local imh = require("setup_helper")

local mode_options = {}
local mode_data = {}
local mode_default = "" -- the default mode to use
local mode_active = ""  -- the mode currently in use (mode_default if not set)
local mode_current = "" -- the mode currently selected (not necessarily active yet)

local class_alert, class_main_input = "", ""

for _,v in ipairs(imh) do
    mode_options[#mode_options + 1] = { v.name, v.description }
    mode_data[v.name] = v
    if v.default == true then
        mode_default = v.name
    end
    
end
-- Get current mode
local gVIES = post_helper.getValidateInEnumSelect
local content

if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    action = content["action"]
      
    if gVIES(mode_options)(content["conn_mode"]) then
        mode_current = content["conn_mode"] or ""
        mode_current = format("%s", mode_current) -- remove tainting, it's ok, it passed validation

        if action == "SWITCH_MODE" then
            processOperations(mode_data[mode_current].operations)
            --proxy.set("uci.env.custovar.setup", mode_current)
            --proxy.apply()
        end
    end
end

mode_active = format("%s", proxy.get("uci.env.custovar.setup")[1].value) -- remove tainting
if mode_active == "" then
    mode_active = mode_default
end

if mode_current == "" then
    mode_current = mode_active
end
for _,v in ipairs(mode_options) do
   --

   if v[1] ~= mode_current then
      class_alert = format("%s monitor-%s",class_alert, v[1])
   else
      class_main_input = format("%s monitor-%s",class_main_input, v[1])
   end
end

ngx.print(ui_helper.createHeader(T"Setup Your Gateway", true, true), '\
\
<div class="modal-body update">\
<div class="advanced hide">');
local tabs = {}
if session:hasAccess("/modals/setup-modal.lp") then
    tabs[#tabs+1] = {
        desc = T"Connection Setup",
        target = "modals/setup-modal.lp", 
        active = "active",
    }
end
if session:hasAccess("/modals/subnet-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Routed Subnet",
        target = "modals/subnet-modal.lp",
    }
end
if session:hasAccess("/modals/AP-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Convert to Access Point",
        target = "modals/AP-modal.lp",
    }
end
ngx.print(ui_helper.createModalTabs(tabs), '\
\
</div>');
local WS = proxy.get("uci.env.custovar.WS")
if WS ~= "2" then
  local auto_warning = {
      alert = {
          id = "auto_warning",
          class = "alert-error"
      },
  }
  ngx.print(ui_helper.createAlertBlock(T"Changing any setting here will disable the Auto sensing of your WAN interface", auto_warning))               
end  
ngx.print('\
<form class="form-horizontal" method="post" action="modals/setup-modal.lp">', 
ui_helper.createMessages(message_helper.popMessages()));
if #imh > 1 then
	-- Only included if there are 2 or more connection modes
	ngx.print('\
	<fieldset id="conn_mode">\
	<legend>', T"Connection Type", '</legend>');

	    local html = {}

	    local mode_attributes = {
	        radio = {
	            class = "inline"
	        },
	        input = {
	            class = "no-save",
	            ["data-for"] = "SWITCH_MODE",
	            class = "monitor-changes",
	        }
	    }
	    local mode_button = {
	        button = {
	            ["data-name"] = "action",
	            ["data-value"] = "SWITCH_MODE",
	            class = format("monitor-conn_mode %s", class_alert),
	        }
	    }
       
    
	    html[#html+1] = ui_helper.createInputRadio(T"Type", "conn_mode", mode_options, mode_current, mode_attributes)
	    local security_warning = {
	        alert = {
	            class = format("alert-warning monitor-conn_mode %s", class_alert),
	        },
	    }
	    html[#html + 1] = ui_helper.createAlertBlock(T"Please click \"Switch Connection Type\" to see the correct options", security_warning)
	    --[[
	    local AUTO_warning = {
	        alert = {
	            class = "alert-warning monitor-conn_mode monitor-AUTO",
	        },
	    }
	    html[#html + 1] = ui_helper.createAlertBlock(T"Allow up to a minute for the AUTO detection to occur", AUTO_warning)
	    ]]
	    html[#html+1] = ui_helper.createButton("", "Switch Connection Type", "icon-cog", mode_button)

	    ngx.print(html, '\
</fieldset>');
end
ngx.print('\
<div class="', format("monitor-conn_mode %s", class_main_input), '" style="display: block;">');
    lp.setpath("/www/snippets/")
    lp.include(mode_data[mode_current].view)
ngx.print('\
</div>\
</form>\
</div>\
<script type=\'text/javascript\'>\
\
var conn_curr = "', mode_current, '";\
var save =  $("#save-config")\
\
function check_conn_mode(){\
  var conn_mode = $("input:radio[name=\'conn_mode\']:checked");\
  if (conn_mode.val()!=conn_curr){\
     save.hide();\
  }else{\
     save.show();\
  }\
}\
\
$(function() {\
  $("[name=\'conn_mode\']").change(function() {check_conn_mode();}); \
});\
</script>',
ui_helper.createFooter() );