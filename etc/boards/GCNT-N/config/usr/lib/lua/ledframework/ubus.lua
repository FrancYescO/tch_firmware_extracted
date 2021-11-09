local ubus, uloop = require('ubus'), require('uloop')
local uci = require('uci')
local cursor = uci.cursor()
local rssi_timer
local backhaul_timer
local gateway_l2interface
local process = require("tch.process")
local lfs = require("lfs")
local dir = lfs.dir

local M = {}

local ipv4_pattern = "%d+%.%d+%.%d+%.%d+" -- This is not a strict pattern, but assumption is made that the output of 'route' will not produce garbage IP addresses.
local MAC_pattern = "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x"
local backhaul_connected=false
local backhaul_rssi=false
local onboarded_rssi=false
local conn=ubus.connect()
if not conn then
   error("ledfw ubus: Failed to connect to ubusd")
end

local ledcfg='ledfw'
local multiapcfg='multiap'
local show_final_wps_state_timeout, show_rssi_status_off_enabled, show_rssi_status_off_timeout
local show_easymesh_status_enabled, show_easymesh_status_timeout, wps_sta_success
local easymesh_enabled, wifi_dr_agent_enabled, err

cursor:load(ledcfg)

show_final_wps_state_timeout, err = cursor:get(ledcfg,'wps_status','timeout')
show_final_wps_state_timeout = show_final_wps_state_timeout and tonumber(show_final_wps_state_timeout) or 300
show_final_wps_state_timeout = show_final_wps_state_timeout * 1000

show_rssi_status_off_enabled, err = cursor:get(ledcfg,'rssi_status_off','enable')
show_rssi_status_off_enabled = show_rssi_status_off_enabled == '1'

show_rssi_status_off_timeout, err = cursor:get(ledcfg,'rssi_status_off','timeout')
show_rssi_status_off_timeout = show_rssi_status_off_timeout and tonumber(show_rssi_status_off_timeout) or 60
show_rssi_status_off_timeout = show_rssi_status_off_timeout * 1000

show_easymesh_status_enabled, err = cursor:get(ledcfg,'easymesh_status','enable')
show_easymesh_status_enabled = show_easymesh_status_enabled == '1'

show_easymesh_status_timeout, err = cursor:get(ledcfg,'easymesh_status','timeout')
show_easymesh_status_timeout = show_easymesh_status_timeout and tonumber(show_easymesh_status_timeout) or 60
show_easymesh_status_timeout = show_easymesh_status_timeout * 1000

cursor:load(multiapcfg)

easymesh_enabled, err=cursor:get(multiapcfg,'agent','enabled')
easymesh_enabled = easymesh_enabled == '1'

cursor:load('wifi_doctor_agent')

wifi_dr_agent_enabled, err = cursor:get('wifi_doctor_agent','config','enabled')
wifi_dr_agent_enabled = wifi_dr_agent_enabled == '1'

cursor:close()

local function retrieve_default_gateway_ip()
  local fd = process.popen("/sbin/route", {"-n"}, "re")
  if not fd then
    return
  end
  for route_line in fd:lines() do
    -- Find the routing line for destination 0.0.0.0
    local destination, gateway = route_line:match("^("..ipv4_pattern..")%s+("..ipv4_pattern..")")
    if destination == "0.0.0.0" then
      fd:close()
      return gateway
    end
  end
  fd:close()
end

local function retrieve_MAC_and_l3interface_for_ipv4(ip)
  local fd = io.open("/proc/net/arp", "r")
  if not fd then
    return
  end
  for arp_line in fd:lines() do
    -- Based on header "IP address       HW type     Flags       HW address            Mask     Device"
    local ip_address, _, _, hw_address, _, device = arp_line:match("^"..string.rep("(%S+)%s+",5).."(%S+)")
    --local ip_address, mac_address = arp_line:match("^("..ipv4_pattern..").*("..MAC_pattern..")")
    if ip_address == ip then
      fd:close()
      return hw_address, device
    end
  end
  fd:close()
end

