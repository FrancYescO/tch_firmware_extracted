local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local untaint = string.untaint
local format, gsub, gmatch, match = string.format, string.gsub, string.gmatch, string.match
local numOfPings = "2"
local xtmintf = proxy.getPN("uci.wanatmf5loopback.",true)
local ethBasePath = "sys.class.net.@"
local led_status_paths = {
  background_schedule = "uci.tod.action.@ledtod.enabled",
  background_timer = "uci.tod.action.@ledtod.timers.@1.value",
  line_last_date = "uci.button.button.@line.lastdate",
  wifi_last_date = "uci.button.button.@wifi.lastdate",
  wps_last_date  = "uci.button.button.@wps.lastdate"
}
-- get <color>
local Led_N = {
  broadband = "led_0",
  wireless  = "led_1",
  wps       = "led_2",
}

local function getLedStatus()
  local paths = {}
  local ret = {
    led_0 = "1",
    led_0_date = "0",
    led_1 = "1",
    led_1_date = "0",
    led_2 = "1",
    led_2_date = "0",
    led_status = "end"
  }

  local ambient = 0
  local path = "uci.ledfw.led."
  local objects = content_helper.convertResultToObject(path, proxy.get(path))
  for _,v in pairs(objects) do
    local name = v.paramindex:sub(2)
    if name == "ambient" then
      if v.status == "on" and v.active == "1" then
        ambient = 1
      end
    elseif Led_N[name] then
      if v.color and v.color:find("red") then
        ret[Led_N[name]] = "0"
      end
    end
  end
  ret["background_enabled"] = tostring(ambient)

  for k,v in pairs(led_status_paths) do
    paths[k] = v
  end
  content_helper.getExactContent(paths)

  ret["led_0_date"] = paths.line_last_date
  ret["led_1_date"] = paths.wifi_last_date
  ret["led_2_date"] = paths.wps_last_date
  ret["background_schedule"] = paths.background_schedule
  if paths.background_timer ~= "" then
    local tab = {
      background_start = "uci.tod.timer.@"..(paths.background_timer)..".start_time",
      background_end = "uci.tod.timer.@"..(paths.background_timer)..".stop_time"
    }
    ret["background_start"] = proxy.get(tab.background_start)[1].value:sub(5)
    ret["background_end"] = proxy.get(tab.background_end)[1].value:sub(5)
  end
  return ret
end

local service_led_status = {
  name = "led_status",
  get = getLedStatus
}

local function isCurTimeInSlot(startTime, endTime)
  local h1, m1 = string.match(startTime, "(%d+):(%d+)")
  local h2, m2 = string.match(endTime, "(%d+):(%d+)")
  local time1 = h1 * 3600 + m1 * 60
  local time2 = h2 * 3600 + m2 * 60
  local h3, m3, s3 = string.match(os.date("%H:%M:%S"), "(%d+):(%d+):(%d+)")
  local time3 = h3 * 3600 + m3 * 60 + s3

  if (time2 < time1) then
    if (time3 < time2) then
      time3 = time3 + 24*3600;
    end
    time2 = time2 + 24*3600;
  end
  if (time3 > time1 and time3 < time2) then
    return true
  else
    return false
  end
end

service_led_status.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in led_status set"
  end
  local paths = {}
  paths["uci.tod.action.@ledtod.enabled"] = args.background_schedule
  if args.background_schedule == "0" then
    paths["rpc.ambientLed.enabled"] = args.background_enabled
  else
    if args.background_enabled == "0" then
      paths["uci.tod.action.@ledtod.enabled"] = "0"
      paths["rpc.ambientLed.enabled"] = "0"
    else
      if not isCurTimeInSlot(args.background_start, args.background_end) then
        paths["rpc.ambientLed.enabled"] = "1"
      end
      paths["uci.tod.timer.@sleep_hours.start_time"] = match(args.background_start, "All") ~= nil and args.background_start or ("All:"..args.background_start)
      paths["uci.tod.timer.@sleep_hours.stop_time"] = match(args.background_end, "All") ~= nil and args.background_end or ("All:"..args.background_end)
    end
  end
  proxy.set(paths)
  proxy.apply()
  return true
end

local service_led_status_refresh = {
  name = "led_status_refresh"
}

service_led_status_refresh.get = function()
  local get = {}
  get["refreshed"] = "1"
  get["led_status_refresh"] = "end"
  return get
end

