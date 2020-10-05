local setmetatable = setmetatable
local match, format, gsub, gmatch, find, lower = string.match, string.format, string.gsub, string.gmatch, string.find, string.lower
local upper = string.upper
local remove = table.remove
local untaint = string.untaint
local dm = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local api = require("fwapihelper")

local usb_path = "sys.usb.device."

local usb_map = {
  ["samba_enabled"] = "uci.samba.samba.filesharing",
  ["samba_server"] = "uci.samba.samba.name",
  ["samba_workgroup"] = "uci.samba.samba.workgroup",
  ["printserver_enabled"] = "uci.printersharing.config.enabled",
  ["dlna_enabled"] = "uci.dlnad.config.enabled",
  ["3g_timeout"] = "uci.wansensing.global.backup_time",
  ["3g_apn"] = "uci.mobiled.profile.@0.apn",
  ["3g_username"] = "uci.mobiled.profile.@0.username",
  ["3g_password"] = "uci.mobiled.profile.@0.password"
}

local samba_auth_map = {
  ["samba_share_on"] = "uci.samba.userauth.wan_access",
  ["disk_protected"] = "uci.samba.userauth.authentication",
  ["disk_username"]  = "uci.samba.userauth.username1",
  ["disk_password"]  = "uci.samba.userauth.password1",
}
local status_path = "rpc.mobiled.device.@1.display_status"
local nwmode_path = "uci.wansensing.global.network_mode"

local Mode3G = {
  ["Mobiled"] = "0",
  ["Mobiled_scheduled"] = "1",
  ["auto"] = "2",
  ["0"] = "Mobiled",
  ["1"] = "Mobiled_scheduled",
  ["2"] = "auto",
}

local function get_usb_storage()
  local usb = api.GetObjects(usb_path)
  for k,v in pairs(usb) do
    if v["interface.1.bInterfaceProtocol"] ~= "50" then
      remove(usb,k)
    end
  end
  return usb
end

local USBStorage = {
  name = "name",
  fs = "partition.#.FileSystem",
  size = "partition.#.TotalSpace",
  available = "partition.#.AvailableSpace",
}

local function get_smb_auth_data()
  local smb_auth_data = {}
  for k,v in pairs(samba_auth_map) do
    smb_auth_data[k] = v
  end
  content_helper.getExactContent(smb_auth_data)
  return smb_auth_data
end

