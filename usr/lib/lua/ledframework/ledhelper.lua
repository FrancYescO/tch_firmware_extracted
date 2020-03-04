local error = error
local M = {}
M.ubus = require('ubus')
M.uci = require('uci')
M.print=print
local lfs = require("lfs")
local open = io.open
local ledPath = "/sys/class/leds/"
local mptcp = lfs.attributes("/etc/init.d/moff", "mode") == "file" and "moff" or "mproxy"

---
-- Get a LED maxinum brightness
-- @function [parent=#ledhelper] getMaxBrightness
-- @param #string name led name
local function getMaxBrightness(name)
    local maxBrightness = 255
    if type(name) == 'function' then name=name() end
    if name then 
       local ledFile = ledPath .. name
       if lfs.attributes(ledFile, "mode") == "directory" then
           local fd = open(ledFile .. "/max_brightness", "r")
           if fd then
              maxBrightness = fd:read("*all")
              fd:close()
           end
       end
    end
    return maxBrightness
end

---
-- returns the data structure required to initialize a timer led
-- @function [parent=#ledhelper] timerLed
-- @param name the name of the led (sysfs)
-- @param delayOn how long to keep the led on (ms)
-- @param delayOff how long to keep the led of (ms)
function M.timerLed(name, delayOn, delayOff)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "timerLed failed: missing or invalid name" })
    end

    local maxB = getMaxBrightness(name)
    local led = {
        name = name,
        trigger = "timer",
        params = {
            brightness = maxB,
            delay_on = delayOn or 500,
            delay_off = delayOff or 500
        }
    }
    return led
end

function M.bundleTimerLed(name, delayOn, delayOff, timerId, invert_timer)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "bundleTimerLed failed: missing or invalid name" })
    end

    local maxB = getMaxBrightness(name)
    local led = {
        name = name,
        trigger = "bundletimer",
        params = {
            timer_id = timerId,
            bundle_brightness = maxB,
            bundle_delay_on = delayOn or 500,
            bundle_delay_off = delayOff or 500,
            invert = invert_timer or 0
        }
    }
    return led
end

---
-- Set a LED in a static state (on / off)
-- @function [parent=#ledhelper] staticLed
-- @param #string name led name
-- @param #boolean state state of the led
function M.staticLed(name, state)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "staticLed failed: missing or invalid name" })
    end
    local val
    local maxB = getMaxBrightness(name)
    if type(state)=="boolean" then
       val=state and maxB or 0
    else
       val=state
    end
    local led = {
        name =  name,
        trigger = "none",
        params = {
            brightness = val
        }
    }
    return led
end

---
-- No LED action, just execute the given function (eg to indicate a state transition, modify a uci parameter, send a log, print a trace,...)
-- @function [parent=#ledhelper] runFunc
-- @param #function fct name of function to execute
function M.runFunc(fct, prms)
    if(fct == nil or fct == '' or type(fct) ~= "function")  then
        error({ errcode = 9002, errmsg = "runFunc failed: missing function" })
    end
    local func = {
        name =  "runFunc",
        fctn = fct,
        params = prms
    }
    return func
end


---
-- Return the L3 interface associated with the openwrt interface
-- @param #string name of the OpenWRT interface
-- @return #string the L3 interface associated
local function getL3Device(interface)
    local conn = M.ubus.connect()
    if not conn then
        -- Do not "fail", we want to continue
        return ""
    end

    local data = conn:call("network.interface." .. interface, "status", { })
    conn:close()
    return data["l3_device"]
end

---
-- Link a LED to the network activity on a openwrt device
-- @function [parent=#ledhelper] netdevLedOWRT
-- @param #string name led name
-- @param #string device openwrt device
-- @param #string mode (combination of link, tx, rx)
--      link: led reflects carrier state
--      tx: led blinks on transmit data
--      rx: led blinks on receive data
-- @param #integer interv blink rate (ms) Frequency (Hz)=1/(2xinterval); minimum 5ms, default 50
-- @param #integer div_fact number of blinks per tx/rx packet; default 10 
function M.netdevLedOWRT(name, device, mode, interv, div_fact)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "netdevLedOWRT failed: missing or invalid name" })
    end
    if (interv and interv < 5) then interv=5 end
    local maxB = getMaxBrightness(name)
    local led = {
        name =  name,
        trigger = "netdev",
        params = {
            brightness = maxB,
            device_name = function()
                return getL3Device(device)
            end,
            mode = mode,
            interval = interv,
            traffic_div_fact = div_fact
        }
    }
    return led
