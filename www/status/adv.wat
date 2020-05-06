local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local match, format, gsub, untaint  = string.match, string.format, string.gsub, string.untaint

local basepath = "sys.usb.device."
local function num2ipv4(ip)
  local ret = bit.band(ip, 255)
  local ip = bit.rshift(ip,8)
  for i=1,3 do
    ret = bit.band(ip,255) .. "." .. ret
    ip = bit.rshift(ip,8)
  end
  return ret
end

local usb_basepath = "sys.usb.device."

local mapParams = {
  ["3g_activation"] = "uci.wansensing.global.network_mode",
  ["3g_timeout"] = "uci.wansensing.global.backup_time",
  ["3g_apn"] = "uci.mobiled.profile.@0.apn",
  ["3g_username"] = "uci.mobiled.profile.@0.username",
  ["3g_password"] = "uci.mobiled.profile.@0.password"
}
local function getMobiledInfo(usb)
  local num_devices = proxy.get("rpc.mobiled.DeviceNumberOfEntries")[1].value
  if tonumber(num_devices) >= 1 then
    usb["3g_connection_status"] = proxy.get("rpc.mobiled.device.@1.display_status")[1].value == "connected" and "1" or "0"
  else
    usb["3g_connection_status"] = 0
  end
  local paths = {}
  for k,v in pairs(mapParams) do
    paths[k] = v
  end
  content_helper.getExactContent(paths)
  for i,j in pairs(paths) do
    usb[i] = j
  end
  if usb["3g_activation"] == "Fixed_line" then
    usb["3g_fallback"] = "0"
  else
    usb["3g_fallback"] = "1"
  end
  if usb["3g_activation"] == "Mobiled" then
     usb["3g_activation"] = "0"
  elseif usb["3g_activation"] == "auto" then
     usb["3g_activation"] = "2"
  elseif usb["3g_activation"] == "Mobiled_scheduled" then
     usb["3g_activation"] = "1"
  end
  usb["3g_pin"] = "********"
end

local service_usb_remove = {
  name = "usb_remove"
}
service_usb_remove.set = function(args)
  if args == nil then
    return nil,"Invalid parameters in servie usb_remove"
  end
  -- diskid =0 or 1, 0-usb port1 1-usb port2
  local disk = ""
  local res = content_helper.convertResultToObject(basepath, proxy.get(basepath))
  for k,v in pairs(res) do
    if v["interface.1.bInterfaceProtocol"] ~= "50" then
      table.remove(res,k)
    end
  end
  local count = #res
  if args.diskId == "0" then
    disk = "-1"
  elseif args.diskId == "1" then
    disk = "-2"
  else
    return nil, "Invalid diskid"
  end
  for k,v in pairs(res) do
    if count == 1 then
      proxy.set(usb_basepath..(v.paramindex)..".unmount", "1")
      proxy.apply()
      break
    end
    if count == 2 and match(v.path, disk) == disk then
      local path = usb_basepath..(v.paramindex)..".unmount"
      proxy.set(usb_basepath..(v.paramindex)..".unmount", "1")
      proxy.apply()
      break
    end
  end
  return true
end

local usb_mapParams = {
   samba_enabled  = "uci.samba.samba.filesharing",
   samba_server = "uci.samba.samba.name",
   samba_workgroup = "uci.samba.samba.workgroup",
   printserver_enabled = "uci.printersharing.config.enabled",
   dlna_enabled    = "uci.dlnad.config.enabled",
}


local function reverseTable(tab)
  local tmp = {}
   for i=1, #tab do
     local key = #tab
      tmp[i] = table.remove(tab)
   end
   return tmp
