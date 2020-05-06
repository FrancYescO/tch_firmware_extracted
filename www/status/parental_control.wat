local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local format, gsub, gmatch, find = string.format, string.gsub, string.gmatch, string.find

local parental_path = "uci.parental.URLfilter."
local parental_enabled_path = "uci.parental.general.enable"
local parental_range_path = "uci.fastweb.webui.parental_control_mode"
local host_path = "sys.hosts.host."
local function getHostNameByMac(mac)
  local name = ""
  local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
  for k,v in pairs(hosts) do
    if v.MACAddress == mac then
      name = v.HostName
      break
    end
  end
  if name:len() == 0 or name == " " then
    name = "unknown_"..mac
  end
  return name
end
local function get_parental_columns()
  local mapParams = {}
  mapParams["total_dev"]  = 0
  mapParams["total_addr"] = 0
  mapParams["enabled"] = proxy.get(parental_enabled_path)[1].value
  mapParams["mode_all"] = proxy.get(parental_range_path)[1].value
  local parentalsInfo = content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  local dev, url = {},{}
  for k,v in pairs(parentalsInfo) do
    if not dev[v.mac] and v.mac ~= "" then
      dev[v.mac] = true
      mapParams["dev_"..(mapParams.total_dev).."_name"] = getHostNameByMac(v.mac)
      mapParams["dev_"..(mapParams.total_dev).."_mac"] = v.mac
      mapParams["dev_"..(mapParams.total_dev).."_icon"] = 3
      mapParams["dev_"..(mapParams.total_dev).."_enabled"] = 1
      mapParams["total_dev"] = mapParams.total_dev + 1
    end
    if not url[v.site] and v.site ~= "" then
       url[v.site] = true
       mapParams["addr_"..(mapParams.total_addr).."_uri"] = v.site
       mapParams["addr_"..(mapParams.total_addr).."_enabled"] = v.action == "DROP" and "1" or "0"
       mapParams["total_addr"] = mapParams.total_addr + 1
    end
  end
  mapParams["pc_list"] = "end"
  return mapParams
end

local service_pc_list_device = {
  name = "pc_list",
  get = get_parental_columns,
}

service_pc_list_device.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_pc_list_device set"
  end
  local paths={}
  local enabled = args.enabled
  local mode_all = args.mode_all

  paths[parental_enabled_path] = enabled
  paths[parental_range_path] = mode_all
  if mode_all == "0" then
    local tmp = {}
    local index = 0
    local parentals =  content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
    for k, v in pairs(parentals) do
      if not tmp[v.site] then
        tmp[v.site] = v.action
      end
      proxy.del(parental_path..(v.paramindex)..".")
    end
    for k,v in pairs(tmp) do
      index = proxy.add(parental_path)
      paths[parental_path..index..".site"] = k
      paths[parental_path..index..".action"] = v
      proxy.set(paths)
    end
  end
  proxy.set(paths)
  proxy.apply()
  return true
end


----parental pc device set  service
local function getHostIpByMac(mac)
  local ip = ""
  local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
  for k,v in pairs(hosts) do
    if v.MACAddress == mac then
      ip = v.IPAddress:match("^%d+%.%d+%.%d+%.%d+") or ""
      break
    end
  end
  return ip
end
local service_pc_device_add = {
  name = "pc_device_set",
}

service_pc_device_add.set = function(args)
  if args == nil then
    return nil, "Invalid parameters"
  end
  local mac = args.mac
  local enabled = args.enabled
  local add, index = 1, 0
  local paths,tmp = {}, {}
  local mode = proxy.get(parental_range_path)[1].value
  local parentals =  content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  if #parentals == 0 then
      index = proxy.add(parental_path)
      paths[parental_path..index..".mac"] = mac
      paths[parental_path..index..".device"] = getHostIpByMac(mac)
      proxy.set(paths)
  else
    for k, v in pairs(parentals) do
      if mac == v.mac then
        add = 0
      end
      if v.mac == "" and v.device == "" then
        add = 0
        paths[parental_path..(v.paramindex)..".mac"] = mac
        paths[parental_path..(v.paramindex)..".device"] = getHostIpByMac(mac)
        proxy.set(paths)
      end
      if tmp[v.site] == nil then
        tmp[v.site] = v
      end
    end
    if add == 1 then
      for k,v in pairs(tmp) do
        index = proxy.add(parental_path)
        paths[parental_path..index..".mac"] = mac
        paths[parental_path..index..".device"] = getHostIpByMac(mac)
        paths[parental_path..index..".action"] = v.action
        paths[parental_path..index..".site"] = v.site
        proxy.set(paths)
      end
    end
  end
  proxy.apply()
  return true
end

----End of parental pc device set service

-----parental pc device del service
local service_pc_device_del = {
  name = "pc_device_del",
}

service_pc_device_del.set = function(args)
  if args == nil then
    return nil, "Invalid parameters"
  end
  local mac = args.mac
        if mac == "" then
    return nil, "mac cannot be empty"
  end
  local data = proxy.get(parental_path)
  for i,j in pairs(data) do
    if j.param == "mac" and j.value == mac then
      proxy.del(j.path)
    end
  end
  return true
end
-----End of parental pc device del

local  service_address_add = {
  name = "pc_address_set",
}

service_address_add.set = function(args)
  if args == nil then
    return nil, "Invalid parameters"
  end
  local add, index = 1, 0
  local paths,dev = {},{}
  local uri = args.uri
  local action = args.enabled == "1" and "DROP" or "ACCEPT"
  local mode = proxy.get(parental_range_path)[1].value
  local parentalsInfo = content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  for k, v in pairs(parentalsInfo) do
    if v.site == "" or v.site == uri then
      add = 0
      paths[parental_path..(v.paramindex)..".site"] = uri
      paths[parental_path..(v.paramindex)..".action"] = action
      proxy.set(paths)
    end
    if dev[v.mac] == nil then
      dev[v.mac] = v
    end
  end
  if mode == "1" and add == 1 then
    for k,v in pairs(dev) do
        paths = {}
        index = proxy.add(parental_path)
        paths[parental_path..index..".mac"] = v.mac
        paths[parental_path..index..".device"] = getHostIpByMac(v.mac)
        paths[parental_path..index..".action"] = action
        paths[parental_path..index..".site"] = uri
        proxy.set(paths)
    end
  elseif mode == "0" and add == 1 then
      index = proxy.add(parental_path)
      paths[parental_path..index..".action"] = action
      paths[parental_path..index..".site"] = uri
      proxy.set(paths)
  end
  proxy.apply()
  return true
end
-------pc address del
local service_address_del = {
  name = "pc_address_del",
}

service_address_del.set = function(args)
  if args == nil then
    return nil, "Invalid parameters"
  end
  local uri = args.uri
  local data = content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  for k,v in pairs(data) do
    if v.site == uri then
      proxy.del(parental_path..(v.paramindex)..".")
    end
  end
  proxy.apply()
  return true
end
register(service_pc_list_device)
register(service_pc_device_add)
register(service_pc_device_del)
register(service_address_add)
register(service_address_del)
------End of pc address del
