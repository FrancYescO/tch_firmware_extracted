--- Gateway field diagnostics (gwfd) Common Library.
--
-- This library provides a set of functions that are integral to developing
-- your own lua scripts to be compatible with the native gwfd daemon and the fifo interface.
-- The library makes use of available functionalities like ubus (events), transformer and uci.

-- The library

local common = {}

-- The required external modules and their affiliate variables

local uci = require("uci")
local ubus = require("ubus")
local logger = require("tch.logger")
common.dkjson = require("dkjson")
local tf_proxy
local tf_uuid
common.ubus_conn = nil
common.log = nil
local uci_cur = uci.cursor()

--[[
-- A self-destructing non-blocking script that can write from one source to one target file
-- Used in timed_write_msg_to_file
--]]
local timed_write_script_path = "/usr/share/ngwfdd/lib/timed_write.sh"

--[[
-- These are special parameter names that are reserved for our ELK implementation.
-- Should they ever appear in any collected parameter name, they will be prefixed with "my_"
-- to protect the logic found in the cloud that is based on the original names.
--]]
local specials = { "index", "tags" }

-- Local functions

-- Check if a variable is of a string type and non-empty

local function valid_nonempty_string(param)
  if type(param) ~= "string" then
    return false
  end

  if param == "" then
    return false
  end

  return true
end

--[[
-- Check if a msg data is of a table type and that
-- the file-name to write it to is a valid non-empty string
--]]

local function valid_msg_file_to_write(msg, fifo_file_path)
  if type(msg) ~= "table" or (not valid_nonempty_string(fifo_file_path)) then
    return false
  end

  if not next(msg) then
    return false
  end

  return true
end

--[[
-- Based on the special parameter names set from before, this
-- function prefixes "my_" if needed. The function
-- takes in data in the form of a table.
--]]

local function fix_special(msg)
  assert(type(msg) == "table")
  for _, v in pairs(specials) do
    local tmp = msg[v]
    if tmp then
      msg[v] = nil --remove the entry
      msg["my_" .. v] = tmp
    end
  end
end

--Initialize the transformer and return the success status.

local function init_transformer()
  tf_proxy = require 'datamodel-bck'
  local fd = assert(io.open("/proc/sys/kernel/random/uuid", "r"))
  tf_uuid = fd:read('*l')
  fd:close()
  tf_uuid = string.gsub(tf_uuid, "-", "")
  return (tf_uuid ~= nil)
end

-- Public API

--- Get Uptime from the proc file system
--
-- @return uptime A float uptime
function common.get_uptime()
  local uptime_file = io.open("/proc/uptime", "r")
  assert(uptime_file, "Failed to get uptime")
  local uptime = uptime_file:read("*number")
  uptime_file:close()
  return uptime
end

--- Check UTF8 validity on a string and replace invalid characters with "?"
--
-- @param s A string that may contain non-UTF8 to be fixed in-place
function common.fixUTF8(s)

  if type(s) ~= "string" then
    error("Invalid input args", 2)
  end

  local idx = 1
  local len = #s
  while idx <= len do
    local b = s:byte(idx)
    -- single byte chars
    if b < 128 then idx = idx + 1
    elseif idx == s:find("[\194-\223][\128-\191]", idx) then idx = idx + 2
    elseif idx == s:find("\224[\160-\191][\128-\191]", idx)
            or idx == s:find("[\225-\236][\128-\191][\128-\191]", idx)
            or idx == s:find("\237[\128-\159][\128-\191]", idx)
            or idx == s:find("[\238-\239][\128-\191][\128-\191]", idx) then idx = idx + 3
    elseif idx == s:find("\240[\144-\191][\128-\191][\128-\191]", idx)
            or idx == s:find("[\241-\243][\128-\191][\128-\191][\128-\191]", idx)
            or idx == s:find("\244[\128-\143][\128-\191][\128-\191]", idx) then idx = idx + 4
    else
      s = s:sub(1, idx - 1) .. "?" .. s:sub(idx + 1)
    end
  end
  return s
end

--- Get the value of given UCI parameter based on a dotted path.
--
-- @param plain_dotted_path Path to the needed uci parameter. E.g., "env.var.prod_number".
-- @return result           The value of the parameter at the given path.
function common.get_uci_param(plain_dotted_path)
  if not valid_nonempty_string(plain_dotted_path) then
    error("Invalid input args", 2)
  end

  local tokens = string.gmatch(plain_dotted_path, "[^.]+")
  local conf = tokens()
  local type = tokens()
  local para = tokens()
  local result = uci_cur:get(conf, type, para)
  return result