end

---
-- Link a LED to the network activity on a openwrt device
-- @function [parent=#ledhelper] netdevLed
-- @param #string name led name
-- @param #string device openwrt device
-- @param #string mode (combination of link, tx, rx)
--      link: led reflects carrier state
--      tx: led blinks on transmit data
--      rx: led blinks on receive data
-- @param #integer interv blink rate (ms) Frequency (Hz)=1/(2xinterval); minimum 5ms, default 50
-- @param #integer div_fact number of blinks per tx/rx packet; default 10 
function M.netdevLed(name, device, mode, interv, div_fact)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "netdevLed failed: missing or invalid name" })
    end
    if (interv and interv < 5) then interv=5 end
    local maxB = getMaxBrightness(name)
    local led = {
        name =  name,
        trigger = "netdev",
        params = {
            brightness = maxB,
            device_name = device,
            mode = mode,
            interval = interv,
            traffic_div_fact = div_fact
        }
    }
    return led
end

---
-- Return the USB device name associated with the openwrt interface
-- @param #string name of the OpenWRT interface
-- @return #string the L3 interface associated
function M.usb_connected()
    local file = io.open("/sys/bus/usb/drivers/usb/1-1", "rb")
    if file then 
		file:close() 
		return '1-1'
	end
    file = io.open("/sys/bus/usb/drivers/usb/2-1", "rb")
    if file then 
		file:close() 
		return '2-1'
	end

    return nil 
end


---
-- Link a LED to the USB activity
-- @function [parent=#ledhelper] usbdevLed
-- @param #string name led name
function M.usbdevLed(name, device, mode)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "usbdevLed failed: missing or invalid name" })
    end

    local led = {
        name =  name,
        trigger = "usbdev",
        params = {
            device_name = device,
            mode = mode
        }

    }
    return led
end


---
-- Play a blinking pattern on
-- @function [parent=#ledhelper] patternLed
-- @param #string name led name
-- @param #string pattern blinking pattern (sequence of 0 and 1)
-- @param #number interval in ms between each state change
--      link: led reflects carrier state
--      tx: led blinks on transmit data
--      rx: led blinks on receive data
function M.patternLed(name, pattern, interval)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "patternLed failed: missing or invalid name" })
    end

    local led = {
        name =  name,
        trigger = "pattern",
        params = {
            delay = interval,
            message = pattern
        }
    }
    return led
end


