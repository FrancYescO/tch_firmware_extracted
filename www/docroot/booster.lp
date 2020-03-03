--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-telstra')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gVSLIR = post_helper.getValidateStringLengthInRange
local gVIES = post_helper.getValidateInEnumSelect
local secondsToTime = post_helper.secondsToTime
local format, match = string.format, string.match
local untaint_mt = require("web.taint").untaint_mt
local proxy = require("datamodel")

local function get_agent_value(index, parameter)
  local name = proxy.get("Device.Services.X_TELSTRA_MultiAP.Agent." .. index .. "." .. parameter)
  return name and name[1].value
end

if ngx.var.request_method == "POST" then
  local action = ngx.req.get_post_args().action
  if action then
    local reset_reboot_path
    local reset_reboot, agent = match(action, "([^%-]*)%-([^%-]*)")
    if reset_reboot == "reboot" then
      reset_reboot_path = "rpc.multiap.agent.Reboot"
    elseif reset_reboot == "reset" then
      reset_reboot_path = "rpc.multiap.agent.Reset"
    end

    if reset_reboot_path then
      local pathvalues
      if agent == "all" then
        if reset_reboot == "reset" then
          pathvalues = {
            ["rpc.mmpbxbrcmdect.registration.clear"] = "all",
            ["uci.env.var.rtfds"] = "1",
          }
          proxy.set(pathvalues)
          proxy.apply()
        end
        pathvalues = { [reset_reboot_path] = "FF:FF:FF:FF:FF:FF" }
        proxy.set(pathvalues)

        ngx.header.content_type = "application/json"
        ngx.print('{ "success":"true" }')
        ngx.timer.at(8, function()
          proxy.apply()
        end)
        ngx.exit(ngx.HTTP_OK)
      elseif agent == "boosters" then
        pathvalues = { [reset_reboot_path] = "01:80:C2:00:00:13" }
        proxy.set(pathvalues)
        ngx.timer.at(1, function()
          proxy.apply()
        end)
        message_helper.pushMessage(T("Action " .. reset_reboot .. " " .. agent .. " triggered"), "success")
      elseif tonumber(agent) then
        local agent_mac = get_agent_value(agent, "IEEE1905Id")
        if agent_mac then
          pathvalues = { [reset_reboot_path] = agent_mac }
          proxy.set(pathvalues)
          ngx.timer.at(1, function()
            proxy.apply()
          end)
          local agent = get_agent_value(agent, "Alias")
          message_helper.pushMessage(T("Action " .. reset_reboot .. " " .. agent .. " triggered"), "success")
        end
      end
    end
  end
end

