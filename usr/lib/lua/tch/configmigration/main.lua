#!/usr/bin/env lua
local format = string.format
local assert = assert

local cmcore = require("tch.configmigration.core")
local config = require("tch.configmigration.config")
--local tprint = require("tch.tableprint")
local logger = require("transformer.logger")
logger.init(3, true) --enable logging to stderr
local log = logger.new("configmigration", config.log_level)

local args = {...}
-- override the user.ini defined in config file
config.user_ini = args[1] or config.user_ini

assert(type(config.user_ini) == "string", "[configmigration]: type of config.user_ini is invalid")
local fd = assert(io.open(config.user_ini, "r"), config.user_ini.." not exist, return with nop")
local s_user_ini = fd:read("*a")
fd:close()

-- g_user_ini hold all information of user.ini
local g_user_ini = cmcore.get_g_user_ini(s_user_ini)

-- release garbage
s_user_ini = nil
collectgarbage()

-- verification
--tprint(g_user_ini)

-- load conversion.map
assert(config.mapfile, "[configmigration]: invalid value of config.mapfile.")
local rc, errmsg = loadfile(config.mapfile)
assert(rc, errmsg)
local rc, res = pcall(rc)
assert(rc, res)
assert(type(res)=="table", "[configmigration]: "..config.mapfile.." should return a 'table'")
local g_maptable = res

-- conversion.map file indicates which section should be converted
for section_name,map_table in pairs(g_maptable) do

  -- try specific handler for each section
  local handler_file = format("%s/%s.lua", config.handler_dir, section_name)
  local rc, errmsg = cmcore.run_handler(handler_file, config, g_user_ini)
  if not rc then
     log:debug("%s ignored (%s)", handler_file, errmsg)
  end

  -- generic hanlder (left part of a section also have opportunity to be processed)
  if map_table then
     local section_string = g_user_ini[section_name]
     cmcore.convert_map(section_string, map_table, g_user_ini)
     -- after conversion, the element in maptable no use anymore, release here
     g_maptable[section_name] = nil
  end
end

cmcore.commit_list()
