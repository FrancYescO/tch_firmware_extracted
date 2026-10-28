--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local format = string.format
local session = ngx.ctx.session
local role = session:getrole()
local modalPath = "/modals/relay-modal.lp"

--Allow to access GUI page as read only, without to login for default user.
if session:hasAccess(modalPath) and not session:isdefaultuser() then
  local dhcprelayState = "connected"

  local relayParams = {
    uciRelayServerIp = "uci.dhcp.relay.@relay.server_addr",
    uciRelayLocalIp = "uci.dhcp.relay.@relay.local_addr",
    interface = "uci.dhcp.relay.@relay.interface",
  }
  content_helper.getExactContent(relayParams)

  local getBackUpValues = content_helper.convertResultToObject("uci.dhcp.relaybackup.", proxy.get("uci.dhcp.relaybackup."))
  if relayParams.uciRelayServerIp == "" and relayParams.uciRelayLocalIp == "" then
    dhcprelayState = "disabled"
    if getBackUpValues and next(getBackUpValues) then
      for _, relayData in pairs(getBackUpValues) do
        relayParams.uciRelayServerIp = relayData.server_addr
        relayParams.uciRelayLocalIp = relayData.local_addr
        relayParams.interface = relayData.interface
      end
    end
  end

  local dhcpLightMap = {
    disabled = "off",
    connected = "green"
  }
  local dhcpStateMap = {
    disabled = T"DHCP Relay disabled",
    connected = T"DHCP Relay enabled"
  }

  ngx.print('\r\
<div class="span3">\r\
  <div class="smallcard">\r\
    ');  ngx.print( ui_helper.createCardHeader(T"Relay Setup", "modals/relay-modal.lp") ); ngx.print('\r\
      ');  if not post_helper.isFeatureEnabled("style", role) then   ngx.print('\r\
        <div class="content card_bg" data-bg-text="&#xf074;">\r\
      ');  else   ngx.print('\r\
        <div class="content">\r\
      ');  end   ngx.print('\r\
    ');  ngx.print(ui_helper.createSimpleLight(nil, dhcpStateMap[dhcprelayState] , { light = { class = dhcpLightMap[dhcprelayState], id = "relaySetupCardDhcpRelayStatusLed" },  span = { id = "relaySetupCardDhcpRelayStatus" }}))
      if post_helper.isFeatureEnabled("relayParamsData", role) then
        ngx.print(format('<p class = "subinfos"> Server IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relayParams["uciRelayServerIp"] ))
        ngx.print(format('<p class = "subinfos"> Local IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relayParams["uciRelayLocalIp"] ))
        ngx.print(format('<p class = "subinfos"> Interface : <strong id="relaysetupcard_relayip">%s</strong></p>',relayParams["interface"] ))
      end
      ngx.print('\r\
    </div>\r\
  </div>\r\
</div>\r\
');  end  ngx.print('\r\
'); 