-- Based on brctl_showmac function from hostmanager.lua
local function brctl_showmac(bridge_interface, mac_address)
  local result = {}
  local fd = process.popen("/usr/sbin/brctl", {"showmacs", bridge_interface}, "re")

  if not fd then
    return result
  end

  for brctl_line in fd:lines() do
    -- Based on header "port no mac addr                is local?       ageing timer"
    local portno, mac, islocal, aging = brctl_line:match("^%s*"..string.rep("(%S+)%s+",3).."(%S+)")
    if mac == mac_address then
      result.portno = tonumber(portno)
      result.mac = mac
      result.islocal = (result.islocal == "yes")
      result.aging = tonumber(aging)
    end
  end

  fd:close()
  return result
end

local function bridge_getport(bridge_interface, portid)
  local syspath = "/sys/class/net/" .. bridge_interface .. "/brif"
  local iter, dir_obj, success

  success, iter, dir_obj = pcall(dir, syspath)
  if (not success) then
    return ""
  end
  for interface in iter, dir_obj do
    if interface ~= "." and interface ~= ".." then
      local f = io.open(syspath .. "/" .. interface .. "/port_no")
      if (f ~= nil) then
	local port = f:read("*n")
	f:close()
	if (port == portid) then
	  return interface
	end
      end
    end
  end
  return ""
end

function M.start(cb)
  uloop.init()
  local conn = ubus.connect()
  if not conn then
    error("Failed to connect to ubusd")
  end

  local events = {}

  events['led.test'] = function(msg)
    if msg ~= nil and msg.edge then
      cb(msg.edge)
    end
  end

  local function wait_for_rssi()
    if backhaul_rssi then
      cb('rssi_on')
      backhaul_rssi=false
    end
  end

  local function stop_show_wps_final_state()
    --conn:send("wireless.wps_led",{wps_state = "off"})
    cb('wps_show_final_state_end')
    --[[ No more need to discriminate between wps sta success next state in case of show easymesh enabled
    if wps_sta_success and show_easymesh_status_enabled then
      cb('wps_show_sta_success_state_end')
    else
      cb('wps_show_final_state_end')
    end
    --]]
    wait_for_rssi()
  end
  
  local function stop_show_rssi()
    cb('rssi_off')
  end

