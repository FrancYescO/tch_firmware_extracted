--- The UCI helper helps you communicate with uci
-- @module transformer.mapper.ucihelper
local M = {}

local uci = require("uci") --doc.ucidoc#doc.ucidoc

local next, error, type = next, error, type
local open = io.open
local match = string.match
local tonumber = tonumber

--- A representation of the UCI target on which an action needs to be performed.
-- The required fields differ depending on which action is being performed.
-- @type binding
-- @field #string config A UCI config.
-- @field #string sectionname A UCI section.
-- @field #string option A UCI option.
-- @field #string default A possible default return value for an action.
-- @field #string state If the UCI state dir needs to be loaded or not.
-- @field #string extended If the action wishes to use extended syntax or not.

--- Variable to hold the default value for the search path for config file changes.
-- We set this variable to avoid clashes with uci cli, which uses "/tmp/.uci"
-- as default.
local save_dir = "/tmp/.transformer" --#string
--- Top level entry point to uci (instantiates a uci context instance).
-- The global UCI_CONFIG can be set when running tests. If set we want to
-- use it. Otherwise it's nil and the context is created with the default conf_dir.
local cursor = uci.cursor(UCI_CONFIG, save_dir) --doc.ucidoc#cursor
--- Create a seperate cursor for reading state.
local state_cursor = uci.cursor(UCI_CONFIG, save_dir) --doc.ucidoc#cursor
state_cursor:add_delta("/var/state")

--- Variable to hold the value for the search path for config file changes for the key cursor.
local save_dir_keys = "/tmp/.transformerkeys" --#string
--- Create a separate cursor for key generation. This will prevent
-- unwanted commits when generating keys on uci. This will also
-- bypass the commitapply context, which we don't want to trigger
-- on key generation.
local keycursor = uci.cursor(UCI_CONFIG, save_dir_keys) --doc.ucidoc#cursor

--- Function that refreshes the given cursor.
-- @param #binding binding The binding representing the location of the config in uci.
--                 This binding should contain at least 1 named table entry: config.
-- @param doc.ucidoc#cursor cursor The cursor we need to refresh.
-- @return #boolean, #string Status and optional error message.
local function refresh_cursor(binding, cursor)
  -- We need to load the config file in case something
  -- changed in uci since we last used the cursor.
  return cursor:load(binding.config)
end

--- Function that commits the generated keys for the given config.
-- @param #binding binding The binding representing the location of the config in UCI.
--                 This binding should contain at least 1 named table entry: config
local function commit_keys(binding)
  local rc = keycursor:commit(binding.config)
  keycursor:unload(binding.config)
  return rc
end

M.commit_keys = commit_keys

--- Function that reverts the generated keys for the given config.
-- @param #binding binding The binding representing the location of the config in UCI.
--                 This binding should contain at least 1 named table entry: config
local function revert_keys(binding)
  -- since all changes are done purely in memory we only
  -- have to unload the cursor to throw them away
  keycursor:unload(binding.config)
end

--- Function that looks into the binding to retrieve the section type of the object (if known)
-- @param #binding binding The binding representing the local of the config in UCI
-- @param #string value The value being set if relevant for the current uci call
-- @return #string
local function get_section_type(binding, value)
  if binding.sectiontype then
    return binding.sectiontype
  end

  if not binding.option and value then
    -- Type is the value passed
    -- i.e. uci set network.wan = interface
    -- valid for both extended and "non" extended case
    return value
  end

  if binding.extended and binding.sectionname then
    -- Extract the type from an anonymous indexed path (@redirect[0] for instance)
    -- i.e. uci set config.@type[3].option = value
    -- otherwise, cannot say about type (i.e. uci set network.wan.ifname = eth4)
    local st = match(binding.sectionname, "@([^%[]+)%[%-?%d+]")
    if st then
      return st
    end
  end

  return '?' -- default value if unknown
end

M.revert_keys = revert_keys

--- Function that commits the changes made to the given config
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 1 named table entry: config
function M.commit(binding)
  refresh_cursor(binding, cursor)
  return cursor:commit(binding.config)
end

