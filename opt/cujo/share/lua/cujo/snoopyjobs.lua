--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo cujo.config, globals cujo.config.wan_ipv6addr

local shims = require "cujo.shims"

local module = {}

function module.initialize()
    -- Watch for changes in the WAN IPv6 address and reconnect to the cloud
    -- when it happens.
    shims.create_timer("ipv6-watchdog", 5, function ()
        local wan_ipv6addr = cujo.snoopy.getdevaddripv6(cujo.config.lan_ifaces)
        if cujo.config.wan_ipv6addr ~= wan_ipv6addr then
            cujo.log:warn('Detected new IPv6 address ', wan_ipv6addr, ', reconnecting')
            cujo.cloud.disconnect()
            cujo.config.wan_ipv6addr = wan_ipv6addr
            cujo.cloud.connect()
        end
    end)
end

return module
