--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

cujo.snoopy = {}

function cujo.snoopy.getdevaddripv6(ifaces)
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
