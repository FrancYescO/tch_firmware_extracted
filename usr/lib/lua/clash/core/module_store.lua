--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]
---
-- Handles all CLI module storage logic. Exposes logic to register new modules to the CLI
-- and to unregister existing modules from the CLI.
--
-- @module core.module_store

local pcall, type, setmetatable, pairs = pcall, type, setmetatable, pairs

local gmatch, match = string.gmatch, string.match

local sort = table.sort

--- @type CliStore
local CliStore = {}
CliStore.__index = CliStore

-- The different types of modules that can be recognized by the CLI.
local COMMAND_MODULE = 1 -- Actual command
local VERIFIER_MODULE = 2 -- Type verifier
local COMPLETER_MODULE = 3 -- Type completer

local module_types = {
  [COMMAND_MODULE] = "command",
  [VERIFIER_MODULE] = "verifier",
  [COMPLETER_MODULE] = "completer",
}

local function fail(self, errmsg, ...)
  self.logger:error(errmsg, ...)
  return nil, errmsg
end

--- Core function to register a new module.
-- All sanity checks should have been performed before calling this function.
-- Module type MUST be one of the known module types or this function will cause an error.
--
-- @tparam CliStore self The table representation of the CLI module store.
-- @int module_type The type of module we are registering.
-- @string module_name The name of the module we are registering.
-- @tparam table|function module The actual module that we are registering.
local function register_module(self, module_type, module_name, module)
  local module_collection = self.modules[module_type]
  module_collection[module_name] = module
end

--- Core function to unregister an existing module.
-- All sanity checks should have been performed before calling this function.
-- Module type MUST be one of the known module types or this function will cause an error.
--
-- @tparam CliStore self The table representation of the CLI module store.
-- @int module_type The type of module we are unregistering.
-- @string module_name The name of the module we are unregistering.
local function unregister_module(self, module_type, module_name)
  local module_collection = self.modules[module_type]
  module_collection[module_name] = nil
end

--- Function to check if a given usage text can be parsed by lapp.
-- @tparam CliStore self The table representation of the CLI module store.
-- @string usage The usage message that we are checking.
-- @treturn table The parsed usage text in table form
-- @error Failed to parse the usage message
local function parse_options(self, usage)
  local ok, result = pcall(self.lapp.process_usage, usage)
  if not ok then
    return nil, "Failed to parse the usage message: "..result
  end
  return result
end

--- Function to check a command module.
-- A command module needs to be a table and contain at least a 'usage\_msg' field.
-- This 'usage\_msg' field needs to be parseable by lapp before we accept the module.
-- @tparam CliStore self The table representation of the CLI module store.
-- @tparam table module The command module that we are checking.
local function check_command(self, module)
  if type(module) ~= "table" then
    return nil, "Command module needs to be a table"
  end
  if not module.usage_msg then
    return nil, "Missing usage message"
  end
  local options, errmsg = parse_options(self, module.usage_msg)
  if not options then
    return nil, errmsg
  end
  module.options = options
  return true
end

--- Function to check a verifier module.
-- A verifier module needs to be a function.
-- @tparam CliStore self The table representation of the CLI module store.
-- @tparam function verify_function The verifier module that we are checking.
-- @treturn boolean True if the given verifier module is a function
-- @error Missing verify function
local function check_verifier(self, verify_function)
  if type(verify_function) ~= "function" then
    return nil, "Missing verify function"
  end
  return true
end

--- Function to check a completer module.
-- A completer module needs to be a function.
-- @tparam CliStore self The table representation of the CLI module store.
-- @tparam function complete_function The completer module that we are checking.
-- @treturn boolean True if the given completer module is a function
-- @error Missing complete function
local function check_completer(self, complete_function)
  if type(complete_function) ~= "function" then
    return nil, "Missing complete function"
  end
  return true
end

--- Function to register a command module.
-- If the command module contains an 'alias' field, register these as well
-- @tparam CliStore self The table representation of the CLI module store.
-- @string name The name for the command module.
-- @tparam table command The command module itself.
local function register_command(self, name, command)
  register_module(self, COMMAND_MODULE, name, command)
  if command.alias then
    -- Alias should be comma separated
    for alias in gmatch(command.alias, "([^,]+)") do
      register_module(self, COMMAND_MODULE, alias, command)
    end
  end
end

--- Function to register a verifier module.
-- For every verifier module we register, we add a type to lapp.
-- @tparam CliStore self The table representation of the CLI module store.
-- @string name The name for the verifier module.
-- @tparam function verifier The verifier module itself.
local function register_verifier(self, name, verifier)
  self.lapp.add_type(name,verifier)
  register_module(self, VERIFIER_MODULE, name, verifier)
end

--- Function to register a completer module.
-- @tparam CliStore self The table representation of the CLI module store.
-- @string name The name for the completer module.
-- @tparam function completer The completer module itself.
local function register_completer(self, name, completer)
  register_module(self, COMPLETER_MODULE, name, completer)
end

