#!/usr/bin/lua

--[[
-- (C) 2018 NETDUMA Software
-- Kian Cross <kian.cross@netduma.com>
--]]

package.path = package.path .. ";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"

require("libos")
local json = require("json")

local themes_path = "/dumaos/themes"

local manifest = json.load(string.format("%s/default/manifest.json", themes_path))

local theme = os.config_get("DumaOS_Theme")
if not theme or theme == "" then
  os.config_set("DumaOS_Theme", "default")
end

local theme_version = os.config_get("DumaOS_Theme_Version")
if not theme_version or theme_version == "" then
  os.config_set("DumaOS_Theme_Version", manifest.version)
end
