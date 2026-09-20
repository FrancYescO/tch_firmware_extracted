#!/usr/bin/lua

--[[
-- (C) 2018 NETDUMA Software
-- Kian Cross <kian.cross@netduma.com>
--]]

package.path = package.path .. ";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"

require("libos")
local json = require("json")

local themes_path = "/dumaos/themes"
local themes_cloud_path = string.format("%s/cloud", themes_path)
local themes_ready_path = string.format("%s/ready", themes_path)

json.save(themes_ready_path, false)

local manifest = json.load(string.format("%s/default/manifest.json", themes_path))

os.config_set("DumaOS_Theme", "default")
os.config_set("DumaOS_Theme_Version", manifest.version)

os.execute(string.format("rm -rf %s && rm -rf  %s/* && mkdir -p %s", themes_cloud_path, themes_cloud_path, themes_cloud_path))
os.execute(string.format("ln -s %s/default %s/default", themes_path, themes_cloud_path))
os.execute("sync")

json.save(themes_ready_path, true)
