local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local match, format, gsub, gmatch, find = string.match, string.format, string.gsub, string.gmatch, string.find

local service_simp_port_mapping = {
  name = "upnp_conf",
}
local upnpBasepath = "sys.upnp.redirect."
service_simp_port_mapping.get = function()
  local get = {}
  get.total_num = "0"
  get.upnp_conf = "end"
  local upnp = content_helper.convertResultToObject(upnpBasepath, proxy.get(upnpBasepath))
  if upnp == nil then
    return nil, "No upnp informatioin"
  end
  get.enabled = proxy.get("uci.upnpd.config.enable_upnp")[1].value
  local count = 0
  for k,v in pairs(upnp) do
    count = count + 1
    get["rule_"..(k-1).."_id"] = k
    get["rule_"..(k-1).."_descr"] = v.description
    get["rule_"..(k-1).."_ext_port"] = v.dest_port
    get["rule_"..(k-1).."_int_port"] = v.src_dport
    get["rule_"..(k-1).."_proto"] = v.proto
    get["rule_"..(k-1).."_ip"] = v.dest_ip
  end
  get.total_num = tostring(count)
  return get
end

service_simp_port_mapping.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_simp_port_mapping set"
  end
  proxy.set("uci.upnpd.config.enable_upnp", args.enabled)
  proxy.apply()
  return true
end

local service_firewall_config = {
  name = "firewall_conf",
}

service_firewall_config.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_firewall_config set"
  end
  local enabled = args.enabled
  local level =  tonumber(args.level)
  if enabled == "0" then
    proxy.set("rpc.network.firewall.mode", "normal")
  elseif enabled == "1" then
    if level == 1 then
      proxy.set("rpc.network.firewall.mode", "high")
    elseif level == 2 then
      proxy.set("rpc.network.firewall.mode", "user")
    end
  end
  proxy.apply()
  return true
end

service_firewall_config.get = function()
  local get = {}
  get.enabled = "1"
  local mode = proxy.get("rpc.network.firewall.mode")
  if mode[1].value == "user" then
    get.level = "2"
    get.enabled = "1"
  elseif mode[1].value == "high" then
    get.level = "1"
    get.enabled = "1"
  elseif mode[1].value == "normal" then
    get.enabled = "0"
    get.level = "1"
  end
  get["firewall_conf"] = "end"
  return get
end

local dmz_enabled_path = "rpc.network.firewall.dmz.enable"
local dmz_destIp_path = "rpc.network.firewall.dmz.redirect.dest_ip"

local service_dmz_config = {
  name = "dmz_conf",
}

service_dmz_config.get = function()
  local get = {
    enabled = dmz_enabled_path,
    server = dmz_destIp_path
  }
  content_helper.getExactContent(get)
  if get.server == "unknown" then
    get.server = "0.0.0.0"
  end
  get["dmz_conf"] = "end"
  return get
end

service_dmz_config.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_dmz_config set"
  end
  local paths = {}
  paths["rpc.network.firewall.dmz.enable"] = args.enabled
  paths["rpc.network.firewall.dmz.redirect.dest_ip"] = args.server
  proxy.set(paths)
  proxy.apply()
  return true
end

-------virtual server list
local basepath = "rpc.network.firewall.portforward."
local function getVirtualServerList()
  local pfw = content_helper.convertResultToObject(basepath, proxy.get(basepath))
  local data = {}
  if pfw == nil then
    return nil, "No port mapping information"
  end
  local count = 0
  for k,v in pairs(pfw) do
    count = count +1
    data["svc_"..(k-1).."_id"] = v.paramindex
    if v.tch_interface then
      data["svc_"..(k-1).."_code"] = (v.tch_interface):len() == 0 and 0 or (v.tch_interface)
    else
      data["svc_"..(k-1).."_code"] = 0
    end
    data["svc_"..(k-1).."_enabled"] = v.enabled
    data["svc_"..(k-1).."_descr"] = v.name
    if match(v.src_dport, ":") == ":" then
      data["svc_"..(k-1).."_ext_port_start"] = match(v.src_dport, "%d+")
      data["svc_"..(k-1).."_ext_port_end"] = match(match(v.src_dport, ":%d+"), "%d+")
    else
      data["svc_"..(k-1).."_ext_port_start"] = v.src_dport
      data["svc_"..(k-1).."_ext_port_end"] = v.src_dport
    end
    if match(v.dest_port, ":") == ":" then
      data["svc_"..(k-1).."_int_port_start"] = match(v.dest_port, "%d+")
      data["svc_"..(k-1).."_int_port_end"] = match(match(v.dest_port, ":%d+"), "%d+")
    else
      data["svc_"..(k-1).."_int_port_start"] = v.dest_port
      data["svc_"..(k-1).."_int_port_end"]  = v.dest_port
    end
    data["svc_"..(k-1).."_proto"] = string.upper(v["proto.@1.value"])
    data["svc_"..(k-1).."_ip"] = v.dest_ip
  end
  data["total_num"] = count
  data["virtual_server"] = "end"
  return data