end

--- Get the values of a group of UCI parameters based on a table of dotted paths.
--
-- @param plain_dotted_paths Table of paths to the needed uci parameters.
-- @return result             Table of values keyed per parameter's name. Otherwise an empty table.
function common.get_uci_params(plain_dotted_paths)
  if type(plain_dotted_paths) ~= "table" then
    error("Invalid input args", 2)
  end

  local result = {}
  for _, param in pairs(plain_dotted_paths) do
    local val, errmsg = common.get_uci_param(param)
    if val then
      local key = string.match(param, '[^.]+$')
      result[key] = val
    else
      print(errmsg)
    end
  end
  return result
end

--- Get the value of an indexed UCI parameter.
-- E.g., system.@system[0].hostname
--
-- @param conf The UCI section name.
-- @param type A type in the conf section.
-- @param index The index on that type.
-- @param param The parameter name.
-- @return The value of the indexed UCI parameter, otherwise nil.
function common.get_uci_param_indexedtype(conf, type, index, param)
  if not (valid_nonempty_string(conf) and valid_nonempty_string(type)
          and valid_nonempty_string(param)) then
    error("Invalid input args", 2)
  end

  index = tonumber(index)
  if (not index) or (index < 0) then
    return nil
  end

  local t = uci_cur:get_all(conf)
  for _, v in pairs(t) do
    if index == v[".index"] then
      if type == v[".type"] then
        return v[param]
      end
    end
  end
  return nil
end

--- Get the values of a table of indexed UCI parameters.
--
-- @param indexed_uci_params The indexed UCI parameters
-- Example of input argument is: <br/>
-- <code>
-- device_indexed_uci_params = {
-- version = {
-- type = "version",
-- index = 0,
-- params = {
-- "product",
-- "marketing_version",
-- "marketing_name"
-- }
-- }
-- }
-- </code>
-- @return result A table containing the values of the indexed UCI parameters keyed by parameter's name, otherwise
-- an empty table.
function common.get_uci_params_indexedtype(indexed_uci_params)
  if type(indexed_uci_params) ~= "table" then
    error("Invalid input args", 2)
  end

  local result = {}
  for k, conf in pairs(indexed_uci_params) do
    for _, p in pairs(conf["params"]) do
      local val, errmsg = common.get_uci_param_indexedtype(k, conf["type"], conf["index"], p)
      if val then
        result[p] = val
      else
        print(errmsg)
      end
    end
  end
  return result
end

--- Create a true set from the list of elements.
--
-- @param list The list of elements
-- @return list  The same list with its elements assigned a true boolean value each.
function common.set(list)
  if type(list) ~= "table" then
    error("Invalid input args", 2)
  end

  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

--- Write data (fed in table format) to the given FIFO file path (unbuffered, to ensure atomic write).
-- The actual data is written in json encoding that also includes the fetched uptime.
-- This is a blocking operation.
--
-- @param msg The data to be written - a table.
-- @param fifo_file_path The file path to write the data to.
-- @return true          If the operation succeeded; false if message too long (then it is dropped)
function common.write_msg_to_file(msg, fifo_file_path)
  if not valid_msg_file_to_write(msg, fifo_file_path) then
    error("Invalid input args", 2)
  end

  fix_special(msg)
  msg.uptime = common.get_uptime()
  local json = common.dkjson.encode(msg)
  if not json or #json >= 4094 then
    return false
  end
  
  local file = assert(io.open(fifo_file_path, "w"), "Could not write to FIFO file!")
  file:setvbuf("no")
  file:write(json..'\n')
  io.close(file)

  return true
end

--- Write data (fed in table format) to the given file path in a non-blocking manner.
-- The actual data is written in json encoding that also includes the fetched uptime.
--
-- @param msg The data to be written - a table.
-- @param fifo_file_path The file path to write the data to.
-- @return true          If the operation has succeeded.
function common.timed_write_msg_to_file(msg, fifo_file_path)
  if not valid_msg_file_to_write(msg, fifo_file_path) then
    error("Invalid input args", 2)
  end

  local tmp_f_name = os.tmpname()
  local tmp_msg_f = assert(io.open(tmp_f_name, "w"), "Could not create a tmp file!")
  fix_special(msg)
  msg.uptime = common.get_uptime()
  local json = common.dkjson.encode(msg)
  tmp_msg_f:write(json)
  tmp_msg_f:write('\n')
  io.close(tmp_msg_f)
  local command = string.format("%s %s %s", timed_write_script_path, tmp_f_name, fifo_file_path)
  local p = assert(io.popen(command), "Could not execute timed-write script!")
  p:close()
  os.remove(tmp_f_name)

  return true