local function get_usb_info()
  local data = {}
  for k,v in pairs(usb_map) do
    data[k] = v
  end
  content_helper.getExactContent(data)

  local usb = get_usb_storage()
  data["total_disks"] = #usb
  for k,v in pairs(usb) do
    local id = k
    v.name = format("Disk %d", id)
    id = id - 1
    -- get mutiple partition index
    local partition_ids = {}
    local tmp=""
    for v_key,v_value in pairs(v) do
      tmp = v_key:match("partition.(%d+).FileSystem")
      if tmp and tmp ~= ""  then
        partition_ids[#partition_ids+1] = tmp
      end
    end
    for key, item in pairs(USBStorage) do
      local path = format("disk_%d_%s", id, key)
      if key == "name" then
        data[path] = v.manufacturer == "" and "Unknown" or v.manufacturer
      else
        local total = 0
        local fs_list = ""
        if #partition_ids > 0 then
          for i=1, tonumber(v.partitionOfEntries) do
            local value = v[item:gsub("#", partition_ids[i])]
            if key == "fs" then
              if value ~= "" then
                value = lower(value)
                local fs_list_tmp =",".. fs_list .. ","
                if match(fs_list_tmp,","..value..",") == nil  then
                  fs_list = fs_list == "" and value or fs_list ..",".. value
                end
              end
            else
              local number = value:match("[0-9]+%.[0-9]+")
              total = tonumber(number) + total
            end
          end
          if key == "fs" then
            data[path] = fs_list
          end
          if key == "size" or key == "available" then
            data[path] = format("%s GB", total)
          end
        end
      end
    end
  end
  local status = dm.get(status_path)
  if status and status[1].value == "connected" then
    data["3g_connection_status"] = "1"
  else
    data["3g_connection_status"] = "0"
  end
  local mode = dm.get(nwmode_path)[1].value
  mode = untaint(mode)
  if mode == "Fixed_line" then
    data["3g_fallback"] = "0"
  else
    data["3g_fallback"] = "1"
    data["3g_activation"] = Mode3G[mode]
  end

  data["3g_pin"] = "********"
  local smb_auth_data = get_smb_auth_data()
  data["disk_protected"] = smb_auth_data.disk_protected
  data["disk_username"]  = smb_auth_data.disk_username
  data["disk_password"]  = smb_auth_data.disk_password
  data["samba_share_on"] = smb_auth_data.samba_share_on == '1' and "wan" or "lan"
  data["usb_status"] = "end"
  return data
end

local function validate_pin(value)
  local pin = value:match("^(%d+)$")
  if pin and pin:len() >= 4 and pin:len() <= 8 then
    return true
  end
  return false
end

local service_usb_status = {
  name = "usb_status",
  get = get_usb_info,
  set = function(args)
    local paths = {}
    for k,v in pairs(usb_map) do
      paths[usb_map[k]] = args[k]
    end

    local smb_auth_data = get_smb_auth_data()
    local samba_share_on = args.samba_share_on == "lan" and "0" or "1"
    if smb_auth_data.samba_share_on ~= samba_share_on then
      dm.set(samba_auth_map.samba_share_on, samba_share_on)
    end
    if smb_auth_data.disk_protected ~= args.disk_protected then
      dm.set(samba_auth_map.disk_protected, args.disk_protected)
    end
    if smb_auth_data.disk_username ~= args.disk_username then
      dm.set(samba_auth_map.disk_username, args.disk_username)
    end
    if smb_auth_data.disk_password ~= args.disk_password then
      dm.set(samba_auth_map.disk_password, args.disk_password)
    end

    if validate_pin(args["3g_pin"]) then
      local pin_state = dm.get("rpc.mobiled.device.@1.sim.pin.pin_state")
      if pin_state and pin_state[1].value ~= "disabled" then
        paths["rpc.mobiled.device.@1.sim.pin.disable"] = args["3g_pin"]
      end
    end
    local mode = "Fixed_line"
    local act_3g = untaint(args["3g_activation"])
    if args["3g_fallback"] == "1" then
      mode = Mode3G[act_3g]
    end
    paths[nwmode_path] = mode

    -- Press button "Activate backup now"
    if not args.samba_enabled and (act_3g == "0" or act_3g == "1") then
      local wan_up = dm.get("rpc.network.interface.@wan.up")
      wan_up = wan_up and wan_up[1].value
      -- if wan is down, enable mobile
      if wan_up == "0" then
        paths["uci.network.interface.@wwan.auto"] = "1"
        paths["uci.network.interface.@wwan.enabled"] = "1"
      end
    end
    dm.set(paths)
    dm.apply()
    return true
  end,
}

local service_usb_remove = {
  name = "usb_remove",
  set = function(args)
    -- diskid = 0 or 1, 0-usb port1 1-usb port2
    local disk = "-1"
    if args.diskId == "1" then
      disk = "-2"
    end
    local usb = get_usb_storage()
    local count = #usb
    for k,v in pairs(usb) do
      if count == 1 or (count == 2 and v.path:match(disk) == disk) then
        local path = format("%s%d.unmount", usb_path, v.paramindex)
        dm.set(path, "1")
        dm.apply()
        break
      end
    end
    return true
  end,
}

local lan_map = {
  dhcpStart = "uci.dhcp.dhcp.@lan.start",
  dhcpLimit = "uci.dhcp.dhcp.@lan.limit",
  dhcpState = "uci.dhcp.dhcp.@lan.ignore",
  leaseTime = "uci.dhcp.dhcp.@lan.leasetime",
  localDevIP = "uci.network.interface.@lan.ipaddr",
  localDevMask = "uci.network.interface.@lan.netmask",
  localIPv6 = "uci.network.interface.@lan.ipv6",
  localIP6prefix = "rpc.network.interface.@6rd.ip6prefix",
}

local function get_lan_status()
  local lan_params ={}
  for k,v in pairs(lan_map) do
    lan_params[k] = v
  end
  content_helper.getExactContent(lan_params)

  local baseip = post_helper.ipv42num(lan_params["localDevIP"])
  local netmask = post_helper.ipv42num(lan_params["localDevMask"])
  local start = tonumber(lan_params["dhcpStart"])
  local numips = tonumber(lan_params["dhcpLimit"])
  local network = bit.band(baseip, netmask)
  local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
  local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
  local ipend = network + numips + start - 1
  if ipend > ipmax then
    ipend = ipmax
  end
  ipstart = post_helper.num2ipv4(ipstart)
  ipend = post_helper.num2ipv4(ipend)
  network = post_helper.num2ipv4(network)

  local data ={}
  data.ip =  lan_params.localDevIP
  data.netmask = lan_params.localDevMask
  data.IPV6_on_LAN = lan_params.localIPv6
  data.IPV6_prefix_6rd = lan_params.localIP6prefix == "" and " " or lan_params.localIP6prefix
  data.DHCP_enabled = (lan_params.dhcpState == "0" or lan_params.dhcpState == "") and  "1" or "0"
  data.DHCP_start = ipstart
  data.DHCP_end = ipend

  if find(lan_params.leaseTime, "h") then
    local hours = gsub(lan_params.leaseTime, "h", "")
    data.DHCP_duration = tostring(tonumber(hours) * 3600)
  else
    data.DHCP_duration = lan_params.leaseTime
  end

  local dhcp_host = api.mgr:GetAllDHCPHost()
  for k,v in ipairs(dhcp_host) do
    data["DHCP_" .. (k-1) .."_mac" ] = v.mac
    data["DHCP_" .. (k-1) .."_ip" ] = v.ip
  end
  return data
end

local service_lan_status = {
  name = "lan_status",
  get = get_lan_status,
}

service_lan_status.set = function(args)
  local paths = {}
  local paths_dhcp = {}
  --need valid ip format---
  local baseip = post_helper.ipv42num(args.ip)
  local netmask = post_helper.ipv42num(args.netmask)
  local dhcpstart = post_helper.ipv42num(args.DHCP_start)
  local dhcpend = post_helper.ipv42num(args.DHCP_end)
  local network = bit.band(baseip, netmask)
  local start = dhcpstart - network
  local limit = dhcpend - network - start + 1
  paths[lan_map.localDevIP] = args.ip
  paths[lan_map.localDevMask] = args.netmask
  paths[lan_map.localIPv6] = args.IPV6_on_LAN
  paths_dhcp[lan_map.dhcpState] = args.DHCP_enabled == "1" and "0" or "1"
  paths_dhcp[lan_map.dhcpStart] = tostring(start)
  paths_dhcp[lan_map.dhcpLimit] = tostring(limit)
  paths_dhcp[lan_map.leaseTime] = args.DHCP_duration
  dm.set(paths_dhcp)
  dm.apply()
  dm.set(paths)
  dm.apply()
  return true
end

local service_dhcp_set = {
  name = "dhcp_set",
  set = function(args)
    api.mgr:SetDHCPHost(untaint(args.mac), untaint(args.ip))
    api.Apply()
    return true
  end
}

local service_dhcp_del = {
  name = "dhcp_del",
  set = function(args)
    api.mgr:DelDHCPHost(untaint(args.mac))
    api.Apply()
    return true
  end,
}

local UPnP = {
  id = "id",
  descr = "description",
  ext_port = "src_dport",
  int_port = "dest_port",
  proto = "proto",
  ip = "dest_ip",
}

local upnp_path = "sys.upnp.redirect."
local enable_upnp_path = "uci.upnpd.config.enable_upnp"

local service_simp_port_mapping = {
  name = "upnp_conf",
  get = function()
    local data = {
      upnp_conf = "end"
    }
    data.enabled = dm.get(enable_upnp_path)[1].value
    local upnp = api.GetObjects(upnp_path)
    for k,v in pairs(upnp) do
      v.id = k
      for key,item in pairs(UPnP) do
        local path = format("rule_%d_%s", k-1, key)
        data[path] = v[item]
      end
    end
    data.total_num = #upnp
    return data
  end,
  set = function(args)
    dm.set(enable_upnp_path, args.enabled)
    dm.apply()
    return true
  end,
}

local FirewallLevel = {
  normal = {enabled = "0", level = "1", firewall_conf = "end"},
  high   = {enabled = "1", level = "1", firewall_conf = "end"},
  user   = {enabled = "1", level = "2", firewall_conf = "end"},
}

local fwm_path = "rpc.network.firewall.mode"

local service_firewall_config = {
  name = "firewall_conf",
  get = function()
    local mode = dm.get(fwm_path)[1].value
    return FirewallLevel[untaint(mode)]
  end,
  set = function(args)
    local enabled = args.enabled
    local level   = args.level
    local mode = "normal"
    if enabled == "1" then
      if level == "1" then
        mode = "high"
      elseif level == "2" then
        mode = "user"
      end
    end
    dm.set(fwm_path, mode)
    dm.apply()
    return true
  end
}


local dmz_enabled_path = "rpc.network.firewall.dmz.enable"
local dmz_destip_path = "rpc.network.firewall.dmz.redirect.dest_ip"

local service_dmz_config = {
  name = "dmz_conf",
}

service_dmz_config.get = function()
  local data = {
    enabled = dmz_enabled_path,
    server = dmz_destip_path
  }
  content_helper.getExactContent(data)
  if data.server == "unknown" then
    data.server = "0.0.0.0"
  end
  data["dmz_conf"] = "end"
  return data
end

service_dmz_config.set = function(args)
  local paths = {}
  paths[dmz_enabled_path] = args.enabled
  paths[dmz_destip_path] = args.server
  dm.set(paths)
  dm.apply()
  return true
end

-- Virtual server list
local PortForward = {
  id = "paramindex",
  descr = "name",
  enabled = "enabled",
  ext_port_start = "ext_port_start",
  ext_port_end = "ext_port_end",
  int_port_start = "int_port_start",
  int_port_end = "int_port_end",
  ip = "dest_ip",
  proto = "protocal"
}

-- This mapping is gotten from Fastweb app/portForwardingConf.js
local PMNameCodeMap = setmetatable({
  ['Xbox Live'] = '1',
  ['Playstation Network'] = '2',
  ['AIM Talk'] = '51',
  ['Bit Torrent'] = '52',
  ['BearShare'] = '53',
  ['Checkpoint FW1 VPN'] = '54',
  ['Counter Strike'] = '55',
  ['DirectX 7'] = '56',
  ['DirectX 8'] = '57',
  ['DirectX 9'] = '58',
  ['eMule'] = '59',
  ['FTP Server'] = '60',
  ['Gamespy Arcade'] = '61',
  ['HTTP Server (World Wide Web)'] = '62',
  ['HTTPS Server'] = '63',
  ['iMesh'] = '64',
  ['KaZaA'] = '65',
  ['Mail Server (SMTP)'] = '66',
  ['Microsoft Remote Desktop'] = '67',
  ['MSN Game Zone'] = '68',
  ['MSN Game Zone (DX)'] = '69',
  ['NNTP Server'] = '70',
  ['Secure Shell Server (SSH)'] = '71',
  ['Steam Games'] = '72',
  ['Telnet Server'] = '73',
  ['VNC'] = '74',
}, { __index = function() return '0' end })

local function get_ports(ports)
  local sp, ep
  sp, ep = ports:match("(%d+):(%d+)")
  if not sp then
    sp = ports
    ep = ports
  end
  return sp, ep
end

local function set_ports(startport, endport)
  if endport and startport ~= endport then
    return format("%s:%s", startport, endport)
  else
    return startport
  end
end

local pfw_path = "rpc.network.firewall.portforward."

local function get_virtual_server_list()
  local data = {
    virtual_server_list = "end"
  }
  local pfw = api.GetObjects(pfw_path)
  for k,v in pairs(pfw) do
    v.ext_port_start, v.ext_port_end = get_ports(v.src_dport)
    v.int_port_start, v.int_port_end = get_ports(v.dest_port)
    v.protocal = upper(v["proto.@1.value"] or "")
    if v.dest_ip == "unknown" then
      v.dest_ip = v.dest_mac
    end
    for key,item in pairs(PortForward) do
      local path = format("svc_%d_%s", k-1, key)
      data[path] = v[item]
      if key == "descr" then
        data[format("svc_%d_code", k-1)] = PMNameCodeMap[untaint(v[item])]
      end
    end
  end
  data.total_num = #pfw
  return data
end

local service_virtual_server_list = {
  name = "virtual_server_list",
  get = get_virtual_server_list,
}

local PFWMapping = {
  enabled = "enabled_#",
  name = "descr_#",
  dest_ip = "ip_#",
}

local PFWInitMapping = {
  ["dest"] = "lan",
  ["src"] = "wan",
  ["target"] = "DNAT",
  ["family"] = "ipv4",
  ["dest_port"] = "int_port",
  ["src_dport"] = "ext_port",
  ["proto.@#.value"] = "proto_#",
}

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
  gw = "uci.network.interface.@lan.ipaddr",
  netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)
