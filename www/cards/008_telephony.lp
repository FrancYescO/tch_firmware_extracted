<%
  local lfs = require("lfs")
  if lfs.attributes("/etc/config/mmpbx", "mode") ~= "file" then
    return
  end

  -- Enable localization
  gettext.textdomain('webui-voice')
  local tinsert, format = table.insert, string.format
  local datamodel = require ("datamodel")
  local ui_helper = require ("web.ui_helper")
  local postHelper = require("web.post_helper")
  local variant_helper = require("variant_helper")
  local variantHelper = postHelper.getVariant(variant_helper, "Telephony", "Card")
  local content_helper = require ("web.content_helper")
  local session = ngx.ctx.session
  local role = session:getrole()
  local userName = session:getusername()

  local switchName, mmpbx_info
  local modalPath

  local sipprofile_path = "uci.mmpbxrvsipnet.profile."
  local sipprofile_ubus_path = "rpc.mmpbx.profile.@"
  local sipprofile_content = content_helper.getMatchedContent(sipprofile_path)
  local mmpbx = {
    state = "uci.mmpbx.mmpbx.@global.enabled"
  }
  content_helper.getExactContent(mmpbx)


  mmpbx_info =  mmpbx.state and mmpbx.state == "1" and  T"Telephony enabled" or  T"Telephony disabled"


  local sipprofile_info = {}
  for _, sipProfileValue in pairs (sipprofile_content) do
    local name = string.match (sipProfileValue.path, "@([^%.]+)")
    if sipProfileValue.userfriendlyname and sipProfileValue.userfriendlyname ~= "" then
      sipprofile_info[name] = sipProfileValue.userfriendlyname
    else
      sipprofile_info[name] = sipProfileValue.uri
    end
  end

  switchName = "mmpbx_enabled"
  if mmpbx.state == "1" then
    if session:hasAccess("/modals/mmpbx-global-modal.lp") then
      modalPath = "/modals/mmpbx-global-modal.lp"
    elseif session:hasAccess("/modals/mmpbx-dect-modal.lp") then
      modalPath = "/modals/mmpbx-dect-modal.lp"
    elseif session:hasAccess("/modals/mmpbx-contacts-modal.lp") then
      modalPath = "/modals/mmpbx-contacts-modal.lp"
    elseif not postHelper.isFeatureEnabled("mmpbxInOutMap", role) and session:hasAccess("/modals/mmpbx-inoutgoingmap-modal.lp") then
      modalPath = "/modals/mmpbx-inoutgoingmap-modal.lp"
    elseif not session:isdefaultuser() then
      return
    end
  elseif session:hasAccess("/modals/mmpbx-global-modal.lp") then
    modalPath = "/modals/mmpbx-global-modal.lp"
  elseif postHelper.getVariantValue(variantHelper, "mmpbxGlobal") and not session:isdefaultuser() then
    return
  end
%>

<div class="span3">
  <div class="smallcard">
    <%
      if postHelper.variantHasAccess(variantHelper, "addMmpbxStateSwitchToCardHeader", role) or userName == "user" then
        ngx.print(ui_helper.createCardHeader( T"Telephony", modalPath, switchName, mmpbx.state))
      else
        ngx.print(ui_helper.createCardHeader( T"Telephony", modalPath))
      end
    %>
    <% if not postHelper.isFeatureEnabled("noCardBackgroundIcons", role) then %>
      <div class="content card_bg" data-bg-text="&#xf095;">
    <% else %>
      <div class="content">
    <% end %>
      <%
	local html = {}
        tinsert(html, ui_helper.createSimpleLight(mmpbx.state, mmpbx_info, { light = { id =  "Telephony_LEDStatus" }, span = { id =  "Telephony_Status" } } ))
        tinsert (html, [[<p class= "subinfos">]] )
        local reged, notreged, reging = 0, 0, 0
        for name, value in pairs (sipprofile_info) do
          local profile = {
            enable = sipprofile_ubus_path..name..".enable",
            res = sipprofile_ubus_path..name..".sipRegisterState"
          }
          content_helper.getExactContent(profile)

          if (type(profile) == "table") then
            if (profile.res == "Registered") then
              reged = reged +1
            elseif (profile.enable == "true") and (profile.res == "Unregistered") then
              notreged = notreged +1
            elseif (profile.enable == "true") and (profile.res == "Registering") then
              reging = reging +1
            end
          end
        end
        tinsert (html, [[<br/>]])
        if reged ~= 0 then
          tinsert(html, format( N( T"<strong %s>%d </strong> Registered Account", T"<strong %s>%d </strong> Registered Accounts", reged), 0, reged))
          tinsert (html, [[<br/>]])
        end
        if reging ~= 0 then
          tinsert(html, format( N(T"<strong %s>%d </strong> Registering Account",T"<strong %s>%d </strong> Registering Accounts",reging), 0, reging))
          tinsert (html, [[<br/>]])
        end
        if notreged ~= 0 then
          tinsert(html, format( N( T"<strong %s>%d </strong> Unregistered Account", T"<strong %s>%d </strong> Unregistered Account", reged), 0, notreged))
          tinsert (html, [[</p>]])
        end
	ngx.print (html)
      %>
    </div>
  </div>
</div>
