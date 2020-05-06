local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local format, gsub, match, find = string.format, string.gsub, string.match, string.find
local parental_path = "uci.parental.URLfilter."
local parental_enabled_path = "uci.parental.general.enable"
local parental_range_path = "uci.fastweb.webui.parental_control_mode"
local host_path = "rpc.hosts.host."

local function get_parental_columns()
  local mapParams, url = {}, {}
  mapParams["total_dev"]  = 0
  mapParams["total_addr"] = 0
  mapParams["enabled"] = proxy.get(parental_enabled_path)[1].value
  mapParams["mode_all"] = proxy.get(parental_range_path)[1].value
  local parentalsInfo = content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
  for i, j in pairs(hosts) do
    local familyType, icon, parentalTag = j.DeviceType:match("^(.*):(%d*):(%d*)$")
    if parentalTag == "1"  then
      mapParams["dev_"..(mapParams.total_dev).."_name"] = (j.FriendlyName):len() ~= 0 and j.FriendlyName or ("unknown_"..mac)
      mapParams["dev_"..(mapParams.total_dev).."_mac"] = j.MACAddress
      mapParams["dev_"..(mapParams.total_dev).."_icon"] = icon ~= "" and icon or "7"
      mapParams["dev_"..(mapParams.total_dev).."_enabled"] = 1
      mapParams["total_dev"] = mapParams.total_dev + 1
    elseif parentalTag == "0"  then
      for k,v in pairs(parentalsInfo) do
        if v.mac == j.MACAddress then
          proxy.del(parental_path..(v.paramindex)..".")
        end
      end
    end
  end
  for k,v in pairs(parentalsInfo) do
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
  local index = 0
  local paths, tmp, path1, path2 = {}, {}, {}, {}
  paths[parental_enabled_path] = args.enabled
  paths[parental_range_path] = args.mode_all
  local curMode = proxy.get(parental_range_path)[1].value
  local parentals =  content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  if curMode == "1" and args.mode_all == "0" then
    tmp = {}
    for k, v in pairs(parentals) do
      if not tmp[v.site] then
        tmp[v.site] = v.action
      end
      proxy.del(parental_path..(v.paramindex)..".")
    end
    for k,v in pairs(tmp) do
      index = proxy.add(parental_path)
      path1[parental_path..index..".site"] = k
      path1[parental_path..index..".action"] = v
      proxy.set(path1)
    end
  end
  if args.mode_all == "1" then
    tmp = {}
    local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
    for k, v in pairs(parentals) do
      if not tmp[v.site] then
        tmp[v.site] = v.action
      end
      proxy.del(parental_path..(v.paramindex)..".")
    end
    for k, v in pairs(hosts) do
      local familyType, icon, parentalTag = v.DeviceType:match("^(.*):(%d*):(%d*)$")
      if parentalTag == "1" then
        for i, j in pairs(tmp) do
          index = proxy.add(parental_path)
          path2[parental_path..index..".mac"] = v.MACAddress
          path2[parental_path..index..".action"] = j
          path2[parental_path..index..".site"] = i
          proxy.set(path2)
        end
      end
    end
  end
  proxy.set(paths)
  proxy.apply()
  return true
end

----parental pc device set  service
local function setDeviceType(mac, tag)
  local devType,devTypePath = "",""
  local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
  for k, v in pairs(hosts) do
    if mac == v.MACAddress then
      devType = v.DeviceType
      devTypePath = host_path..(v.paramindex)..".DeviceType"
      break
    end
  end
  local path = {}
  if devType == "" then
    path[devTypePath] = "::1"
  else
    path[devTypePath] = gsub(devType, "%d$", tag, 1)
  end
  proxy.set(path)
  proxy.apply()
end

local service_pc_device_add = {
  name = "pc_device_set",
}

service_pc_device_add.set = function(args)
  if args == nil then
    return nil, "Invalid parameters"
  end
  local mac = args.mac
  setDeviceType(mac,"1")
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
  for k,v in pairs(data) do
    if v.param == "mac" and v.value == mac then
      proxy.del(v.path)
    end
  end
  setDeviceType(mac,"0")
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
  local paths = {}
  local uri = args.uri
  local action = args.enabled == "1" and "DROP" or "ACCEPT"
  local mode = proxy.get(parental_range_path)[1].value
  local parentalsInfo = content_helper.convertResultToObject(parental_path, proxy.get(parental_path))
  for k, v in pairs(parentalsInfo) do
    if v.site == uri then
      add = 0
      paths[parental_path..(v.paramindex)..".action"] = action
      proxy.set(paths)
    end
  end
  if add == 1 then  -- Fastweb asks to use an empty URL entry if any when adding a new URL via GUI
    for k, v in pairs(parentalsInfo) do
      if v.site == "" then
        add = 0
        paths[parental_path..(v.paramindex)..".action"] = action
        paths[parental_path..(v.paramindex)..".site"] = uri
        proxy.set(paths)
        break
      end
    end
  end
  if mode == "1" and add == 1 then
    local hosts = content_helper.convertResultToObject(host_path, proxy.get(host_path))
    for k,v in pairs(hosts) do
      local familyType, icon, parentalTag = v.DeviceType:match("^(.*):(%d*):(%d*)$")
      if parentalTag == "1"  then
        paths = {}
        index = proxy.add(parental_path)
        paths[parental_path..index..".mac"] = v.MACAddress
        paths[parental_path..index..".action"] = action
        paths[parental_path..index..".site"] = uri
        proxy.set(paths)
      end
    end
  elseif mode == "0" and add == 1 then
    paths = {}
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
