--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-telstra')

local ipairs, string = ipairs, string
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local agent_state = proxy.get("uci.multiap.agent.enabled")[1].value
local controller_state = proxy.get("uci.multiap.controller.enabled")[1].value
local agent_exist
local agentPath = "Device.Services.X_TELSTRA_MultiAP.Agent."
local agentInfo = proxy.get(agentPath)
local agentList = content_helper.convertResultToObject(agentPath, agentInfo)
for _, k in pairs(agentList) do
    if k.MACAddress ~= "" then
        agent_exist = true
        break
    end
end
local items = {
    {"home.lp", T"Home"},
}
if agent_state == "1" and controller_state == "1" and agent_exist ~= nil then
    items[#items+1] = {"boosterstatus.lp", T"Wi-Fi Booster Status"}
    items[#items+1] = {"booster.lp", T"Wi-Fi Boosters"}
    items[#items+1] = {"wifidevices.lp", T"Wi-Fi Devices"}
else
    items[#items+1] = {"https://www.telstra.com.au/broadband/extras/wifi-extender", T"Boost Your Wi-Fi"}
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(items) do
    local active = ""
    if uri == ("/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a href="%s" target="_self">%s</a></li>', active, v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 