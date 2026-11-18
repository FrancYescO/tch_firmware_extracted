--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local find, sub = string.find, string.sub
local wanIntf = post_helper.getActiveInterface()

-- TODO: only one eth wan interface is defined in the current product. If in the future, more than one eth wan interfaces are defined, need to use a list instead.
local ethPortPath = "uci.ethernet.port."
local ethIntf
local ethIntfList = proxy.getPN(ethPortPath, true)
if ethIntfList then
  for _, intf in pairs(ethIntfList) do
    if proxy.get(intf.path..wanIntf)[1].value:untaint() == "1" then
      local startIndex, intfStart = find(intf.path, ethPortPath.."@")
      if intfStart then
        local intfEnd = find(sub(intf.path, intfStart + 1), "%.")
        if intfEnd then
          ethIntf = sub(sub(intf.path, intfStart + 1), 1, intfEnd - 1)
          break
        end
      end
    end
  end
end

local wan = {
  iface = format("uci.network.interface.@%s.ifname", wanIntf)
}
content_helper.getExactContent(wan)

-- Here we just try to remove the potential vlan id from the interface name.
local iface = string.match(wan.iface, "([^%.]+)")
local stats
local deviceDetails = proxy.get(format("uci.network.device.@%s.ifname", iface))
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
local intf_state = "disabled"
local intf_state_map = {
  disabled =  T"Ethernet disabled",
  connected = T"Ethernet connected",
  disconnected = T"Ethernet not connected"
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green"
}

if stats.operstate == "up" then
  intf_state= stats.carrier ~= "0" and "connected" or "disconnected"
else
  intf_state = "disabled"
end

local session = ngx.ctx.session
local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
  modalPath = "modals/broadband-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath) ); ngx.print('\
');  if post_helper.isFeatureEnabled("noCardBackgroundIcons") then   ngx.print('\
  <div class="content">\
');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ac;">\
');  end   ngx.print('\
  ');  ngx.print( ui_helper.createSimpleLight(nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } }) ); ngx.print('\
</div>\
'); 