local validateLanIP = post_helper.getValidateStringIsDeviceIPv4(ipdetails.gw, ipdetails.netmask)

local service_virtual_server_add = {
  name = "virtual_server_set",
  set = function(args)
    local total_num = tonumber(args["total_num"])
    local paths = {}
    local path, index
    for i=0, total_num-1 do
      if not validateLanIP(args["ip_"..i]) then
        return nil, "Invalid IP in service_virtual_server_add set:" .. string.untaint(args["ip_"..i])
      end

      if args["id_"..i] == nil then
        index = dm.add(pfw_path)
        for k,v in pairs(PFWInitMapping) do
          path = format("%s%d.%s", pfw_path, index, k)
          if k == "dest_port" or k == "src_dport"then
            local sp = args[format("%s_start_%d", v, i)]
            local ep = args[format("%s_end_%d", v, i)]
            paths[path] = set_ports(sp, ep)
          elseif k == "proto.@#.value" then
            local pindex = dm.add(pfw_path..index..".proto.")
            path = path:gsub("#", pindex)
            paths[path] = args[v:gsub("#",i)]
          else
            paths[path] = v
          end
        end
      else
        index = tonumber(args["id_"..i])
      end

      for k,v in pairs(PFWMapping) do
        path = format("%s%d.%s", pfw_path, index, k)
        paths[path] = untaint(args[v:gsub("#",i)])
      end
    end
    dm.set(paths)
    dm.apply()
    return true
  end,
}

