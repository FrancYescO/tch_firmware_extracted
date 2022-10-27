#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=300})
  fifo_file_path = args.fifo
  interval = args.interval
end

local lfs = require("lfs")
if not lfs.attributes("/usr/bin/fhcd", "ino") then
  return
end

local uloop = require("uloop")
local ubus_conn = require("ubus").connect()

-- Uloop timer and the required interval
local timer

local function get_process_memory(info)
  local file = io.open("/proc/" .. info.pid .. "/status", "r")
  if not file then
    return
  end
  local status = file:read("*all")
  file:close()
  if not status then
    return
  end
  local vmhwm_exp = "VmHWM:%s+(%d+)%s+kB"
  local vmhwm = status:match(vmhwm_exp)
  local vmrss_exp = "VmRSS:%s+(%d+)%s+kB"
  local vmrss = status:match(vmrss_exp)
  local vmdata_exp = "VmData:%s+(%d+)%s+kB"
  local vmdata = status:match(vmdata_exp)
  info.vmhwm = tonumber(vmhwm)
  info.vmrss = tonumber(vmrss)
  info.vmdata = tonumber(vmdata)
end

local function get_total_cpu()
  local file = io.open("/proc/stat", "r")
  local line = file:read("*l")
  file:close()
  local  exp = "^cpu%s+(%d+) (%d+) (%d+)"
  local user, nice, system = line:match(exp)
  local user_total = user + nice
  if not user then
    return
  end
  return user_total, system
end

local function get_num_fhcd_fd(info)
  local num_fd = 0
  for _ in lfs.dir("/proc/" .. info.pid .. "/fdinfo") do
    num_fd = num_fd +1
  end
  info.num_fd = num_fd
end

local function strip_nodeconf(nodeconf)
  for k in pairs(nodeconf) do
    if k ~= "_seq" then
      nodeconf[k] = nil
    end
  end
end

local function strip_epinfo(epinfo)
  for _, ep in pairs(epinfo) do
    for k in pairs(ep) do
      if k ~= "name" and k ~= "type" then
        ep[k] = nil
      end
    end
  end
end

local function replace_ID_with_serial(ID2serial, nodes)
  for _, node in pairs(nodes) do
    for TLV_ID, TLV_acks in pairs(node.acks or {}) do
      local acks_tmp = {}
      for node_ID, seq in pairs(TLV_acks) do
        acks_tmp[ID2serial[node_ID]] = seq
      end
      node.acks[TLV_ID] = acks_tmp
    end
    for _, peer in ipairs(node.peers or {}) do
      peer.peer_id = ID2serial[peer.peer_id]
    end
  end
end

local function get_dump_fhcd(info)
  local dump = ubus_conn:call("fhcd", "dump", {})
  if not dump then
    return
  end
  local node_count = 0
  local nodes = {}
  local ID2serial = {}
  for ID, node in pairs(dump.nodes) do
    node_count = node_count + 1
    local serial = node.nodeinfo.serial
    ID2serial[ID] = serial
    strip_nodeconf(node.nodeconf)
    strip_epinfo(node.epinfo)
    node.peer_count = #node.peers
    nodes[serial] = node
  end
  replace_ID_with_serial(ID2serial, nodes)
  dump.node_id = nil
  dump.node_count = node_count
  dump.nodes = nodes
  info.dump = dump
end

local cpu_history = {
  fhcd_user = 0,
  fhcd_system = 0,
  child_user = 0,
  child_system = 0
}
local fhcd_service_events = {}
local function service_cb(msg, name)
  if msg.service ~= "fhcd" then
    return
  end
  name = name:match("^instance%.(.+)")
  if not name then
    return
  end
  cpu_history.fhcd_user = 0
  cpu_history.fhcd_system = 0
  cpu_history.child_user = 0
  cpu_history.child_system = 0
  local counter = fhcd_service_events[name] or 0
  fhcd_service_events[name] = counter + 1
end

ubus_conn:subscribe("service", { notify = service_cb })

do
  local tot_user, tot_system = get_total_cpu()
  cpu_history.tot_user = tot_user
  cpu_history.tot_system = tot_system
end

local function get_process_cpu(info)
  local file = io.open("/proc/" .. info.pid .. "/stat", "r")
  if not file then
    return
  end
  local stat = file:read("*l")
  file:close()
  if not stat then
    return
  end
  local exp = "%d+ %([^%)]+%) . %d+ %d+ %d+ %d+ %-?%d+ %d+ %d+ %d+ %d+ %d+ (%d+) (%d+) (%d+) (%d+)"
  local fhcd_user, fhcd_system, child_user, child_system = stat:match(exp)
  if not fhcd_user then
    return
  end
  local tot_user, tot_system = get_total_cpu()
  info.cpu_fhcd_user = (100 * (fhcd_user - cpu_history.fhcd_user)) / (tot_user - cpu_history.tot_user)
  info.cpu_fhcd_system = (100 * (fhcd_system - cpu_history.fhcd_system)) / (tot_system - cpu_history.tot_system)
  info.cpu_child_user = (100 * (child_user - cpu_history.child_user)) / (tot_user - cpu_history.tot_user)
  info.cpu_child_system = (100 * (child_system - cpu_history.child_system)) / (tot_system - cpu_history.tot_system)

  cpu_history.tot_user = tot_user
  cpu_history.tot_system = tot_system
  cpu_history.fhcd_user = fhcd_user
  cpu_history.fhcd_system = fhcd_system
  cpu_history.child_user = child_user
  cpu_history.child_system = child_system
end

local function get_fhcd_info()
  local info = {}
  local fhcd_service = ubus_conn:call("service", "list", { name = "fhcd" })

  info.name = "fhcd"
  info.service = fhcd_service_events
  if fhcd_service["fhcd"] then
    local fhcd_pid = fhcd_service.fhcd.instances.fhcd.pid
    if fhcd_pid then
      info.pid = fhcd_pid
      get_process_cpu(info)
      get_process_memory(info)
      get_dump_fhcd(info)
      get_num_fhcd_fd(info)
    end
  end
  gwfd.write_msg_to_file(info, fifo_file_path)
  collectgarbage()
  timer:set(interval) -- reschedule on the uloop
end

-- Main
-- tune the lua garbage collector to be more aggressive and reclaim memory sooner
-- default value of setpause is 200, set it to 100
collectgarbage("setpause",100)
collectgarbage("collect")
collectgarbage("restart")

uloop.init()

gwfd.init("gwfd_fhcd", 6, {})
timer = uloop.timer(get_fhcd_info)
get_fhcd_info()
xpcall(uloop.run, gwfd.errorhandler)
