--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local ipairs = ipairs
local session = ngx.ctx.session
local json = require("dkjson")
local role = session:getrole()
local gVCS = post_helper.getValidateCheckboxSwitch()
local orValidation = post_helper.getOrValidation
local andValidation = post_helper.getAndValidation
local optionalValidation = post_helper.getOptionalValidation
local content_helper = require("web.content_helper")
local tz_data = require("tz_helper")
local lfs = require("lfs")
local proxy = require("datamodel")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "SystemInfo", "TimeManagement")
local wanIntf = post_helper.getActiveInterface()

local system_time = os.date("%F %T", os.time())

-- NTP Servers
local paramNtp = {
  NTPServer = format("rpc.network.interface.@%s.NTPServers", wanIntf)
}
content_helper.getExactContent(paramNtp)

local duplicateCheck = false
local index = "1"

local ntpServerList = content_helper.convertResultToObject("uci.system.ntp.server.", proxy.get("uci.system.ntp.server."))
local ntp_servers = {}
for _, name in pairs(ntpServerList) do
  if name.value == paramNtp.NTPServer then
    duplicateCheck = true
  end
  ntp_servers[#ntp_servers+1] = string.untaint(name.value)
  index = string.match(name.paramindex,"%d+") + 1
end

paramNtp.time_servers = table.concat(ntp_servers,", ")

if ngx.req.get_uri_args().getNTP == "true" then
  paramNtp.time_servers = table.concat(ntp_servers,", ")
  local responseData = paramNtp.time_servers
  ngx.header.content_type = "application/json"
  ngx.print(json.encode(responseData))
  ngx.exit(ngx.OK)
end

if not duplicateCheck and paramNtp.NTPServer ~= "" then
  local indexVal = proxy.add("uci.system.ntp.server.")
  if indexVal then
    local success = proxy.set("uci.system.ntp.server.@"..index..".value", paramNtp.NTPServer)
    if success then
      proxy.apply()
    end
  end
end

local ntp_columns = {
  {
    header = T"Server Name",
    name = "ntp_server",
    param = "value",
    type = "text",
    unique = true,
  }
}

local ntp_valid = {
  ntp_server = post_helper.validateNTP
}

local ntp_options = {
  tableid = "ntp_servers",
  basepath = "uci.system.ntp.server.@.",
  createMsg = T"Add new NTP server",
  minEntries = 1,
  maxEntries = 3,
}

if not post_helper.isFeatureEnabled("ntpmodify", role) then
  ntp_options.canEdit = false
  ntp_options.canDelete = false
end

local ntp_data, ntp_helpmsg = post_helper.handleTableQuery(ntp_columns, ntp_options, nil, nil, ntp_valid)
session:store("ntp_data",ntp_data)

-- Configurable system parameters
local system_params = {
  system_timezone = "uci.system.system.@system[0].timezone",
  system_zonename = "uci.system.system.@system[0].zonename",
  system_network_timezone = "uci.system.system.@system[0].network_timezone"
}

local system_valid = {
  system_timezone = function(value, object, key)
    local gui_tz = value
    local valid, helpmsg = post_helper.validateNonEmptyString(value)
    if valid then
      local tz_value, zonename_value = string.match(gui_tz,'(.*)_timezone_(.*)')

      --tz_value is the matched result from tz_helper.lua, can not be empty string
      if not tz_value or not zonename_value then
        return valid, helpmsg
      end

      object.system_timezone = tz_value
      object.system_zonename = zonename_value
    end
    return valid, helpmsg
  end,
  system_zonename = function(value, object,key)
    return true
  end,
  system_network_timezone = function(value, object, key)
    local err, msg = optionalValidation(gVCS(value, object, key))
    if not err then
      return err, msg
    end

    if object[key] == "1" then
      object["system_timezone"] = nil
      object["system_zonename"] = nil
    end
    return true
  end,
}

local system_data, system_helpmsg = post_helper.handleQuery(system_params, system_valid)

-- Get timezones
local zonepath = "/usr/share/zoneinfo"
local timezones = {}
for _,v in pairs(tz_data) do
  for file in lfs.dir(zonepath) do
    if string.match(file, "[^.]+") and string.match(v[2],file) and timezones[#timezones] ~= v then
        table.insert(timezones,v)
    end
  end
end

local function getTimeZoneName(list, isRemote)
  local default_tztable = {
    [true] = "UTC",
    [false] = nil,
  }

  local tz = system_data["system_timezone"]
  local tz_name = system_data["system_zonename"]
  if tz == "" then
    return default_tztable[isRemote]
  end

  if isRemote then
    default_tztable[isRemote] = tz
  end

  if tz_name ~= "" then
    if isRemote then
      return tz_name
    else
      return tz .. "_timezone_" .. tz_name
    end
  end

  for _, v in ipairs(list) do
    local key = string.match(v[1], "^([^_]*)")
    if key == tz then
      if isRemote then
        return v[2]
      else
        return v[1]
      end
    end
  end
  return default_tztable[isRemote]
end

ngx.print(ui_helper.createHeader(T"Time", true, true))
  ngx.print('\
\
<div class="modal-body update">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  lp.setpath("/www/snippets/")
  lp.include("tabs-system-info.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/time-management-modal.lp">\
  <fieldset>\
    <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
    ');  
      local nw_enable_class = {
        input = {
          class = "monitor-changes",
        }
      }
      local default_tz_class = {
        group = {
          class = "monitor-system_network_timezone monitor-1"
        }
      }
      local user_tz_class = {
        group = {
          class = "monitor-system_network_timezone monitor-0"
        }
      }

      local html = {}
      html[#html + 1] = ui_helper.createLabel( T"System Time", format('<label id = "system_time">%s</label>', system_time))
      if post_helper.isFeatureEnabled("networktz", role) then
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Network Timezone", "system_network_timezone", system_data["system_network_timezone"], nw_enable_class)
      end
      local currentTZ_remote = getTimeZoneName(timezones, true)
      local currentTZ_gui = getTimeZoneName(timezones, false)
      if post_helper.variantHasAccess(variantHelper, "timeZone", role) then
        html[#html + 1] = ui_helper.createLabel(T"Current Timezone", currentTZ_remote, default_tz_class)
      else
        local netTimeZone = system_data["system_network_timezone"] == "0" and "Off" or "On"
        html[#html + 1] = ui_helper.createLabel(T"Network Timezone", netTimeZone)
        html[#html + 1] = ui_helper.createLabel(T"Current Timezone", system_data["system_zonename"])
      end
      if post_helper.isFeatureEnabled("systemtz", role) then
        html[#html + 1] = ui_helper.createInputSelect(T"Current Timezone", "system_timezone", timezones, currentTZ_gui, user_tz_class)
      end
      -- NTP servers
      if post_helper.variantHasAccess(variantHelper, "ntpServer", role) then
        html[#html + 1] = format('<div class="control-group advanced hide"><label class="control-label">%s</label><div class="controls">',T"NTP servers")
        html[#html + 1] = ui_helper.createTable(ntp_columns, ntp_data, ntp_options, nil, ntp_helpmsg)
        html[#html + 1] = '</div></div>'
      else
        html[#html + 1] = ui_helper.createLabel(T"NTP servers", paramNtp["time_servers"])
      end
      ngx.print(html)
      ngx.print('\
  </fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
  var target = "/modals/time-management-modal.lp";\
  function getNTPServer(target) {\
    $.ajax({type: "get", url: target+"?getNTP=true&auto_update=true" , dataType: "json", success: function(response) {\
      $("[id =\'NTP servers\']").html(response)\
    }});\
  }\
  var interval = setTimeout(function(){ getNTPServer(target) }, 100);\
</script>\
'); 