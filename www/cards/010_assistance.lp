--pretranslated: do not change this file
 
-- The card is shown, even if the modal is not accessible
gettext.textdomain('webui-core')

local modal = '/modals/assistance-modal.lp'

local format = string.format
local ngx = ngx
local proxy = require("datamodel")
local session = ngx.ctx.session
local admin = session:hasAccess(modal)
local ui_helper = require("web.ui_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local post_helper = require("web.post_helper")
local role = session:getrole()
local wanIntf = post_helper.getActiveInterface()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "GatewayPage", "gateway")
local assistanceHelper = post_helper.getVariant(variant_helper, "Assistance", "assistance")
local hideAssistanceCard = post_helper.getVariantValue(variantHelper, "hideAssitanceCard")
local remoteAssistance = post_helper.getVariantValue(assistanceHelper, "remoteAssistance")

if not hideAssistanceCard or (hideAssistanceCard and session:hasAccess(modal) and not session:isdefaultuser()) then

  local ipAddress = proxy.get("rpc.network.interface.@"..wanIntf..".ipaddr")[1].value

  local ipv6LightMap = {
    down = "red",
    up = "green"
  }

  if assistant then
    local content = {}, state, wanStatus
    if assistant:enabled() then
      state = "1"
      local url = assistant:URL()
      local url6 = assistant:URL6()
      wanStatus = (ipAddress ~= "" or (url6 and url6 ~= "")) and "up" or "down"
      local light = ui_helper.createSimpleLight(nil, T"Enabled", { light = { class = ipv6LightMap[wanStatus] , id =  "Assistance_LEDStatus"}, span = { id =  "Assistance_Status" }})
      if admin then
        content[#content + 1] = light..'<br/>'
        content[#content + 1] = url and T"URL:"..format(' <strong id="port">%s</strong>', url)..'<br/>'
        if remoteAssistance and url6 then
          content[#content + 1] = T"URL6:"..format(' <strong style="word-wrap: break-word">%s</strong>', url6)..'<br/>'
        end
        content[#content + 1] = (url or url6) and T"Username:"..format(' <strong id="username">%s</strong>', assistant:username()).."<br/>"
        content[#content + 1] = (not url and not url6) and  T"There is no connection to the Internet." or ""
      else
        content = {light}
      end
    else
      state = "0"
      content = {
        ui_helper.createSimpleLight(state, T"Disabled", { light = { id =  "Assistance_LEDStatus" }, span = { id =  "Assistance_Status" } })
      }
    end
    if post_helper.isFeatureEnabled("assistview", role) then  ngx.print('\
      <div class="span3">\
        <div class="smallcard">\
          ');  if admin then
              if not post_helper.isFeatureEnabled("assistcardview", role) then
                ngx.print(ui_helper.createCardHeader(T"Assistance", modal))
              else
                ngx.print(ui_helper.createCardHeader(T"Assistance", modal, 'ra_enabled', state, {input = {id = "assistance_card_enable"}}))
              end
            else
              ngx.print(ui_helper.createCardHeader(T"Assistance"))
          end   ngx.print('\
          ');  if not post_helper.isFeatureEnabled("style", role) then   ngx.print('\
            <div class="content card_bg" data-bg-text="&#xf0fe;">\
          ');  else   ngx.print('\
            <div class="content">\
          ');  end   ngx.print('\
          ');  ngx.print( content ); ngx.print('\
        </div>\
      </div>\
    </div>\
  ');  end
  end
end
  ngx.print('\
'); 