--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx, string = ngx, string
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format, match = string.format, string.match
local floor = math.floor
local sshinfopath = "/etc/"

local env = {
  factory = "uci.env.rip.factory_id",
  serial = "uci.env.rip.serial",
}
content_helper.getExactContent(env)

local serial_num = format("%s%s",env.factory,env.serial)
local syslog_present, syslog_filter_sw = "0", "0"

-- SSH Access
local ssh_lan, ssh_wan = "0", "0"    -- assume disabled
local ssh_lan_index, ssh_wan_index = "-1", "-1"
local ssh_wan_new, ssh_lan_new

-- local function to handle setting firewall rule
-- parameter target will have a value of DROP or ACCEPT for SSH-wan entry
local function set_firewall(target)
   -- go through rules to find SSH-wan anonymous section name
   local rules = proxy.get("uci.firewall.rule.")
   for _,v in ipairs(rules) do
      if v.param == "name" and v.value == "SSH-wan" then
         proxy.set(v.path.."target", target)
         return
      end
   end
end

local function write_loginfo(fileName, GUI_info)
  local f = io.open(fileName, "w")
  if f then
    f:write(GUI_info)
    f:close()
  end
end

local dbpath = "uci.dropbear.dropbear."
local dbvalues = proxy.get(dbpath)
local data = content_helper.convertResultToObject(dbpath, dbvalues)

for _,v in pairs(data) do
  if v.Interface == "lan" then
    ssh_lan = v.enable
    ssh_lan_index = v.paramindex
  elseif v.Interface == "wan" then
    ssh_wan = v.enable
    ssh_wan_index = v.paramindex
  end
end

local Syslog = proxy.get("uci.system.system.@system[0].log_ip","uci.system.system.@system[0].log_filter_ip")
if Syslog[1].value ~= "" or Syslog[2].value ~= "" then
  syslog_present = "1"
  if Syslog[2].value ~= "" then
    syslog_filter_sw = "1"
  end
end

if ngx.var.request_method == "POST" then
  local vars = ngx.req.get_post_args()
  local ssh_index = nil

  if vars["action"] == "SAVE" then
    -- SSH Access
    ssh_wan_new = string.untaint(vars["ssh_wan"])
    ssh_lan_new = string.untaint(vars["ssh_lan"])

    -- set lan
    if ssh_lan_new ~= ssh_lan then
      ssh_lan = ssh_lan_new
      proxy.set(dbpath..ssh_lan_index.. ".enable", ssh_lan)
      -- Log  that someone has changed SSH access
      ngx.log(ngx.ALERT, "Local Setting of SSH on lan to "..ssh_lan)
      if ssh_lan_new == "1" then
        ssh_index = ssh_lan_index
      end
    end

    -- set wan
    if ssh_wan_new ~= ssh_wan then
      ssh_wan = ssh_wan_new
      proxy.set(dbpath..ssh_wan_index.. ".enable", ssh_wan)
      if ssh_wan == "1" then
         set_firewall("ACCEPT")
      else
         set_firewall("DROP")
      end
      -- Log  that someone has changed SSH access
      ngx.log(ngx.ALERT, "Local Setting of SSH on wan to "..ssh_wan)
      if ssh_wan_new == "1" then
        ssh_index = ssh_wan_index
      end
    end

    if ssh_index ~= nil then
      local ip = string.untaint(ngx.var.remote_addr)
      local timestamp = os.date("%d.%m.%Y %H:%M:%S")
      local GUI_info = "GUI" .. "_" .. ip .. "_" .. timestamp
      write_loginfo(sshinfopath..string.untaint(proxy.get("uci.dropbear.dropbear.@lan.Interface")[1].value), GUI_info)
    end

    syslog_present = vars["syslog_present"]
    syslog_filter_sw = vars["syslog_filter_sw"]
    proxy.set("uci.system.system.@system[0].log_ip","")
    proxy.set("uci.system.system.@system[0].log_filter_ip","")
    proxy.apply()
  end
end



