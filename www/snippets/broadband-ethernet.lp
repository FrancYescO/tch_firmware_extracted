--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local find, sub = string.find, string.sub


-- TODO: only one eth wan interface is defined in the current product. If in the future, more than one eth wan interfaces are defined, need to use a list instead.
local ethPortPath = "uci.ethernet.port."
local ethIntf
local ethIntfList = proxy.getPN(ethPortPath, true)
if ethIntfList then
  for _, interface in pairs(ethIntfList) do
    if proxy.get(interface.path.."wan")[1].value:untaint() == "1" then
      local _, intfStart = find(interface.path, ethPortPath.."@")
      if intfStart then
        local intfEnd = find(sub(interface.path, intfStart+1), "%.")
        if intfEnd then
          ethIntf = sub(sub(interface.path, intfStart+1), 1, intfEnd-1)
          break
        end
      end
    end
  end
end

local wan = {
  iface = "uci.network.interface.@wan.ifname"
}
content_helper.getExactContent(wan)

-- Here we just try to remove the potential vlan id from the interface name.
local iface = string.match(wan.iface, "([^%.]+)")
local stats
local deviceDetails = proxy.get(string.format("uci.network.device.@%s.ifname", iface))
local deviceIfname = ""
if deviceDetails then
  deviceIfname = deviceDetails[1].value
end
if iface and ethIntf and (find(iface, ethIntf) or find(deviceIfname, ethIntf)) then
  ethIntf = ethIntf:untaint()
  stats = {
    operstate = "sys.class.net.@" .. ethIntf .. ".operstate",
    carrier = "sys.class.net.@" .. ethIntf .. ".carrier",
    speed = "sys.class.net.@" .. ethIntf .. ".speed"
  }
  content_helper.getExactContent(stats)
else
  stats = {
    operstate = "down",
    carrier = "0",
    speed = "0"
  }
end

-- Figure out interface state
local intf_state
local intf_state_map = {
  disabled = T"Ethernet disabled",
  connected = T"Ethernet connected",
  disconnected = T"Ethernet not connected"
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green"
}

intf_state  = stats.operstate == "up" and (stats.carrier ~= "0") and "connected" or "disconnected" or "disabled"
  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
  ');  
    local html = {}
    -- Label that shows Ethernet status
    html[#html + 1] = ui_helper.createLight(T"Status", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 