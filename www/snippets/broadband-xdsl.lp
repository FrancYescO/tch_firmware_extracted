--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format = string.format
local floor = math.floor
local tonumber = tonumber
local session = ngx.ctx.session
local role = session:getrole()
local proxy = require("datamodel")

local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
local iconDown = "<i class=\"icon-download icon-large gray\"></i> "
local ajax_helper = require("web.ajax_helper")
local ajax_attr = {
  span = {
    ["data-ajaxrefresh"] = "5",
    class = "span4"
  }
}

local content = {}
content_other_line = {}
local DSLMode
local dslDownstream
local DSLMode_other_line
local dslOtherLine
local showBondingStats
local bstats
local multimode_options = {}
local bondingStatus
local dsl_switch_params = {}
local dsl_switch_valid = {}
local dsl_switch_data

local dslSupport = proxy.getPN("sys.class.xdsl.", true)
if dslSupport and next(dslSupport) then
  content = {
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
    dsl_bonding_status = "sys.class.xdsl.@line0.BondingStatus"
  }

  content_other_line = {
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
    dsl_downstream_delay = "sys.class.xdsl.@line1.DownstreamDelay"
  }

-- Get the content
  content_helper.getExactContent(content)
  content_helper.getExactContent(content_other_line)

  if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
    ajax_helper.handleAjaxQuery({dsl_uptime = "sys.class.xdsl.@line0.ShowtimeStart"}, function(c)
      c.dsl_uptime = post_helper.secondsToTime(c["dsl_uptime"])
      local function notnil(path)
      if path == nil or path == "" then
        return "0"
      end
      return path
    end
    c.dsl_max_linerate = format("%s %s Mbps %s %s Mbps", iconUp, floor(tonumber(notnil(content.dsl_linerate_up_max))/10)/100, iconDown, floor(tonumber(notnil(content.dsl_linerate_down_max))/10)/100)
    c.dsl_linerate = format("%s %s Mbps %s %s Mbps", iconUp, floor(tonumber(notnil(content.dsl_linerate_up))/10)/100, iconDown, floor(tonumber(notnil(content.dsl_linerate_down))/10)/100)
    c.dsl_transfered = format("%s %s MBytes %s %s MBytes", iconUp, floor(tonumber(notnil(content.dsl_transfered_up))/ 1048576 * 100)/100, iconDown, floor(tonumber(notnil(content.dsl_transfered_down))/ 1048576 * 100)/100)
    c.dsl_power = format("%s %s dBm %s %s dBm", iconUp, notnil(content.dsl_power_up), iconDown, notnil(content.dsl_power_down))
    c.dsl_attenuation = format("%s %s dB %s %s dB", iconUp, notnil(content.dsl_attenuation_up), iconDown, notnil(content.dsl_attenuation_down))
    c.dsl_margin = format("%s %s dB %s %s dB", iconUp, notnil(content.dsl_margin_up), iconDown, notnil(content.dsl_margin_down))
  end)
end

dslDownstream = tonumber(content["dsl_downstream_delay"])
if not dslDownstream then
  DSLMode = ""
elseif dslDownstream > 2 then
  DSLMode = "Interleaved"
else
  DSLMode = "Fast"
end

dslOtherLine = tonumber(content_other_line["dsl_downstream_delay"])
if not dslOtherLine then
  DSLMode_other_line = ""
elseif dslOtherLine > 2 then
  DSLMode_other_line = "Interleaved"
else
  DSLMode_other_line = "Fast"
end

bstats = tonumber(content["dsl_bonding_support"])
showBondingStats = bstats == 1 and true or false

