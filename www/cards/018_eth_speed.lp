--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local table = table
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local match = string.match
local session = ngx.ctx.session
local ethportCount = 0
local ethSpeed = {}
local portsValue = {}
local portStatus = proxy.get("sys.eth.port.")
  for _, statusVal in ipairs(portStatus) do
    if statusVal["param"] == "status"  and statusVal["value"] ~= "" then
      portsValue [match(statusVal["path"], "sys.eth.port.@(eth%d)")] = statusVal["value"]
    end
  end
local ethPorts = {
  {"eth0", "eth0"}
}
for i=0,4 do
  local ethPort = "eth" .. i
  local path = "uci.ethernet.port.@" .. ethPort .. "."
  local speedCheck = proxy.get(path .. "speed")
  if speedCheck ~= nil then
    ethportCount = ethportCount + 1
    table.insert(ethPorts, {ethPort, ethPort})
    ethSpeed[ethPort] = speedCheck[1].value
  end
end
if session:hasAccess("/modals/ethspeed-modal.lp") then
  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"ETH Linespeed", "modals/ethspeed-modal.lp") ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0ec;" id="ethspeedid">\
      <p class="subinfos">\
      <div id="ethspeedalign">\
      ');  
      local html = {}
      local basic = {
        span = {
          class = "ethspeeds"
        },
        label = {
          class = "ethspeedsVal"
        }
      }
      local ethCount = -1
      for _,v in ipairs(ethPorts) do
        if ethCount == 4 and  portsValue["eth" .. ethCount] == "up" then
          html[#html+1] = ui_helper.createLabel(T"WAN LINE SPEED", ethSpeed["eth" ..ethCount],basic)
        end
        if ethCount ~= 4 and ethCount ~= -1 then
          html[#html+1] = ui_helper.createLabel(T"LAN " .. ethCount+1 .. " LINE SPEED", ethSpeed["eth" ..ethCount],basic)
        end
        ethCount = ethCount + 1
      end
      ngx.print(html)
        ngx.print('\
    </div>\
    </div>\
  </div>\
</div>\
');  end  ngx.print('\
'); 