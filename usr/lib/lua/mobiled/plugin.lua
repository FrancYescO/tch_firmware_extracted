---------------------------------
--! @file
--! @brief The Plugin class loading the correct library
---------------------------------

local Plugin = {}
Plugin.__index = Plugin

function Plugin.create(runtime, name, cfg)
	local p = {
		name = name
	}

	local status, error = pcall(require, name)
	p.plugin = status and error or nil
	if not p.plugin then
		return nil, "Failed to load " .. name .." plugin".." (" .. error .. ")"
	end

	status, error = p.plugin.init_plugin(runtime, cfg)
	if not status then return nil, error end

	setmetatable(p, Plugin)
	return p
end

function Plugin:reconfigure(cfg)
	return self.plugin.reconfigure_plugin(cfg)
end

function Plugin:destroy()
	return self.plugin.destroy_plugin()
end

return Plugin
