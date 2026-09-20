local error = error
local M = {}
local ubus = require('ubus')

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

    local led = {
        name = name,
        trigger = "timer",
        params = {
            brightness = 255,
            delay_on = delayOn or 500,
            delay_off = delayOff or 500
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

    local led = {
        name =  name,
        trigger = "none",
        params = {
            brightness = state and 255 or 0
        }
    }
    return led
end


---
-- Return the L3 interface associated with the openwrt interface
-- @param #string name of the OpenWRT interface
-- @return #string the L3 interface associated
local function getL3Device(interface)
    local conn = ubus.connect()
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
function M.netdevLedOWRT(name, device, mode)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "netdevLedOWRT failed: missing or invalid name" })
    end

    local led = {
        name =  name,
        trigger = "netdev",
        params = {
            device_name = function()
                return getL3Device(device)
            end,
            mode = mode
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
function M.netdevLed(name, device, mode)
    if(name == nil or name == '')  then
        error({ errcode = 9002, errmsg = "netdevLed failed: missing or invalid name" })
    end

    local led = {
        name =  name,
        trigger = "netdev",
        params = {
            device_name = device,
            mode = mode
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

return M