---[[
-- Syslog filters
local filter_columns = {
  {
    header = T"Filter",
    name = "filter_string",
    param = "value",
    type = "text",
  }
}

local vNES = post_helper.validateNonEmptyString
local function validateFilter(value, object, key)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if string.match(value, "[^A-Za-z0-9\-\_\.\,\!]") then
    return nil, T"Only alphanumeric characters, exclamation (!), commas (,), full stops(.), underscores(_) and hiphens(-) are allowed, no spaces"
  end
    return true
end

local filter_valid = {
  filter_string = validateFilter
}

local filter_options = {
  tableid = "syslog_filters",
  basepath = "uci.system.system.@system[0].log_filter.@.",
  createMsg = T"Add new Syslog Filter",
  minEntries = 1,
  maxEntries = 10,
}


local filter_data, filter_helpmsg = post_helper.handleTableQuery(filter_columns, filter_options, nil, nil, filter_valid)

--]]

local function validateSyslogPort(value, data, key)
    value = value and match(value, "^[%s0]*(%d+)%s*$")
    local port = value and tonumber(value)
    if port and (floor(port) == port) and port >= 1 and port < 65536 then
        if data and key then
          data[key] = value
        end
        return true
    end
    return nil, T"Port is invalid. It should be between 1 and 65535."
end

local syslog_Params = {
  syslog_filter_ip = "uci.system.system.@system[0].log_filter_ip",
  syslog_port = "uci.system.system.@system[0].log_port",
  syslog_ip = "uci.system.system.@system[0].log_ip",
}

local gVIPIL = post_helper.getValidationIfPropInList
local vSII = post_helper.validateStringIsIP
local vB = post_helper.validateBoolean
local vSLP = post_helper.getOptionalValidation(validateSyslogPort)
local vNES = post_helper.validateNonEmptyString

local function valid_comma_string(value)
  local rc, msg = vNES(value)
  if not rc then
    return rc, msg
  end
  if string.match(value, "[^%w,]") then
    return nil, T"Only alphanumeric characters, commas (,), full spots(.), underscores(_) and hiphens(-) are allowed, no spaces"
  end
    return true
end

local function syslogValidate(ipaddr, object)
  if object.syslog_present == '1' then
    if object.syslog_filter_sw == '0' then
      local success, errmsg = vSII(ipaddr)
      if not success then
        return nil, errmsg
      end
    end
  end
  return true
end

local function syslogFilterValidate(ipaddr, object)
  if object.syslog_present == '1' then
    if object.syslog_filter_sw == '1' then
      local success, errmsg = vSII(ipaddr)
      if not success then
        return nil, errmsg
      end
    end
  end
  return true
end

local syslog_valid = {
  syslog_present = vB,
  syslog_filter_sw = vB,
  syslog_ip = syslogValidate,
  syslog_filter_ip = syslogFilterValidate,
  syslog_port = gVIPIL(vSLP, "syslog_filter_sw", {"1"}),
}
local syslog_Params, helpmsg = post_helper.handleQuery(syslog_Params, syslog_valid)

local function resetreboot(path)
  proxy.set(path, "1")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  if action == "system_bootp" then
    return resetreboot("sys.bootp.enable")
  end
