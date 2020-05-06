---
-- @module transformer.mapper.command
local M = {}

local pairs, ipairs, assert, type = pairs, ipairs, assert, type
local require = require
local format, gsub = string.format, string.gsub
local open = io.open

local posix = require("tch.posix")
local unix = require("tch.socket.unix")

--- Function to validate if the given argument is a correct command array.
-- @param array The array that needs to be checked.
-- @error If the given argument isn't a table, it's values are not a string,
--        or it contains a 'launch_command' or 'command_socket' field.
-- @return nil If all checks passed.
local function validate_command_array(array)
  assert(type(array)=="table")
  for key, value in pairs(array) do
    assert(type(value)=="string")
    assert(value~="launch_command")
    assert(value~="command_socket")
  end
end

--- Function to validate if the given argument is a correct command representation.
-- @param command The command representation that needs to be checked.
-- @error If the given argument is not a table, or it doesn't contain a 'name' or
--        'full_path' string entry.
-- @error If the full_path doesn't point to an actual file
-- @error If the given argument contains an invalid 'options_without_argument',
--        'options_with_argument' or 'operands' array.
-- @return nil If all checks passed.
local function validate_command(command)
  assert(type(command)=="table")
  assert(command.name)
  assert(type(command.name)=="string")
  assert(command.full_path)
  assert(type(command.full_path)=="string")
  local fd = open(command.full_path)
  assert(fd)
  fd:close()
  if command.options_without_argument then
    validate_command_array(command.options_without_argument)
  end
  if command.options_with_argument then
    validate_command_array(command.options_with_argument)
  end
  if command.operands then
    validate_command_array(command.operands)
  end
end

local boolean_param_info = {
  access = "readWrite",
  type = "boolean",
}

local string_param_info = {
  access = "readWrite",
  type = "string",
}

--- Helper function to create boolean readWrite parameters.
-- @param parameters The parameters table from a mapping. The newly created parameters
--                   will be added to this table.
-- @param options_array An array of strings for which we want to create boolean
--                      parameters in the datamodel.
-- @note There is no check if an option already exists, it will simply be overwritten.
local function create_boolean_parameters(parameters, options_array)
  for _, option in ipairs(options_array) do
    parameters[option] = boolean_param_info
  end
end

--- Helper function to create string readWrite parameters.
-- @param parameters The parameters table from a mapping. The newly created parameters
--                   will be added to this table.
-- @param options_array An array of strings for which we want to create string
--                      parameters in the datamodel.
-- @note There is no check if an option already exists, it will simply be overwritten.
local function create_string_parameters(parameters, options_array)
  for _, option in ipairs(options_array) do
    parameters[option] = string_param_info
  end
end

local defaults = {
  string = "",
  boolean = "0",
}

--- Helper function to create an entries function for a command mapping.
-- @param command_mapping The command mapping to which we need to add an entries function.
-- @param resolve The resolve function from Transformer.
-- @note A command is modeled as an optional single instance so that the local
--       session cache can be verified in the entries function. The instance will always exist.
local function create_entries(command_mapping, resolve)
  command_mapping.entries = function(mapping, parentkey)
    local session_cache = mapping._session_cache
    for sessionid in pairs(session_cache) do
      local exists = resolve("Command.Session.@.", sessionid)
      if not exists then
        session_cache[sessionid] = nil
      end
    end
    return {parentkey}
  end
end

--- Helper function to create a get function for a command mapping.
-- @param command_mapping The command mapping to which we need to add the get function.
local function create_getter(command_mapping)
  command_mapping.get = function(mapping, paramname, parentkey)
    local session_cache = mapping._session_cache
    -- If a parameter is ever set, it should be in the session cache.
    if session_cache[parentkey] and session_cache[parentkey][paramname] then
      return session_cache[parentkey][paramname]
    end
    return defaults[mapping.objectType.parameters[paramname].type]
  end
end

