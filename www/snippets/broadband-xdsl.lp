--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format = string.format
local floor = math.floor
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable

-- Construct an uptime string from the number of seconds
local function secondsToTime(uptime)
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format(T"%ddays %dhours %dmin %dsec", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%dhours %dmin %dsec", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%dmin %dsec", minutes, seconds)
  else
    return format(T"%dsec", seconds)
  end
end

local content = {
  dsl_status = "sys.class.xdsl.@line0.Status",
  dsl_type = "sys.class.xdsl.@line0.ModulationType",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  dsl_linerate_up_max = "sys.class.xdsl.@line0.UpstreamMaxRate",
  dsl_linerate_down_max = "sys.class.xdsl.@line0.DownstreamMaxRate",
  dsl_uptime = "sys.class.xdsl.@line0.ShowtimeStart",
  dsl_power_up = "sys.class.xdsl.@line0.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line0.DownstreamPower",
  dsl_attenuation_up = "sys.class.xdsl.@line0.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line0.DownstreamAttenuation",
  dsl_margin_up = "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  dsl_transfered_up = "sys.class.xdsl.@line0.BytesSent",
  dsl_transfered_down = "sys.class.xdsl.@line0.BytesReceived",
  dsl_downstream_delay = "sys.class.xdsl.@line0.DownstreamDelay",
  dsl_bonding_support = "sys.class.xdsl.@line0.BondingSupport",
}

local content_other_line = {
  dsl_status = "sys.class.xdsl.@line1.Status",
  dsl_type = "sys.class.xdsl.@line1.ModulationType",
  dsl_linerate_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
  dsl_linerate_up_max = "sys.class.xdsl.@line1.UpstreamMaxRate",
  dsl_linerate_down_max = "sys.class.xdsl.@line1.DownstreamMaxRate",
  dsl_uptime = "sys.class.xdsl.@line1.ShowtimeStart",
  dsl_power_up = "sys.class.xdsl.@line1.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line1.DownstreamPower",
  dsl_attenuation_up = "sys.class.xdsl.@line1.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line1.DownstreamAttenuation",
  dsl_margin_up = "sys.class.xdsl.@line1.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line1.DownstreamNoiseMargin",
  dsl_transfered_up = "sys.class.xdsl.@line1.BytesSent",
  dsl_transfered_down = "sys.class.xdsl.@line1.BytesReceived",
  dsl_downstream_delay = "sys.class.xdsl.@line1.DownstreamDelay",
}

-- Get the content
content_helper.getExactContent(content)
content_helper.getExactContent(content_other_line)

local DSLMode
local ddd = tonumber(content["dsl_downstream_delay"])
if not ddd then
    DSLMode = ""
elseif ddd>2 then
    DSLMode = "Interleaved"
else
    DSLMode = "Fast"
end

local DSLMode_other_line
local ddd = tonumber(content_other_line["dsl_downstream_delay"])
if not ddd then
    DSLMode_other_line = ""
elseif ddd>2 then
    DSLMode_other_line = "Interleaved"
else
    DSLMode_other_line = "Fast"
end

local showBondingStats
local bstats = tonumber(content["dsl_bonding_support"])
if bstats == 1 then
  showBondingStats = true
else
  showBondingStats = false
end

local multimode_options = {
  {'gdmt,glite,t1413,adsl2,adsl2annexm,adsl2plus,vdsl2', 'Automatic' },
  {'t1413','T1.413'},
  {'gdmt', 'G.992.1 (G.DMT)'},
  {'glite', 'G.992.2 (G.LITE)'},
  {'adsl2', 'G.992.3 (ADSL2)'},
  {'adsl2plus', 'G.992.5 (ADSL2+)'},
  {'adsl2annexm', 'G.992.5_m (ADSL2+M)'},
--  {'vdsl2', 'G.993.2 (VDSL2)'},
}

local typemapping = setmetatable(
  {
   ["ADSL_G.dmt"]="G.DMT",
   ["ADSL_ANSI_T1.413"]="T1.413",
   ["ADSL_G.lite"]="G.LITE",
   ["ADSL_G.dmt.bis"]="ADSL2",
   ["ADSL_2plus"]="ADSL2+",
   ["ADSL_re-adsl"]="RE-ADSL2",
   ["VDSL2"]="VDSL2",
   ["G.fast"]="G.fast",
   [""]="Unknown",
  }, untaint_mt)

