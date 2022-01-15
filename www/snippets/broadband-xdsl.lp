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
  dsl_bonding_support = "sys.class.xdsl.@line0.BondingStatus",
  dsl_profile_name = "sys.class.xdsl.@line0.ProfileName",
  --telmex specific paramter
  dsl_latn_up = "sys.class.xdsl.@line0.UpstreamLATN",
  dsl_latn_down = "sys.class.xdsl.@line0.DownstreamLATN",
  dsl_satn_up = "sys.class.xdsl.@line0.UpstreamSATN",
  dsl_satn_down = "sys.class.xdsl.@line0.DownstreamSATN",
  dsl_snrm_up = "sys.class.xdsl.@line0.UpstreamSNRMpb",
  dsl_snrm_down = "sys.class.xdsl.@line0.DownstreamSNRMpb",
  dsl_kl0 = "sys.class.xdsl.@line0.UPBOKLE",
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
  dsl_bonding_support = "sys.class.xdsl.@line1.BondingStatus",
  dsl_profile_name = "sys.class.xdsl.@line1.ProfileName",
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
local bstats1 = tonumber(content_other_line["dsl_bonding_support"])
if (bstats == 1) or (bstats1 == 1) then
  showBondingStats = true
else
  showBondingStats = false
end

-- DSL enable switch
local dsl_switch_params = {
    dsl_enable = "sys.class.xdsl.@line0.Enable",
}
local dsl_switch_valid = {
    dsl_enable = post_helper.validateBoolean,
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

    -- Statistics are only relevant if xdsl status is up
    -- Statistics are only relevant if xdsl status is up
    if (content["dsl_status"] == "Up") or (content_other_line["dsl_status"] == "Up") then
		if (content["dsl_status"] == "Up") then
			html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", secondsToTime(content["dsl_uptime"]), attributes)
			html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content["dsl_type"]), attributesAdvanced)
				if (content["dsl_type"] == "VDSL2") then
					html[#html + 1] = ui_helper.createLabel(T"VDSL2 Profile",T(content["dsl_profile_name"]),attributesAdvanced)
				end
					html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvanced)
		else
			if (content_other_line["dsl_status"] == "Up") then
			html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", secondsToTime(content_other_line["dsl_uptime"]), attributes)
			html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content_other_line["dsl_type"]), attributesAdvanced)
				if (content_other_line["dsl_type"] == "VDSL2") then
					html[#html + 1] = ui_helper.createLabel(T"VDSL2 Profile",T(content_other_line["dsl_profile_name"]),attributesAdvanced)
				end
				html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode_other_line), attributesAdvanced)
			end
		end

   -- Display the specific info base on Telmex
      --kl0 start
        dslKl0 = content["dsl_kl0"]
        if content["dsl_type"] == "VDSL2" then
			html[#html + 1] =
			  ui_helper.createLabel(
				T"KL0",
				format("%.2f dB",tonumber(dslKl0)/100),
				attributesAdvanced
			  )
        end
      --kl0 end
	--local function for display multi line
	local function displayList(up, down, name)
		  local i = 0
		  local downtable = {}
		  local uptable = {}
		  line = format("<table>")
		  dslUp = content[up]
		  dslDown = content[down]
          if content["dsl_type"] == "VDSL2" then
			  for token in string.gmatch(dslDown, "[^,%s]+") do
			    if token == "N/A" then
				   token = format("&ensp;%s", token)
                else
				   token = format("&ensp;%s dB", token)
				end
				downtable[i] = token
				i = i + 1
			  end
			  i = 0
			  for token in string.gmatch(dslUp, "[^,%s]+") do
			    if token == "N/A" then
				   token = format("&ensp;%s", token)
                else
				   token = format("&ensp;%s dB", token)
				end
				uptable[i] = token
				i = i + 1
			  end
			  for i=0, 4, 1 do
                  if downtable[i] == nil then
				     downtable[i] = format("&ensp;%s","N/A")
				  end
                  if uptable[i] == nil then
				     uptable[i] = format("&ensp;%s","N/A")
				  end
				  if i == 0 then
						line = format("%s <tr> <td>%s</td> <td>US%s</td> <td>%s</td> <td>%s<td> <td>DS%s</td> <td>%s</td> </tr>", line, iconUp, i, uptable[i], iconDown, i+1, downtable[i])
                  elseif i == 3 or i == 4 then
						line = format("%s <tr> <td>%s</td> <td>US%s</td> <td>%s</td> <td>%s<td> </tr>", line, "", i, uptable[i], "")
				  else
						line = format("%s <tr> <td>%s</td> <td>US%s</td> <td>%s</td> <td>%s<td> <td>DS%s</td> <td>%s</td> </tr>", line, "", i, uptable[i], "", i+1, downtable[i])
				  end
			  end

			  line = format("%s </table>",line)
			  html[#html + 1] =
				ui_helper.createLabel(
				  name,
				  line,
				  attributesAdvanced
				)
          end
	end
   -- End of Display the specific info base on Telmex

      -- Display the xdsl maximum line rate
      local dslLineRateMaxUp, dslLineRateMaxDown = 0, 0
      local otherDslLineRateMaxUp, otherDslLineRateMaxDown = 0, 0
      if tonumber(content["dsl_linerate_up_max"]) ~= nil and tonumber(content["dsl_linerate_down_max"]) ~= nil then
        dslLineRateMaxUp = content["dsl_linerate_up_max"]
        dslLineRateMaxDown = content["dsl_linerate_down_max"]
      end
      if tonumber(content_other_line["dsl_linerate_up_max"]) ~= nil and tonumber(content_other_line["dsl_linerate_down_max"]) ~= nil then
    otherDslLineRateMaxUp = content_other_line["dsl_linerate_up_max"]
        otherDslLineRateMaxDown = content_other_line["dsl_linerate_down_max"]
  end
	if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Maximum Line rate",
            format("%s %s Kbps %s %s Kbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
            attributesAdvanced
          )
    else
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then 
			html[#html + 1] =
			  ui_helper.createLabel(
				T"Maximum Line rate",
				format("%s %s Kbps %s %s Kbps | %s %s Kbps %s %s Kbps", iconUp, otherDslLineRateMaxUp, iconDown, otherDslLineRateMaxDown, iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
				attributesAdvanced
			  )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
				html[#html + 1] =
				  ui_helper.createLabel(
					T"Maximum Line rate",
					format("%s %s Kbps %s %s Kbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
					attributesAdvanced
				  )
			else
				html[#html + 1] =
			  ui_helper.createLabel(
				T"Maximum Line rate",
				format("%s %s Kbps %s %s Kbps", iconUp, otherDslLineRateMaxUp, iconDown, otherDslLineRateMaxDown),
				attributesAdvanced
			  )
			end
		end
	end
      -- Display the xdsl current line rate
      local dslLineRateUp, dslLineRateDown, otherDslLineRateUp, otherDslLineRateDown = 0, 0, 0, 0
      if tonumber(content["dsl_linerate_up"]) ~= nil and tonumber(content["dsl_linerate_down"]) ~= nil then
        dslLineRateUp = content["dsl_linerate_up"]
        dslLineRateDown = content["dsl_linerate_down"]
      end
      if tonumber(content_other_line["dsl_linerate_up"]) ~= nil and tonumber(content_other_line["dsl_linerate_down"]) ~= nil then
        otherDslLineRateUp = content_other_line["dsl_linerate_up"]
        otherDslLineRateDown = content_other_line["dsl_linerate_down"]
      end
      if showBondingStats ~= true then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Rate",
            format("%s %s Kbps %s %s Kbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
            attributes
          )
      else
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then 
			html[#html + 1] =
			  ui_helper.createLabel(
				T"Line rate",
				format("%s %s Kbps %s %s Kbps | %s %s Kbps %s %s Kbps", iconUp, otherDslLineRateUp, iconDown, otherDslLineRateDown, iconUp, dslLineRateUp, iconDown, dslLineRateDown),
				attributes
			  )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
				html[#html + 1] =
				  ui_helper.createLabel(
					T"Line rate",
					format("%s %s Kbps %s %s Kbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
					attributes
				  )
			else
				html[#html + 1] =
			  ui_helper.createLabel(
				T"Line rate",
				format("%s %s Kbps %s %s Kbps", iconUp, otherDslLineRateUp, iconDown, otherDslLineRateDown),
				attributes
			  )
			end
		end
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
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then 
        html[#html + 1] =
          ui_helper.createLabel(
            T"Data Transferred",
            format("%s %s MBytes %s %s MBytes | %s %s MBytes %s %s MBytes", iconUp, otherDslTransferedUp, iconDown, otherDslTransferedDown, iconUp, dslTransferedUp, iconDown, dslTransferedDown),
            attributesAdvanced
          )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
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
					format("%s %s MBytes %s %s MBytes", iconUp, otherDslTransferedUp, iconDown, otherDslTransferedDown),
					attributesAdvanced
				  )
			end
		end
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
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then 
        html[#html + 1] =
          ui_helper.createLabel(
            T"Output Power",
            format("%s %s dBm %s %s dBm | %s %s dBm %s %s dBm", iconUp, otherDslPowerUp, iconDown, otherDslPowerDown, iconUp, dslPowerUp, iconDown, dslPowerDown),
            attributesAdvanced
          )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
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
					format("%s %s dBm %s %s dBm", iconUp, otherDslPowerUp, iconDown, otherDslPowerDown),
					attributesAdvanced
				  )
			end
		end
      end
      local dslAttenuationUp, dslAttenuationDown, otherDslAttenuationUp, otherDslAttenuationDown
      local lineAttenuation, token
      local i = 0
      local t = {}
      dslAttenuationUp = content["dsl_attenuation_up"]
      dslAttenuationDown = content["dsl_attenuation_down"]
      otherDslAttenuationUp = content_other_line["dsl_attenuation_up"]
      otherDslAttenuationDown = content_other_line["dsl_attenuation_down"]
      if showBondingStats ~= true then
        if content["dsl_type"] == "VDSL2" then
		   displayList("dsl_attenuation_up", "dsl_attenuation_down", T"Loop Attenuation by Band")
		   displayList("dsl_satn_up", "dsl_satn_down", T"Signal Attenuation by Band")
		   displayList("dsl_snrm_up", "dsl_snrm_down", T"Signal-noise Ratio Margin by Band")
        else --VDSL
          html[#html + 1] =
            ui_helper.createLabel(
              T"Line Attenuation",
              format("%s %s dB %s %s dB", iconUp, dslAttenuationUp, iconDown, dslAttenuationDown),
              attributesAdvanced
            )
        end
      else --showBondingStats
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then 
        html[#html + 1] =
          ui_helper.createLabel(
            T"Line Attenuation",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, otherDslAttenuationUp, iconDown, otherDslAttenuationDown, iconUp, dslAttenuationUp, iconDown, dslAttenuationDown),
            attributesAdvanced
            )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
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
					format("%s %s dB %s %s dB", iconUp, otherDslAttenuationUp, iconDown, otherDslAttenuationDown),
					attributesAdvanced
					)
			end
		end
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
		if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "Up") then
        html[#html + 1] =
          ui_helper.createLabel(
            T"Noise Margin",
            format("%s %s dB %s %s dB | %s %s dB %s %s dB", iconUp, otherDslMarginUp, iconDown, otherDslMarginDown, iconUp, dslMarginUp, iconDown, dslMarginDown),
            attributesAdvanced
          )
		else
			if (content["dsl_status"] == "Up") and (content_other_line["dsl_status"] == "NoSignal") then 
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
					format("%s %s dB %s %s dB", iconUp, otherDslMarginUp, iconDown, otherDslMarginDown),
					attributesAdvanced
				  )
			end
		end
      end
    end
    ngx.print(html)
    ngx.print('\
\
</fieldset>\
'); 