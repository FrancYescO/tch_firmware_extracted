--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local Viewer = require'loop.debug.Viewer'
local Verbose = require'loop.debug.Verbose'

local viewer = Viewer{
    linebreak = false,
    nolabels = true,
    noindices = true,
    metaonly = true,
    maxdepth = 2,
}

local log = Verbose{
    viewer = viewer,
    taglength = 10,
    groups = {
        -- log levels
        {'error'},
        {'warn'},
        {'info', 'config', 'feature', 'status', 'enabler'},
        {'debug', 'communication', 'features', 'services', 'nflua', 'jobs', 'nflua_debug'},
        -- tag groups
        communication = {
            'cloud',
            'hibernate',
            'stomp',
        },
        features = {
            'access',
            'appblocker',
            'rabidctl',
            'scan',
            'status_update',
            'tcptracker',
            'apptracker',
        },
        services = {
            'safebro',
            'trackerblock',
        },
    },
}

local log_level_orig = log.level
function log:level(...)
    if select("#", ...) == 0 then
        return log_level_orig(self)
    else
        log_level_orig(self, ...)
        if cujo and cujo.nf and cujo.nf.initialized then
            cujo.nf.dostring(string.format(
                'debug_logging = %s',
                self:flag('nflua_debug')))
        end
    end
end

local loglevel = tonumber(os.getenv("CUJO_LOGLEVEL"))
if loglevel == nil then
    loglevel = 2
end

log:settimeformat'%H:%M:%S'
log.timed = true
log:level(loglevel)

return log