-- DSL enable switch
local dsl_switch_params = {
    dsl_enable = "sys.class.xdsl.@line0.Enable",
    dsl_mode = "rpc.xdsl.multimode",
}
local gVIES = post_helper.getValidateInEnumSelect
local dsl_switch_valid = {
    dsl_enable = post_helper.validateBoolean,
    dsl_mode = gVIES(multimode_options),
}
local dsl_switch_data, dsl_switch_helpmsg = post_helper.handleQuery(dsl_switch_params, dsl_switch_valid)

  ngx.print('\
\
<fieldset>\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');  
    local html = {}

    -- Icons
    local statusIcon
    if (content["dsl_status"] == "Up") or (content_other_line["dsl_status"] == "Up") then
      statusIcon = "<div class=\"light green\"></div>"
    elseif content["dsl_status"] == "NoSignal" and (content_other_line["dsl_status"] == "NoSignal") then
      statusIcon = "<div class=\"light red\"></div>"
    else
      statusIcon = "<div class=\"light orange\"></div>"
    end
    local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
    local iconDown = " <i class=\"icon-download icon-large gray\"></i> "

    -- Attributes
    local attributes = { span = { class = "span4" } }
    local attributesAdvanced = { group = { class = "advanced hide" }, span = { class = "span4" } }

    -- Display the xdsl status
    if content_other_line["dsl_status"] == "Up" then
      html[#html + 1] =
        ui_helper.createLabel(
          T"DSL Status",
          format("%s%s", statusIcon, T(content_other_line["dsl_status"]))
                                  -- ^this does not work !!!!
        )
    else
      html[#html + 1] =
        ui_helper.createLabel(
          T"DSL Status",
          format("%s%s", statusIcon, T(content["dsl_status"]))
                                  -- ^this does not work !!!!
        )
    end

    html[#html + 1] = ui_helper.createSwitch(T"DSL Enabled", "dsl_enable", dsl_switch_data["dsl_enable"])
    local info_class = {
      alert = {
        class = "alert alert-info",
      }
    }

    html[#html + 1] = "<div class='advanced hide'>"
    html[#html + 1] = ui_helper.createAlertBlock(T("Select a DSL standard that your gateway should use to connect to your ISP's exchange. Choose 'Automatic' to let your gateway choose a standard based on your distance from and type of exchange."), info_class)
    html[#html + 1] = ui_helper.createInputSelect(T"DSL Standard", "dsl_mode", multimode_options, dsl_switch_data["dsl_mode"])
    html[#html + 1] = "</div>"
    -- Statistics are only relevant if xdsl status is up
    if (content["dsl_status"] == "Up") or (content_other_line["dsl_status"] == "Up") then
      if( content["dsl_status"] == "Up") then
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", secondsToTime(content["dsl_uptime"]), attributes)
        html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(typemapping[content["dsl_type"]] or "Unknown"), attributesAdvanced)
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvanced)
      else
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", secondsToTime(content_other_line["dsl_uptime"]), attributes)
        html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(typemapping[content_other_line["dsl_type"]] or "Unknown"), attributesAdvanced)
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode_other_line), attributesAdvanced)
      end

      -- Display the xdsl maximum line rate
      local dslLineRateMaxUp, dslLineRateMaxDown = 0, 0
      local otherDslLineRateMaxUp, otherDslLineRateMaxDown = 0, 0
      if tonumber(content["dsl_linerate_up_max"]) ~= nil and tonumber(content["dsl_linerate_down_max"]) ~= nil then
        dslLineRateMaxUp = floor(content["dsl_linerate_up_max"] / 10) / 100
        dslLineRateMaxDown = floor(content["dsl_linerate_down_max"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up_max"]) ~= nil and tonumber(content_other_line["dsl_linerate_down_max"]) ~= nil then
    otherDslLineRateMaxUp = floor(content_other_line["dsl_linerate_up_max"] / 10) / 100
        otherDslLineRateMaxDown = floor(content_other_line["dsl_linerate_down_max"] / 10) / 100
  end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown, iconUp, otherDslLineRateMaxUp, iconDown, otherDslLineRateMaxDown),
            attributesAdvanced
          )
      end
      -- Display the xdsl current line rate
      local dslLineRateUp, dslLineRateDown, otherDslLineRateUp, otherDslLineRateDown = 0, 0, 0, 0
      if tonumber(content["dsl_linerate_up"]) ~= nil and tonumber(content["dsl_linerate_down"]) ~= nil then
        dslLineRateUp = floor(content["dsl_linerate_up"] / 10) / 100
        dslLineRateDown = floor(content["dsl_linerate_down"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up"]) ~= nil and tonumber(content_other_line["dsl_linerate_down"]) ~= nil then
    otherDslLineRateUp = floor(content_other_line["dsl_linerate_up"] / 10) / 100
        otherDslLineRateDown = floor(content_other_line["dsl_linerate_down"] / 10) / 100
      end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
            attributes
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown, iconUp, otherDslLineRateUp, iconDown, otherDslLineRateDown),
            attributes
          )
      end
      -- Display the amount of data transfered over the xdsl conenction
      local dslTransferedUp, dslTransferedDown, otherDslTransferedUp, otherDslTransferedDown = 0, 0, 0, 0
      if tonumber(content["dsl_transfered_up"]) ~= nil and tonumber(content["dsl_transfered_down"]) ~= nil then
        dslTransferedUp = floor(content["dsl_transfered_up"] / 1048576 * 100) / 100
        dslTransferedDown = floor(content["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      if tonumber(content_other_line["dsl_transfered_up"]) ~= nil and tonumber(content_other_line["dsl_transfered_down"]) ~= nil then
    otherDslTransferedUp = floor(content_other_line["dsl_transfered_up"] / 1048576 * 100) / 100
        otherDslTransferedDown = floor(content_other_line["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes | %s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown, iconUp, otherDslTransferedUp, iconDown, otherDslTransferedDown),
            attributesAdvanced
          )
      end
      -- Display power, attenuation and noise margin
      local dslPowerUp, dslPowerDown, otherDslPowerUp, otherDslPowerDown = 0, 0, 0, 0
      if tonumber(content["dsl_power_up"]) ~= nil and tonumber(content["dsl_power_down"]) ~= nil then
        dslPowerUp = content["dsl_power_up"]
        dslPowerDown = content["dsl_power_down"]
      end
      if tonumber(content_other_line["dsl_power_up"]) ~= nil and tonumber(content_other_line["dsl_power_down"]) ~= nil then
        otherDslPowerUp = content_other_line["dsl_power_up"]
        otherDslPowerDown = content_other_line["dsl_power_down"]
      end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm | %s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown, iconUp, otherDslPowerUp, iconDown, otherDslPowerDown),
            attributesAdvanced
          )
      end
      local dslAttenuationUp, dslAttenuationDown, otherDslAttenuationUp, otherDslAttenuationDown
      dslAttenuationUp = content["dsl_attenuation_up"]
      dslAttenuationDown = content["dsl_attenuation_down"]
      otherDslAttenuationUp = content_other_line["dsl_attenuation_up"]
      otherDslAttenuationDown = content_other_line["dsl_attenuation_down"]

      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown, iconUp, otherDslAttenuationUp, iconDown, otherDslAttenuationDown),
            attributesAdvanced
          )
      end
      local dslMarginUp, dslMarginDown, otherDslMarginUp, otherDslMarginDown = 0, 0, 0, 0
      if tonumber(content["dsl_margin_up"]) ~= nil and tonumber(content["dsl_margin_down"]) ~= nil then
        dslMarginUp = content["dsl_margin_up"]
        dslMarginDown = content["dsl_margin_down"]
      end
      if tonumber(content_other_line["dsl_margin_up"]) ~= nil and tonumber(content_other_line["dsl_margin_down"]) ~= nil then
        otherDslMarginUp = content_other_line["dsl_margin_up"]
        otherDslMarginDown = content_other_line["dsl_margin_down"]
      end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown, iconUp, otherDslMarginUp, iconDown, otherDslMarginDown),
            attributesAdvanced
          )
      end
    end
    ngx.print(html)
    ngx.print('\
\
</fieldset>\
'); 