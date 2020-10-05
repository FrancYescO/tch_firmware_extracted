local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local modf = math.modf
local format = string.format
local concat = table.concat
local untaint = string.untaint
local date, time = os.date, os.time
local dm = require("datamodel")
local fwcommon = require("fwcommon")
local content_helper = require("web.content_helper")
local execute = require("tch.process").execute
local hostpath = "rpc.hosts.host."

local mt = { __index = function() return "" end }

local function get_param(path)
  local param = dm.get(path)
  return param and param[1] and untaint(param[1].value) or ""
end

local function get_objects(path, sorted)
  return content_helper.convertResultToObject(path, dm.get(path), sorted)
end

local function get_index_objects(objects)
  local indexobjs = {}
  for k,v in pairs(objects) do
    local name = v.paramindex:sub(2)
    v.paramindex = nil
    indexobjs[name] = v
  end
  return indexobjs
end

local function get_path(data, option)
  if data.sectiontype then
    -- for named multi-instance
    if option then
      return format("%s.%s.%s.@%s.%s", data.pathtype or "uci", data.config, data.sectiontype, data.sectionname, option)
    else
      return format("%s.%s.%s.", data.pathtype or "uci", data.config, data.sectiontype)
    end
  else
    if option then
      -- for single instance
      return format("%s.%s.%s.%s", data.pathtype or "uci", data.config, data.sectionname, option)
    else
      -- for each for all the config file section
      return format("%s.%s.", data.pathtype or "uci", data.config)
    end
  end
end

local function get(data, option)
  local path = get_path(data, option or "")
  local param = dm.get(path)
  if option then
    if not param then
      -- for uci list type
      local values = {}
      path = get_path(data, option .. ".")
      param = dm.get(path)
      if type(param) == "table" then
        for k,v in pairs(param) do
          values[k] = untaint(v.value)
        end
        return values
      end
    end
    -- for uci option type
    return param and param[1] and untaint(param[1].value) or ""
  else
    -- when option is nil, return back sectiontype or ""
    return param and data.sectiontype or ""
  end
end

local function getall(data)
  local path = get_path(data, "")
  local params = dm.get(path)
  local options = setmetatable({}, mt)
  local lists = {}
  for k,v in pairs(params or {}) do
    -- for list type
    if v.param == "value" and v.path:match("@%d+%.$") then
      local key, id = v.path:match("%.(.*)%.@(%d+)%.$")
      if not lists[key] then
        lists[key] = {}
      end
      lists[key][tonumber(id)] = untaint(v.value)
    else
      options[v.param] = untaint(v.value)
    end
  end
  for k,v in pairs(lists) do
    options[k] = untaint(v)
  end
  return options
end

local function set(data, option)
  if option then
    local path = get_path(data, option)
    return dm.set(path, data.options[option])
  else
    local paths = {}
    local p = ""
    for k,v in pairs(data.options) do
      p = get_path(data, k)
      if type(v) == "table" then
        p = format("%s.", p)
        local items = dm.get(p) or {}
        local ne = #items
        local nn = #v
        if ne > nn then
          for i=nn+1,ne do
            dm.del(format("%s@%d.", p, i))
          end
        elseif ne < nn then
          for i=ne+1,nn do
            dm.add(p)
          end
        end
        for id,value in ipairs(v) do
          local lp = format("%s@%d.value", p, id)
          paths[lp] = value
        end
      else
        paths[p] = tostring(v)
      end
    end
    return dm.set(paths)
  end
end

local function add(data)
  local path = get_path(data, nil)
  return dm.add(path, data.sectionname)
end

local function del(data)
  local path = get_path(data, "")
  return dm.del(path)
end

local function each(data, func)
  local path = get_path(data, nil)
  local sections = get_objects(path)
  for _, section in ipairs(sections) do
    section[".name"] = section.paramindex:sub(2)
    section.paramindex = nil
    local lists = {}
    for opt, value in pairs(section) do
      local key, id = opt:match("^(.*)%.@(%d+)%.value$")
      if key and id then
        if not lists[key] then
          lists[key] = {}
        end
        lists[key][tonumber(id)] = value
        section[opt] = nil
      end
    end
    for k,v in pairs(lists) do
      section[k] = v
    end
    local utsection = {}
    for k,v in pairs(section) do
      utsection[untaint(k)] = untaint(v)
    end
    local r = func(utsection)
    if r == false then --need explicit false to stop
      return
    end
  end