end
local function getUsbInfo()
  local res = content_helper.convertResultToObject(basepath, proxy.get(basepath))
  local usb_disk_info = {}
  local count = 0
  res = reverseTable(res)
  for k,v in pairs(res) do
    --Only collect usb storage inforamtion(dont include usb 3g module)
    if v["interface.1.bInterfaceProtocol"] ~= "50" then
      table.remove(res,k)
    end
  end
  usb_disk_info["total_disks"] = #res
  for k,v in pairs(res) do
    if match(v.path, "-1") == "-1" then
      v["id"] = 1
    end
    if match(v.path, "-2") == "-2" then
      v["id"] = 2
    end
  end
  table.sort(res, function(a,b)  return a.id<b.id end)
  for i=1, #res do
    usb_disk_info["disk_"..(i-1).."_name"] = match(res[i]["path"], "-1") == "-1" and "Disk1" or "Disk2"
    local path = basepath..res[i]["paramindex"]..".partition."
    local diskinfo = content_helper.convertResultToObject(path, proxy.get(path))
    usb_disk_info["disk_"..(i-1).."_size"] = 0
    usb_disk_info["disk_"..(i-1).."_available"] = 0
    for k,v in pairs(diskinfo) do
      usb_disk_info["disk_"..(i-1).."_fs"] = v.FileSystem
      usb_disk_info["disk_"..(i-1).."_size"] = usb_disk_info["disk_"..(i-1).."_size"] + tonumber(match(v.TotalSpace, "[0-9]+%.[0-9]+"))
      usb_disk_info["disk_"..(i-1).."_available"] = usb_disk_info["disk_"..(i-1).."_available"] + tonumber(match(v.AvailableSpace, "[0-9]+%.[0-9]+"))
    end
    usb_disk_info["disk_"..(i-1).."_size"] = tostring(usb_disk_info["disk_"..(i-1).."_size"]).." GB"
    usb_disk_info["disk_"..(i-1).."_available"] = tostring(usb_disk_info["disk_"..(i-1).."_available"]).." GB"
  end
  local content = {}
  for k,v in pairs(usb_mapParams) do
    content[k] = v
  end
  content_helper.getExactContent(content)
  for k,v in pairs(content) do
    usb_disk_info[k] = v
  end
  usb_disk_info["samba_share_on"] = "lan"
  usb_disk_info["disk_protected"] = "0"
  usb_disk_info["disk_username"] = ""
  usb_disk_info["disk_password"] = ""
  usb_disk_info["usb_status"] = "end"
  getMobiledInfo(usb_disk_info)
  return usb_disk_info
end

local service_usb_status = {
  name = "usb_status",
  get = getUsbInfo
}
local function validate_pin(value)
  local pin = value:match("^(%d+)$")
  if pin ~= nil then
    if string.len(pin) >= 4 and string.len(pin) <= 8 then
      return true
    end
  end
  return false
end

service_usb_status.set = function(args)
  if args == nil then
    return nil,"Invalid parameters in servie usb_status set"
  end
  local paths = {}
  if args.samba_enabled ~= nil then
    paths[usb_mapParams.samba_enabled] = args.samba_enabled
    paths[usb_mapParams.samba_server]  = args.samba_server
    paths[usb_mapParams.samba_workgroup] = args.samba_workgroup
    paths[usb_mapParams.printserver_enabled] = args.printserver_enabled
    paths[usb_mapParams.dlna_enabled] = args.dlna_enabled
  end
  paths[mapParams["3g_apn"]] = args["3g_apn"]
  paths[mapParams["3g_username"]] = args["3g_username"]
  paths[mapParams["3g_password"]] = args["3g_password"]
  paths[mapParams["3g_timeout"]] = args["3g_timeout"]
  if validate_pin(args["3g_pin"]) == true then
    local num_devices = proxy.get("rpc.mobiled.DeviceNumberOfEntries")[1].value
    if tonumber(num_devices) >= 1 then
      local pin_state = proxy.get("rpc.mobiled.device.@1.sim.pin.pin_state")[1].value
      if pin_state ~= "disabled" then
        paths["rpc.mobiled.device.@1.sim.pin.disable"] = args["3g_pin"]
      end
    end
  end
  if args["3g_fallback"] == "0" then
    paths[mapParams["3g_activation"]] = "Fixed_line"
  else
    if args["3g_activation"] == "0" then
      paths[mapParams["3g_activation"]] = "Mobiled"
    elseif args["3g_activation"] == "1" then
      paths[mapParams["3g_activation"]] = "Mobiled_scheduled"
    elseif args["3g_activation"] == "2" then
      paths[mapParams["3g_activation"]] = "auto"
    end
  end
  -- Press button "Activate backup now"
  if args.samba_enabled == nil then
    if args["3g_activation"] == "0" or args["3g_activation"] == "1" then
      local wan_up = proxy.get("rpc.network.interface.@wan.up")
      wan_up = wan_up and wan_up[1].value
      -- if wan is down, enable mobile
      if wan_up == "0" then
        paths["uci.network.interface.@wwan.auto"] = "1"
        paths["uci.network.interface.@wwan.enabled"] = "1"
      end
    end
  end
  proxy.set(paths)
  proxy.apply()
  return true
end

--lan setup----------------------------------------------------------------------
local dhcp_intfs_path = "uci.dhcp.dhcp."
local dhcp_host_path  =  "uci.dhcp.host."

local lan_mapParams_path = {
  dhcpStart = "uci.dhcp.dhcp.@lan.start",
  dhcpLimit = "uci.dhcp.dhcp.@lan.limit",
  dhcpState = "uci.dhcp.dhcp.@lan.ignore",
  leaseTime = "uci.dhcp.dhcp.@lan.leasetime",
  localdevIP = "uci.network.interface.@lan.ipaddr",
  localdevmask = "uci.network.interface.@lan.netmask",
  localIPv6 = "uci.network.interface.@lan.ipv6",
  localIP6prefix = "rpc.network.interface.@6rd.ip6prefix",
}

