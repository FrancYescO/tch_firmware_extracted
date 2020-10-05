local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local format, gsub = string.format, string.gsub
local untaint = string.untaint
local content_helper = require("web.content_helper")
local api = require("fwapihelper")
local dm = require("datamodel")

-- get <color>
local Led_N = {
  broadband = "led_0",
  wireless  = "led_1",
  wps       = "led_2",
}

-- get <lastdate>
local Led_Date = {
  line = "led_0_date",
  wifi = "led_1_date",
  wps  = "led_2_date",
}

local Background = {
  enabled = {"background_schedule", "0"},
  start   = {"background_start", "22:00"},
  stop    = {"background_end",   "07:00"},
}

local function get_led_status()
  local data = {
    led_status = "end"
  }
  -- Set default LED color to green
  for _,v in pairs(Led_N) do
    data[v] = "1"
  end

  local ambient = 0
  local objects = api.GetObjects("uci.ledfw.led.")
  for _,v in pairs(objects) do
    local name = v.paramindex:sub(2)
    if name == "ambient" then
      if v.status == "on" and v.active == "1" then
        ambient = 1
      end
    elseif Led_N[name] then
      if v.color and v.color:find("red") then
        data[Led_N[name]] = "0"
      end
    end
  end
  data["background_enabled"] = tostring(ambient)
  objects = api.GetObjects("uci.button.button.")
  for _,v in pairs(objects) do
    local name = v.paramindex:sub(2)
    if Led_Date[name] then
      data[Led_Date[name]] = v.lastdate
    end
  end
  objects = api.mgr:GetFWTimerAll(nil, "led")
  api.SetItemValues(data, objects, Background)

  return data
end

local service_led_status = {
  name = "led_status",
  get = get_led_status,
  set = function(args)
    local enabled = untaint(args.background_enabled)
    local schedule = untaint(args.background_schedule)
    local start   = untaint(args.background_start)
    local stop    = untaint(args.background_end)
    if not (enabled == "1" and schedule == "1" and api.mgr:CheckTimeSlot(start, stop)) then
      dm.set("rpc.ambientLed.enabled", enabled)
    end
    if enabled == "0" then
      schedule = "0"
    end
    api.mgr:SetLedTimer(start, stop)
    api.mgr:SetLedAction(schedule)
    api.Apply()
    return true
  end,
}

local service_led_status_refresh = {
  name = "led_status_refresh",
  get = {
    refreshed = "1",
    led_status_refresh = "end",
  }
}

-- Wlan information collection
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

local function get_wlan(wlan)
  local ssidobj = api.GetIndexObjects("rpc.wireless.ssid.")
  local apobj   = api.GetIndexObjects("rpc.wireless.ap.")
  -- 5G enabled status
  wlan.wl0_enabled = (ssidobj.wl1.oper_state == "1" and apobj.ap0.oper_state == "1") and "1" or "0"
  -- 2G enabled status
  wlan.wl1_enabled = (ssidobj.wl0.oper_state == "1" and apobj.ap4.oper_state == "1") and "1" or "0"

  for k,v in pairs(iface) do
    -- switch wl0 and wl1 due to CPE wl0 is 2G, wl1 is 5G. Fastweb requirements wl0 is 5G, wl1 is 2G
    local index, num = gsub(v, "wl0", "wl1")
    if num == 0 then
      index = gsub(v, "wl1", "wl0")
    end

    if index:find("_") then
      wlan[index.."_bss_enabled"] = apobj[k]["public"]
    end
    wlan[index.."_ssid"] = ssidobj[v]["ssid"]
    wlan[index.."_security"] = apobj[k]["security.mode"]
  end
end

-- Collect USB information
local function get_usb_info(usb)
  usb["usb_port1"] = ""
  usb["usb_port2"] = ""
  local usbobj = api.GetObjects("sys.usb.device.")
  local i = 1
  while i <=  #usbobj do
    usb["usb_port"..i] = (usbobj[i].manufacturer == "") and "Unknown" or usbobj[i].manufacturer
    i = i+1
  end
end


local SystemInfo = {
  "lanip",
  "linerate_us",
  "linerate_ds",
  "wan_link",
  "wanip",
  "wangw",
  "wan_model",
}

local function collect_information()
  local data = {
    udhcpd = "uci.dhcp.dhcp.@lan.ignore",
    eth1_media_type = "sys.class.net.@eth0.speed",
    eth2_media_type = "sys.class.net.@eth1.speed",
    eth3_media_type = "sys.class.net.@eth2.speed",
    eth4_media_type = "sys.class.net.@eth3.speed",
    eth1_link = "sys.class.net.@eth0.operstate",
    eth2_link = "sys.class.net.@eth1.operstate",
    eth3_link = "sys.class.net.@eth2.operstate",
    eth4_link = "sys.class.net.@eth3.operstate",
  }

  content_helper.getExactContent(data)
  for i=1,4 do
    local index = format("eth%d_link", i)
    data[index] = data[index] == "up" and "1" or "0"
  end

  local sysinfo = api.GetSystemInfo()
  for _,v in ipairs(SystemInfo) do
    data[v] = sysinfo[v]
  end

  get_wlan(data)
  get_usb_info(data)
  data["diagnostics"] = "end"
  return data
end


local service_diagnostic = {
  name = "diagnostic",
  get = collect_information,
}

local hop_ping_path   = "rpc.network.interface.#.nexthop_ping"
local dns1_ping_path  = "rpc.network.interface.#.dnsserver1_ping"
local dns2_ping_path  = "rpc.network.interface.#.dnsserver2_ping"

local Status = setmetatable({
  Success = "Success",
  Requested = "Ongoing",
  Waiting = "Ongoing",
}, { __index = function() return "Fail" end })

local function process_ping(pattern, ifname)
  local path = pattern:gsub("#", ifname)
  dm.set(path, "Requested")
  dm.apply()
  local count = 30
  local status = "None"

  repeat
    local state = dm.get(path)
    if state then
      status = Status[untaint(state[1].value)]
      if status == "Ongoing" then
        --triggers the state machine do not remove
        local testpath = format("rpc.network.interface.%s.status_ping_test", ifname)
        dm.set(testpath, "Done")
        dm.apply()
      end
    end
    api.Sleep("1")
    count = count - 1
  until status ~= "Ongoing" or count <= 0

  return status == "Success" and "1" or "0"
end

local function get_ping_status()
  local data = {
    ping_status = "end"
  }

  local servers, ifname = api.GetDnsServers()
  local server_num = #servers

  data["next_hop_ping"] = process_ping(hop_ping_path, ifname)
  data["next_dns_ping"] = "0"
  if server_num >= 1 then
    data["next_dns_ping"] = process_ping(dns1_ping_path, ifname)
  end
  if server_num >= 2  then
    local state = process_ping(dns2_ping_path, ifname)
    data["next_dns_ping"] = state == "1" and data["next_dns_ping"] or "0"
  end

  return data
end
local service_ping_status = {
  name = "ping_status",
  get = get_ping_status,
}

register(service_ping_status)
register(service_led_status)
register(service_led_status_refresh)
register(service_diagnostic)
