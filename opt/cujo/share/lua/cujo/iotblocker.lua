--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

-- This module manages ipsets that are used to reject traffic to/from specific
-- IPv4, IPv6, or MAC addresses, as informed by the agent-service.
local module = {}

local sets = {}

function module.set(addr, add)
    local v = cujo.util.addrtype(addr)
    assert(v, 'invalid address')
    if not sets[v] then error('unsupported address type: ' .. v) end
    sets[v]:set(add, addr)
    if add then
        if v == 'mac' then
            local mac = addr:upper()
            for net in pairs(cujo.config.nets) do
                for ip in pairs(cujo.apptracker.traffic[net][mac]) do
                    cujo.config.connkill(net, nil, ip)
                    cujo.config.connkill(net, ip, nil)
                end
            end
        else
            cujo.config.connkill(v, nil, addr)
            cujo.config.connkill(v, addr, nil)
        end
    end
end

function module.flush()
    for _, set in pairs(sets) do set:flush() end
end

function module.initialize()
    local nets = {'mac'}
    for net in pairs(cujo.config.nets) do nets[#nets + 1] = net end
    for _, net in ipairs(nets) do
        sets[net] = cujo.ipset.new{name = 'iotblock_' .. net, type = net}
    end
end

return module
