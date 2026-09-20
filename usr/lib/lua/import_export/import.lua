
local require = require
local concat = table.concat

local importversion = require "import_export.importversion"
local loader = require "import_export.loader"
local Importer = require "import_export.importer"

local logger = require('tch.logger').new("import", 6)

local function log_print(...)
  logger:warning("%s", concat({...}, ' '))
end

local function default_env()
  local env = {}
  env._G = env
  env.assert = assert
  env.error = error
  env.getfenv = getfenv
  env.getmetatable = getmetatable
  env.ipairs = ipairs
  env.next = next
  env.pairs = pairs
  env.pcall = pcall
  env.print = log_print
  env.rawequal = rawequal
  env.rawget = rawget
  env.rawset = rawset
  env.select = select
  env.setfenv = setfenv
  env.setmetatable = setmetatable
  env.tonumber = tonumber
  env.tostring = tostring
  env.type = type
  env.unpack = unpack
  env.xpcall = xpcall
  env.math = math
  env.string = string
  env.table = table
  env.logger = logger
  env.io = {
    open = io.open,
    lines = io.lines,
  }
  return env
end


local M = {}

local function load_conversion_def(uci, from_version, initial_env)
  local conversion_file = importversion.locate(uci, from_version)
  if not conversion_file then
    return nil, "no import conversion for version "..from_version
  end
  local convdef = importversion.ConversionDef()
  local env = importversion.importenv(convdef, initial_env)
  local r, err, tb = importversion.load(conversion_file, env)
  if not r then
    return nil, err, tb
  end
  return convdef
end

function M.importer_from_version(uci, from_version, initial_env)
  initial_env = initial_env or default_env()
  local convdef, err, tb = load_conversion_def(uci, from_version, initial_env)
  if not convdef then
    return nil, err, tb
  end
  local importer = Importer(convdef)
  return function(_, import_data)
    local data, e = loader.load(import_data.rawcontent)
    if not data then
      return nil, "Failed to load importdata: "..e
    end
    return importer:import(uci, data)
  end
end

return M