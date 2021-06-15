--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local module = {}

function module.getdevaddripv6(ifaces)
    local last_non_2000_match = nil
    for _, iface in ipairs(ifaces) do
        local address = cujo.config.getdevaddr(iface, 'ipv6', true)
        if address ~= nil and address:sub(1, 1) == '2' then
            return address
        else
            last_non_2000_match = address
        end
    end
    return last_non_2000_match
end

return module
