--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

-- wan status data
local wan_data = {
  wans_enable       = "uci.wansensing.global.enable",
  wans_l2type       = "uci.wansensing.global.l2type",
  dsl_status        = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up   = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  ethwan_status     = "sys.eth.port.@eth4.status",
}
content_helper.getExactContent(wan_data)
local mobiled_state = {
  mob_session_state = "rpc.mobiled.device.@1.network.sessions.@1.session_state"
}
content_helper.getExactContent(mobiled_state)

local WS_en = wan_data.wans_enable
local WS_mode = wan_data.wans_l2type
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

local session = ngx.ctx.session
local modalPath
if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
end

  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Broadband", modalPath, nil, nil, nil) ); ngx.print('\
    <div class="content">\
    ');  ngx.print( ui_helper.createSimpleLight(nil, WS_state_map, { light = { class = WS_light_map[WS_State] } }) ); ngx.print('\
    ');  
      local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
      local iconDown = " <i class=\"icon-download icon-small gray\"></i> "
      local html = {}
      if wan_data["dsl_status"] == "Up" then
        html[#html+1] = ui_helper.createSimpleLight("1", "DSL connected")
        -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
        -- rate is already cleared.
        local rate_up = tonumber(wan_data["dsl_linerate_up"])
        local rate_down = tonumber(wan_data["dsl_linerate_down"])
        if rate_up and rate_down then
          rate_up = floor(rate_up / 10) / 100
          rate_down = floor(rate_down / 10) / 100
          html[#html+1] = format("<p class=\"subinfos bbsubinfos\">&emsp; %s %.2f Mbps</p>", iconUp, rate_up)
          html[#html+1] = format("<p class=\"subinfos bbsubinfos\">&emsp; %s %.2f Mbps</p>", iconDown, rate_down)
        end
      elseif wan_data["dsl_status"] == "NoSignal" then
        html[#html+1] = ui_helper.createSimpleLight("4", "DSL disconnected")
      else
        html[#html+1] = ui_helper.createSimpleLight("2", "DSL connecting")
      end
      if wan_data["ethwan_status"] == "up" then
        html[#html+1] = ui_helper.createSimpleLight("1", "Ethernet connected")
      else
        html[#html+1] = ui_helper.createSimpleLight("4", "Ethernet disconnected")
      end
      if mobiled_state["mob_session_state"] == "connected" then
        html[#html+1] = ui_helper.createSimpleLight("1", "Mobile connected")
      end
      ngx.print(html)
      ngx.print('\
    </div>\
  </div>\
</div>\
'); 