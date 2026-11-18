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
-- A module that contains all CLI IO handling logic.
--
-- @module core.io_handler

local setmetatable, require, type, pairs, unpack, pcall, ipairs =
      setmetatable, require, type, pairs, unpack, pcall, ipairs
local remove, insert = table.remove, table.insert
local open = io.open
local gmatch, gsub, format, match, upper = string.gmatch, string.gsub, string.format, string.match, string.upper
local sort = table.sort

local logger = require("transformer.logger") -- TODO move this out of Transformer

local CliIO = {} -- metatable to hold CLI IO function definitions
CliIO.__index = CliIO

-- The different states of the CLI. These states are extended with a state for every type that is loaded.
local EMPTY_STATE = "empty" -- Empty line, nothing has been typed yet.
local COMMAND_STATE = "command" -- The user is entering a command.
local OPTION_STATE = "option" -- The user is entering an option.
local COMPLETE_STATE = "complete" -- Everything that the user entered is fully completed. (Not able to auto-complete anything)
local UNKNOWN_TYPE_STATE = "unknown_type" -- The user entering a string after the command or the option.
local UNKNOWN_STATE = "unknown" -- We are in an unknown state (typing unknown command, ...)

local cli_states = {
  [EMPTY_STATE] = EMPTY_STATE,
  [COMMAND_STATE] = COMMAND_STATE,
  [OPTION_STATE] = OPTION_STATE,
  [COMPLETE_STATE] = COMPLETE_STATE,
  [UNKNOWN_TYPE_STATE] = UNKNOWN_TYPE_STATE,
  [UNKNOWN_STATE] = UNKNOWN_STATE,
}

local function fail(self, errmsg, ...)
  self.log:error(errmsg, ...)
  return nil, errmsg
end