multimode_options = {
  {'gdmt, glite, t1413, adsl2, adsl2annexm, adsl2plus, vdsl2', 'Automatic'},
  {'t1413','T1.413'},
  {'gdmt', 'G.992.1 (G.DMT)'},
  {'glite', 'G.992.2 (G.LITE)'},
  {'adsl2', 'G.992.3 (ADSL2)'},
  {'adsl2plus', 'G.992.5 (ADSL2+)'},
  {'adsl2annexm', 'G.992.5_m (ADSL2+M)'},
  {'vdsl2', 'G.993.2 (VDSL2)'}
}

bondingStatus = tonumber(content["dsl_bonding_status"])

-- DSL enable switch
dsl_switch_params = {
  dsl_enable = "sys.class.xdsl.@line0.Enable"
}
dsl_switch_valid = {
  dsl_enable = post_helper.validateBoolean
}
if post_helper.isFeatureEnabled("broadBandModalDSL", role) then
  dsl_switch_params.dsl_mode = "rpc.xdsl.multimode"
  dsl_switch_params.rnc_enable = "sys.class.xdsl.@line0.RNCEnable"
  dsl_switch_valid.dsl_mode = post_helper.getValidateInEnumSelect(multimode_options)
  dsl_switch_valid.rnc_enable = post_helper.validateBoolean