--[[ Possible WPS states :
                wifi_wps_inprogress = "inprogress",
                wifi_wps_off = "off"
                wifi_wps_error = "error",
                wifi_wps_session_overlap = "session_overlap",
                wifi_wps_setup_locked = "setup_locked",
                wifi_wps_idle = "idle",
                wifi_wps_success = "success"
--]]

  -- Add event handler for onboarding, wps_client_session_begins and wps_client_session_ends
  events['wireless.wps_led'] = function(msg)
    if msg ~= nil and msg.wps_state ~= nil then
      cb('wifi_wps_' .. msg.wps_state)
      if msg.mode == "sta" then
        if msg.wps_state == "inprogress" then
          cb('onboarding_initiated')
        elseif msg.wps_state == "error" or msg.wps_state == "session_overlap" or msg.wps_state == "setup_locked" then
          cb('onboarding_failed')
        end
      else
        if msg.wps_state == "inprogress" then
          cb('wps_client_session_begins')
        end
      end
      if msg.wps_state == "success" or msg.wps_state == "error" or msg.wps_state == "session_overlap" or msg.wps_state == "setup_locked" then
         if wps_final_state_timer then
            wps_final_state_timer:cancel()
            wps_final_state_timer=nil
         end
         wps_final_state_timer = uloop.timer(stop_show_wps_final_state, show_final_wps_state_timeout)
      end
      if msg.wps_state == "success" and msg.mode == "sta" then
        wps_sta_success=true
      else
        wps_sta_success=false
      end
    end
  end

  events['fwupgrade'] = function(msg)
    if msg ~= nil and msg.state ~= nil then
      cb("fwupgrade_state_" .. msg.state)
      if msg.state == "upgrading" or msg.state == "flashing" then
        cb("remote_mgmt_session_begins")
      elseif msg.state == "done" or msg.state == "failed" then
        cb("remote_mgmt_session_ends")
      end
    end
  end

  events['rtfd'] = function(msg)
      if msg ~= nil and msg.state ~= nil then
          if msg.state=="started" then
             cb("rtfd_in_progress")
          end
      end
  end

  events['wireless.wlan_led'] = function(msg)
    if easymesh_enabled or not wifi_dr_agent_enabled and msg ~= nil then
      if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
         cb("wifi_state_on")
      end
    end
  end

  events['wifi_doctor_agent.state'] = function(msg)
    if not easymesh_enabled and msg ~= nil then
      if msg.status == "Started" then
         cb("wifi_state_on")
      end
    end
  end

  local function read_rssi()
    local endpoint_data = conn:call("wireless.endpoint", "get", {})
    if endpoint_data and next(endpoint_data) then
      -- TODO add support for multiple endpoints?
      local endpoint_instance_name = next(endpoint_data)
      local endpoint_instance_data = endpoint_data[endpoint_instance_name]
      local rssi = endpoint_instance_data["rssi"]
      rssi = rssi and tonumber(rssi)
      if rssi and rssi > -75 then
        cb('good_connection')
      elseif rssi and rssi <= -75 and rssi > -85 then
        cb('average_connection')
      elseif rssi and rssi <= -85 then
        cb('bad_connection')
      end
      if not backhaul_rssi then
        backhaul_rssi=true
        if show_rssi_timer then
           show_rssi_timer:cancel()
           show_rssi_timer=nil
        end
        show_rssi_timer = show_rssi_status_off_enabled and uloop.timer(stop_show_rssi, show_rssi_status_off_timeout) or nil
      end
    end
    rssi_timer = uloop.timer(read_rssi, 5000)
  end

  -- Function to determine how we're connected to a gateway (if at all)
  local function check_backhaul_link()
    -- First retrieve the default gateway
    local gateway_ip = retrieve_default_gateway_ip()
    -- Find the MAC address and the layer3 interface for the default gateway
    local gateway_mac, gateway_l3interface = retrieve_MAC_and_l3interface_for_ipv4(gateway_ip)
    -- Retrieve the layer2 interface used to connect to this MAC address
    local brctl_info = brctl_showmac(gateway_l3interface, gateway_mac)
    gateway_l2interface = brctl_info.portno and bridge_getport(gateway_l3interface, brctl_info.portno) or ""
    if gateway_l2interface:match("^eth") then
      -- Ethernet backhaul
      if rssi_timer then
        rssi_timer:cancel()
        rssi_timer = nil
      end
      cb('good_connection')
      if onboarded_rssi then
        if show_rssi_timer then
           show_rssi_timer:cancel()
           show_rssi_timer=nil
        end
        show_rssi_timer = show_rssi_status_off_enabled and uloop.timer(stop_show_rssi, show_rssi_status_off_timeout) or nil
        onboarded_rssi = false
      end
    elseif gateway_l2interface:match("^wl") then
      -- Wireless backhaul
      if not rssi_timer then
        read_rssi()
      end
    else
      -- No connection
      if not backhaul_connected then cb('backhaul_disconnect') end
      if rssi_timer then
        rssi_timer:cancel()
        rssi_timer = nil
      end
    end 
    backhaul_timer = uloop.timer(check_backhaul_link, 5000)
  end

  events['wireless.endpoint'] = function(msg)
    if msg ~= nil and msg.state ~= nil then
      if msg.state == "Disconnected" then
        -- If Ignored, Let L2/L3 backhaul IP decide what to do 
        --cb('backhaul_disconnect')
        backhaul_connected=false
        if backhaul_rssi then
          cb('rssi_on')
          backhaul_rssi=false
        end
        if rssi_timer then
          rssi_timer:cancel()
          rssi_timer = nil
        end
      elseif msg.state == "Authorized" then
        -- If Ignored, Let L2/L3 backhaul IP decide what to do 
        backhaul_connected=true
      --else
        -- TODO: What to do with 'Associated' event?
      end
    end
  end

  events['map_agent.onboarding_event'] = function(msg)
    if easymesh_enabled and show_easymesh_status_enabled and msg ~= nil and msg.status ~= nil then
	  --cb('easymesh_onboarding_' .. msg.status) -- 'Inprogress', 'Success', 'Failure', 'Controller_Not_Reachable'
      if msg.status == "Inprogress" then
          cb('easymesh_onboarding_inprogress')
      elseif msg.status == "Success" then
          cb('easymesh_onboarding_ok')
          if gateway_l2interface:match("^eth") then
              onboarded_rssi = true
          end
      elseif msg.status == "Failure" then
          cb('easymesh_onboarding_nok')
      elseif msg.status == "Controller_Not_Reachable" then
          cb('easymesh_onboarding_na')
      end
    end
  end

  backhaul_timer = uloop.timer(check_backhaul_link, 5000)

  conn:listen(events)
  uloop.run()
end

return M
