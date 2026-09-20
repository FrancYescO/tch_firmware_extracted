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
}

-- Get the content
content_helper.getExactContent(content)

local DSLMode
local ddd = tonumber(content["dsl_downstream_delay"])
if not ddd then
    DSLMode = ""
elseif ddd>2 then
    DSLMode = "Interleaved"
else
    DSLMode = "Fast"
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Broadband", true, true, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
');  
    local html = {}
    local tabs = {
        {
            desc = T"DSL link status",
            active = "active",
            target = "modals/broadband-modal.lp",
        },
        {
            desc = T"Ethernet link status",
            target = "modals/broadband-eth-modal.lp",
        },
        {
            desc = T"DSL Diagnostics",
            target = "modals/diagnostics-xdsl-modal.lp?entry=bb",
        },
    }
    table.insert (html, ui_helper.createModalTabs(tabs))
    ngx.print (html)
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
    <fieldset>\
      ');  
        local html = {}

        -- Icons
        local statusIcon
        if content["dsl_status"] == "Up" then
          statusIcon = "<div class=\"light green\"></div>"
        elseif content["dsl_status"] == "NoSignal" then
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
        html[#html + 1] =
          ui_helper.createLabel(
            T"DSL Status",
            format("%s%s", statusIcon, T(content["dsl_status"]))
          )

        -- Statistics are only relevant if xdsl status is up
        if content["dsl_status"] == "Up" then
          html[#html + 1] = ui_helper.createLabel(T"DSL Uptime", post_helper.secondsToTime(content["dsl_uptime"]), attributes)
          html[#html + 1] = ui_helper.createLabel(T"DSL Type", T(content["dsl_type"]), attributesAdvanced)

          html[#html + 1] = ui_helper.createLabel(T"DSL Mode", T(DSLMode), attributesAdvanced)

          -- Display the xdsl maximum line rate
          local dslLineRateMaxUp = floor(content["dsl_linerate_up_max"] / 10) / 100
          local dslLineRateMaxDown = floor(content["dsl_linerate_down_max"] / 10) / 100
          html[#html + 1] =
            ui_helper.createLabel(
              T"Maximum Line rate",
              format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateMaxUp, iconDown, dslLineRateMaxDown),
              attributesAdvanced
            )

          -- Display the xdsl current line rate
          local dslLineRateUp = floor(content["dsl_linerate_up"] / 10) / 100
          local dslLineRateDown = floor(content["dsl_linerate_down"] / 10) / 100
          html[#html + 1] =
            ui_helper.createLabel(
              T"Line Rate",
              format("%s %s Mbps %s %s Mbps", iconUp, dslLineRateUp, iconDown, dslLineRateDown),
              attributes
            )

          -- Display the amount of data transfered over the xdsl conenction
          local dslTransferedUp, dslTransferedDown
          if tonumber(content["dsl_transfered_up"]) ~= nil and tonumber(content["dsl_transfered_down"]) ~= nil then
            dslTransferedUp = floor(content["dsl_transfered_up"] / 1048576 * 100) / 100
            dslTransferedDown = floor(content["dsl_transfered_down"] / 1048576 * 100) / 100
          else
            dslTransferedUp = 0
            dslTransferedDown = 0
          end
          html[#html + 1] =
            ui_helper.createLabel(
              T"Data Transferred",
              format("%s %s MBytes %s %s MBytes", iconUp, dslTransferedUp, iconDown, dslTransferedDown),
              attributesAdvanced
            )

          -- Display power, attenuation and noise margin
          html[#html + 1] =
            ui_helper.createLabel(
              T"Output Power",
              format("%s %s dBm %s %s dBm", iconUp, content["dsl_power_up"], iconDown, content["dsl_power_down"]),
              attributesAdvanced
            )
          html[#html + 1] =
            ui_helper.createLabel(
              T"Line Attenuation",
              format("%s %s dB %s %s dB", iconUp, content["dsl_attenuation_up"], iconDown, content["dsl_attenuation_down"]),
              attributesAdvanced
            )
          html[#html + 1] =
            ui_helper.createLabel(
              T"Noise Margin",
              format("%s %s dB %s %s dB", iconUp, content["dsl_margin_up"], iconDown, content["dsl_margin_down"]),
              attributesAdvanced
            )
        end
        ngx.print(html)
        ngx.print('\
\
    </fieldset>\
    </form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 