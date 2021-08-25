#!/usr/bin/env lua

local uloop = require 'uloop'
uloop.init()

local ubus = require('ubus').connect()
local uci = require 'uci'
local process = require 'tch.process'

local function load_l3_devices()
  local l3 = {}
  local intfs = ubus:call("network.interface", "dump", {}) or {}
  for _, intf in ipairs(intfs.interface or {}) do
    local l3_device = intf.l3_device
    if l3_device then
      l3[intf.interface] = l3_device
    end
  end
  return l3
end

local function lxc_interface_connection_index(lxc, interface, l3_devices)
  local l3 = l3_devices[interface]
  if not l3 then
    return
  end
  for option, value in pairs(lxc) do
    local index = option:match("lxc_net_(%d+)_link")
    if index and value==l3 then
      return index
    end
  end
end

local function lxc_net_option(lxc, index, option)
  local n = ("lxc_net_%s_%s"):format(index, option)
  return lxc[n]
end

local function lxcs_connected_to(interface, l3_devices)
  local cursor = uci.cursor(nil, "/var/state")
  local lxcs = {}
  cursor:foreach("lxc", "lxc_instance", function(lxc)
    local index = lxc_interface_connection_index(lxc, interface, l3_devices)
    if index then
      lxcs[lxc[".name"]] = {
        type = lxc_net_option(lxc, index, "type"),
        link = lxc_net_option(lxc, index, "link"),
        veth_pair = lxc_net_option(lxc, index, "veth_pair"),
      }
    end
  end)
  cursor:close()
  return lxcs
end

local function reattach_lxc_to_bridge(info)
  if info.type ~= "veth" then
    return
  end
  local bridge = info.link
  local device = info.veth_pair
  if bridge and device then
    process.execute("brctl", {"addif", bridge, device})
  end
end

local function send_lxc_network_reload(lxc)
  process.execute("lxc-attach", {"-n", lxc, "--", "/etc/init.d/network", "reload"})
end

local function reload_lxc_network(interface)
  local lxcs = lxcs_connected_to(interface, load_l3_devices())
  for lxc, info in pairs(lxcs) do
    reattach_lxc_to_bridge(info)
    send_lxc_network_reload(lxc)
  end
end

local function interface_up(interface)
  reload_lxc_network(interface)
end

local function interface_event(data)
  if data.action=="ifup" then
    interface_up(data.interface)
  end
end

local function main()
  ubus:listen{
    ["network.interface"] = interface_event,
  }
  uloop.run()
end

main()