local actions = {
  [COMMAND_MODULE] = {
    check = check_command,
    register = register_command,
  },
  [VERIFIER_MODULE] = {
    check = check_verifier,
    register = register_verifier,
  },
  [COMPLETER_MODULE] = {
    check = check_completer,
    register = register_completer,
  },
}

--- Function to register a new module to the store.
-- The given module will be added to the module store based on the specified parameters.
-- A command module is represented as a table, while completer and verifier modules are
-- represented as functions.
--
-- @tparam table|function module The new module to be added to the store.
-- @int[opt=1] module_type The type of module that's being registered.
-- @string[opt] module_name The name of the module that's being registered.
-- @treturn boolean True if everything is successful.
-- @error Illegal module type
-- @error Missing module name
-- @error Failed module verification
function CliStore:register_module(module, module_type, module_name)
  module_type = module_type or COMMAND_MODULE
  if not module_types[module_type] then
    return fail(self, "Failed to register module: Illegal module type")
  end
  module_name = module_name or (type(module) == "table" and module.name)
  if not module_name then
    return fail(self, "Failed to register module: Missing module name")
  end
  self.logger:debug("Registering module %s with type %s", module_name, module_type)

  local action = actions[module_type]
  local ok, errmsg = action.check(self, module)
  if not ok then
    return fail(self, "Failed to register module: " .. errmsg)
  end
  action.register(self, module_name, module)
  return true
end

--- Function to unregister an existing module from the store.
-- The given module will be removed from the module store based on the specified parameters.
-- A command module is represented as a table, while completer and verifier modules are
-- represented as functions.
--
-- @tparam table|function module The new module to be removed from the store.
-- @int[opt=1] module_type The type of module that's being unregistered.
-- @string[opt] module_name The name of the module that's being unregistered.
-- @treturn boolean True if everything is successful.
-- @error Illegal module type
-- @error Missing module name
function CliStore:unregister_module(module, module_type, module_name)
  module_type = module_type or COMMAND_MODULE
  if not module_types[module_type] then
    return fail(self, "Failed to unregister module: Illegal module type")
  end
  module_name = module_name or (type(module) == "table" and module.name)
  if not module_name then
    return fail(self, "Failed to unregister module: Missing module name")
  end
  self.logger:debug("Unregistering module %s with type %s", module_name, module_type)

  unregister_module(self, module_type, module_name)
  if module_type == COMMAND_MODULE and module.alias then
    for alias in gmatch(module.alias, "([^,]+)") do
      unregister_module(self, COMMAND_MODULE, alias)
    end
  end
  return true
end

--- Function to retrieve all registered modules of a given type.
-- @int module_type The type of module for which we want to retrieve all registered modules.
-- @treturn[1] table All registered modules that correspond to the given module type.
-- @treturn[2] nil If the given module type is unknown.
function CliStore:retrieve_modules(module_type)
  return self.modules[module_type]
end

-- "command" is an internal type, so we need to provide the completer
-- TODO move this out of module store
local function complete_command(self, command)
  self.logger:debug("complete_command called with word %s", command or "unknown")
  local cmds = self.retrieve_modules(self, COMMAND_MODULE)
  local verifiers = self.retrieve_modules(self, VERIFIER_MODULE)
  local verifier = verifiers.command
  local ok = pcall(verifier, command)
  local results = {}
  if command == "" or ok then
    if cmds then
      for cmd in pairs(cmds) do
        if match(cmd, "^"..command) then
          results[#results + 1] = cmd
        end
      end
    end
    if match("reload", "^"..command) then
      results[#results + 1] = "reload"
    end
    if match("help", "^"..command) then
      results[#results + 1] = "help"
    end
    if match("exit", "^"..command) then
      results[#results + 1] = "exit"
    end
  end
  sort(results)
  return results
end

-- TODO move this out of module store
local function complete_command_wrapper(self)
  return function(command)
    return complete_command(self, command)
  end
end

-- TODO move this out of module store
local function verify_command(command)
  if match(command, "^[%w]+[%w_]*$") then
    return command
  end
  error("Not a valid command")
end

-- TODO "option" is an internal type, so we need to provide the completer
-- TODO "option" is an internal type, so we need to provide the verifier

---
-- @section end
local M = {}

--- Initializes a new module store.
-- @param logger An initialized syslog logger object.
-- @param lapp An initialized Lua Penlight lapp object.
-- @treturn CliStore A new CLI module store.
M.init = function(logger, lapp)
  local self = {
    modules = {
      [COMMAND_MODULE] = {},
      [VERIFIER_MODULE] = {},
      [COMPLETER_MODULE] = {},
    },
    logger = logger,
    lapp = lapp,
    COMMAND_MODULE = COMMAND_MODULE,
    VERIFIER_MODULE = VERIFIER_MODULE,
    COMPLETER_MODULE = COMPLETER_MODULE,
  }
  local store = setmetatable(self, CliStore)
  store:register_module(complete_command_wrapper(self), COMPLETER_MODULE, "command")
  store:register_module(verify_command, VERIFIER_MODULE, "command")
  return store
end

return M