---
-- Return the correct interface for the 5GHz wireless AP
-- @function [parent=#ledhelper] get_wl1_ifname
-- @param no parameters
---
function M.get_wl1_ifname()
   local cursor = M.uci.cursor()
   local wl1_ifname = cursor:get('wireless', 'wl1', 'ifname')

   if not wl1_ifname then
        -- Ensure that always a value is returned
        local radio_type = cursor:get('wireless', 'radio_5G', 'type')
        if radio_type == 'broadcom' then
             -- Default value for Broadcom based solutions is wl1
             wl1_ifname = "wl1"
        elseif radio_type == 'quantenna' then
             -- Default value for Quantenna based solutions is eth5
             wl1_ifname = "eth5"
        else
             -- Default value
             wl1_ifname = "wl1"
        end
   end

   cursor:close()
   return wl1_ifname
end

---
-- Returns true if MPTCP is enabled in UCI, false otherwise
-- @function [parent=#ledhelper] is_MPTCP_enabled
-- @param no parameters
function M.is_MPTCP_enabled()
   local cursor = M.uci.cursor()
   local enabled
   if mptcp == "moff"  then
        enabled = cursor:get('moff', 'config', 'enable')
   else
        enabled = cursor:get('mproxy', 'globals', 'enable')
   end

   cursor:close()
   return enabled == '1'
end

---
-- Returns true if LTE Backup is enabled in UCI, false otherwise
-- @function [parent=#ledhelper] is_LTE_Backup_enabled
-- @param no parameters
function M.is_LTE_Backup_enabled()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('network', 'lte_backup', 'auto')

   cursor:close()
   return enabled == '1'
end

---
-- Returns true if TITAN (SingleIP) is enabled in UCI, false otherwise
-- @function [parent=#ledhelper] is_TITAN_enabled
-- @param no parameters
function M.is_TITAN_enabled()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('network', 'globals', 'mode')

   cursor:close()
   return enabled == 'TITAN'
end

---
-- Returns true if ZTC provisioning occured and parameter was set in UCI, false otherwise
-- @function [parent=#ledhelper] is_ZTC_provisioned
-- @param no parameters
function M.is_ZTC_provisioned()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('env', 'var', 'ztc_transactionid')

   cursor:close()
   return enabled ~= nil
end

---
-- Returns true if status LED behaviour is enabled in UCI (to switch off all but the power led if all services are OK), false otherwise
-- @function [parent=#ledhelper] is_status_led_enabled
-- @param no parameters
function M.is_status_led_enabled()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('ledfw', 'status_led', 'enable')

   cursor:close()
   return enabled == '1'
end

---
-- Returns true if onboarding is enabled in UCI (for Wifi Services enabled devices), false otherwise
-- @function [parent=#ledhelper] is_onboarding_enabled
-- @param no parameters
function M.is_onboarding_enabled()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('ledfw', 'onboarding', 'enable')

   cursor:close()
   return enabled == '1'
end

---
-- Returns true if the WiFi LED should be on when WiFi is enabled but no stations are connected (no associated clients), false otherwise
-- @function [parent=#ledhelper] is_WiFi_LED_on_if_NSC
-- @param no parameters
function M.is_WiFi_LED_on_if_NSC()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('ledfw', 'wifi', 'nsc_on')

   cursor:close()
   return enabled == '1'
end

---
-- Returns true if power LED should blink when there is a CWMP (remote management) session ongoing, false otherwise
-- @function [parent=#ledhelper] is_show_remote_mgmt
-- @param no parameters
function M.is_show_remote_mgmt()
   local cursor = M.uci.cursor()
   local enabled = cursor:get('ledfw', 'remote_mgmt', 'in_progress')

   cursor:close()
   return enabled == '1'
end

---
-- Returns the DSL status code
-- @function [parent=#ledhelper] xdsl_status
-- @param no parameters
function M.xdsl_status()
    local conn = M.ubus.connect()
    if not conn then
        -- Do not "fail", we want to continue
        return ""
    end

    local data = conn:call("xdsl", "status", { })
    conn:close()
    return data["statuscode"]
end

---
-- Returns the value of the wansensing l2type in UCI (default "ADSL")
-- @function [parent=#ledhelper] wansensing_l2type
-- @param no parameters
function M.wansensing_l2type()
   local cursor = M.uci.cursor()
   local l2type = cursor:get('wansensing', 'global', 'l2type')

   cursor:close()
   if not l2type then
        -- Ensure that always a value is returned
        return "ADSL"
   else
        return l2type
   end
end

---
-- Returns the value of sfp boot status (sfp_connecting or sfp_unplug)
-- @function [parent=#ledhelper] get_sfp_boot_status
-- @param no parameters
function M.get_sfp_boot_status()
    local fd, errmsg = open("/proc/sfp/sfp_status", "r")
    if not fd then
        return "sfp_unplug"
    end
    local sfp_status = fd:read("*l")
    fd:close()
    if sfp_status == "plugin" then
        return "sfp_connecting"
    else
        return "sfp_unplug"
    end
end

---
-- Returns the value of the UCI ledfw depending interface for a given service led (which service do you want the given LED to follow), or nil if not found
-- @function [parent=#ledhelper] get_led_itf
-- @param no parameters
function M.get_led_itf(service)
   local cursor = M.uci.cursor()
   local itf
   if service then
      itf=cursor:get('ledfw', service, 'itf')
   end
   cursor:close()
   return itf
end

---
-- Returns the value of the UCI ledfw service led name depending on the given interface (which LED should follow the given interface), or nil if none found
-- @function [parent=#ledhelper] get_led_itf
-- @param no parameters
function M.get_depending_led(itf)
   local cursor = M.uci.cursor()
   local service
   local cb=function(tbl)
      if tbl.itf==itf then
         service=tbl[".name"]
	     return false
	  end
   end
   if itf then
      cursor:foreach('ledfw', 'service', cb)
   end
   cursor:close()
   return service
end

return M
