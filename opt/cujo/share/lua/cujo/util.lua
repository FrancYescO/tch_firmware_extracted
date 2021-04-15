--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

cujo.util = {}

local addrtype = {ipv4 = 'ip4', ipv6 = 'ip6'}
function cujo.util.addrtype(addr)
	for v, typ in pairs(addrtype) do
		local rep = cujo.net.iptobin(v, addr)
		if rep ~= nil then return typ, rep end
	end
	if addr:match'^%w+:%w+:%w+:%w+:%w+:%w+$' then return 'mac' end
end

function cujo.util.ipv(ip)
	return tonumber(cujo.util.addrtype(ip):sub(-1))
end

function cujo.util.append(t, ...)
	vararg.map(function (v) table.insert(t, v) end, ...)
	return t
end

function cujo.util.join(dst, src)
	for _, v in ipairs(src) do table.insert(dst, v) end
	return dst
end

do
	local publisher = oo.class()
	function publisher:subscribe(handler) self.list[handler] = true end
	function publisher:unsubscribe(handler) self.list[handler] = nil end
	function publisher:empty() return next(self.list) == nil end
	function publisher:__call(...) for elem in pairs(self.list) do elem(...) end end
	function cujo.util.createpublisher() return publisher{list = {}} end
end
do
	local enabler = oo.class()
	function enabler:get() return self.enabled end
	function enabler:set(enable)
		enable = enable and true or false
		if enable == self.enabled then return end
		self:f(enable)
		if enable == self.enabled then
			cujo.log:enabler(self.name, enable and ' started' or ' stopped')
			self.pub(enable)
		end
	end
	function enabler:subscribe(handler) self.pub:subscribe(handler) end
	function enabler:unsubscribe(handler) self.pub:unsubscribe(handler) end
	function cujo.util.createenabler(name, f, enable)
		return enabler{name = name, f = f, pub = cujo.util.createpublisher(),
			enabled = enable and true or false}
	end
end
