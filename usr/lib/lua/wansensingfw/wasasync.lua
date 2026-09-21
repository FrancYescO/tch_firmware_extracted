local netlink=require("tch.netlink")

local runtime = { }
local cb
local timer
local nl
local pending

local M = {}

function M.init (rt, event_cb)
    -- intialize uloop
    runtime = rt
    cb = event_cb
    pending=0

    local conn = runtime.ubus
    -- check connection with ubus
    if not conn then
        error("Failed to connect to ubusd")
    end

    -- register for ubus notifications
    local sub = {
       notify = function( msg )
                   if msg and msg.interface then
                      if msg.up == true then
                         cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') ..  "_ifup")
                      else
                         cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') ..  "_ifdown")
                      end
                   end
                end,
    }
    conn:subscribe( "network.interface", sub )

    -- register for ubus events
    local events = {}
    events['network.neigh'] = function(msg)
        if msg and msg.interface and (msg.action=="add" or msg.action=="delete") and 
           type(msg['ipv4-address'])=="table" and type(msg['ipv4-address'].address)=="string" then
            cb('network_neigh_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action .. '_' .. msg['ipv4-address'].address)
        end
    end

    events['xdsl'] = function(msg)
        if msg then
            cb('xdsl_' .. msg.statuscode)
        end
    end

     events['gpon.ploam'] = function(msg)
        if msg and msg.statuscode then
            if msg.statuscode ~= 5 then
                cb('gpon_ploam_0')
            end
         end
    end

     events['gpon.omciport'] = function(msg)
         if msg and msg.statuscode then
             cb('gpon_ploam_' .. msg.statuscode)
         end
     end

    events['bfdecho'] = function(msg)
        if msg and msg.interface and msg.state then
            local value = msg.state == "1" and "ok" or "nok"
            cb('supervision_' .. msg.interface:gsub('[^%a%d_]','_') ..'_' .. value)
        end
    end

    events['dns'] = function(msg)
        if msg and msg.interface and msg.state then
            local value = msg.state == "1" and "ok" or "nok"
            cb('supervision_' .. msg.interface:gsub('[^%a%d_]','_') ..'_' .. value)
        end
    end

    events['dhcp.client'] = function(msg)
        if msg and msg.interface then
            if msg.event == "renew" then
                cb('dhcp_renew_' .. msg.interface:gsub('[^%a%d_]','_') .. '_renew')
            elseif msg.event == "renew_failed" then
                cb('dhcp_renew_' .. msg.interface:gsub('[^%a%d_]','_') .. '_failed')
            end
        end
    end

    events['dhcpv6.client'] = function(msg)
        if msg and msg.interface then
            if msg.event == "updated" then
                cb('dhcp_renew_' .. msg.interface:gsub('[^%a%d_]','_') .. '_renew')
            elseif msg.event == "renew_failed" then
                cb('dhcp_renew_' .. msg.interface:gsub('[^%a%d_]','_') .. '_failed')
            end
        end
    end

    events['mmpbx.endcall'] = function(msg)
        if msg then
            cb('mmpbx_call_ended')
        end
    end

    events['wansensing'] = function(msg)
        if msg and msg.event == "reload" then
            cb('wansensing_reload')
        end
    end

    events['mobiled'] = function(msg)
        if msg and msg.dev_idx then
            if msg.event == "device_initialized" then
                cb('mobiled_device_' .. tostring(msg.dev_idx) .. '_initialized')
            end
        end
    end

    conn:listen(events)

    --register for netlink events
    local err = ""
    nl, err = netlink.listen(function(dev, status)
        if status then
            cb('network_device_' .. dev .. '_up')
        else
            cb('network_device_' .. dev .. '_down')
        end
    end)
    if not nl then
        error("Failed to register with netlink" .. err)
    end
end

function M.timerstart(timeout)
    -- create a timer to event timeout
    if pending == 0 then
       pending=1
       timer = runtime.uloop.timer(function () pending=0 cb('timeout') end)
       timer:set(timeout)
    else
	runtime.logger:error("attempt to start timer while timer still pending")
    end
end

function M.timerstop()
    if timer then
        pending=0
        timer:cancel()
    end
end

function M.start()
    runtime.uloop.run()
end

return M

