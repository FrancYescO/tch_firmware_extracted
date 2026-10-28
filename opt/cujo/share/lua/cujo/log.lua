--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local Viewer = require'loop.debug.Viewer'
local Verbose = require'loop.debug.Verbose'

local viewer = Viewer{
	linebreak = false,
	nolabels = true,
	noindices = true,
	metaonly = true,
	maxdepth = 2,
}

cujo.log = Verbose{
	viewer = viewer,
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
			'appblock',
			'rabidctl',
			'scan',
			'status_update',
			'traffic',
		},
		services = {
			'safebro',
			'trackerblock',
		},
	},
}

local log_level_orig = cujo.log.level
function cujo.log:level(...)
	if select("#", ...) == 0 then
		return log_level_orig(cujo.log)
	else
		log_level_orig(cujo.log, ...)
		if cujo.nf and cujo.nf.initialized then
			cujo.nf.dostring(string.format(
				'debug_logging = %s',
				cujo.log:flag('nflua_debug')))
		end
	end
end

local loglevel = tonumber(os.getenv("CUJO_LOGLEVEL"))
if loglevel == nil then
    loglevel = 2
end

cujo.log:settimeformat'%H:%M:%S'
cujo.log.timed = true
cujo.log:level(loglevel)