end
dsl_switch_data = post_helper.handleQuery(dsl_switch_params, dsl_switch_valid)
end
  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
  <div id = "broadbandView">\
  ');  
    local html = {}
    -- Icons
    local statusIcon
    if (content and content["dsl_status"] == "Up") or (content_other_line and content_other_line["dsl_status"] == "Up") then
      statusIcon = "<div class=\"light green\" id = \"DSL_Status_Id\"></div>"
    elseif (content and content["dsl_status"] == "NoSignal") and (content_other_line and content_other_line["dsl_status"] == "NoSignal") then
      statusIcon = "<div class=\"light red\" id = \"DSL_Status_Id\"></div>"
    elseif post_helper.isFeatureEnabled("ethernetStatus", role) and #content == 0 and #content_other_line == 0 then
      html[#html + 1] = ui_helper.createLight(T"Status", nil, "Ethernet not connected", { light = { class = "red" } })
    else
      statusIcon = "<div class=\"light orange\" id = \"DSL_Status_Id\"></div>"
    end
    iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
    iconDown = " <i class=\"icon-download icon-large gray\"></i> "

    -- Attributes
    local attributesAdvanced = { group = { class = "advanced hide" }, span = { class = "span4" } }
    local attributes = { span = { class = "span4" } }
    if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
      attributesAdvanced = { span = { class = "span4" } }
      attributes = ajax_attr
    end

    -- Display the xdsl status
    if content_other_line and content_other_line["dsl_status"] == "Up" then
      html[#html + 1] = ui_helper.createLabel(T"DSL Status", format("%s%s", statusIcon, T(content_other_line["dsl_status"])))
    elseif content and content["dsl_status"] then
      html[#html + 1] = ui_helper.createLabel(T"DSL Status", format("%s%s", statusIcon, T(content["dsl_status"])))
    end

      local infomessage = {
        alert = {
          class = "alert-info"
        }
      }
    if not post_helper.isFeatureEnabled("broadBandModalPVC", role) and role == "admin" then
      local intf_state
      local intf_state_map = {
        disabled = T"disabled",
        connected = T"enabled",
        disconnected = T"VLAN not connected"
      }
      local intf_light_map = {
        disabled = "off",
        disconnected = "red",
        connected = "green"
      }

      intf_state = dsl_switch_data["dsl_enable"] == "1" and "connected" or "disabled"
      html[#html + 1] = ui_helper.createLight(T"DSL", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
    elseif dsl_switch_data then
      if role ~= "admin" and not post_helper.isFeatureEnabled("broadBandModalView", role) or post_helper.isFeatureEnabled("broadBandModalView", role) then
        html[#html + 1] = ui_helper.createSwitch(T"DSL Enabled", "dsl_enable", dsl_switch_data["dsl_enable"])
      end
    end
    if not post_helper.isFeatureEnabled("broadBandHelper", role) or (post_helper.isFeatureEnabled("broadBandModalDSL", role) and role ~= "admin") then
      html[#html + 1] = "<div class='advanced hide'>"
      html[#html + 1] = ui_helper.createAlertBlock(T"Select a DSL standard that your gateway should use to connect to your ISP's exchange. Choose 'Automatic' to let your gateway choose a standard based on your distance from and type of exchange.", infomessage)
      html[#html + 1] = ui_helper.createInputSelect(T"DSL Standard", "dsl_mode", multimode_options, dsl_switch_data and dsl_switch_data["dsl_mode"])
      if post_helper.isFeatureEnabled("broadBandHelper", role) then
        -- Tie GUI into RNC enable UCI control
        html[#html + 1] = ui_helper.createSwitch(T"RNC Enabled", "rnc_enable", dsl_switch_data and dsl_switch_data["rnc_enable"])
        if (bondingStatus == 1) then
          html[#html + 1] = ui_helper.createLabel(T"DSL Bonding", T"Yes", attributesAdvanced)
        else
          html[#html + 1] = ui_helper.createLabel(T"DSL Bonding", T"No", attributesAdvanced)
        end
      end
      html[#html + 1] = "</div>"
    end

    -- Statistics are only relevant if xdsl status is up
    if( content and content["dsl_status"] == "Up") or (content_other_line and content_other_line["dsl_status"] == "Up") then
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
          ajax_attr.span.id = "dsl_uptime"
      end
      if (content and content["dsl_status"] == "Up") then
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", post_helper.secondsToTime(content["dsl_uptime"]), attributes)
        if post_helper.isFeatureEnabled("broadBandModalPVC", role) then
          html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content["dsl_type"]), attributesAdvanced)
          html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvanced)
        else
           local attributesAdvancedMode = { group = { class = "advanced hide" }, span = { class = "span4" } }
           if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
             attributesAdvancedMode = { span = { class = "span4" } }
             attributes = ajax_attr
           end
           html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content["dsl_type"]), attributesAdvancedMode)
           html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvancedMode)
        end
      else
        html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", post_helper.secondsToTime(content_other_line and content_other_line["dsl_uptime"]), attributes)
        html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content_other_line["dsl_type"]), attributesAdvanced)
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode_other_line), attributesAdvanced)
      end

      -- Display the xdsl maximum line rate
      local dslLineRateMaxUp, dslLineRateMaxDown = 0, 0
      local otherDslLineRateMaxUp, otherDslLineRateMaxDown = 0, 0
      if tonumber(content["dsl_linerate_up_max"]) and tonumber(content["dsl_linerate_down_max"]) then
        dslLineRateMaxUp = floor(content["dsl_linerate_up_max"] / 10) / 100
        dslLineRateMaxDown = floor(content["dsl_linerate_down_max"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up_max"]) and tonumber(content_other_line["dsl_linerate_down_max"]) then
        otherDslLineRateMaxUp = floor(content_other_line["dsl_linerate_up_max"] / 10) / 100
        otherDslLineRateMaxDown = floor(content_other_line["dsl_linerate_down_max"] / 10) / 100
  end
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id = "dsl_linerate"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown, iconUp, otherDslLineRateMaxUp, iconDown, otherDslLineRateMaxDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
            attributesAdvanced
          )
      end
      -- Display the xdsl current line rate
      local dslLineRateUp, dslLineRateDown, otherDslLineRateUp, otherDslLineRateDown = 0, 0, 0, 0
      if tonumber(content["dsl_linerate_up"]) and tonumber(content["dsl_linerate_down"]) then
        dslLineRateUp = floor(content["dsl_linerate_up"] / 10) / 100
        dslLineRateDown = floor(content["dsl_linerate_down"] / 10) / 100
      end
      if tonumber(content_other_line["dsl_linerate_up"]) and tonumber(content_other_line["dsl_linerate_down"]) then
    otherDslLineRateUp = floor(content_other_line["dsl_linerate_up"] / 10) / 100
        otherDslLineRateDown = floor(content_other_line["dsl_linerate_down"] / 10) / 100
      end
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id = "dsl_linerate"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps | %s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown, iconUp, otherDslLineRateUp, iconDown, otherDslLineRateDown),
            attributes
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
            attributes
          )
      end
      -- Display the amount of data transfered over the xdsl conenction
      local dslTransferedUp, dslTransferedDown, otherDslTransferedUp, otherDslTransferedDown = 0, 0, 0, 0
      if tonumber(content["dsl_transfered_up"]) and tonumber(content["dsl_transfered_down"]) then
        dslTransferedUp = floor(content["dsl_transfered_up"] / 1048576 * 100) / 100
        dslTransferedDown = floor(content["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      if tonumber(content_other_line["dsl_transfered_up"]) and tonumber(content_other_line["dsl_transfered_down"]) then
    otherDslTransferedUp = floor(content_other_line["dsl_transfered_up"] / 1048576 * 100) / 100
        otherDslTransferedDown = floor(content_other_line["dsl_transfered_down"] / 1048576 * 100) / 100
      end
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id="dsl_transfered"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes | %s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown, iconUp, otherDslTransferedUp, iconDown, otherDslTransferedDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown),
            attributesAdvanced
          )
      end
      -- Display power, attenuation and noise margin
      local dslPowerUp, dslPowerDown, otherDslPowerUp, otherDslPowerDown = 0, 0, 0, 0
      if tonumber(content["dsl_power_up"]) and tonumber(content["dsl_power_down"]) then
        dslPowerUp = content["dsl_power_up"]
        dslPowerDown = content["dsl_power_down"]
      end
      if tonumber(content_other_line["dsl_power_up"]) and tonumber(content_other_line["dsl_power_down"]) then
        otherDslPowerUp = content_other_line["dsl_power_up"]
        otherDslPowerDown = content_other_line["dsl_power_down"]
      end
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id="dsl_power"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm | %s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown, iconUp, otherDslPowerUp, iconDown, otherDslPowerDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm", iconUp, dslPowerUp, iconDown, dslPowerDown),
            attributesAdvanced
          )
      end
      local dslAttenuationUp, dslAttenuationDown, otherDslAttenuationUp, otherDslAttenuationDown
      dslAttenuationUp = content["dsl_attenuation_up"]
      dslAttenuationDown = content["dsl_attenuation_down"]
      otherDslAttenuationUp = content_other_line["dsl_attenuation_up"]
      otherDslAttenuationDown = content_other_line["dsl_attenuation_down"]
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id="dsl_attenuation"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown, iconUp, otherDslAttenuationUp, iconDown, otherDslAttenuationDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown),
            attributesAdvanced
          )
      end
      local dslMarginUp, dslMarginDown, otherDslMarginUp, otherDslMarginDown = 0, 0, 0, 0
      if tonumber(content["dsl_margin_up"]) and tonumber(content["dsl_margin_down"]) then
        dslMarginUp = content["dsl_margin_up"]
        dslMarginDown = content["dsl_margin_down"]
      end
      if tonumber(content_other_line["dsl_margin_up"]) and tonumber(content_other_line["dsl_margin_down"]) then
        otherDslMarginUp = content_other_line["dsl_margin_up"]
        otherDslMarginDown = content_other_line["dsl_margin_down"]
      end
      if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
        ajax_attr.span.id="dsl_margin"
      end
      if showBondingStats then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown, iconUp, otherDslMarginUp, iconDown, otherDslMarginDown),
            attributesAdvanced
          )
      else
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB", iconUp, dslMarginUp, iconDown, dslMarginDown),
            attributesAdvanced
          )
      end
    end
    ngx.print(html)
    ngx.print('\
</div>\
</fieldset>\
'); 