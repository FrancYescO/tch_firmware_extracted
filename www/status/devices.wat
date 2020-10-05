local ipairs = ipairs
local pairs = pairs
local match, format, gsub, find = string.match, string.format, string.gsub, string.find
local untaint = string.untaint
local concat = table.concat
local api = require("fwapihelper")

-- index dev_#_<item>
local connected_config = {
  "name",
  "mac",
  "ip",
  "family",
  "icon",
  "type_of_connection",
  "network",
  "boost",
  "boost_remaining",
  "stop",
  "stop_remaining",
}

-- index dev_#_<item>
local family_config = {
  "name",
  "mac",
  "icon",
  "online",
  "last_connection",
  "ip",
  "type_of_connection",
  "network",
  "parental",
  "boost_scheduled",
  "boost_mon",
  "boost_tue",
  "boost_wed",
  "boost_thu",
  "boost_fri",
  "boost_sat",
  "boost_sun",
  "boost_duration",
  "boost_start",
  "stop_scheduled",
  "stop_mon",
  "stop_tue",
  "stop_wed",
  "stop_thu",
  "stop_fri",
  "stop_sat",
  "stop_sun",
  "stop_duration",
  "stop_start",
  "routine",
}

-- index dev_#_<item>
local history_config = {
  "name",
  "mac",
  "last_connection",
  "ip",
}

local function get_device_info(servicename, config)
  local list = api.GetDeviceList()
  local device = {}
  local number = 0
  local name = ""
  for id, dev in ipairs(list or {}) do
    if (servicename == "connected_device_list" and dev.online == "1")
      or (servicename == "family_device_list" and dev.family == "1")
      or (servicename == "device_history_list" and dev.online == "0") then
      for _,item in ipairs(config) do
        name = format("dev_%d_%s", number, item)
        device[name] = dev[item]
      end
      number = number + 1
    end
  end
  device["total_num"] = number
  device[servicename] = "end"
  return device
end

local Lease = {
  ["1800"] = "0h 30'",
  ["3600"] = "1h 00'",
  ["5400"] = "1h 30'",
  ["7200"] = "2h 00'",
  ["14400"] = "4h 00'"
}

local Activity = {"boost", "stop"}
local ActivityMap = {
  enabled = "scheduled",
  duration = "duration",
  start = "start",
}

local DeviceMap = {
  icon_id = "icon_id",
  routine = "routine",
}

local function set_device(args, mode, activity)
  local mac = untaint(args.mac)
  local setbs = {}
  local options = {}
  local duration
  if type(activity) == "string" then
    setbs[activity] = {}
    setbs[activity].enabled = untaint(args.activate)
    duration = untaint(args.counter)
    if duration ~= "-1" then
      setbs[activity].duration = duration
    end
  elseif type(activity) == "table" then
    for _,v in ipairs(activity) do
      setbs[v] = {}
      setbs[v].frequency = api.GetFrequency(args, v)
      for opt,item in pairs(ActivityMap) do
        setbs[v][opt] = untaint(args[format("%s_%s", v, item)])
      end
    end
    for opt,item in pairs(DeviceMap) do
      options[opt] = untaint(args[item])
    end
    options["group_name"] = "Family"
    options["mac"] = mac
    api.SetDeviceName(mac, untaint(args.family_name))
    if args.parental_ctl then
      api.mgr:SetDeviceParentalCtl(mac, untaint(args.parental_ctl))
    end
  end
  --Set Fastweb configuration
  api.mgr:SetFWDevice(mac, options)

  --Set ToD configuration
  for act,opt in pairs(setbs) do
    api.mgr:SetBSTimer(mac, mode, act, opt.duration, opt.start, opt.frequency)
    api.mgr:SetBSAction(mac, mode, act, opt.enabled)
    opt.lease = Lease[opt.duration]
    opt.duration = nil
    api.mgr:SetFWTimer(mac, {mode, act}, opt)
  end
end

local service_connected_device = {
  name = "connected_device_list",
  get = function()
    return get_device_info("connected_device_list", connected_config)
  end,
}

local service_family_device = {
  name = "family_device_list",
  get = function()
    return get_device_info("family_device_list", family_config)
  end
}

local service_history_device = {
  name = "device_history_list",
  get = function()
    return get_device_info("device_history_list", history_config)
  end
}

local service_boost_device = {
  name = "boost_device",
  set = function(args)
    set_device(args, "online", "boost")
    api.Apply()
    api.Sleep("1")
    return true
  end
}

local service_stop_device = {
  name = "stop_device",
  set = function(args)
    set_device(args, "online", "stop")
    api.Apply()
    api.Sleep("1")
    return true
  end,
}

local service_family_device_add = {
  name = "family_device_add",
  set = function(args)
    set_device(args, "routine", Activity)
    api.Apply()
    return true
  end,
}

local service_family_device_del = {
  name = "family_device_del",
  set = function(args)
    local mac = untaint(args.mac)
    api.mgr:SetFWDevice(mac, "group_name", "Other")
    api.mgr:DisableDeviceRoutine(mac)
    api.Apply()
    return true
  end,
}

local service_generic_device_edit = {
  name = "generic_device_edit",
  set = function(args)
    local mac = untaint(args.mac)
    api.SetDeviceName(mac, untaint(args.name))
    api.mgr:SetFWDevice(mac, "icon_id", untaint(args.icon_id))
    api.Apply()
    return true
  end,
}

register(service_connected_device)
register(service_family_device)
register(service_history_device)
register(service_stop_device)
register(service_boost_device)
register(service_family_device_add)
register(service_family_device_del)
register(service_generic_device_edit)