--- Function which gets a parameter from uci
-- This function will try to get a parameter from uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 2 named table entries:
--                 config, sectionname, option(optional), default(optional), state(optional), extended(optional)
--                 When option is undefined, the section type is retrieved.
--                 When extended is defined, extended syntax lookup is performed.
-- @return #string In order of return preference: The value in UCI, the default defined
--                 in the given binding or the empty string.
function M.get_from_uci(binding)
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  local cursor = (binding.state == nil or binding.state) and state_cursor or cursor --doc.ucidoc#cursor
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      if option then
        result = cursor:get(config .. "." .. section .. "." .. option)
      else
        result = cursor:get(config .. "." .. section)
      end
    else
      if option then
        result = cursor:get(config, section, option)
      else
        result = cursor:get(config, section)
      end
    end
  end
  cursor:unload(config)
  if result then
    return result
  end
  if binding.default then
    return binding.default
  end
  -- We assume the value is an empty string in this case.
  return ''
end

--- Function which gets a parameter from uci
-- This function will try to get a parameter from uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                 This binding should contain at least 1 named table entries:
--                 config, sectionname (optional), extended (optional)
-- @return #table
function M.getall_from_uci(binding)
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  local cursor = (binding.state == nil or binding.state) and state_cursor or cursor
  local result = refresh_cursor(binding, cursor)
  if result then
    if section then
      if binding.extended then
        result = cursor:get_all(config .. "." .. section)
      else
        result = cursor:get_all(config, section)
      end
    else
      result = cursor:get_all(config)
    end
  end
  cursor:unload(config)
  if result then
    return result
  end
  -- We assume the value is an empty string in this case.
  return {}
end