-----Virtual server del
local service_virtual_server_del = {
  name = "virtual_server_del",
  set = function(args)
    for i in gmatch(untaint(args.id), "%d+") do
      local path = format("%s%d.", pfw_path, i)
      dm.del(path)
    end
    dm.apply()
    return true
  end
}

local BlackList = {
  "mac",
  "name",
  "enabled"
}

local function get_black_list()
  local data = {
    enabled = "1",
    bl_conf = "end"
  }

  data.mode = api.mgr:GetBlackListMode()
  local devices = api.GetDevicesByMacIndex()
  local bldevices = api.mgr:GetBlackListDevice()
  for k,v in pairs(bldevices) do
    local mac = untaint(v.mac)
    v.name = devices[mac] and devices[mac].FriendlyName or format("Unknown-%s", mac)
    for _,item in ipairs(BlackList) do
      local path = format("dev_%d_%s", k-1, item)
      data[path] = v[item]
    end
  end
  data["total_num"] = #bldevices
  return data
end

local service_bl_device_list = {
  name = "bl_conf",
  get = get_black_list,
  set = function(args)
    local mode = untaint(args.mode)
    api.mgr:SetBlackListMode(mode)
    api.Apply()
    return true
  end,
}

local service_bl_device_add = {
  name = "bl_device_set",
  set = function(args)
    local mac = untaint(args.mac)
    local enabled = untaint(args.enabled)
    api.mgr:SetBlackListDevice(mac, enabled)
    api.Apply()
    return true
  end,
}

local service_bl_device_del = {
  name = "bl_device_del",
  set = function(args)
    local mac = untaint(args.mac)
    api.mgr:DelBlackListDevice(mac)
    api.Apply()
    return true
  end,
}

register(service_usb_status)
register(service_usb_remove)
register(service_lan_status)
register(service_dhcp_set)
register(service_dhcp_del)
register(service_simp_port_mapping)
register(service_firewall_config)
register(service_dmz_config)
register(service_virtual_server_list)
register(service_virtual_server_add)
register(service_virtual_server_del)
register(service_bl_device_list)
register(service_bl_device_add)
register(service_bl_device_del)