end

local proxy = {
  get = get,
  getall = getall,
  set = set,
  add = add,
  del = del,
  each = each,
}

local M = {
  mgr = fwcommon.SetProxy(proxy),
  proxy = proxy,
}

local PV4 = "^%d+%.%d+%.%d+%.%d+"
local PV6 = "^%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*"

local Duration = setmetatable({
  ["0h 30'"] = "1800",
  ["1h 00'"] = "3600",
  ["1h 30'"] = "5400",
  ["2h 00'"] = "7200",
  ["4h 00'"] = "14400"
}, { __index = function() return "5400" end })

local Frequency = setmetatable({
  ["Do not repeat"] = "0,0,0,0,0,0,0",
  ["Weekends"] = "0,0,0,0,0,1,1",
  ["Working days"] = "1,1,1,1,1,0,0",
  ["Daily"] = "1,1,1,1,1,1,1",
  ["0,0,0,0,0,0,0"] = "Do not repeat",
  ["0,0,0,0,0,1,1"] = "Weekends",
  ["1,1,1,1,1,0,0"] = "Working days",
  ["1,1,1,1,1,1,1"] = "Daily",
},{ __index = function() return "" end })

local Week = { "mon", "tue", "wed", "thu", "fri", "sat", "sun" }

local function get_weekdays(frequency, weekdays)
  local w = weekdays
  local weekstr = Frequency[untaint(frequency)]
  if weekstr == "" then
    weekstr = "0,0,0,0,0,0,0"
  end
  w.mon, w.tue, w.wed, w.thu, w.fri, w.sat, w.sun = weekstr:match("^(%d*),(%d*),(%d*),(%d*),(%d*),(%d*),(%d*)$")
end

local function get_remaining(mac, prefixs)
  local stop = M.mgr:GetFWTimer(mac, prefixs, "stop")
  local remaining = 0
  if not (stop and stop:match("^%d+$"))  then
    stop = M.mgr:UpdateFWTimerStop(mac, prefixs)
  end

  if stop then
    local current = time()
    remaining = tonumber(stop) - tonumber(current)
  end
  return remaining > 0 and tostring(remaining) or "0"
end

local function get_routine(mac, prefixs)
  local timer = M.mgr:GetFWTimerAll(mac, prefixs)
  local r = {}
  r.scheduled = timer.enabled ~= "" and timer.enabled or "0"
  r.start = timer.start ~= "" and timer.start or "00:00"
  r.duration = Duration[timer.lease]
  get_weekdays(timer.frequency, r)
  return r
end

local function get_hosts()
  return get_objects(hostpath)
end

