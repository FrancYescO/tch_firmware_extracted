<%
local lfs = require("lfs")
if lfs.attributes("/etc/config/mmpbx", "mode") ~= "file" then
  return
end

-- Enable localization
gettext.textdomain('webui-voice')
local tinsert, format = table.insert, string.format
datamodel = require ("datamodel")
ui_helper = require ("web.ui_helper")
content_helper = require ("web.content_helper")
local session = ngx.ctx.session

local switchName = nil
local modalPath = nil
local mmpbx_info = nil

local sipprofile_path = "uci.mmpbxrvsipnet.profile."
local sipprofile_ubus_path = "rpc.mmpbx.profile.@"
local sipprofile_content = content_helper.getMatchedContent(sipprofile_path)
local mmpbx_state, error = datamodel.get("uci.mmpbx.mmpbx.@global.enabled")

if mmpbx_state then
    mmpbx_state = format("%s",mmpbx_state[1].value)
else
    mmpbx_state = "0"
end

if mmpbx_state and mmpbx_state == "1" then
    mmpbx_info = T"Telephony enabled"
else
    mmpbx_info = T"Telephony disabled"
end

local sipprofile_info = {}
local v = {}
for _, v in pairs (sipprofile_content) do
    local name = string.match (v.path, "@([^%.]+)")
    if v.userfriendlyname ~= nil and v.userfriendlyname ~= "" then
        sipprofile_info[name] = v.userfriendlyname
    else
        sipprofile_info[name] = v.uri
    end
end

    modalPath = "/modals/mmpbx-log-modal.lp"
%>

<div class="span3">
  <div class="smallcard">
    <%
      ngx.print(ui_helper.createCardHeader(T"Telephony", modalPath, switchName, mmpbx_state))
    %>
    <div class="content">
    <%
	local html = {}
    tinsert(html, ui_helper.createSimpleLight(mmpbx_state, mmpbx_info, { light = { id =  "Telephony_LEDStatus" }, span = { id =  "Telephony_Status" } } ))
    tinsert (html,[[<p class= "subinfos">]] )
    local name, value = "", ""
    local reged, notreged, reging = 0,0,0
    for name, value in pairs (sipprofile_info) do
        local res = datamodel.get (sipprofile_ubus_path..name..".sipRegisterState")
        local enYN = datamodel.get (sipprofile_ubus_path..name..".enable")
        if (type(res) == "table") then
            if (res[1].value == "Registered") then
                reged = reged +1
            elseif (enYN[1].value == "true") and (res[1].value == "Unregistered") then
                notreged = notreged +1
            elseif (enYN[1].value == "true") and (res[1].value == "Registering") then
                reging = reging +1
            end
        end
    end
    tinsert (html, [[<br/>]])
    if reged ~= 0 then
        tinsert(html, format('<strong>%d</strong> '..T"Registered Accounts", reged))
        tinsert (html, [[<br/>]])
    end
    if reging ~= 0 then
        tinsert(html, format('<strong>%d</strong> '..T"Registering Accounts", reging))
        tinsert (html, [[<br/>]])
    end
    if notreged ~= 0 then
        tinsert(html, format('<strong>%d</strong> '..T"Unregistered Accounts", notreged))
        tinsert (html, [[</p>]])
    end
	ngx.print (html)
    %>
    </div>
  </div>
</div>
