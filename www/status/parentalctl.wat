local ipairs = ipairs
local pairs = pairs
local format = string.format
local untaint = string.untaint
local api = require("fwapihelper")

-- index dev_#_<item>
local pc_list_device = {
  "name",
  "mac",
  "icon",
  "enabled",
}

local pc_list_url = {
  "uri",
  "enabled",
}

local waitingflag = false

local function get_pc_list()
  local data = {}
  local list = api.GetDeviceList()
  local number = 0
  local name = ""
  if waitingflag then
    api.Sleep("1")
    waitingflag = false
  end

  data["enabled"] = api.mgr:GetParentalCtlStatus()
  data["mode_all"] = api.mgr:GetParentalCtlMode()

  for id, dev in ipairs(list or {}) do
    if (dev.parental == "1") then
      for _,item in ipairs(pc_list_device) do
        name = format("dev_%d_%s", number, item)
        data[name] = dev[item] or "1"
      end
      number = number + 1
    end
  end
  data["total_dev"] = number
  number = 0
  local urls = api.mgr:GetAllURLs()
  for id, url in pairs(urls) do
    if url.uri ~= "" then
      for _,item in ipairs(pc_list_url) do
        name = format("addr_%d_%s", number, item)
        data[name] = untaint(url[item])
      end
      number = number + 1
    end
  end
  data["total_addr"] = number
  data["pc_list"] = "end"
  return data
end

local service_pc_list = {
  name = "pc_list",
  get = get_pc_list,
  set = function(args)
    api.mgr:SetParentalCtlStatus(untaint(args.enabled))
    api.mgr:SetParentalCtlMode(untaint(args.mode_all))
    api.Apply()
    return true
  end,
}

local function set_parental_ctl(args, enabled)
  local mac = untaint(args.mac)
  api.mgr:SetDeviceParentalCtl(mac, untaint(enabled))
  api.Apply()
  return true
end

local function get_url_id(url)
  local urls = api.mgr:GetAllURLs()
  local id
  for k, v in pairs(urls) do
    if v.uri == url then
      id = v.id
      break
    end
  end
  return id
end

local service_pc_device_add = {
  name = "pc_device_set",
  set = function(args)
    return set_parental_ctl(args, "1")
  end,
}


local service_pc_device_del = {
  name = "pc_device_del",
  set = function(args)
    return set_parental_ctl(args, "0")
  end,
}

local  service_address_add = {
  name = "pc_address_set",
  set = function(args)
    local url = untaint(args.uri)
    local id = get_url_id(url)
    if not id then
      id = get_url_id("") -- Fastweb asks to use an empty URL entry if any when adding a new URL via GUI
      if not id then
        id = api.mgr:AddURL()
      end
    end
    local options = {
      site = url,
      action = untaint(args.enabled)
    }
    api.mgr:SetURL(id, options)
    api.Apply()
    waitingflag = true
    return true
  end,
}

local service_address_del = {
  name = "pc_address_del",
  set = function(args)
    local url = untaint(args.uri)
    local id = get_url_id(url)
    if id then
      api.mgr:DelURL(id)
      api.Apply()
      waitingflag = true
    end
    return true
  end,
}

register(service_pc_list)
register(service_pc_device_add)
register(service_pc_device_del)
register(service_address_add)
register(service_address_del)