function M.GetDeviceList()
  local devices = setmetatable({}, mt)
  local hosts = get_hosts()
  for k, v in pairs(hosts or {}) do
    local mac = untaint(v.MACAddress)
    local fwd = M.mgr:GetFWDeviceAll(mac)
    devices[#devices+1] = {
      name = v.FriendlyName,
      mac = v.MACAddress,
      ip = v.DhcpLeaseIP:match(PV4) or v.DhcpLeaseIP:match(PV6) or v.IPAddress:match(PV4) or v.IPAddress:match(PV6),
      online = v.State, -- connected or not
      type_of_connection = v.L2Interface:find("eth") and "0" or "1",
      last_connection = date("%Y-%m-%dT%H:%M", tonumber(untaint(v.ConnectedTime))),
      family = fwd.group_name:find("Family") and "1" or "0",
      icon = fwd.icon_id ~= "" and fwd.icon_id or "7",
      parental = fwd.parental_ctl == "1" and "1" or "0",
      routine =  fwd.routine == "1" and "1" or "0",
      network = "Network",
      boost = M.mgr:GetBoostStatus(mac),
      boost_remaining = get_remaining(mac, {"online", "boost"}),
      stop = M.mgr:GetStopStatus(mac),
      stop_remaining = get_remaining(mac, {"online", "stop"}),
    }
    if devices[#devices].family == "1" then
      for _,activity in pairs({"boost", "stop"}) do
        local r = get_routine(mac, {"routine", activity})
        for k,v in pairs(r) do
          local itemstr = format("%s_%s", activity, k)
          devices[#devices][itemstr] = v
        end
      end
    end
  end
  return devices
end

function M.SetDeviceName(mac, name)
  local hosts = get_hosts()
  local index
  for k,v in ipairs(hosts) do
    if v.MACAddress == mac then
      index = v.paramindex
      break
    end
  end
  if index then
    local path = format("%s%s.FriendlyName", hostpath, index)
    dm.set(path, name)
  end
end

function M.GetDnsServers()
  local ifname_path = "uci.network.interface.@wan.ifname"
  local dnsservers_path = "rpc.network.interface.#.dnsservers"
  local param = get_param(ifname_path)
  local ifname = "@wan"
  if param:match("^@") then
    ifname = param
  end

  local servers = {}
  local dns_servers = get_param(dnsservers_path:gsub("#",ifname))
  dns_servers:gsub("[^,]+", function(c)
    servers[#servers+1] = c
  end)
  return servers, ifname
end

function M.GetSystemInfo()
  local sysinfo = {
    lanmac = "uci.network.interface.@lan.macaddr",
    linerate_us = "sys.class.xdsl.@line0.UpstreamCurrRate",
    linerate_ds = "sys.class.xdsl.@line0.DownstreamCurrRate",
  }
  local intfobj = M.GetIndexObjects("rpc.network.interface.")
  local wan_intf = "wan"
  local wan_type = "Ethernet"
  if intfobj.wwan.ipaddr ~= "" then
    wan_intf = "wwan"
    wan_type = "Mobile"
  end
  local llintf = intfobj[wan_intf]["ppp.ll_intf"]
  if llintf:find("atm") then
    wan_type = "ADSL"
  elseif llintf:find("ptm") then
    wan_type = "VDSL"
  elseif llintf:find("veip") then
    wan_type = "GPON"
  end
  sysinfo.wanmac = format("uci.network.interface.@%s.macaddr", wan_intf)
  content_helper.getExactContent(sysinfo)
  sysinfo.lanip = intfobj["lan"].ipaddr
  sysinfo.wan_link = intfobj[wan_intf].up
  sysinfo.wanip = intfobj[wan_intf].ipaddr
  sysinfo.wangw = intfobj[wan_intf].nexthop
  sysinfo.wan_model = wan_type
  return sysinfo
end

function M.GetDevicesByMacIndex()
  local devices = {}
  local hosts = get_hosts()
  for k,v in ipairs(hosts) do
    devices[untaint(v.MACAddress)] = v
  end
  return devices
end

function M.GetFrequency(weekdays, prefix)
  local frequency = {}
  for _,w in ipairs(Week) do
    frequency[#frequency+1] = untaint(weekdays[format("%s_%s", prefix, w)])
  end
  return Frequency[concat(frequency, ",")]
end

function M.GetWeekdays(frequency, weekdays, prefix)
  local w = {}
  get_weekdays(frequency, w)
  for k,v in pairs(w) do
    local key = format("%s_%s", prefix, k)
    weekdays[key] = v
  end
end

function M.SetItemValues(data, info, map)
  for k,v in pairs(map) do
    if info[k] == "" then
      data[v[1]] = v[2]
    else
      data[v[1]] = info[k]
    end
  end
end

function M.GetWlGuestTimeout()
  local remaining = get_remaining(nil, "guest_restriction")
  return remaining == "0" and "-1" or remaining
end

function M.GetObjects(path, sorted)
  return get_objects(path, sorted)
end

function M.GetIndexObjects(path, sorted)
  return get_index_objects(get_objects(path, sorted))
end

function M.Sleep(time)
  execute("sleep", {time})
end

function M.Apply()
  dm.apply()
end

return M
