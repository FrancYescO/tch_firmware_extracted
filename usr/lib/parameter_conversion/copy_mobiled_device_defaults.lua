#!/usr/bin/lua

local uci = require("uci").cursor()

local device_defaults = uci:get_all("mobiled", "device_defaults")
if device_defaults then
	uci:foreach("mobiled", "device", function(section)
		for key, value in pairs(device_defaults) do
			if not section[key] then
				uci:set("mobiled", section[".name"], key, value)
			end
		end
	end)
end

uci:commit("mobiled")
