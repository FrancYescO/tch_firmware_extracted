--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local cospawn = require'coutil.spawn'
local process = require'process'

local shims = require 'cujo.shims'

local module = {}

local function errhandler(err)
    cujo.log:error('unhandled Lua error: ', debug.traceback(err))
end

function module.spawn(name, f, ...) cospawn.catch(errhandler, name, f, ...) end

function module.exec(cmd, args, on_finish)
    on_finish = on_finish or function() end
    if cujo.config.privileges and cujo.config.privileges.capabilities == 'sudo' then
        args = table.pack(cmd,table.unpack(args))
        cmd = 'sudo'
    end
    local args_str = table.concat(args, " ")
    cujo.log:jobs("starting '", cmd, ' ', args_str, "'")
    local proc, err = process.create{
        execfile = assert(cmd, 'missing command'),
        arguments = args,
    }
    if not proc then
        cujo.log:error("failed to run '", cmd, ' ', args_str, "' (", err, ')')
        return on_finish(nil, err)
    end
    local finish = os.time() + cujo.config.job.timeout
    shims.create_stoppable_timer("job-watcher", cujo.config.job.pollingtime, function()
        local exitval, err = process.exitval(proc)
        if exitval == 0 then
            cujo.log:jobs("command '", cmd, " ", args_str, "' executed successfully")
            on_finish(true)
            return nil
        end
        if exitval then
            cujo.log:warn("command '", cmd, " ", args_str, "' exit with error ", exitval)
            on_finish(nil, exitval)
            return nil
        end
        if err ~= 'unfulfilled' then
            cujo.log:error("error running command '", cmd, " ", args_str, "' (", err, ')')
            on_finish(nil, err)
            return nil
        end
        if os.time() >= finish then
            cujo.log:warn("command '", cmd, " ", args_str, "' is taking too long")
            on_finish(nil, 'timeout')
            return nil
        end
        return cujo.config.job.pollingtime
    end)
end

return module