local content_sys_network = {
  lanip = "uci.network.interface.@lan.ipaddr",
  udhcpd = "uci.dhcp.dhcp.@lan.ignore",
  eth1_media_type = "sys.class.net.@eth0.speed",
  eth2_media_type = "sys.class.net.@eth1.speed",
  eth3_media_type = "sys.class.net.@eth2.speed",
  eth4_media_type = "sys.class.net.@eth3.speed",
  eth1_link = "sys.class.net.@eth0.operstate",
  eth2_link = "sys.class.net.@eth1.operstate",
  eth3_link = "sys.class.net.@eth2.operstate",
  eth4_link = "sys.class.net.@eth3.operstate",
  wan_link = "rpc.network.interface.@wan.up",
  wanip = "rpc.network.interface.@wan.ipaddr",
  wangw = "rpc.network.interface.@wan.nexthop",
  linerate_us = "sys.class.xdsl.@line0.UpstreamCurrRate",
  linerate_ds = "sys.class.xdsl.@line0.DownstreamCurrRate",
}
local hop_ping_path   = "rpc.network.interface.@wan.nexthop_ping"
local dns1_ping_path  = "rpc.network.interface.@wan.dnsserver1_ping"
local dns2_ping_path  = "rpc.network.interface.@wan.dnsserver2_ping"
local dnsservers_path = "rpc.network.interface.@wan.dnsservers"
local ifname_path     = "uci.network.interface.@wan.ifname"
local num_servers = 0

local function getStatus(param)
  local status = "Fail"
  local statusTest = proxy.get(param)
  if statusTest then
    statusTest = statusTest[1].value
    if statusTest == "Success" then
      status = "Success"
    elseif statusTest == "Requested" or  statusTest == "Waiting" then
      status = "Ongoing"
      --triggers the state machine do not remove
      proxy.set("rpc.network.interface.@wan.status_ping_test","Done")
      proxy.apply()
    end
  end
  return status
end

local function  pingTest()
  local get = {}
  if proxy.get(ifname_path)[1].value == "@mgmt" then
    hop_ping_path   = "rpc.network.interface.@mgmt.nexthop_ping"
    dns1_ping_path  = "rpc.network.interface.@mgmt.dnsserver1_ping"
    dns2_ping_path  = "rpc.network.interface.@mgmt.dnsserver2_ping"
    dnsservers_path = "rpc.network.interface.@mgmt.dnsservers"
  end
  local pingTable = {
    hop_ping  = hop_ping_path,
    dns1_ping = dns1_ping_path,
    dns2_ping = dns2_ping_path,
  }
  local content = {
    dns_servers = dnsservers_path
  }
  content_helper.getExactContent(content)
  if content["dns_servers"] and content["dns_servers"] ~= "" then
    num_servers = tonumber(select(2, string.gsub(content["dns_servers"], ",",","))) + 1
  end
  for _,v in ipairs(xtmintf) do
    proxy.set( v["path"].."NumberOfRepetitions", numOfPings)
    proxy.set(v["path"].."DiagnosticsState", "Requested")
  end
  proxy.set(hop_ping_path, "Requested")
  if num_servers >= 1 then
    proxy.set(dns1_ping_path, "Requested")
  end
  if num_servers >= 2  then
    proxy.set(dns2_ping_path, "Requested")
  end
  proxy.apply()

  --Waiting for the ping complete one by one
  local nexthop_ping_state = "None"
  local dns1_ping_state = "None"
  local dns2_ping_state = "None"
  local count = 30  --max waiting time 2s*30
  repeat
    nexthop_ping_state = getStatus(hop_ping_path)
    dns1_ping_state = getStatus(dns1_ping_path)
    dns2_ping_state = getStatus(dns2_ping_path)
    os.execute("sleep 2")
    count = count -1
  until  dns1_ping_state ~= "Ongoing" and nexthop_ping_state ~= "Ongoing" and dns2_ping_state ~= "Ongoing" or count <= 0

  content_helper.getExactContent(pingTable)
  get["next_hop_ping"] = pingTable.hop_ping == "Success" and "1" or "0"
  if num_servers == 1 and pingTable.dns1_ping == "Success" then
    get["next_dns_ping"] = "1"
  elseif num_servers == 2 and (pingTable.dns1_ping == "Success" or pingTable.dns2_ping == "Success") then
    get["next_dns_ping"] = "1"
  else
    get["next_dns_ping"] = "0"
  end
  get["ping_status"] = "end"

  return get
end
---------End of Wan Information collection

