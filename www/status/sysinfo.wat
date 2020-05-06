local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local format, gsub, gmatch, find, sub, untaint, match = string.format, string.gsub, string.gmatch, string.find, string.sub, string.untaint, string.match
local floor = math.floor

local content_sys_info = {
  model = "uci.env.var.prod_friendly_name",
  sw_version = "uci.version.version.@version[0].marketing_version",
  fw_version = "uci.version.version.@version[0].version",
  hw_version = "uci.env.rip.board_mnemonic",
  lanip = "uci.network.interface.@lan.ipaddr",
  wanmac = "uci.network.interface.@wan.macaddr",
  wangw = "rpc.network.interface.@wan.nexthop",
  wandns1 = "rpc.network.interface.@wan.dnsservers",
  linerate_us = "sys.class.xdsl.@line0.UpstreamCurrRate",
  linerate_ds = "sys.class.xdsl.@line0.DownstreamCurrRate",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override"
}

-- Construct an uptime string from the number of seconds
local function secondsToTime(uptime)
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format("%dday:%dh:%dm:%ds", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format("%dh:%dm:%ds", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format("%dm:%ds", minutes, seconds)
  else
    return format("%ds", seconds)
  end
end

local function getSysInfo()
  local content = {}
  local ifname = untaint(proxy.get("uci.network.interface.@wan.ifname")[1].value)
  if match(ifname, "^@") then
    content_sys_info.wangw = "rpc.network.interface." .. ifname .. ".nexthop"
    content_sys_info.wandns1 = "rpc.network.interface." .. ifname .. ".dnsservers"
  end
  for k,v in pairs(content_sys_info) do
    content[k] = v
  end

  content_helper.getExactContent(content)
  if content["fw_version"] then
    local version = content["fw_version"]
    local newversion
    local pos
    pos=find(version, "%-[^%-]*$")
    if pos ~= nil then
      newversion = sub(version, 1, pos-1)
    end
    if content.fwversion_override ~= "" then
      if content.fwversion_override == "override1" then
        pos=find(version, "%-")
        if pos ~= nil then
          newversion = sub(version, 1, pos-1)
        end
      else
        newversion = content.fwversion_override
      end
    end
    if newversion then
      version=newversion
    end
    content["fw_version"] = content.fwversion_prefix .. version .. content.fwversion_suffix
  end
  content["uptime"] = secondsToTime(content_helper.readfile("/proc/uptime","number",floor))
  content["date_info"] = os.date("%F %T", os.time())

  local wan_intf = "wan"
  local content_wwan = {
    ipaddr = "rpc.network.interface.@wwan.ipaddr",
  }
  content_helper.getExactContent(content_wwan)
  if content_wwan.ipaddr:len() ~= 0 then
    wan_intf = "wwan"
  end

  local content_wan = {
    wanip = "rpc.network.interface.@"..wan_intf..".ipaddr",
    wan_ll_intf = "rpc.network.interface.@"..wan_intf..".ppp.ll_intf",
  }
  content_helper.getExactContent(content_wan)
  local wan_type = "Ethernet"
  if find(content_wan.wan_ll_intf, "atm") == 1 then
    wan_type = "ADSL"
  elseif find(content_wan.wan_ll_intf, "ptm") == 1 then
    wan_type = "VDSL"
  elseif wan_intf == "wwan" then
    wan_type = "Mobile"
  end
  content["wan_model"] = wan_type
  if content["wanmac"]:len() == 0 then
    content["wanmac"] = proxy.get("uci.env.rip.eth_mac")[1].value
  end
  content["sysinfo"] = "end"
  return content
end

-----Register system information service
local service_system_info ={
  name = "sysinfo",
  get = getSysInfo,
}
register(service_system_info)

local service_system_reset = {
  name = "reset"
}
service_system_reset.get = function()
  local get = {}
  proxy.set("rpc.system.reboot", "GUI")
  proxy.apply()
  return get
end
register(service_system_reset)
