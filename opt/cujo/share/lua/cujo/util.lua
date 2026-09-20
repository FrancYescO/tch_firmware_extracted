--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local Viewer = require'loop.debug.Viewer'
local oo = require "loop.base"
local vararg = require "vararg"

local module = {}

-- For IP addresses, returns a pair: A string identifying IPv4 vs IPv6 and the
-- binary representation of the address.
--
-- For MAC addresses, returns only the string "mac".
local addrtype = {ipv4 = 'ip4', ipv6 = 'ip6'}
function module.addrtype(addr)
    for v, typ in pairs(addrtype) do
        local rep = cujo.net.iptobin(v, addr)
        if rep ~= nil then return typ, rep end
    end
    if addr:match'^%w+:%w+:%w+:%w+:%w+:%w+$' then return 'mac' end
end

-- Assumes the input is an IP address and returns a single number, 4 or 6,
-- according to the IP version.
function module.ipv(ip)
    return tonumber(module.addrtype(ip):sub(-1))
end

local function tobytes(n, m)
    local bytes = {}
    for i = 0, m - 1 do
        bytes[m - i] = (n >> i * 8) & 0xFF
    end
    return table.unpack(bytes)
end
function module.bintomac(address)
    return string.format('%02X:%02X:%02X:%02X:%02X:%02X', tobytes(address, 6))
end

function module.append(t, ...)
    vararg.map(function (v) table.insert(t, v) end, ...)
    return t
end

function module.join(dst, src)
    for _, v in ipairs(src) do table.insert(dst, v) end
    return dst
end

local serializer = Viewer{
    linebreak = false,
    nolabels = true,
    nofields = true,
    noarrays = true,
}
function module.serialize(...)
    return serializer:tostring(...)
end

-- Publishers are basically lists of callbacks, that can be called conveniently
-- by calling the publisher itself.
do
    local publisher = oo.class()
    function publisher:subscribe(handler) self.list[handler] = true end
    function publisher:unsubscribe(handler) self.list[handler] = nil end
    function publisher:empty() return next(self.list) == nil end
    function publisher:__call(...) for elem in pairs(self.list) do elem(...) end end
    function module.createpublisher() return publisher{list = {}} end
end

-- Enablers keep track of two booleans "wanted" and "enabled" and a publisher,
-- along with a function that is called to notify of a change.
--
-- self.wanted is set prior to calling the function. Once the function as well
-- as the callback completes, self.enabled will be set to signify that the
-- operation is complete and the desired state has been attained.
--
-- Neither self.wanted nor self.enabled should be modified by third parties.
do
    local enabler = oo.class()
    function enabler:get() return self.enabled end
    function enabler:set(enable, callback)
        enable = enable and true or false
        if enable == self.wanted then return callback() end
        self.wanted = enable
        return self:f(enable, function()
            cujo.log:enabler(self.name, enable and ' started' or ' stopped')
            self.pub(enable)
            callback()
            self.enabled = enable
        end)
    end
    function enabler:subscribe(handler) self.pub:subscribe(handler) end
    function enabler:unsubscribe(handler) self.pub:unsubscribe(handler) end
    function module.createenabler(name, f)
        return enabler{name = name, f = f, pub = module.createpublisher(),
            wanted = false, enabled = false}
    end
end

return module
