--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require = require
local xpcall = require 'tch.xpcall'
local format = string.format
local loadstring = loadstring
local logger = require "transformer.logger"

local function show_pcall_trace(err)
  logger:error(err)
  for ln in debug.traceback():gmatch("([^\n]*)\n?") do
    logger:debug(ln)
  end
  return err
end

local function pcall(fn, ...)
  return xpcall(fn, show_pcall_trace, ...)
end
-- the require for io is not strictly needed, but it makes unit testing
-- (with a mock io) so much easier.
local io = require 'io'
local lfs = require 'lfs'

local M = {}

local module_name = "transformer.persistency.convert"
local script_dir
do
  -- find the path of the downgrade scripts
  local modname = module_name:gsub("%.", "/")
  for d in package.path:gmatch("([^;]*);?") do
    local fn = d:gsub("%?", modname)
    if lfs.attributes(fn, 'mode')=='file' then
      script_dir = (fn:match("(.*/)") or './') .. "conversion/"
      break
    end
  end
end
M.script_dir = script_dir

local function pragma_get(db, pragma)
  local stmt = format("PRAGMA %s;", pragma)
  local r = db:execSql(stmt)
  return r and r[pragma]
end

local function require_upgrade_script(to_version)
  local script_name = format("transformer.persistency.conversion.upgrade_to_%d", to_version)
  local ok, script = pcall(require, script_name)
  if not ok then
    return nil
  end
  return script
end

local function load_downgrade_script(from_version)
  local script
  if script_dir then
    local fn = format("%sdowngrade_from_%d", script_dir, from_version)
    local f = io.open(fn, 'rb')
    if f then
      script = f:read("*a")
      f:close()
    end
  end
  return script
end

local function insert_downgrade_script(db, from_version, script)
  db:execSql( [[
    CREATE TABLE IF NOT EXISTS downgrade (
      version INTEGER PRIMARY KEY,
      script TEXT NOT NULL
    );
  ]])

  db:execSql( [[
    INSERT OR REPLACE
    INTO downgrade(version, script)
    VALUES(:version, :script);
  ]],
  {
    version = from_version,
    script = script
  })
end

local function get_downgrade_script(db, from_version)
  local result = db:execSql([[
    SELECT script
    FROM downgrade
    WHERE version=:version
    ]],
    { version=from_version}
  )
  return result and result.script
end


local function upgrade(db, current_version, target_version)
  repeat
    local next_version = current_version + 1
    local script = require_upgrade_script(next_version)
    if not (script and pcall(script.convert, db)) then
      --upgrade script failed
      return false
    end

    current_version = pragma_get(db, "user_version")
    if next_version~=current_version then
      -- no upgrade happened
      return false
    end

    local ok, downgrade_script = pcall(load_downgrade_script, current_version)
    if downgrade_script then
      pcall(insert_downgrade_script, db, current_version, downgrade_script)
    end

  until current_version==target_version
end

local function downgrade(db, current_version, target_version)
  repeat
    local next_version = current_version - 1
    local downgrade = get_downgrade_script(db, current_version)
    if not downgrade then
      return false
    end
    local convert
    local ok, script = pcall(loadstring, downgrade)
    if ok and script then
      ok, convert = pcall(script)
    end
    if not( convert and pcall(convert.convert, db)) then
      return false
    end

    current_version = pragma_get(db, "user_version")
  until current_version==target_version
end

function M.convert(db, target_version)
  -- A newly created, empty database does not need converting.
  local schema_version = pragma_get(db, "schema_version") or 0
  if schema_version==0 then
    return true
  end

  local current_version = pragma_get(db, "user_version") or 0
  if current_version == target_version then
    -- there is not conversion to do
    return true
  end

  -- a conversion is needed. Do this is one transaction
  db:startTransaction()

  -- now perform the upgrade or downgrade
  if current_version < target_version then
    upgrade(db, current_version, target_version)
  elseif target_version < current_version then
    downgrade(db, current_version, target_version)
  end

  -- check if the upgrade ended up at the correct version
  local new_version = pragma_get(db, "user_version")
  if new_version ~= target_version then
    -- conversion failed
    db:rollbackTransaction()
    return false
  end

  -- conversion succeeded
  db:commitTransaction()

  -- remove any cruft left in the database
  db:execSql("VACUUM;")
  -- make sure the wal file gets cleared
  db:execSql("PRAGMA journal_mode=DELETE;")
  db:execSql("PRAGMA journal_mode=WAL;")
  return true
end

return M
