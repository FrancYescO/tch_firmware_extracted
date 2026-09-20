#!/usr/bin/lua

local ubus = require("ubus")
local uloop = require("uloop")
local x = require("uci").cursor()
local ubus_conn = ubus.connect()

if not ubus_conn then
  return
end

uloop.init()

local interface = arg[1]
if not interface then
  return
end

local type = arg[2] or "ipv4"

local i = 0
local interval, timer

function send_bfdecho_msg()
    interval = x:get("bfdecho", "bfdecho_config", "poll_interval") or "30"
    local data = ubus_conn:call("network.interface." .. interface, "status", {})
    if data and data["up"] then
         local intf, src_ip, destmac, timeout, ipv4_addr, ipv6_addr
         local delay, ipv4_enabled, ipv6_enabled

         local config = x:get_all("bfdecho")
         timeout = config and config["bfdecho_config"] and config["bfdecho_config"]["timeout"]
         delay = config and config["bfdecho_config"] and config["bfdecho_config"]["delay"]

	 intf = data["device"]

	 if type == "ipv4" then
	   ipv4_enabled = config and config["bfdecho_config"] and config["bfdecho_config"]["ipv4_enabled"]
           if ipv4_enabled == "disabled" then
             ubus_conn:send("bfdecho",{interface = interface, state = "1"})
             timer:set(tonumber(interval) * 1000)
	     return
	   end
           ipv4_addr = data["ipv4-address"] and data["ipv4-address"][1] and data["ipv4-address"][1].address
	   src_ip = ipv4_addr
	 elseif type == "ipv6" then
           ipv6_enabled = config and config["bfdecho_config"] and config["bfdecho_config"]["ipv6_enabled"]
           if ipv6_enabled == "disabled" then
             ubus_conn:send("bfdecho",{interface = interface, state = "1"})
             timer:set(tonumber(interval) * 1000)
	     return
	   end
           ipv6_addr = data["ipv6-address"] and data["ipv6-address"][1] and data["ipv6-address"][1].address
           src_ip = ipv6_addr
	 end

         local nexthop = ""
         for j=1, #data["route"] do
             local source = string.match(data["route"][j].source, "(.*)\/%d+")
             if not source then
                 source = data["route"][j].source
             end
             if data["route"][j].nexthop and data["route"][j].nexthop ~= "0.0.0.0" and data["route"][j].nexthop ~= "::" and src_ip == source then
                 nexthop = data["route"][j].nexthop
                 break
             end
         end

         local fd = io.popen("ip neigh")
         if fd then
             for line in fd:lines() do
                 if string.match(line,nexthop) then
                     destmac = string.match(line, "(%w+:%w+:%w+:%w+:%w+:%w+)")
                     break
                 end
             end
         end
         fd:close()

        --send bfd echo package
        if i==0 then
            math.randomseed(tostring(os.time()):reverse():sub(1, 6))
            delay = math.random(1, tonumber(delay))
            os.execute("sleep " .. delay)
        end
        i = i + 1
        local serial_number = x:get("env", "var", "serial") or ""
        local oui = x:get("env", "var", "oui") or ""
        local payload = oui .. "-" .. serial_number
	if intf and destmac and src_ip and timeout then
          local cmd = "/usr/sbin/bfdecho --intf " .. intf .. " --dmac " ..  destmac  .. " --srcip " .. src_ip .. " --destip " .. src_ip .. " --timeout " .. timeout .. " -p " .. payload

          cmd = io.popen(cmd)
          if not cmd then
            timer:set(tonumber(interval) * 1000)
	    return
	  end

	  local line = cmd:read("*a")
	  if not line then
            timer:set(tonumber(interval) * 1000)
	    return
	  end
	  local status
          if type == "ipv4" then
            status = string.match(line, "bfdechov4.state.status=(%d)")
          elseif type == "ipv6" then
            status = string.match(line, "bfdechov6.state.status=(%d)")
	  end
          local t = {interface = interface, state = status}
          ubus_conn:send("bfdecho", t)
	end
    end
    timer:set(tonumber(interval) * 1000)
end

interval = x:get("bfdecho", "bfdecho_config", "poll_interval") or "30"
timer = uloop.timer(send_bfdecho_msg)
send_bfdecho_msg()
timer:set(tonumber(interval) * 1000)

uloop.run()