---------Wlan information collection
local iface = {
  ap0 = "wl1",
  ap1 = "wl1_1",
  ap2 = "wl1_2",
  ap3 = "wl1_3",
  ap4 = "wl0",
  ap5 = "wl0_1",
  ap6 = "wl0_2",
  ap7 = "wl0_3",
}

local function getWlan(wlan)
  local interfaces = {
    wl0_enabled1 = "rpc.wireless.ssid.@wl0.oper_state",
    wl0_enabled2 = "rpc.wireless.ap.@ap4.oper_state",
    wl1_enabled1 = "rpc.wireless.ssid.@wl1.oper_state",
    wl1_enabled2 = "rpc.wireless.ap.@ap0.oper_state"
  }
  content_helper.getExactContent(interfaces)
  if interfaces.wl1_enabled1 == "1" and interfaces.wl1_enabled2 == "1" then
    wlan.wl0_enabled = 1
  else
    wlan.wl0_enabled = 0
  end
  if interfaces.wl0_enabled1 == "1" and interfaces.wl0_enabled2 == "1" then
    wlan.wl1_enabled = 1
  else
    wlan.wl1_enabled = 0
  end

  for k, v in pairs(iface) do
    local params ={
      bss_enabled = "rpc.wireless.ap.@"..k..".public",
      ssid = "rpc.wireless.ssid.@"..v..".ssid",
      security = "rpc.wireless.ap.@"..k..".security.mode"
    }
    content_helper.getExactContent(params)
    local s = ""
    if match(v, "wl0") == "wl0" then
      s = gsub(v, "wl0", "wl1")
    elseif match(v, "wl1") == "wl1" then
      s = gsub(v, "wl1", "wl0")
    end
    if string.match(s, "_") == "_" then
      wlan[s.."_bss_enabled"] = params.bss_enabled
    end
    wlan[s.."_ssid"] = params.ssid
    wlan[s.."_security"] = params.security
  end
end
---------End of Wlan information collection

--------USB information collection
local usbCountPath = "sys.usb.DeviceNumberOfEntries"
local usbDetailPath = "sys.usb.device."

local function getUsbInfo(get)
  get["usb_port1"] = "Not Connected"
  get["usb_port2"] = "Not Connected"
  local number = proxy.get(usbCountPath)[1].value

  --If only 1 usb port is connected, need to determine which one is connected based on the path
  if tonumber(number) == 1 then
    local usbDetail = content_helper.convertResultToObject(usbDetailPath, proxy.get(usbDetailPath))
    for k,v in pairs(usbDetail) do
      if match(v.path, "-1") == "-1" then
        get["usb_port1"] = "Connected"
        break
      end
      if match(v.path, "-2") == "-2"  then
        get["usb_port2"] = "Connected"
        break
      end
    end
  --when 2 ports are both connected, no need determine
  elseif tonumber(number) == 2 then
    get["usb_port1"] = "Connected"
    get["usb_port2"] = "Connected"
  end
end
--------End of USB information collection
local function collectAllInfo()
  local get = {}
  local paths = {}
  for k,v in pairs(content_sys_network) do
    paths[k] = v
  end
  content_helper.getExactContent(paths)
  for k,v in pairs(paths) do
    get[k] =v
  end
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
    wan_ll_intf = "rpc.network.interface.@"..wan_intf..".ppp.ll_intf"
  }
  content_helper.getExactContent(content_wan)
  local wan_type = "Ethernet"
  if string.find(content_wan.wan_ll_intf, "atm") == 1 then
    wan_type = "ADSL"
  elseif string.find(content_wan.wan_ll_intf, "ptm") == 1 then
    wan_type = "VDSL"
  elseif wan_intf == "wwan" then
    wan_type = "Mobile"
  end
  get["wan_model"] = wan_type
  get["eth1_link"] = paths["eth1_link"] == "up" and "1" or "0"
  get["eth2_link"] = paths["eth2_link"] == "up" and "1" or "0"
  get["eth3_link"] = paths["eth3_link"] == "up" and "1" or "0"
  get["eth4_link"] = paths["eth4_link"] == "up" and "1" or "0"
  getUsbInfo(get)
  getWlan(get)
  get["diagnostics"] = "end"
  return get
end
local diagnostic_network_info = {
  name = "diagnostic",
  get = collectAllInfo,
}

local service_ping_status = {
  name = "ping_status",
  get = pingTest
}
register(service_ping_status)
register(service_led_status)
register(service_led_status_refresh)
register(diagnostic_network_info)