end
local title = T"System Extras"
  ngx.print('\
');  ngx.print(ui_helper.createHeader(title, false, false))   ngx.print('\
<div class="modal-body update">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/system-modal.lp">\
<fieldset>\
  <legend>');  ngx.print( T"Global" ); ngx.print('</legend>\
    ');  
      local bootp_alert = {
        alert = {
          class = "alert-info hide",
          id = "bootp-msg"
        }
      }
      local bootp = {
        group = {
          class = "wait-for-reboot"
        },
        button = {
          id = "btn-system-bootp",
          class = "custom-handler"
        }
      }
      local html = {}
      html[#html + 1] = ui_helper.createButton(T"LAN Upgrade", T"BOOTP", "icon-exchange", bootp)
      html[#html + 1] = ui_helper.createAlertBlock(T"Entering BOOTP, please wait...", bootp_alert)
      ngx.print(html)
      ngx.print('\
</fieldset>\
\
<fieldset>\
  <legend>');  ngx.print( T"SSH Access" ); ngx.print('</legend>\
    ');  
      local html = {}
      html[#html + 1] = ui_helper.createSwitch(T"LAN", "ssh_lan", ssh_lan)
      html[#html + 1] = ui_helper.createSwitch(T"WAN", "ssh_wan", ssh_wan)
      ngx.print(html)
      ngx.print('\
</fieldset>\
\
<fieldset>\
  <legend>');  ngx.print( T"System Log" ); ngx.print('</legend>\
    ');  
      local html = {}
      local switch_class_enable = {
        input = {
          class = "monitor-changes",
        }
      }
      html[#html + 1] = ui_helper.createSwitch(T"Enable Syslog", "syslog_present", syslog_present, switch_class_enable)
      local switch_class_filter = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          class = "monitor-changes",
        }
      }
      local Sysloginput = {
        group = {
          class ="monitor-syslog_present monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "15",
          class = "span2",
        },
      }
      local Sysloginputip_fltr_fltr = {
        group = {
          class ="monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1",
        },
        input = {
          maxlength= "50",
          class = "span5",
         },
      }
      html[#html+1] = [[<div class="monitor-syslog_filter_sw monitor-0 monitor-hide-syslog_filter_sw">]]
      html[#html+1] = ui_helper.createInputText(T"IP", "syslog_ip", syslog_Params["syslog_ip"], Sysloginput, helpmsg["syslog_ip"])
      html[#html+1] = [[</div>]]
      html[#html+1] = ui_helper.createInputText(T"Filter IP", "syslog_filter_ip", syslog_Params["syslog_filter_ip"], Sysloginputip_fltr, helpmsg["syslog_filter_ip"])
      html[#html+1] = ui_helper.createSwitch(T"Enable Filter", "syslog_filter_sw", syslog_filter_sw, switch_class_filter)
      local filter_warning = {
        alert = {
          class = "alert-info monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Every filter is a regular expression string; Start with '!' to invert selection", filter_warning)
      html[#html + 1] = format('<div class="control-group"><label class="control-label monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1">%s</label><div class="controls">', T"Syslog filters")
      html[#html+1] = ui_helper.createTable(filter_columns, filter_data, filter_options, Sysloginputip_fltr_fltr, filter_helpmsg)
      html[#html + 1] = '</div></div>'
      html[#html+1] = ui_helper.createInputText(T"Port", "syslog_port", syslog_Params["syslog_port"], Sysloginput, helpmsg["syslog_port"])
      ngx.print(html)
      ngx.print('\
</fieldset></form>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
  $("#btn-system-bootp").click(function() {\
     if (confirm("');  ngx.print(T"This will put your gateway into LAN Upgrade"); ngx.print('")){\
       tch.showProgress(\'');  ngx.print(T"Rebooting..."); ngx.print('\');\
       return resetreboot($("#bootp-msg"), $(this), "system_bootp");\
     }\
  });\
\
  $("[name=syslog_present]").change(function(){\
    $("[name=syslog_ip]").val("");\
    $("[name=syslog_filter_ip]").val("");\
  });\
\
  $("#btn-serial").click(function(){\
    $("[name=syslog_prefix]").val("');  ngx.print(serial_num); ngx.print('");\
    $("#modal-no-change").slideUp();\
    $("#modal-changes").slideDown();\
  });\
\
  $("[name=syslog_filter_sw]").change(function(){\
     if ($( this ).val() == "0"){\
       $("[name=syslog_ip]").val($("[name=syslog_filter_ip]").val());\
       $("[name=syslog_filter_ip]").val("");\
       $("[name=syslog_filter]").val("daemon");\
     }\
     else{\
       $("[name=syslog_filter_ip]").val($("[name=syslog_ip]").val());\
       $("[name=syslog_ip]").val("");\
       $("[name=syslog_filter]").val("daemon");\
     }\
  });\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 