--- Function which sets a parameter on uci
-- This function will try to set a parameter on uci using the
-- information available in the given binding.
-- @param #binding binding The binding representing the location of the parameter in uci.
--                This binding should contain at least 2 named table entries:
--                config, sectionname, option (optional), extended (optional)
--                When option is undefined, the section type is set.
--                When extended is defined, extended syntax lookup is performed.
-- @param #string value The value that needs to be set
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.set_on_uci(binding, value, commitapply)
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  local stype = get_section_type(binding, value)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  if not value then
    error("No value given to be set on UCI", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    local extended = binding.extended
    if extended and (type(value)=='table') then
      -- extended syntax and a table value do not go well together
      -- translate to simple section name and proceed with non-extended syntax
      extended = false
      -- split in section type and index
      local sectype, idx = section:match('^@([^[]+)%[%s*(%d+)%s*%]')
      if sectype then
        -- extended syntax actually used
        -- loop over all section of the given type until we reach the given
        -- index
        idx = tonumber(idx)
        local i = 0
        local name
        cursor:foreach(config, sectype, function(s)
          if i==idx then
            name = s['.name']
            return false -- break
          end
          i = i + 1
        end)
        if name then
          extended = false
          section = name
        else
          -- the section does not exist
          return
        end
      end
    end
    if extended then
      if option then
        result = cursor:set(config .. "." .. section .. "." .. option .. "=" .. value)
      else
        result = cursor:set(config .. "." .. section                  .. "=" .. value)
      end
    else
      if option then
        result = cursor:set(config, section, option, value)
      else
        result = cursor:set(config, section,         value)
      end
    end
  end
  if result then
    -- We save here so the set is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the set won't be lost.
    result = cursor:save(config)
  end
  if result and commitapply then
    if option then
      commitapply:newset(config .. "." .. stype .. '.' .. section .. "." .. option)
    else
      commitapply:newadd(config .. "." .. stype .. '.' .. section)
    end
  end
  cursor:unload(config)
end

--- Function which adds an object on uci.
-- @param #binding binding The binding representing the object type that needs to be added
--                This binding should contain at least 2 named table entries:
--                config, sectionname
--                In this case the section name actually represents the section type.
-- @param commitapply The Commit & Apply context (optional)
-- @return #string The name of the newly created object
-- @return #nil, #string Traditional nil and error message
-- WARNING: This function will not commit!
function M.add_on_uci(binding, commitapply)
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section type could be found in the given binding", 2)
  end
  local result = refresh_cursor(binding, cursor)
  local errmsg
  if result then
    result, errmsg = cursor:add(config, section)
  end
  local save_result
  if result then
    -- We save here so the add is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the add won't be lost.
    save_result = cursor:save(config)
  end
  if result and save_result and commitapply then
    commitapply:newadd(config .. "." .. section .. "." .. result)
  end
  cursor:unload(config)
  return result, errmsg
end

--- Function to delete an object on uci
-- @param #binding binding The binding representing the instance that needs to be deleted
--                This binding should contain at least 2 named table entries:
--                config, sectionname, option (optional), extended (optional)
--                When option is undefined, the entire section is deleted.
--                When extended is defined, extended syntax lookup is performed.
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.delete_on_uci(binding, commitapply)
  local config = binding.config
  local section = binding.sectionname
  local option = binding.option
  local stype = get_section_type(binding)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      if option then
        result = cursor:delete(config .. "." .. section .. "." .. option)
      else
        result = cursor:delete(config .. "." .. section)
      end
    else
      if option then
        result = cursor:delete(config, section, option)
      else
        result = cursor:delete(config, section)
      end
    end
  end
  local save_result
  if result then
    -- We save here so the delete is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the delete won't be lost.
    save_result = cursor:save(config)
  end
  if result and save_result and commitapply then
    if option then
      commitapply:newdelete(config .. "." .. stype .. '.' .. section .. "." .. option)
    else
      commitapply:newdelete(config .. "." .. stype .. '.' .. section)
    end
  end
  cursor:unload(config)
end

--- Function to change an item index inside the uci datamodel
-- @param #binding binding The binding representing the instance that needs to be deleted
--                This binding should contain at least 2 named table entries:
--                config, sectionname, extended (optional)
--                When extended is defined, extended syntax lookup is performed.
-- @param #number index   The new index to use for the item
-- @param commitapply The Commit & Apply context (optional)
-- WARNING: This function will not commit!
function M.reorder_on_uci(binding, index, commitapply)
  local config = binding.config
  local section = binding.sectionname
  local stype = get_section_type(binding)
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No section name could be found in the given binding", 2)
  end
  if not (type(index) == "number") then
    error("Index must be a number", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if binding.extended then
      result = cursor:reorder(config .. "." .. section .. "=" .. index)
    else
      result = cursor:reorder(config, section, index)
    end
  end
  local save_result
  if result then
    -- We save here so the reorder is persisted to file, although it is not
    -- yet committed! We persist to file, so if we lose or reload our cursor for
    -- some reason, the reorder won't be lost.
    save_result = cursor:save(config)
  end
  if result and save_result and commitapply then
    commitapply:newreorder(config .. "." .. stype .. '.' .. section)
  end
  cursor:unload(config)
end

--- Function which loops over all instances of the given type
-- in the given config in uci and executes the given function.
-- @param #binding binding The binding representing the config and the type over which
--                needs to be iterated.
--                This binding should contain at least 1 named table entries:
--                config, sectionname(optional), state(optional)
--                When sectionname is nil, all sections will be iterated regardless of type.
-- @param func    The function that needs to be executed for each instance.
function M.foreach_on_uci(binding,func)
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  -- Create a separate cursor for the loop. Another ucihelper function can be
  -- passed as second argument and will (un)load the cursor.
  local cursor = uci.cursor(UCI_CONFIG, save_dir)
  if binding.state == nil or binding.state then
    cursor:add_delta("/var/state")
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    if section then
      result = cursor:foreach(config, section, func)
    else
      result = cursor:foreach(config, func)
    end
  end
  cursor:unload(config)
  return result
end

--- Function which reverts the state of uci
-- @param #binding binding The binding representing the config that needs to be reverted
--                This binding should contain at least 1 named table entry:
--                config
function M.revert(binding)
  local config = binding.config
  if not config then
    error("No config could be found in the given binding", 2)
  end
  local result = refresh_cursor(binding, cursor)
  if result then
    result = cursor:revert(config)
  end
  if result then
    result = cursor:save(config)
  end
  cursor:unload(config)
  return result
end

--- Generate a unique key
-- This function will generate a 16byte key by reading data from dev/urandom
local key = ("%02X"):rep(16)
local fd = assert(open("/dev/urandom", "r"))
function M.generate_key()
  local bytes = fd:read(16)
  return key:format(bytes:byte(1,16))
end

--- Function which stores a unique key for the given section in the
-- given config in UCI. If no key is given it generates one.
-- @param #binding binding The binding representing the config and the section for which
--                a unique key needs to be generated.
--                This binding should contain at least 2 named table entries:
--                config, sectionname
-- @param #string key The key to store in UCI. Optionally; if not provide a key will
--                    be generated.
-- NOTE: This function works on a separate cursor and needs to be followed by either
-- commit_keys or revert_keys.
function M.generate_key_on_uci(binding, key)
  local config = binding.config
  local section = binding.sectionname
  if not config then
    error("No config could be found in the given binding", 2)
  end
  if not section then
    error("No sectionname could be found in the given binding", 2)
  end
  key = key or M.generate_key()
  -- For performance reasons we do not save; all changes are kept
  -- in memory. The assumption is that several keys are generated and
  -- then commit_keys()/revert_keys() is called immediately afterwards.
  -- Those functions will make the changes persistent or throw them away.
  local result = keycursor:set(config, section, "_key", key)
  return key
end

return M
