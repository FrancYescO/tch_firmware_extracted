--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local module = {}

--- Execute raptr commands
-- Handling following combinations:
--  raptr set   [-v[v[...]] <group>
--  raptr clear [-v[v[...]] <group>
--  raptr check [-w <timeout>] [-v[v[...]] group <group>
local function run_raptr(rargs, callback)
    local raptr_bin = os.getenv'CUJO_HOME' .. "/bin/raptr"

    local verbosity_flags = nil
    local loglevel = cujo.log:level()
    if loglevel > 1 and loglevel < 10 then
        verbosity_flags = "-" .. string.rep('v', loglevel - 1)
    end

    local raptr_args = {rargs['command'], verbosity_flags}
    if rargs['command'] == 'check' then
        raptr_args[#raptr_args + 1] = '-w'
        raptr_args[#raptr_args + 1] = cujo.config.job.timeout
        raptr_args[#raptr_args + 1] = 'group'
        if rargs['absent'] == true then
            raptr_args[#raptr_args + 1] = '--not-present'
        end
    end

    raptr_args[#raptr_args + 1] = rargs['group']

    return cujo.jobs.exec(raptr_bin, raptr_args, callback)
end

function module.set(group, callback)
    if cujo.config.external_nf_rules then return callback() end
    return run_raptr({command = 'set', group = group}, callback)
end

function module.clear(group, callback)
    if cujo.config.external_nf_rules then return callback() end
    return run_raptr({command = 'clear', group = group}, callback)
end

function module.check(group, callback)
    return run_raptr({command = 'check', group = group}, callback)
end

function module.check_absent(group, callback)
    return run_raptr({command = 'check', absent = true, group = group}, callback)
end

return module
