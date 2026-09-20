<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local format = string.format
local content_helper = require("web.content_helper")

-- Process the selected mode if any
local imh = require("internetmode_helper")

local mode_options = {}
local mode_data = {}
local mode_default = "" -- the default mode to use
local mode_active = ""  -- the mode currently in use (mode_default if not set)
for _,v in ipairs(imh) do
    mode_options[#mode_options + 1] = { v.name, v.description }
    mode_data[v.name] = v
    if v.default == true then
        mode_default = v.name
    end
end

-- Get current mode by 'wan_mode' 
mode_active = format("%s", proxy.get("uci.network.config.wan_mode")[1].value) -- remove tainting

--'wan_mode' not there, then get @wan.proto
local wan_proto = {
    proto = "uci.network.interface.@wan.proto",
}
content_helper.getExactContent(wan_proto)
if mode_active == "" then
    mode_active = format("%s",wan_proto.proto)
end

--still empty, the use default ppp@wan@bridge@eth4+atm
if mode_active == "" then
    mode_active = "default"
end


-- Display the card but do not give access if not allowed
local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">

<%
    lp.setpath("/www/cards/snippets/")
    lp.include(mode_data[mode_active].card)
    -- have to bring it back to original value ... singleton
    lp.setpath("/www/cards/")
%>
  </div>
</div>