end

local service_virtual_server_list = {
  name = "virtual_server_list",
}

service_virtual_server_list.get = function()
  return getVirtualServerList()
end

------End of service_virtual_server_list

-----Virtual server set
local service_virtual_server_add = {
  name = "virtual_server_set",
}
service_virtual_server_add.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_virtual_server_add set"
  end
  local total_num = tonumber(args["total_num"])
  local svc_code = args["svc_code"]
  local paths = {}
  for i=1, total_num do
    if args["id_"..(i-1)] == nil then
      local index = proxy.add(basepath)
      local protoIndex = proxy.add(basepath..index..".proto.")
      paths[basepath..index..".tch_interface"] = args.svc_code
      paths[basepath..index..".name"] = args["descr_"..(i-1)]
      paths[basepath..index..".enabled"] = args["enabled_"..(i-1)]
      if args["ext_port_start_"..(i-1)] ~= args["ext_port_end_"..(i-1)] then
        paths[basepath..index..".dest_port"] = args["int_port_start_"..(i-1)]..":"..args["ext_port_end_"..(i-1)]
        paths[basepath..index..".src_dport"] = args["ext_port_start_"..(i-1)]..":"..args["ext_port_end_"..(i-1)]
      else
        paths[basepath..index..".dest_port"] = args["int_port_start_"..(i-1)]
        paths[basepath..index..".src_dport"] = args["ext_port_start_"..(i-1)]
      end
      paths[basepath..index..".proto.@"..protoIndex..".value"] = args["proto_"..(i-1)]
      paths[basepath..index..".dest_ip"] = args["ip_"..(i-1)]
      paths[basepath..index..".dest"] = "lan"
      paths[basepath..index..".src"] = "wan"
      paths[basepath..index..".target"] = "DNAT"
      paths[basepath..index..".family"] = "ipv4"
    else
      paths[basepath..tonumber(args["id_"..(i-1)])..".enabled"] = args["enabled_"..(i-1)]
      paths[basepath..tonumber(args["id_"..(i-1)])..".name"] = args["descr_"..(i-1)]
      paths[basepath..tonumber(args["id_"..(i-1)])..".dest_ip"] = args["ip_"..(i-1)]
    end
  end
  proxy.set(paths)
  proxy.apply()
  return true
end
----End of service_virtual_server_set

