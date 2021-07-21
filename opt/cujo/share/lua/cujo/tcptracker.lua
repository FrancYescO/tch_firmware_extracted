--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

-- State tracking for the "synlistener", which captures the "tcptracker" events
-- sent from the kernel agent. In addition, if the "tcptracker" feature itself
-- is enabled, information about TCP SYN packets is sent to the agent-service,
-- basically informing it of fresh TCP connections.

local util = require 'cujo.util'

local refcount = 0

local function enable(callback)
        refcount = refcount + 1
        if refcount == 1 then
                return cujo.nfrules.set('tcptracker', function()
                        cujo.nfrules.check('tcptracker', callback)
                end)
        else
                return callback()
        end
end

local function disable(callback)
        refcount = refcount - 1
        if refcount == 0 then
                return cujo.nfrules.clear('tcptracker', function()
                        cujo.nfrules.check_absent('tcptracker', callback)
                end)
        else
                return callback()
        end
end

local function is_enabled()
        return refcount > 0
end

return {
    conns = util.createpublisher(),
    enable = util.createenabler('tcptracker', function (_, enable, callback)
        if enable then
            cujo.tcptracker.synlistener.enable(callback)
            cujo.nf.subscribe('tcptracker', cujo.tcptracker.conns)
        else
            cujo.tcptracker.synlistener.disable(callback)
            cujo.nf.unsubscribe('tcptracker', cujo.tcptracker.conns)
        end
    end),
    synlistener = {
        enable = enable,
        disable = disable,
        is_enabled = is_enabled,
    },
}
