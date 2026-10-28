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
local wanIntf = post_helper.getActiveInterface()

local content = {
  factory = "uci.env.rip.factory_id",
  serial = "uci.env.rip.serial",
  syslog_ip = "uci.system.system.@system[0].log_ip",
  syslog_filter_ip = "uci.system.system.@system[0].log_filter_ip",
}
content_helper.getExactContent(content)

local serial_num = format("%s%s", content.factory, content.serial)
local syslog_present, syslog_filter_sw = "0", "0"

local type_params = {
  {"circular", T"Circular"},
  {"file", T"File"},
}

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
  elseif v.Interface == wanIntf then
    ssh_wan = v.enable
    ssh_wan_index = v.paramindex
  end
end

if content.syslog_ip ~= "" or content.syslog_filter_ip ~= "" then
  syslog_present = "1"
  if content.syslog_filter_ip ~= "" then
    syslog_filter_sw = "1"
  end
end

if ngx.var.request_method == "POST" then
  local vars = ngx.req.get_post_args()
  local ssh_index = nil
  local setTable = {}

  if vars["action"] == "SAVE" then
    -- SSH Access
    ssh_wan_new = string.untaint(vars["ssh_wan"])
    ssh_lan_new = string.untaint(vars["ssh_lan"])

    -- set lan
    if ssh_lan_new ~= ssh_lan then
      ssh_lan = ssh_lan_new
      setTable["uci.dropbear.dropbear.@lan.enable"] = ssh_lan
      -- Log  that someone has changed SSH access
      ngx.log(ngx.ALERT, "Local Setting of SSH on lan to "..ssh_lan)
      if ssh_lan_new == "1" then
        ssh_index = ssh_lan_index
      end
    end

    -- set wan
    if ssh_wan_new ~= ssh_wan then
      ssh_wan = ssh_wan_new
      setTable["uci.dropbear.dropbear."..ssh_wan_index..".enable"] = ssh_wan
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
    if vars["syslog_present"] == "0" and ( content["syslog_ip"] ~= "" or content["syslog_filter_ip"] ~= "" ) then
      setTable["uci.system.system.@system[0].log_ip"] = ""
      setTable["uci.system.system.@system[0].log_filter_ip"] = ""
    end
    proxy.set(setTable)
    proxy.apply()
  end
end

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

local syslog_Params = {
  syslog_filter_ip = "uci.system.system.@system[0].log_filter_ip",
  syslog_port = "uci.system.system.@system[0].log_port",
  syslog_ip = "uci.system.system.@system[0].log_ip",
  syslog_size = "uci.system.system.@system[0].log_size",
}

local validateList = post_helper.getValidationIfPropInList
local validateEnum = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local validatePort = post_helper.getOptionalValidation(post_helper.validateSyslogPort)
local validateSize = post_helper.getOptionalValidation(post_helper.validateSyslogSize)

local curintf = "lan"
local contentData = {
  localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
  localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
}
content_helper.getExactContent(contentData)

local function syslogValidate(ipaddr, object)
  if object.syslog_present == '1' then
    if object.syslog_filter_sw == '0' then
      local success, errmsg = post_helper.filterIPValidation(ipaddr, contentData)
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
      local success, errmsg = post_helper.filterIPValidation(ipaddr, contentData)
      if not success then
        return nil, errmsg
      end
    end
  end
  return true
end

local syslog_valid = {
  syslog_present = validateBoolean,
  syslog_filter_sw = validateBoolean,
  syslog_ip = syslogValidate,
  syslog_filter_ip = syslogFilterValidate,
  syslog_port = validateList(validatePort, "syslog_filter_sw", {"1"}),
  syslog_size = validateList(validateSize, "syslog_filter_sw", {"1"}),
}

local syslog_Params, helpmsg = post_helper.handleQuery(syslog_Params, syslog_valid)

--If any error is thrown, the previous IP details should be retained
if next(helpmsg) then
  if content["syslog_ip"] ~= "" or content["syslog_filter_ip"] ~= "" then
    local setTable = {}
    setTable["uci.system.system.@system[0].log_ip"] = content.syslog_ip
    setTable["uci.system.system.@system[0].log_filter_ip"] = content.syslog_filter_ip
    proxy.set(setTable)
    proxy.apply()
  end
end

local title = T"System Extras"
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Management", false, false))   ngx.print('\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-management.lp")
  ngx.print('\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/system-modal.lp">\
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
      html[#html+1] = ui_helper.createInputText(T"Size", "syslog_size", syslog_Params["syslog_size"], Sysloginputip_fltr, helpmsg["syslog_size"])
      html[#html+1] = ui_helper.createInputText(T"Port", "syslog_port", syslog_Params["syslog_port"], Sysloginputip_fltr, helpmsg["syslog_port"])
      html[#html + 1] = ui_helper.createLabel(T" Filter Path", T"/var/log/filt_msg", Sysloginputip_fltr)
      html[#html+1] = ui_helper.createSwitch(T"Enable Filter", "syslog_filter_sw", syslog_filter_sw, switch_class_filter)
      local filter_warning = {
        alert = {
          class = "alert-info monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1"
        },
      }
      if syslog_filter_sw == "1" then
        html[#html + 1] = ui_helper.createAlertBlock(T"Every filter is a regular expression string; Start with '!' to invert selection", filter_warning)
        html[#html + 1] = format('<div class="control-group"><label class="control-label monitor-syslog_present monitor-1 monitor-syslog_filter_sw monitor-1">%s</label><div class="controls">', T"Syslog filters")
        html[#html+1] = ui_helper.createTable(filter_columns, filter_data, filter_options, Sysloginputip_fltr_fltr, filter_helpmsg)
        html[#html + 1] = '</div></div>'
      end
      ngx.print(html)
      ngx.print('\
</fieldset></form>\
</div>\
<script>\
  var serial_numValue = "');  ngx.print( serial_num ); ngx.print('";\
</script>\
<script src="/js/system.js"></script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 