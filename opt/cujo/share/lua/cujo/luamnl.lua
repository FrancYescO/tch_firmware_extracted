--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local mnl = require'cujo.mnl'
local oo = require 'loop.base'

local shims = require 'cujo.shims'

local fd_reader_stop
local fd_reader_set_callback

local Wrapper = oo.class()

function Wrapper:readall(callback)
    fd_reader_set_callback(callback)

    -- Ask luamnl to dump the conntrack table.
    self.__object:trigger()
end

function Wrapper.close()
    -- Don't actually close the mnl socket (self.__object) here, the GC will
    -- do that eventually. If we do it here then the GC will trigger an
    -- error because double-closing is not supported.
    fd_reader_stop()
end

local luamnl = {}

function luamnl.create(t)
    local object = mnl.new(t.bus, t.bylines, t.groups)

    local bybatch = t.bybatch or function() end

    fd_reader_stop, fd_reader_set_callback = shims.on_mnl_readable(
        object:getfd(), cujo.config.apptracker.conntrack_recv_buf_size, function()
            local ok, err = object:process()
            if not ok then
                -- This means that the socket is no longer readable i.e.
                -- we've exhausted the buffer for now, so it's not a
                -- problem. This should happen every time on the last
                -- iteration of the calling loop (in on_mnl_readable).
                if err == 'timeout' then
                    return 'done'
                end

                cujo.log:error("mnl read failed: ", err)
                return 'done'
            end
            local delay_until = bybatch()
            if delay_until ~= nil then
                return 'delay', delay_until
            end
        end)

    return Wrapper{__object = object}
end

return luamnl
