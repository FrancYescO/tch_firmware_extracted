local M = {}


local uci_helper = require("transformer.mapper.ucihelper")
local foreach_on_uci = uci_helper.foreach_on_uci
local open = io.open
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local format = string.format
local min = math.min
local max = math.max
local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring

local ubus = require("ubus")
local conn = ubus.connect()
if not conn then
  error("Failed to connect to ubusd")
end

-- Convert an interface name ('wan', 'lan' ...) to a zone
local firewallzone_binding = {config="firewall", sectionname="zone"}
function M.interface2zone(interfacename)
  local result
  foreach_on_uci(firewallzone_binding, function(s)
    if (s.network == nil and s.name == interfacename) then
      result = s
      return false
    end
    if (type(s.network) == "table") then
      for _, zone_interfacename in pairs(s.network) do
        if (zone_interfacename == interfacename) then
          result = s
          return false
        end
     end
    end
  end)
  return result
end

-- Get lan zones in {[zone] = true} format, plus nr of items
function M.get_lan_zones()
  local result={}
  local count=0

  foreach_on_uci(firewallzone_binding, function(s)
    if s['wan']~='1' then
      result[s['name']] = true
      count = count + 1
    end
  end
  )
  return result, count
end

-- Get all interfaces marked as WAN in firewall zones
function M.findLanWanInterfaces(wan)
  -- iterate over all firewall zones. If zone wan flag is set/not set, add interfaces to result
  local interfaces={}
  uci_helper.foreach_on_uci(firewallzone_binding,function(s)
    -- iterate over all zones and append interface names
    if (s['wan']=='1') == wan then
      -- 'network' is optional, check for its presence (and that's it's a table)
      if type(s['network']) == "table" then
        for _,v in pairs(s['network']) do
          interfaces[#interfaces+1]=v
        end
      else
        -- network interface name equals zone name if network is unspecified
        interfaces[#interfaces+1]=s['name']
      end
    end
  end
  )
  return interfaces
end

-- Checks whether a certain device is part of a certain bridge
local function device_in_bridge(device, bridge)
  if not bridge then
    return false
  end
  local bridge_status = M.get_ubus_device_status(bridge)
  if (bridge_status and bridge_status['bridge-members']) then
    for _, v in ipairs(bridge_status['bridge-members']) do
      if (v == device) then
        return true
      end
    end
  end
  return false
end

-- Retrieve the information on UBUS under network.device
local function get_ubus_device_status(devname)
  return conn:call("network.device", "status", { name = devname })
end
M.get_ubus_device_status = get_ubus_device_status

-- Retrieve the information on UBUS under network.interface.{wan/lan/...}
local function get_ubus_interface_status(intf)
  return conn:call("network.interface." .. intf, "status", { })
end
M.get_ubus_interface_status = get_ubus_interface_status


-- Find lower-layer interface from ubus, returns an array
-- If lower layer is a bridge, returns the interfaces in the bridge
local function get_lower_layers_with_status(intf, show_bridge)
  local llintf={}
  local status=get_ubus_interface_status(intf)
  if status then
    local dev=status['device']
    if dev then
      if (show_bridge ~= 1) and match(dev,"^br%-") then -- bridge
        local devicestatus=conn:call("network.device", "status", { name = dev })
        if devicestatus then
          local bridgemembers=devicestatus['bridge-members']
          if bridgemembers then 
            if type(bridgemembers)=='table' then
              llintf=bridgemembers
            elseif type(bridgemembers)=='string' then
              llintf[1]=bridgemembers
            end
          end
        end
      else
        llintf[1]=dev
      end
    end
  end
  return llintf, status
end
M.get_lower_layers_with_status = get_lower_layers_with_status

function M.get_lower_layers(intf, show_bridge)
  local lowerLayers, _ = get_lower_layers_with_status(intf, show_bridge)
  return lowerLayers
end

-- Convert a device ('eth4') to an interface name ('wan') (using UBUS)
function M.dev2interface(device)
  local namespaces = conn:objects()
  for _, interface in pairs(namespaces) do
    local name = match(interface, "^network%.interface%.(.*)")
    if (name) then
      local info = conn:call(interface, "status", { })
      if (info and (info['device'] == device or device_in_bridge(device, info['device']))) then
        return name
      end
    end
  end
  return nil
end

-- Split key in two parts and return these parts.
-- Used separator is |.
function M.split_key(key)
  return match(key, "^([^|]*)|(.*)")
end

-- Convert the interface to the real device (including VLAN)
function M.intf2device(intf, wan_con_key)
  local ll_intfs = M.get_lower_layers(intf)
  local _, expected_novid = M.split_key(wan_con_key)
  for _,v in ipairs(ll_intfs) do
    -- strip vlan id
    local no_vid=gsub(v,'%.%d+','')
    if no_vid == expected_novid then
      return v
    end
  end
  return nil
end


-- lookup table for getIntfInfo
local pathlookup = {
  ["operstate"] = "/sys/class/net/%s/operstate",
  ["address"] = "/sys/class/net/%s/address",
  ["carrier"] = "/sys/class/net/%s/carrier",
  ["multicast"] = "/sys/class/net/%s/statistics/multicast",
  ["rx_bytes"] = "/sys/class/net/%s/statistics/rx_bytes",
  ["rx_compressed"] = "/sys/class/net/%s/statistics/rx_compressed",
  ["rx_crc_errors"] = "/sys/class/net/%s/statistics/rx_crc_errors",
  ["rx_dropped"] = "/sys/class/net/%s/statistics/rx_dropped",
  ["rx_errors"] = "/sys/class/net/%s/statistics/rx_errors",
  ["rx_fifo_errors"] = "/sys/class/net/%s/statistics/rx_fifo_errors",
  ["rx_frame_errors"] = "/sys/class/net/%s/statistics/rx_frame_errors",
  ["rx_length_errors"] = "/sys/class/net/%s/statistics/rx_length_errors",
  ["rx_missed_errors"] = "/sys/class/net/%s/statistics/rx_missed_errors",
  ["rx_over_errors"] = "/sys/class/net/%s/statistics/rx_over_errors",
  ["rx_packets"] = "/sys/class/net/%s/statistics/rx_packets",
  ["tx_aborted_errors"] = "/sys/class/net/%s/statistics/tx_aborted_errors",
  ["tx_bytes"] = "/sys/class/net/%s/statistics/tx_bytes",
  ["tx_carrier_errors"] = "/sys/class/net/%s/statistics/tx_carrier_errors",
  ["tx_compressed"] = "/sys/class/net/%s/statistics/tx_compressed",
  ["tx_dropped"] = "/sys/class/net/%s/statistics/tx_dropped",
  ["tx_errors"] = "/sys/class/net/%s/statistics/tx_errors",
  ["tx_fifo_errors"] = "/sys/class/net/%s/statistics/tx_fifo_errors",
  ["tx_heartbeat_errors"] = "/sys/class/net/%s/statistics/tx_heartbeat_errors",
  ["tx_packets"] = "/sys/class/net/%s/statistics/tx_packets",
  ["tx_window_errors"] = "/sys/class/net/%s/statistics/tx_window_errors",
  ["mtu"] = "/sys/class/net/%s/mtu"
}

-- get info from /sys/class/net
function M.getIntfInfo(dev, value)
  local pathtemplate = pathlookup[value]
  if pathtemplate then
    local realpath = format(pathtemplate, dev)
    local fd = open(realpath)
    if fd then
      local value = fd:read("*line")
      fd:close()
      return value
    end
  end
  return ""
end

-- determine if an interface is an alias
local alias_binding={config="network",sectionname="",option=""}
function M.is_alias(intf)
  alias_binding.sectionname=intf
  alias_binding.option="ifname"
  local ifname=uci_helper.get_from_uci(alias_binding)
  alias_binding.option="device"
  local device=uci_helper.get_from_uci(alias_binding)
  local pat="^@"
  if type(ifname)=='string' and type(device)=='string' and (match(device,pat) or match(ifname,pat)) then
    return true
  end
  return false
end

-- get statistics for network interface
function M.get_intf_stat(intfname, statname)
    local status = M.get_ubus_interface_status(intfname)
    local l3device = status.l3_device
    if l3device then
      status = M.get_ubus_device_status(l3device)
      if status.statistics and status.statistics[statname] then
        return tostring(status.statistics[statname])
      end
      -- statname not available in ubus, try /sys/class/net
      local stat = M.getIntfInfo(l3device, statname)
      if stat ~= nil then
        return stat
      end
    end
    return "0"
end

-- Determine whether a network device is currently in use, by
-- checking whether it is up and it has received bytes
function M.device_in_use(device)
-- for pppoa, ll interfaces do not show up in ubus call network.device status
-- we need to get this info from /sys/class/net/
  local operstate = M.getIntfInfo(device,"operstate")
  local rx_bytes = M.getIntfInfo(device,"rx_bytes")
  return (operstate=="up" and rx_bytes and tonumber(rx_bytes)>0)
end

-- hex2decimal function
local hexmap = {
  ["0"]=0,["1"]=1,["2"]=2,["3"]=3,
  ["4"]=4,["5"]=5,["6"]=6,["7"]=7,
  ["8"]=8,["9"]=9,["A"]=10,["B"]=11,
  ["C"]=12,["D"]=13,["E"]=14,["F"]=15,
  ["a"]=10,["b"]=11,["c"]=12,["d"]=13,
  ["e"]=14,["f"]=15,
}

function M.hex2Decimal(hexstring)
  local result=0
  local multiplier=1
  if hexstring then
    local reversehexstring=hexstring:reverse()
    for hexdigit in gmatch(reversehexstring,"%x") do
      result=result+hexmap[hexdigit]*multiplier
      multiplier=multiplier*16
    end
  end
  return format("%.0f",result)
end

-- Convert netmask from /24 to 255.255.255.0
function M.netmask2mask(maskbits)
    if (type(maskbits) ~= "number") then
      return nil
    end
    local result = ""
    for i=1,4 do
      result = result .. tostring(256 - 2^(8 - min(8, maskbits)))
      if (i < 4) then
        result = result .. "."
      end
      maskbits = max(0, maskbits - 8)
    end
    return result
end

return M