--- Helper function to expand the given arguments into the execv arguments array.
-- @param options_array An array of strings for which we created parameters in the datamodel.
-- @param set_arguments A table holding all arguments that were previously set.
-- @param execv_args_array An array of strings representing the arguments that were set and which can
--                         be passed to execv. It's in this array that new arguments will be added (if any).
-- @param option_type The type of arguments we're expanding (boolean or string)
-- @param include_option A boolean to indicate the option name is also an argument to be passed to execv or not.
local function expand_arguments(options_array, set_arguments, execv_args_array, argument_type, include_option)
  for _, option in ipairs(options_array) do
    if set_arguments[option] and set_arguments[option] ~= defaults[argument_type] then
      if include_option then
        execv_args_array[#execv_args_array + 1] = option
      end
      if argument_type ~= "boolean" then
        execv_args_array[#execv_args_array + 1] = set_arguments[option]
      end
    end
  end
end

--- Helper function to expand the arguments that were set into an array that can be passed to execv.
-- @param command A table representation of the command.
-- @param set_arguments A table holding all arguments that were previously set.
-- @return An array of all parameters that were set before launching the command in a format that
--         can be passed to execv.
local function expand_exec_arguments(command, set_arguments)
  local exec_args_array = {}
  if command.options_without_argument then
    expand_arguments(command.options_without_argument, set_arguments, exec_args_array, "boolean", true)
  end
  if command.options_with_argument then
    expand_arguments(command.options_with_argument, set_arguments, exec_args_array, "string", true)
  end
  if command.operands then
    expand_arguments(command.operands, set_arguments, exec_args_array, "string")
  end
  return exec_args_array
end

--- Helper function to fork and exec the given command with the given arguments.
local function fork_and_exec(cmd, args, socketname, sessionid)
  local logger = require("transformer.logger")
  if not socketname or not sessionid then
    logger:critical("Failed to launch %s: Missing socketname or sessionid", cmd)
    return nil, "Failed to launch command"
  end
  local pid = assert(posix.fork())
  if pid == 0 then
    -- This is the child process
    local actual_pid = posix.getpid()
    local fd, err = open ("/cgroups/cpumemblk/clash/"..sessionid.."/tasks", "w")
    if not fd then
      os.exit(0)
    end
    fd:write(actual_pid)
    fd:close()
    local sk = unix.stream()
    assert(sk:connect(socketname))
    local fd = sk:fd()
    posix.dup2(fd, 0) -- stdin
    posix.dup2(fd, 1) -- stdout
    posix.dup2(fd, 2) -- stderr
    local ok, err = posix.execv(cmd, args)
    -- if we reach this code, execv failed. Exit the child process.
    logger:critical("Execv failed with error message: %s", err)
    os.exit(0)
  end
end

--- Helper function to create a set function for a command mapping.
-- @param command_mapping The command mapping to which we need to add the set function.
local function create_setter(command_mapping)
  command_mapping.set = function(mapping, paramname, paramvalue, parentkey)
    local session_cache = mapping._session_cache
    if not session_cache[parentkey] then
      session_cache[parentkey] = {}
    end
    if paramname == "launch_command" then
      local exec_args = expand_exec_arguments(mapping._command, session_cache[parentkey])
      return fork_and_exec(mapping._command.full_path, exec_args, session_cache[parentkey]["command_socket"], parentkey)
    else
      session_cache[parentkey][paramname] = paramvalue
    end
  end
end

--- Create a command mapping based on the given command table representation.
-- This function takes a table representation of a command and converts it into a mapping
-- that can be used by Transformer.
-- @tparam table command The table representation of a command. This representation should contain
--                       at least 2 named table entries:
--                           name: The name of the command to be used in the mapping.
--                           full_path: The full filepath of the binary to be executed.
--                           options_without_argument(optional): An array of all possible options that take no argument.
--                           options_with_argument(optional): An array of all possible options that take an argument.
--                           operands(optional): An array of all possible operand.
-- @treturn table A mapping representation of the given command.
-- @note The order used in one of the optional arrays is the order in which they will be passed to the binary if they are set.
--       None of the optional arrays can contain a 'launch_command' or 'command_socket' entry.
function M.createCommandMap(command)
  validate_command(command)
  local mapping = {
    objectType = {
      name = format("Command.Session.@.%s.", command.name),
      access = "readOnly",
      minEntries = 0,
      maxEntries = 1,
    }
  }
  local parameters = {}
  if command.options_without_argument then
    create_boolean_parameters(parameters, command.options_without_argument)
  end
  if command.options_with_argument then
    create_string_parameters(parameters, command.options_with_argument)
  end
  if command.operands then
    create_string_parameters(parameters, command.operands)
  end
  parameters["launch_command"] = {
    access = "readWrite",
    type = "boolean",
  }
  parameters["command_socket"] = {
    access = "readWrite",
    type = "string",
  }
  mapping.objectType.parameters = parameters
  mapping._command = command
  mapping._session_cache = {}
  create_entries(mapping, resolve)
  create_getter(mapping)
  create_setter(mapping)
  return mapping
end

--- Create and register a command mapping based on the given command table representation.
-- This function takes a table representation of a command and converts it into a mapping
-- that can be used by Transformer. It then registers this mapping with Transformer.
-- @tparam table command The table representation of a command.
-- @see createCommandMap
function M.registerCommand(command)
  register(M.createCommandMap(command))
end

return M