end

--- Get the value of a given parameter based on its transformer path.
--
-- @param path The transformer path to the required parameter.
-- @param msg The table in which the fetched value is placed and keyed by parameter name.
-- @param skip_conversion An optional table of params for which to skip number conversion.
-- @return msg   Otherwise nil if the parameter could not be fetched.
function common.get_transformer_param(path, msg, skip_conversion)
  if not valid_nonempty_string(path) or type(msg) ~= "table" then
    error("Invalid input args", 2)
  end

  skip_conversion = skip_conversion or {}
  local results, errmsg = tf_proxy.get(tf_uuid, path)

  if not results then
    print(errmsg)
    return nil, errmsg
  end

  for _, param in ipairs(results) do
    local number
    if not skip_conversion[param.param] then
      number = tonumber(param.value)
    end
    if number then
      msg[param.param] = number
    else
      msg[param.param] = param.value
    end
  end

  return msg
end

--- Get the values of a given table of parameters based on their transformer paths.
--
-- @param paths A table of transformer paths to the required parameters.
-- @param msg The table in which the fetched values are placed and keyed by parameter name.
-- @param skip_conversion An optional table of params for which to skip number conversion.
-- @return msg   Otherwise nil if one of the parameters could not be fetched.
function common.get_transformer_params(paths, msg, skip_conversion)

  if type(paths) ~= "table" or type(msg) ~= "table" then
    error("Invalid input args", 2)
  end

  skip_conversion = skip_conversion or {}
  for _, key in pairs(paths) do
    local results, errmsg = tf_proxy.get(tf_uuid, key)
    if not results then
      print(errmsg)
      return nil
    end
    for _, param in ipairs(results) do
      local number
      if not skip_conversion[param.param] then
        number = tonumber(param.value)
      end
      if number then
        msg[param.param] = number
      else
        msg[param.param] = param.value
      end
    end
  end
  return msg
end


--- A generic error handler that logs to syslog using a transformer logger.
--
-- @param err The error string to be logged
function common.errorhandler(err)
  common.log:critical(err)
  for line in string.gmatch(debug.traceback(), "([^\n]*)\n") do
    common.log:critical(line)
  end
end

--- Initialize the common gwfd library.
--
-- @param logger_name The name of the logger you wish to use.
-- @param logging_level The logging level to be used - must be an integer.
-- @param options The initialization options table
-- Options include booleans for: init_transformer, return_ubus_conn
-- E.g., options = {init_transformer = true}
-- @return common.log       Logger to be used by the application.
-- @return common.ubus_conn A ubus connection if indicated per options.
function common.init(logger_name, logging_level, options)

  assert(valid_nonempty_string(logger_name), "String is expected for logger name")
  local l_level = tonumber(logging_level)
  assert(l_level and (l_level >= 0), "Number is expected for logging level")
  assert(type(options) == "table", "Table is expected for options")

  logger.init(logger_name, l_level)
  common.log = logger

  assert(common.log, "Could not create a logger")

  if next(options) then
    if options.return_ubus_conn then
      common.ubus_conn = ubus.connect()
      assert(common.ubus_conn, "Failed to connect to ubus")
    end

    if options.init_transformer then
      local rv = init_transformer()
      if not rv then
        common.close()
      end
      assert(rv, "Failed to initialize transformer")
    end
  end

  if common.ubus_conn then
    return common.log, common.ubus_conn
  end

  return common.log
end

local function seconds_to_milliseconds(sec)
  return sec and (sec*1000)
end

function common.parse_args(args, default)
  default = default or {}
  return {
    fifo = arg[1],
    interval = seconds_to_milliseconds(tonumber(arg[2]) or default.interval)
  }
end

--- Close and finalize the common gwfd library.
function common.close()
  if common.ubus_conn then
    common.ubus_conn:close()
  end
  common.ubus_conn = nil
  tf_proxy = nil
  tf_uuid = nil
end

return common
