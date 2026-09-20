local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wwan_ifdown',
    'supervision_wan_nok',
    'supervision_wan_ok',
    'supervision_wan6_nok',
    'supervision_wan6_ok',
    'dhcp_renew_wan_failed',
    'dhcp_renew_wan_renew',
    'dhcp_renew_wan6_failed',
    'dhcp_renew_wan6_renew',
}

local events = {
    timeout = true,
    network_interface_wwan_ifdown = true,
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    local x = uci.cursor()

    if events[event] then --timeout or wwan down
        logger:notice("The L3DHCP main script is checking link connectivity on l2type interface " .. tostring(l2type))

        -- check if wan is up Or wan6 is up and has global IPv6 address
        -- For Telstra, only when wan6 is up and has global IPv6 address, wan6 is applicable for upper layer application
        if scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6", true) then
          -- disable 3G/4G
          failoverhelper.mobiled_enable(runtime, "0", "wwan")
          runtime.l3dhcp_failures = 0
        else
          runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
          if runtime.l3dhcp_failures > 3 then
            return "L3DHCPSense"
          else
            return "L3DHCP", true -- do next check using fasttimeout rather than timeout
          end
        end
    elseif event == "dhcp_renew_wan_failed" or event == "dhcp_renew_wan6_failed" then
        local ipv4 = (event == "dhcp_renew_wan_failed")
        local wanIntf = ipv4 and "wan" or "wan6"

        logger:notice("DHCP renew failed on ".. wanIntf .. ", to restart it")

        local intfStatus = ipv4 and scripthelpers.checkIfInterfaceHasIP("wan6", true) or scripthelpers.checkIfInterfaceIsUp("wan")
        if intfStatus == false then
            -- both wan and wan6 are down
            return "L3DHCPSense"
        else
            -- MMPBX and CWMP will switch to wan6/wan intf by itself once it receives the wan/wan6 down event
            conn:call("network.interface." .. wanIntf, "down", { })
            conn:call("network.interface." .. wanIntf, "up", { })
        end
    elseif event == "dhcp_renew_wan_renew" or event == "dhcp_renew_wan6_renew" then
        local ipv4 = (event == "dhcp_renew_wan_renew")
        local delay_timer = ipv4 and "l3dhcp_renew_delay_timer_v4" or "l3dhcp_renew_delay_timer_v6"
        local wait_timer = ipv4 and "l3dhcp_renew_wait_timer_v4" or "l3dhcp_renew_wait_timer_v6"

        runtime[delay_timer] = nil
        runtime[wait_timer] = nil

        logger:notice("IP" .. (ipv4 and "v4" or "v6") .. " DHCP renew successed.")
    elseif event == "supervision_wan_ok" or event == "supervision_wan6_ok" then
        --logger:notice("supervision is successful." .. event)
        return "L3DHCP"
    elseif event == "supervision_wan_nok" or event == "supervision_wan6_nok" then
        local ipv4 = (event == "supervision_wan_nok")
        local wanIntf = ipv4 and "wan" or "wan6"

        -- supervision IPv4/v6 fails
        logger:notice("supervision failed " .. event)

        -- Failure account has reach the limitation, bring down wan(wan6) intf, then bring up again
        -- Telstra : If either IPv4 or IPv6 BFD Echo fails and reaches its fail limit, then that IP interface only is to be brought down and all gateway internal services notified to use the alternate interface. The other IP interface is to remain up, unless it also fails.
        local delay_timer = ipv4 and "l3dhcp_renew_delay_timer_v4" or "l3dhcp_renew_delay_timer_v6"
        local wait_timer = ipv4 and "l3dhcp_renew_wait_timer_v4" or "l3dhcp_renew_wait_timer_v6"
        local wanStatus = ipv4 and scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6", true)

        if runtime[delay_timer] ~= nil or runtime[wait_timer] ~= nil or wanStatus == false then
            return "L3DHCP"
        end

        local rand_delay = math.random(1000, 30 * 1000)

        logger:notice("delay " .. rand_delay .. "ms to renew " .. wanIntf)
        runtime[delay_timer] = runtime.uloop.timer(function()
            if runtime[delay_timer] ~= nil then
                runtime[delay_timer] = nil
                logger:notice("sending DHCP renew for " .. wanIntf)
                conn:call("network.interface." .. wanIntf, "renew", { })

                -- to start another timer to wait for renew event
                runtime[wait_timer] = runtime.uloop.timer(function()
                    if runtime[wait_timer] ~= nil then
                        runtime[wait_timer] = nil
                        logger:notice("Interface " .. wanIntf .. " renew timeout")
                        if wanIntf == "wan" then
                            os.execute('ubus send dhcp.client  ' .. "'" .. '{"event":"renew_failed","interface":"wan"}' .. "'")
                        else
                            os.execute('ubus send dhcpv6.client  ' .. "'" .. '{"event":"renew_failed","interface":"wan6"}' .. "'")
                        end
                    end
                end, 4 * 1000)    -- wait for DHCP renew for 4 seconds according to CR
            end
        end, rand_delay)
    else
        if l2type == 'ETH' then
            if not scripthelpers.l2HasCarrier("eth4") then
                return "L2Sense"
            end
        elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
        -- if we get there, then we're not concerned, the non used L2 went down
    end

    return "L3DHCP"
end

return M