--- Function to tokenize the line into words
-- @param line #string The user input string
-- @return #table The array of words found in the given input string
local function tokenize(line)
  local result = {}
  local start_pattern  = [=[^(['"])]=]
  local end_pattern = [=[(['"])$]=]
  local buf, quoted
  for word in line:gmatch("%S+") do
    local squoted = word:match(start_pattern)
    local equoted = word:match(end_pattern)
    local escaped = word:match([=[(\*)['"]$]=])
    if squoted and not quoted and not equoted then
      buf, quoted = word, squoted
    elseif buf and equoted == quoted and #escaped % 2 == 0 then
      word, buf, quoted = buf .. ' ' .. word, nil, nil
    elseif buf then
      buf = buf .. ' ' .. word
    end
    if not buf then
      result[#result + 1] = word:gsub(start_pattern,""):gsub(end_pattern,"")
    end
  end
  return result
end

local function getCommands(self)
  return self.store:retrieve_modules(self.store.COMMAND_MODULE)
end

--- Parse the given line and try to determine the CLI state.
-- @param self #table A table representation of the CLI core.
-- @param words #table The current line of input tokenized.
-- @return #string, #string The current state of the CLI and the part of the input line that corresponds with this state.
local function processLine(self, words)
  if #words == 0 then
    return EMPTY_STATE, ""
  end
  local cli_state = UNKNOWN_STATE
  local lastword = words[#words]
  local command = remove(words, 1)
  if command then
    self.log:debug("Something on the line. command=%s, lastword=%s", command, lastword)
    -- There is something on the line, see if we know it.
    local commands = getCommands(self)
    if commands and commands[command] then
      -- First word is a known command
      if #words == 0 then
        -- There is no more input to process, move to the complete state.
        cli_state = COMPLETE_STATE
      elseif match(lastword, "^[%-]+") then
        -- The last word is an option (or the start of one).
        cli_state = OPTION_STATE
      else
        -- First word is a command, check the expected pattern
        local cmd = commands[command]
        self.lapp.callback = function(parm,theArg,res)
          if cmd.options[parm] then
            cli_state = cli_states[cmd.options[parm].type] or UNKNOWN_TYPE_STATE
          end
        end
        local result, err = pcall(self.lapp.process_options_string, cmd.usage_msg, words)
        if not result then
          self.log:error(err)
        end
      end
    else
      -- Something is there, but the first word is unknown to us
      cli_state = UNKNOWN_STATE
      lastword = command
    end
    insert(words, 1, command)
  end
  return cli_state, lastword
end

local indent = "  "

--- This function is inspecting the CLI state and shows relevant help info depending on the state!
-- @param self #table A table representation of the CLI core.
-- @param line #string
local function showhelp(self, line)
  line = line or ""
  local words = tokenize(line)
  -- Derive the state of the cli command
  local cli_state, lastword = processLine(self,words)
  self.log:debug("Entered showhelp with state %s and lastword %s", cli_state, lastword)
  if lastword == "help" and #words > 1 then
    local command = words[1]
    local commands = getCommands(self)
    if commands and commands[command] then
      local module = commands[command]
      local helpinfo = "Usage: " .. module.name
      if module.options then
        local namedoption = false
        local operand_string = ""
        for helpline in commands[command].usage_msg:gmatch('([^\n]*)\n') do
          if helpline:match("-(.*)") then
            namedoption = true
          end
          if helpline:match("<") then
            operand_string = operand_string .. " " .. helpline:match("(<[^%s]*>)")
          end
        end
        if namedoption then
          helpinfo = helpinfo .. " [options]"
        end
        helpinfo = helpinfo .. operand_string
      end
      self:println(helpinfo)
      -- Print the alias information (if any)
      if type(commands[command].alias) == "string" then
        helpinfo = "Known aliases: " .. commands[command].alias
        self:println(helpinfo)
      end
      self:println("")
      self:println( commands[command].usage_msg)
      return
    end
  end
  if cli_state == EMPTY_STATE or cli_state == UNKNOWN_STATE then
    self:println("AVAILABLE COMMANDS:")
    self:println("===================")
    local to_print = {}
    local commands = getCommands(self)
    for name, module in pairs(commands) do
      if name == module.name then
        local helpinfo = indent .. name
        -- Print the alias information (if any)
        if type(module.alias) == "string" then
          helpinfo = helpinfo .. indent .. "(" .. module.alias .. ")"
        end
        to_print[#to_print + 1] = helpinfo
      end
    end
    sort(to_print)
    for _, helpinfo in pairs(to_print) do
      self:println(helpinfo)
    end

    -- Hardcoded since these commands will always be there (core commands).
    self:println(indent .. "reload")
    self:println(indent .. "help")
    self:println(indent .. "exit")
    return
  end
end

CliIO.showhelp = showhelp

--- Auto Completion callback function
-- @param self #table A table representation of the CLI core.
-- @param line #string The current line of input
local function complete(self, line)
  -- Derive the state of the cli command
  local words = tokenize(line)
  local cli_state, lastword = processLine(self,words)
  self.log:debug("Retrieved state %s", cli_state)
  if cli_state == UNKNOWN_STATE or cli_state == EMPTY_STATE then
    -- We are in an unknown or empty state, see if we can complete a command
    cli_state = COMMAND_STATE
  end
  local completers = self.store:retrieve_modules(self.store.COMPLETER_MODULE)
  -- Check if we have a completer for the current state
  if completers[cli_state] then
    local completer = completers[cli_state]
    -- Call the action function corresponding to the completer of the current state
    local completions = completer(lastword, line)
    for _, suggestion in ipairs(completions) do
      self.log:debug("Adding completion %s", suggestion)
      self.reader:addcompletion(gsub(line, lastword.."$", suggestion))
    end
  end
end

--- Process the user input and call actions
-- @param line The current line of input
function CliIO:process(line)
  -- Tokenize the current line
  local words = tokenize(line)
  -- First handle the help case. If the line ends with the word help, divert to showhelp.
  if words[#words] and words[#words] == "help" then
    showhelp(self, line)
    return
  end
  local commands = getCommands(self)
  -- Check if the first word is a known command
  if commands and #words > 0 and commands[words[1]] then
    local cmd = remove(words, 1)

    -- Call the action function with arguments typed by user
    -- Process the line and create an argument table. This will call the verifier for each
    -- type. If verification fails, the args table will not contain an entry for that parameter.
    local ok, args = pcall(self.lapp.process_options_string, commands[cmd].usage_msg, words)
    local rv, errmsg
    if ok then
      ok, rv, errmsg = pcall(commands[cmd].action, args)
    end
    if not ok or (not rv and errmsg) then
      if errmsg then
        self:println(errmsg)
      end
      showhelp(self, line.." help")
    end
  else
    if (line == "") then
      -- If the line is empty, do nothing
    else
      -- If the typed command is invalid present the user message
      self:println("invalid command: [%s]", tostring(line))
      showhelp(self, line)
    end
  end
end

-- Passthrough function to linenoise
function CliIO:readLine()
  local line = self.reader:getline()
  if line then
    -- This will add the typed line to the history buffer maintained in the linenoise library
    self.reader:addhistory(line)
  end
  return line
end

function CliIO:println(...)
  local data = format(...)
  self.reader:println(data.."\n")
end

function CliIO:println_raw(...)
  local data = ...
  self.reader:println(data)
end

function CliIO:destroy()
  if self.historyfile then
    self.reader:savehistory(self.historyfile)
  end
  if self.reader then
    self.reader:deinit()
    self.reader = nil
  end
end

function CliIO:setStore(store)
  self.store = store
end

function CliIO:registerState(state)
  cli_states[state] = state
end

function CliIO:clearScreen()
  self.reader:clearscreen()
end

function CliIO:loadBanner(banner_location)
  local file, msg = open(banner_location, "r")
  if file then
    for line in file:lines() do
      self:println(line)
    end
    self:println("====================================================================================")
    file:close()
  end
end

function CliIO:loadHistory(historyfile)
  self.historyfile = historyfile
  self.reader:loadhistory(historyfile)
end

function CliIO:loadCompleter()
  self.reader:setcompletion(function(line)
    complete(self, line)
  end)
end

local function init_linenoise(self)
  -- Initialize the linenoise library
  local linenoise = require("linenoise")
  if not linenoise then
    -- Exit the CLI, fatal error
    self.log:critical("Unable to load linenoise library")
    return nil, "Unable to load linenoise library"
  end
  self.reader = linenoise.reader(self.prompt)
  return true
end

local M = {}
--- Initializes the core module and linenoise. Display the technicolor banner screen
M.init = function(log_level, prompt)
  package.loaded["pl.lapp"] = nil
  if prompt ~= "" then
    prompt = prompt .. ">"
  end
  local self = {
    reader = nil,  -- Linenoise reader
    log = logger.new("CLI", log_level), -- TODO move this out of io_handler
    sockets = {}, -- Event sockets,
    lapp = require("pl.lapp"),
    prompt = prompt,
  }
  self.lapp.show_usage_error = "throw"

  local ok, errmsg = init_linenoise(self)
  if not ok then
    return nil, errmsg
  end

  return setmetatable(self, CliIO)
end

return M
