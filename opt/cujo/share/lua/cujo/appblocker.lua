--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local shims = require 'cujo.shims'
local util = require 'cujo.util'

-- Matches IPPROTO_TCP and IPPROTO_UDP in Linux.
local prototoint = {tcp = 6, udp = 17}

local packfmt = {ip4 = 'I6Bc4I2', ip6 = 'I6Bc16I2'}

local function set(name, mac, ip, proto, port, add)
    assert(cujo.appblocker.enable:get() == true, 'feature not enabled')
    -- This encoding must match the one used in nf_appblocker.
    local ipv, ipb = cujo.util.addrtype(ip)
    local id = string.pack(packfmt[ipv], tonumber(mac:gsub(':', ''), 16),
        prototoint[proto], ipb, port)
    local action = add and 'add' or 'del'
    cujo.nf.dostring(string.format('appblocker[%q](%q, %q)', action, name, id))

    if add then
        for sip in pairs(cujo.apptracker.traffic[ipv][mac]) do
            cujo.config.connkill(ipv, sip, ip, proto, port)
        end
    end
    cujo.log:appblocker(action, ' ', mac, ', ', ip, ', ', proto, ', ', port,
        " in set '", name, "'")
end

local function flush(name)
    cujo.nf.dostring(string.format('appblocker.flush(%q)', name))
    cujo.log:appblocker("flush set '", name, "'")
end

local sets = {'main', 'timed'}
local module = {
    enable = util.createenabler('appblocker', function (_, enable, callback)
        for _, name in pairs(sets) do flush(name) end

        if enable then
            cujo.nfrules.set('appblocker', function()
                cujo.nfrules.check('appblocker', callback)
            end)
        else
            cujo.nfrules.clear('appblocker', function()
                cujo.nfrules.check_absent('appblocker', callback)
            end)
        end
    end),
}

for _, name in ipairs(sets) do
    module[name] = {
        set = function (mac, ip, proto, port, add)
            return set(name, mac, ip, proto, port, add)
        end,
        flush = function ()
            return flush(name)
        end,
    }
end

local stop_timer = nil

-- Flush the 'timed' set on a period defined by cujo.appblocker.timed.reset, as
-- given by the cloud.
--
-- Supports use cases like "every day from 22:00–08:00 this device is not
-- allowed to access the Internet", by deleting the rules at 08:00. But note
-- that we flush all rules, not just one, and the cloud is required to re-send
-- the rule so that it starts again at 22:00 the next day.
function module.timed.reset(delay, period)
    if stop_timer ~= nil then
        stop_timer()
        stop_timer = nil
    end

    cujo.log:appblocker('reset next timed flush in ', delay, 's', ' then, every ', period, 's')

    stop_timer = shims.create_stoppable_timer("appblocker-flush-timer", delay, function()
        cujo.jobs.spawn("appblocker-flusher", cujo.appblocker.timed.flush)
        return period
    end)
end

function module.initialize()
    for _, name in ipairs(sets) do
        flush(name)
    end
end

return module
