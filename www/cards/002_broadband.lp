--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local dyntab_helper = require("web.dyntab_helper")
local lp = require("web.lp")
local session = ngx.ctx.session
local role = session:getrole()
local bridged = require("bridgedmode_helper")

local function statusView()
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
    vid_voip         = "uci.network.device.@vlan_voip.vid",
    variant          = "uci.env.var.iinet_variant"
  }
  content_helper.getExactContent(xdsl_data)

  local WS_State, WS_state_map
  if xdsl_data.wans_enable == "1" then
    if xdsl_data.wans_l2type == "" then
      WS_State = "None"
      WS_state_map = T"WAN Sensing L2: None"
    else
      WS_State = "Enabled"
      WS_state_map = format(T"WAN Sensing L2: %s", xdsl_data.wans_l2type)
    end
  else
    WS_State = "Disabled"
    WS_state_map = T"WAN Sensing: Disabled"
  end

  local WS_light_map = {
    Disabled = "off",
    None = "orange",
    Enabled = "green"
  }

  -- eth data
  local eth_data = {
    ethwan_status = "sys.eth.port.@eth4.status"
  }
  content_helper.getExactContent(eth_data)

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
    ngx.print('\
  <div class="span3">\
    <div class="smallcard">\
      ');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath, nil, nil, nil) ); ngx.print('\
      <div class="content">\
      ');  if xdsl_data.variant ~= "novus" then   ngx.print('\
       ');  ngx.print( ui_helper.createSimpleLight(nil, WS_state_map, { light = { class = WS_light_map[WS_State] } }) ); ngx.print('\
      ');  end    ngx.print('\
      ');  
      local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
      local iconDown = " <i class=\"icon-download icon-small gray\"></i> "

      --As the customer required: when no line connected, all status have to show as disconnected.
      if xdsl_data["dsl_status"] == "NoSignal" and eth_data["ethwan_status"] ~= "up" then
        ngx.print(
                  "<div class='simple-desc'>",
                  "<div class=\"light red\"></div>",
                  T"DSL disconnected",
                  "</div>"
                 )
        ngx.print(
                  "<div class='simple-desc'>",
                  "<div class=\"light red\"></div>",
                  T"Ethernet disconnected",
                  "</div>"
                 )
      else
        if mode_current ~= "ethernet" and mode_current ~= "ethernetvlan" then
          if xdsl_data["dsl_status"] == "Up" then
            ngx.print(
              "<div class='simple-desc'>",
              "<div class=\"light green\"></div>",
              T"DSL connected",
              "</div>"
            )
            ngx.print("<p class='subinfos'>")
            if mode_current == "vdslvlan" then
              if xdsl_data.variant ~= "novus" then
                ngx.print(
                  T"VLAN ID for PPPoE: ",
                  xdsl_data["vid_wan"],
                  "</br>"
                )
              else
                ngx.print(
                  T"VLAN ID for PPPoE: ",
                  xdsl_data["vid_hfc"],
                  "</br>"
                )
                ngx.print(
                  T"VLAN ID for VoIP: ",
                  xdsl_data["vid_voip"],
                  "</br>"
                )
              end
            end
            -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
            -- rate is already cleared.
            local rate_up = tonumber(xdsl_data["dsl_linerate_up"])
            local rate_down = tonumber(xdsl_data["dsl_linerate_down"])
            if rate_up and rate_down then
              rate_up = floor(rate_up / 10) / 100
              rate_down = floor(rate_down / 10) / 100
              ngx.print(
                "&emsp; ",
                iconUp,
                format("%.2f Mbps", rate_up),
                "</br>",
                "&emsp; ",
                iconDown,
                format('%.2f Mbps', rate_down)
              )
            end
            ngx.print("</p>")
          elseif xdsl_data["dsl_status"] == "NoSignal" then
            ngx.print(
              "<div class='simple-desc'>",
              "<div class=\"light red\"></div>",
              T"DSL disconnected",
              "</div>"
            )
          else
            ngx.print(
              "<div class='simple-desc'>",
              "<div class=\"light orange\"></div>",
              T"DSL connecting",
              ": ",
              xdsl_data["dsl_status"],
              "...</div>"
            )
          end
        else
          if eth_data["ethwan_status"] == "up" then
            ngx.print(
              "<div class='simple-desc'>",
              "<div class=\"light green\"></div>",
              T"Ethernet connected",
              "</div>"
              )
          else
            ngx.print(
              "<div class='simple-desc'>",
              "<div class=\"light red\"></div>",
              T"Ethernet disconnected",
              "</div>"
            )
          end
          if mode_current == "ethernetvlan" then
            ngx.print(
              "<p class='subinfos'>",
              T"VLAN ID for PPPoE: ",
              xdsl_data["vid_hfc"],
              "</br>"
            )
            if xdsl_data.variant == "novus" then
                ngx.print(
                  T"VLAN ID for VoIP: ",
                  xdsl_data["vid_voip"]
                )
            end
            ngx.print("</p>")
          end
        end
      end
        ngx.print('\
\
    </div>\
  </div>\
</div>\
');  end
if post_helper.isFeatureEnabled("broadBandCardView", role) then
  local bmh = require("broadbandmode_helper")
  local tabdata = bmh.broadBandDetails and dyntab_helper.process(bmh.broadBandDetails()) or dyntab_helper.process(bmh)
  if tabdata and tabdata.current.card then
    if not session:hasAccess("/modals/broadband-modal.lp") and not session:isdefaultuser() then
      return
    end
      ngx.print('\
    <div class="span3">\
      <div class="smallcard">\
      ');  
        lp.setpath("/www/cards/snippets/")
        if not bridged.isBridgedMode() then
          lp.include(tabdata.current.card)
        else
          lp.include("002_broadband_bridge.lp")
        end
        -- have to bring it back to original value ... singleton
        lp.setpath("/www/cards/")
        ngx.print('\
      </div>\
    </div>\
');  end
else
  statusView()
end   ngx.print('\
'); 