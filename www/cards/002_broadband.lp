<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local dyntab_helper = require("web.dyntab_helper")
local bmh = require("broadbandmode_helper").get()
local bridged = require("bridgedmode_helper")
local tabdata = dyntab_helper.process(bmh)
local mode_current = tabdata.current.name

-- xdsl data
local xdsl_data = {
  wans_enable       = "uci.wansensing.global.enable",
  wans_l2type       = "uci.wansensing.global.l2type",
  dsl_status        = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up   = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  vid_wan           = "uci.network.device.@vlan_ppp.vid",
  vid_hfc           = "uci.network.device.@vlan_hfc.vid",
  vid_video         = "uci.network.device.@vlan_video.vid",
}
content_helper.getExactContent(xdsl_data)

local WS_en = xdsl_data.wans_enable
local WS_mode = xdsl_data.wans_l2type
if WS_mode == "" then
  WS_mode = "NONE"
end
local WS_State
if WS_en == "1" then
   if WS_mode == "NONE" then
      WS_State = "None"
      WS_state_map = T"WAN Sensing L2: None"
   else
      WS_State = "Enabled"
      WS_state_map = format(T"WAN Sensing L2: %s",WS_mode)
   end
else
   WS_State = "Disabled"
   WS_state_map = T"WAN Sensing: Disabled"
end

local WS_light_map = {
  Disabled = "off",
  None = "orange",
  Enabled = "green",
}


-- eth data
local eth_data = {
  ethwan_status = "sys.eth.port.@eth4.status",
}
content_helper.getExactContent(eth_data)

local session = ngx.ctx.session

local modalPath

if not bridged.isBridgedMode() then
    if session:hasAccess("/modals/broadband-modal.lp") then
        modalPath = "modals/broadband-modal.lp"
    end
else
    if session:hasAccess("/modals/broadband-bridge-modal.lp") then
        modalPath = "modals/broadband-bridge-modal.lp"
    end
end
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"Broadband", modalPath, nil, nil, nil) %>
    <div class="content">
    <%= ui_helper.createSimpleLight(nil, WS_state_map, { light = { class = WS_light_map[WS_State] } }) %>
    <%
      local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
      local iconDown = " <i class=\"icon-download icon-small gray\"></i> "

      --As the customer required: when no line connected, all status have to show as disconnected.
      if xdsl_data["dsl_status"] == "NoSignal" and eth_data["ethwan_status"] ~= "up" then
        ngx.print(
                  "<p><div class=\"light red\"></div>",
                  T"DSL disconnected",
                  "</p>"
                 )
        ngx.print(
                  "<p><div class=\"light red\"></div>",
                  T"Ethernet disconnected",
                  "</p>"
                 )
      else
        if mode_current ~= "ethernet" and mode_current ~= "ethernetvlan" then
          if xdsl_data["dsl_status"] == "Up" then
            ngx.print(
              "<p><div class=\"light green\"></div>",
              T"DSL connected",
              "</p>"
            )
        if mode_current == "vdslvlan" then
            ngx.print(
              "<p>",
              T"VLAN ID for PPPoE: ",
              xdsl_data["vid_wan"],
              "</p>"
            )
            ngx.print(
              "<p>",
              T"VLAN ID for Video: ",
              xdsl_data["vid_video"],
              "</p>"
            )
        end
            -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
            -- rate is already cleared.
            local rate_up = tonumber(xdsl_data["dsl_linerate_up"])
            local rate_down = tonumber(xdsl_data["dsl_linerate_down"])
            if rate_up and rate_down then
              rate_up = floor(rate_up / 10) / 100
              rate_down = floor(rate_down / 10) / 100
              ngx.print(
                "<p class=\"subinfos\">&emsp; ",
                iconUp,
                format("%.2f Mbps", rate_up),
                "</p>",
                "<p class=\"subinfos\">&emsp; ",
                iconDown,
                format('%.2f Mbps', rate_down),
                "</p>"
              )
            end
          elseif xdsl_data["dsl_status"] == "NoSignal" then
            ngx.print(
              "<p><div class=\"light red\"></div>",
              T"DSL disconnected",
              "</p>"
            )
          else
            ngx.print(
              "<p><div class=\"light orange\"></div>",
              T"DSL connecting",
              ": ",
              xdsl_data["dsl_status"],
              "...</p>"
            )
          end
        else
          if eth_data["ethwan_status"] == "up" then
            ngx.print(
              "<p><div class=\"light green\"></div>",
              T"Ethernet connected",
              "</p>"
              )
          else
            ngx.print(
              "<p><div class=\"light red\"></div>",
              T"Ethernet disconnected",
              "</p>"
            )
          end
          if mode_current == "ethernetvlan" then
            ngx.print(
              "<p>",
              T"VLAN ID for PPPoE: ",
              xdsl_data["vid_hfc"],
              "</p>"
            )
          end
        end
      end
      %>

    </div>
  </div>
</div>