local function web_get_lan_status()
  local lan_mapParams ={}
  for k,v in pairs(lan_mapParams_path) do
    lan_mapParams[k] = v
  end
  content_helper.getExactContent(lan_mapParams)
  local baseip = post_helper.ipv42num(lan_mapParams["localdevIP"])
  local netmask = post_helper.ipv42num(lan_mapParams["localdevmask"])
  local start = tonumber(lan_mapParams["dhcpStart"])
  local numips = tonumber(lan_mapParams["dhcpLimit"])
  local network = bit.band(baseip, netmask)
  local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
  local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
  local ipend = network + numips + start - 1
  local ipstart = num2ipv4(ipstart)
  if ipend > ipmax then
    ipend = ipmax
  end
  local ipend = num2ipv4(ipend)
  local network = num2ipv4(network)

  local web_lan_mapParams ={}
  web_lan_mapParams.ip =  lan_mapParams.localdevIP
  web_lan_mapParams.netmask = lan_mapParams.localdevmask
  web_lan_mapParams.IPV6_on_LAN = lan_mapParams.localIPv6
  web_lan_mapParams.IPV6_prefix_6rd = lan_mapParams.localIP6prefix == "" and " " or lan_mapParams.localIP6prefix
  web_lan_mapParams.DHCP_enabled = (lan_mapParams.dhcpState == "0" or lan_mapParams.dhcpState == "") and  "1" or "0"
  web_lan_mapParams.DHCP_start = ipstart
  web_lan_mapParams.DHCP_end = ipend
  if string.find(lan_mapParams.leaseTime, "h") then
    local hours = gsub(lan_mapParams.leaseTime, "h", "")
    web_lan_mapParams.DHCP_duration = tostring(tonumber(hours) * 3600)
  else
    web_lan_mapParams.DHCP_duration = lan_mapParams.leaseTime
  end

  local all_dhcp_host = content_helper.convertResultToObject(dhcp_host_path, proxy.get(dhcp_host_path))
  local count = 0
  for k,v in ipairs(all_dhcp_host) do
    web_lan_mapParams["DHCP_" .. (count) .."_mac" ] = v.mac
    web_lan_mapParams["DHCP_" .. (count) .."_ip" ] = v.ip
    count = count + 1
  end
  return web_lan_mapParams
end

local service_lan_status = {
  name = "lan_status",
  get = web_get_lan_status
}

service_lan_status.set = function(args)
  local lan_status = {}
  --need valid ip format---
  lan_status[untaint(lan_mapParams_path.localdevIP)] = args.ip
  lan_status[untaint(lan_mapParams_path.localdevmask)] = args.netmask
  lan_status[untaint(lan_mapParams_path.localIPv6)] = args.IPV6_on_LAN
  lan_status[untaint(lan_mapParams_path.dhcpState)] = args.DHCP_enabled == "1" and "0" or "1"
  local baseip = post_helper.ipv42num(args.ip)
  local netmask = post_helper.ipv42num(args.netmask)
  local dhcpstart = post_helper.ipv42num(args.DHCP_start)
  local dhcpend = post_helper.ipv42num(args.DHCP_end)
  local network = bit.band(baseip, netmask)
  local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
  local start = dhcpstart - network
  local limit = dhcpend - network - start + 1
  lan_status[untaint(lan_mapParams_path.dhcpStart)] = tostring(start)
  lan_status[untaint(lan_mapParams_path.dhcpLimit)] = tostring(limit)
  lan_status[untaint(lan_mapParams_path.leaseTime)] = args.DHCP_duration
  proxy.set(lan_status)
  proxy.apply()
  return true
end

local service_dhcp_set = {
  name = "dhcp_set"
}

service_dhcp_set.set = function(args)
  local all_dhcp_host = content_helper.convertResultToObject(dhcp_host_path, proxy.get(dhcp_host_path))
  local exist = 0
  for k,v in pairs(all_dhcp_host) do
    if v.mac == args.mac then
      exist = 1
    end
  end
  if exist == 0 then
    local dhcp_host_status ={}
    local index = proxy.add(dhcp_host_path)
    dhcp_host_status[(dhcp_host_path..(index)..".ip")] = args.ip
    dhcp_host_status[(dhcp_host_path..(index)..".mac")] = args.mac
    proxy.set(dhcp_host_status)
    proxy.apply()
  end
  return true
end

local service_dhcp_del = {
  name = "dhcp_del"
}

service_dhcp_del.set = function(args)
  local index = 0
  local all_dhcp_host = content_helper.convertResultToObject(dhcp_host_path, proxy.get(dhcp_host_path))
  for k,v in ipairs(all_dhcp_host) do
    if args.mac == v.mac then
      proxy.del(dhcp_host_path..(v.paramindex)..".")
      proxy.apply()
    end
  end
  return true
end
register(service_usb_status)
register(service_lan_status)
register(service_dhcp_set)
register(service_dhcp_del)
register(service_usb_remove)
