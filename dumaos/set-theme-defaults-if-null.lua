#!/usr/bin/lua
package.path=package.path..";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"require("libos")local o=require("json")local e="/dumaos/themes"local o=o.load(string.format("%s/default/manifest.json",e))local e=os.config_get("DumaOS_Theme")if not e or e==""then
os.config_set("DumaOS_Theme","default")end
local e=os.config_get("DumaOS_Theme_Version")if not e or e==""then
os.config_set("DumaOS_Theme_Version",o.version)end