-----Virtual server del
local function getId(args)
  local id={}
  local num = tonumber(args.total_num)
  for i in string.gmatch(args.id, "%d+") do
    id[#id + 1] = i
  end
  if #id ~= num or #id > num  then
    return "nil"
  end
  return id
end
local service_virtual_server_del = {
  name = "virtual_server_del",
}
service_virtual_server_del.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_virtual_server_del set"
  end
  for k,v in pairs(getId(args)) do
    proxy.del(basepath..tonumber(v)..".")
  end
  proxy.apply()
  return true
end
local bl_path = "uci.firewall.rule."
local host_path = "sys.hosts.host."
local ACCEPT = "ACCEPT"
local DROP = "DROP"
local function getHostNameByMac(mac)
  local name = ""
  local res = content_helper.convertResultToObject(host_path, proxy.get(host_path))
  for k,v in pairs(res) do
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

local function getBlList()
  local bl = {}
  bl["enabled"] = "1"
  bl["total_num"] = "0"
  bl["mode"] = "block"
  local count = 0
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  for k,v in pairs(res) do
    if (v.name == ACCEPT or v.name == DROP) and v.src_mac ~= "" then
      bl["dev_"..count.."_mac"] = v.src_mac
      bl["dev_"..count.."_name"] = getHostNameByMac(v.src_mac)
      bl["dev_"..count.."_enabled"] = v.enabled
      count = count+1
      bl["mode"] = v.target == ACCEPT and "allow" or "block"
    end
  end
  bl["total_num"] = count
  bl["bl_conf"] = "end"
  return bl
end
local service_bl_device_list = {
  name = "bl_conf",
  get = getBlList,
}

local function getCurMode()
  local mode = DROP
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  for k,v in pairs(res) do
    if (v.name == ACCEPT or v.name == DROP) and v.src_mac ~="" then
      mode = v.target
      break
    end
  end
  return mode
end

local function getCurDevCount()
  local count = 0
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  for k,v in pairs(res) do
    if (v.name == ACCEPT or v.name == DROP) and v.src_mac ~="" then
      count = count + 1
      break
    end
  end
  return count
end

service_bl_device_list.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_black_device_list set"
  end
  local paths = {}
  local mode = args.mode == "allow" and ACCEPT or DROP
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  for k,v in pairs(res) do
    if v.name == ACCEPT or v.name == DROP then
      if v.src_mac == "" then
        proxy.del(bl_path..(v.paramindex)..".")
      else
        paths[bl_path..(v.paramindex)..".target"] = mode
        paths[bl_path..(v.paramindex)..".name"] = mode
        proxy.set(paths)
      end
    end
  end
  paths={}
  if getCurDevCount() ~= 0 and mode == ACCEPT then
    local index = proxy.add(bl_path)
    paths[bl_path..index..".dest_port"] = "80"
    paths[bl_path..index..".src"] = "lan"
    paths[bl_path..index..".enabled"] = "1"
    paths[bl_path..index..".target"] = DROP
    paths[bl_path..index..".name"] = DROP
    proxy.set(paths)
  end
  proxy.apply()
  return true
end

local service_bl_device_add = {
  name = "bl_device_set",
}


service_bl_device_add.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_bl_device_add set"
  end
  local exist = 0
  local del = 0
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  local mode = getCurMode()
  for k,v in pairs(res) do
    if v.src_mac == args.mac then
        proxy.set(bl_path..(v.paramindex)..".enabled", args.enabled)
        exist = 1
        break
    end
    if v.name == DROP and v.src_mac == "" then
      proxy.del(bl_path..(v.paramindex)..".")
      del = 1
    end
  end
  local paths = {}
  if exist == 0 then
    local index = proxy.add(bl_path)
    paths[bl_path..index..".dest_port"] = "80"
    paths[bl_path..index..".src_mac"] = args.mac
    paths[bl_path..index..".src"] = "lan"
    paths[bl_path..index..".enabled"] = args.enabled
    paths[bl_path..index..".target"] = mode
    paths[bl_path..index..".name"] = mode
    proxy.set(paths)
  end
  if del == 1 then
    local index = proxy.add(bl_path)
    paths[bl_path..index..".dest_port"] = "80"
    paths[bl_path..index..".src"] = "lan"
    paths[bl_path..index..".enabled"] = "1"
    paths[bl_path..index..".target"] = DROP
    paths[bl_path..index..".name"] = DROP
    proxy.set(paths)
  end
  proxy.apply()
  return true
end

local service_bl_device_del = {
  name = "bl_device_del",
}

service_bl_device_del.set = function(args)
  if args == nil then
    return nil, "Invalid parameters in service_bl_device_del set"
  end
  local res = content_helper.convertResultToObject(bl_path, proxy.get(bl_path))
  for k,v in pairs(res) do
    if v.src_mac == args.mac then
      proxy.del(bl_path..(v.paramindex)..".")
    end
    if getCurDevCount() == 0 and  v.name == DROP and v.src_mac == "" then
      proxy.del(bl_path..(v.paramindex)..".")
    end
  end
  proxy.apply()
  return true
end

register(service_bl_device_del)
register(service_bl_device_add)
register(service_bl_device_list)
register(service_virtual_server_list)
register(service_virtual_server_add)
register(service_firewall_config)
register(service_dmz_config)
register(service_simp_port_mapping)
register(service_virtual_server_del)
