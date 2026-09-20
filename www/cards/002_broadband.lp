<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

-- xdsl data
local xdsl_data = {
  wans_enable       = "uci.wansensing.global.enable",
  wans_l2type       = "uci.wansensing.global.l2type",
  dsl_status        = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up   = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
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

if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
end

%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeaderNoIcon(T"Broadband", modalPath, nil, nil, nil) %>
    <div class="content">
    <%= ui_helper.createSimpleLight(nil, WS_state_map, { light = { class = WS_light_map[WS_State] } }) %>
    <%
      local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
      local iconDown = " <i class=\"icon-download icon-small gray\"></i> "

      if xdsl_data["dsl_status"] == "Up" then
        ngx.print(
          "<p><div class=\"light green\"></div>",
          T"DSL connected",
          "</p>"
        )
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
          T(xdsl_data["dsl_status"]), --this does not work !!!!
          "...</p>"
        )
      end
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
    %>

    </div>
  </div>
</div>
