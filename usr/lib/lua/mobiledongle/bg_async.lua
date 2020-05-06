local netlink=require("tch.netlink")

local tprint = require("tch/tableprint")


local runtime = { }
local cb
local timer

local M = {}

function M.init (rt, event_cb)
   -- intialize uloop
   runtime = rt

   cb = event_cb

end

function M.timerstart(timeout)
   -- create a timer to event timeout
   timer = runtime.uloop.timer(function () cb('timeout') end)
   timer:set(timeout)
end

function M.timerstop()
   if timer then
     timer:cancel()
   end
end

function M.start()
   local conn = runtime.ubus
   -- check connection with ubus
   if not conn then
      error("Failed to connect to ubusd")
   end

   -- register for ubus events
   local events = {}
   events['network.interface.wwan'] = function(msg)
   
   				   print("==== mbdasync.lua ====")
   				   print("==== mbdasync.lua ====")
   				   print("==== mbdasync.lua ====")
   				   print("==== mbdasync.lua ====")
   				   print("==== mbdasync.lua ====")
   				   print("= 1 === mbdasync.lua ====")
   				   tprint(msg)
   				   print("= END = 2 == mbdasync.lua ====")
   				   print("= END === mbdasync.lua ====")
   				   print("= END === mbdasync.lua ====")
   				   print("= END === mbdasync.lua ====")
   				   print("= END === mbdasync.lua ====")
				   cb("network_interface_wwan")
   			--[[	
				    if msg and msg.interface and msg.action then
				       cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
				    end
				    ]]
				 end

   conn:listen(events)

   --register for netlink events
   local nl,err = netlink.listen(function(dev, status)
				    if dev == "3g-wwan" or dev == "wwan0" then
					    if status then
					       cb('network_device_wwan_up')
					    else
					       cb('network_device_wwan_down')
					    end
				    end
			      end)
   if not nl then
      error("Failed to register with netlink" .. err)
   end

   runtime.uloop.run()
end

return M
