<%
local lfs = require("lfs")
if lfs.attributes("/etc/config/mmpbx", "mode") ~= "file" then
  return
end

-- Enable localization
gettext.textdomain('webui-voice')
local string= string
local tinsert, format, match = table.insert, string.format, string.match
local datamodel = require ("datamodel")
local ui_helper = require ("web.ui_helper")
local content_helper = require ("web.content_helper")
local session = ngx.ctx.session

local content_mmpbx = {
    enabled = "uci.mmpbx.mmpbx.@global.enabled",
    state = "rpc.mmpbx.state",
    ipaddr = "rpc.network.interface.@wan.ipaddr",
}
content_helper.getExactContent(content_mmpbx)

local mmpbx_info
if content_mmpbx.enabled == "1" then
    mmpbx_info = T"Telephony enabled"
else
    mmpbx_info = T"Telephony disabled"
end

local switchName
local modalPath
if session:hasAccess("/modals/mmpbx-global-modal.lp") then
    switchName = "mmpbx_enabled"
    modalPath = "/modals/mmpbx-global-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">
    <%
    ngx.print(ui_helper.createCardHeader(T"Telephony", modalPath, switchName, content_mmpbx.enabled))
    %>
    <div class="content">
    <%
	local html = {}
    html[#html+1] = ui_helper.createSimpleLight(content_mmpbx.enabled, mmpbx_info)
    html[#html+1] = '<p></p>'
    if content_mmpbx.enabled == "1" then
        if content_mmpbx.state == "RUNNING" and content_mmpbx.ipaddr ~= "" then
            local profiles = {}
            for _,v in ipairs(datamodel.getPN("uci.mmpbxrvsipnet.profile.", true)) do
                local profile = match(v.path, "uci%.mmpbxrvsipnet%.profile%.@([^%.]+)%.")
                if profile then
                    profiles[#profiles+1] = profile
                end
            end
            local reged, notreged, reging = 0,0,0
            local sipprofile_ubus_path = "rpc.mmpbx.profile.@"
            for _, profile in pairs (profiles) do
                content_profile = {
                    enable = sipprofile_ubus_path..profile..".enable",
                    state = sipprofile_ubus_path..profile..".sipRegisterState"
                }
                content_helper.getExactContent(content_profile)
                if (content_profile.state == "Registered") then
                    reged = reged +1
                elseif (content_profile.enable == "true") and (content_profile.state == "Unregistered") then
                    notreged = notreged +1
                elseif (content_profile.enable == "true") and (content_profile.state == "Registering") then
                    reging = reging +1
                end
            end
            if reged ~= 0 then
                html[#html+1] = format('<p class= "subinfos"><strong>%d</strong> '..T"Registered Accounts" .. '</p>', reged)
            end
            if reging ~= 0 then
                html[#html+1] = format('<p class= "subinfos"><strong>%d</strong> '..T"Registering Accounts" .. '</p>', reging)
            end
            if notreged ~= 0 then
                html[#html+1] = format('<p class= "subinfos"><strong>%d</strong> '..T"Unregistered Accounts" .. '</p>', notreged)
            end
        else
            html[#html+1] = ui_helper.createSimpleLight('2', 'Telephony connecting')
        end
    end
	ngx.print (html)
    %>
    </div>
  </div>
</div>