-- booster table
local booster_columns = {
  { --1
    header = T"Status",
    name = "signal",
    param = "SignalStrength",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --2
    header = T"Type",
    name = "connection_type",
    param = "ConnectionType",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --3
    header = T"Firmware",
    name = "software_version",
    param = "SoftwareVersion",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --4
    header = T"Model",
    name = "model_number",
    param = "ModelNumber",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --5
    header = T"S/N",
    name = "serial_number",
    param = "SerialNumber",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --6
    header = T"2.4GHz</br>MAC Addr.",
    name = "bssid2ghz",
    param = "BSSID2GHZ",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --7
    header = T"5GHz</br>MAC Addr.",
    name = "bssid5ghz",
    param = "BSSID5GHZ",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --8
    header = T"Uptime",
    name = "uptime",
    param = "UpTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  { --9
    header = T"Index",
    name = "index",
    param = "paramindex",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
}

local booster_valid = {}

local booster_options = {
    tableid     = "booster",
    basepath    = "Device.Services.X_TELSTRA_MultiAP.Agent.",
    canAdd      = false,
    canDelete   = false,
    canApply    = false,
    canEdit     = false,
    sorted      = "paramindex",
}

local time_format = { minute = 'min', minutes='mins', second = 'sec', seconds='secs'}
local type_convert = setmetatable({
  WiFi5G = "Wi-Fi(5GHz)",
  WiFi2G = "Wi-Fi(2.4GHz)",
}, untaint_mt)

local function booster_filter(data)
  if data.MACAddress ~= "" then
    if data.UpTime ~= "" then
      data.UpTime = secondsToTime(data.UpTime) or ""
      data.UpTime = string.gsub(data.UpTime, "([^%s]+)", time_format)
    end
    data.ConnectionType = type_convert[data.ConnectionType] or data.ConnectionType
    if data.ConnectionType == "Ethernet" then
      data.SignalStrength = "Excellent"
    elseif data.SignalStrength ~= "" and tonumber(data.SignalStrength) then
      data.ConnectionType = data.ConnectionType .. "/" .. data.SignalStrength .. "dBm"
      local signal_strengh = tonumber(data.SignalStrength)
      if signal_strengh <= -127 then
        return false
      elseif signal_strengh < -85 then
        data.SignalStrength = "Weak"
      elseif signal_strengh > -75 then
        data.SignalStrength = "Excellent"
      else
        data.SignalStrength = "Good"
      end
    end
    return true
  end
  return false
end

local booster_data, booster_helpmsg = post_helper.handleTableQuery(booster_columns, booster_options, booster_filter, nil, booster_valid)

local led_options = {
  {"Normal", T"Bright"},
  {"Dim", T"Dim"},
  {"Off", T"OFF"},
}

local column_paramindex, column_type = 9, 2
local mapParams, mapValid = {}, {}

local function validateAgentName(value, object, key)
  local ok, msg = gVSLIR(1,70)(value)
  if not ok then return ok,msg end
  if match(value, "[^%w%_%-%s%@]") then
    return nil, 'only alphanumeric charaters [a-zA-Z0-9], space, "_" or "-" are allowed'
  end
  return true
end

for k,v in ipairs(booster_data) do
  local index = v[column_paramindex]
  mapParams["agent_" .. index] = "Device.Services.X_TELSTRA_MultiAP.Agent." .. index .. ".Alias"
  mapParams["led_" .. index] = "Device.Services.X_TELSTRA_MultiAP.Agent." .. index .. ".LED"
  mapValid["agent_" .. index] = validateAgentName
  mapValid["led_" .. index] = gVIES(led_options)
end

local booster_config, booster_config_helpmsg
if next(mapParams) then
  booster_config, booster_config_helpmsg = post_helper.handleQuery(mapParams, mapValid)
end

local function createButton(icon, action, text)
  return format('<div id="btn-%s" class="btn custom-handler" data-name="action" data-value="%s" style="color:#2372B9;text-shadow:0px -1px 0px rgba(0,0,0,0.25);margin-right:4px"><i class="icon-%s"></i> %s</div>', action, action, icon, text)
end

local function createConfirmMsg(html, action, msg, button_extra_class)
  local confirming = {
    alert = {
      class = "alert hide",
      id = "confirming-msg-" .. action
    }
  }
  html[#html+1] = '<div class="span11" style="margin-left:0px">'
  html[#html+1] = ui_helper.createAlertBlock(T(msg), confirming)
  html[#html+1] = string.format([[
    <div id="%s" class="hide">
      <div id="%s" class="btn btn-primary %s" data-name="action" data-value="%s">%s</div>
      <div id="%s" class="btn cancel">%s</div>
    </div>
   </div>
   ]], "changes-" .. action, "confirm-" .. action, button_extra_class or "", action, T"Confirm", "cancel-" .. action, T"Cancel")
end
  ngx.print('\
\
');  
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
<div class="container">\
');  lp.include("tabs-home.lp")   ngx.print('\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="/booster.lp">\
\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
');  
  local reboot_resetting = {
    alert = {
      class = "alert hide",
      id = "msg-reset-all"
    }
  }
  local html = {}
  html[#html+1] = '<div style="line-height:10px">&nbsp;</div>'
  html[#html+1] = createButton("refresh","reboot-all", "Reboot (Router+Boosters)", "custom-handler")
  html[#html+1] = createButton("bolt", "reset-all", "Reset (Router+Boosters)", "custom-handler")
  html[#html+1] = createButton("refresh","reboot-boosters", "Reboot Boosters", "custom-handler")
  html[#html+1] = createButton("bolt", "reset-boosters", "Reset Boosters", "custom-handler")
  html[#html+1] = ui_helper.createAlertBlock(T"Resetting the router and boosters to factory defaults, please wait...", reboot_resetting)
  createConfirmMsg(html, "reset-all", "All your configuration on your router and all boosters will be lost. Are you sure to reset the router and all boosters?", "custom-handler")

  reboot_resetting.alert.id = "msg-reboot-all"
  html[#html+1] = ui_helper.createAlertBlock(T"Rebooting the router and all boosters, please wait...", reboot_resetting)
  createConfirmMsg(html, "reboot-all", "Are you sure to reboot the router and all boosters?", "custom-handler")

  reboot_resetting.alert.id = "msg-reboot-boosters"
  html[#html+1] = ui_helper.createAlertBlock(T"Rebootinging all boosters, please wait...", reboot_resetting)
  createConfirmMsg(html, "reboot-boosters", "Are you sure to reboot all boosters?")

  reboot_resetting.alert.id = "msg-reset-boosters"
  html[#html+1] = ui_helper.createAlertBlock(T"Resetting all boosters, please wait...", reboot_resetting)
  createConfirmMsg(html, "reset-boosters", "All your configuration on all boosters will be lost. Are you sure to reset all boosters?")
  ngx.print(html)
  ngx.print('\
</fieldset>\
</fieldset>&nbsp;</br>&nbsp;<fieldset>\
');  
table.remove(booster_columns,column_paramindex)

local led_attr = {
  select = { class = "span2" },
}

for k,v in ipairs(booster_data) do
  local index = v[column_paramindex]
  table.remove(v, column_paramindex)

  html = {}
  html[#html+1] = '<fieldset>'
  local agent_attr
  if booster_config_helpmsg["agent_" .. index] then
    html[#html+1] = '<div class="control-group error span3" style="margin-left:0px">'
    agent_attr = {
      input = {
        class = "tooltip-on error span2",
        ["data-placement"] = "top",
        ["data-original-title"] = booster_config_helpmsg["agent_" .. index],
      }
    }
  else
    html[#html+1] = '<div class="control-group span3" style="margin-left:0px">'
    agent_attr = { input = { class = "span2" }}
  end
  html[#html+1] = createButton("refresh","reboot-" .. index, " ")
  html[#html+1] = createButton("bolt", "reset-" .. index, " ")
  html[#html+1] = ui_helper.createSimpleInputText("agent_" .. index, booster_config["agent_" .. index], agent_attr)
  html[#html+1] = '</div>'
  html[#html+1] = '<div class="span3">'
  html[#html+1] = '<label>LED:&nbsp;</label>'
  html[#html+1] = ui_helper.createSimpleInputSelect("led_" .. index, led_options, booster_config["led_" .. index], led_attr, booster_config_helpmsg["led_" .. index])
  html[#html+1] = '</div>'

  reboot_resetting.alert.id = "msg-reboot-" .. index
  html[#html+1] = ui_helper.createAlertBlock(T"Rebooting " .. booster_config["agent_" .. index] ..", please wait...", reboot_resetting)
  createConfirmMsg(html, "reboot-" .. index, "Are you sure to reboot " .. booster_config["agent_" .. index] .. "?")

  reboot_resetting.alert.id = "msg-reset-" .. index
  html[#html+1] = ui_helper.createAlertBlock(T"Resetting " ..booster_config["agent_" .. index] .. ", please wait...", reboot_resetting)
  createConfirmMsg(html, "reset-" .. index, "All your configuration on " .. booster_config["agent_" .. index] .. " will be lost. Are you sure to reset " ..booster_config["agent_" .. index] .. "?")
  if v[column_type] ~= "Ethernet" then
    booster_columns[column_type]["header"] = "Type/Signal"
  else
    booster_columns[column_type]["header"] = "Type"
  end
  html[#html+1] = ui_helper.createTable(booster_columns, {v}, booster_options, nil, booster_helpmsg)
  html[#html+1] = '</fieldset>'
  ngx.print(html)
end
  ngx.print('\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
');  
lp.include("footer.lp")
  ngx.print('\
<script>\
  $(document).on("click", ".btn[data-name][data-value]:not(.disabled):not(.custom-handler)", function() {\
    $(".btn[data-name][data-value]:not(.disabled):not(.custom-handler)").addClass("disabled");\
  });\
  $(document).on("click", ".btn.custom-handler",function(){\
    var str = $(this).attr("id").split("-");\
    var type = str[0];\
    var action = str[1]+"-"+str[2]\
    if (type == "btn") {\
      //var action = $(this).attr("id").match(/btn-(\\S*)/)[1];\
      $("#confirming-msg-"+action).removeClass("hide").addClass("show");\
      $("#changes-"+action).removeClass("hide").addClass("show");\
      $(".btn[data-name][data-value]:not(.disabled):not(#confirm-"+action+")").addClass("disabled");\
    } else if (type == "confirm") {\
      var target = $("form").attr("action");\
      $("#msg-"+action).removeClass("hide").addClass("show");\
      $("#confirming-msg-"+action).removeClass("show").addClass("hide");\
      $("#changes-"+action).removeClass("show").addClass("hide");\
      $.post(\
        target,\
        { action: action,  CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
        wait_for_webserver_down,\
        "json"\
      );\
      return false;\
    }\
  });\
\
  $(document).on("click", ".btn.cancel",function(){\
    var action = $(this).attr("id").match(/cancel-(\\S*)/)[1];\
    $("#confirming-msg-"+action).removeClass("show").addClass("hide");\
    $("#changes-"+action).removeClass("show").addClass("hide");\
    $(".btn.disabled[data-name][data-value]:not(#confirm-"+action+")").removeClass("disabled")\
  });\
</script>\
'); 