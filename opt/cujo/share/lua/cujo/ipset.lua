--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local oo = require 'loop.base'

local ipset = {meta = oo.class()}

function ipset.meta:set(add, entry, on_set)
    cujo.jobs.exec(
        cujo.config.ipset,
        {add and 'add' or 'del', self.name, tostring(entry), '-exist'},
        on_set)
end

function ipset.meta:flush()
    cujo.jobs.exec(cujo.config.ipset, {'flush', self.name})
end

function ipset.new(params)
    local name = cujo.config.set_prefix .. params.name
    cujo.jobs.exec(cujo.config.ipset, {'-n', 'list', name})
    return ipset.meta{name = name}
end

return ipset
