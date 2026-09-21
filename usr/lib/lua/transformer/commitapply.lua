--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- Commit & Apply module.
--
-- Idea is that a set of rules and corresponding actions is loaded.
-- All configuration changes are reported to the commit & apply context
-- who will check whether any rules match that change. If so, the
-- corresponding action is queued for execution.
-- When commit & apply is told to apply all changes it will execute
-- all queued actions asynchronously in the background.
--
-- A rule file must have a .ca extension. Each line must contain a
-- rule and an action, separated by whitespace.
-- A rule is any valid string pattern for use by Lua's string.match()
-- function. It cannot contain any whitespace.
-- An action is any valid command that can be executed. Whitespace is
-- allowed, e.g. to separate command line arguments from the application.

local lfs = require("lfs")
local type, setmetatable, error, pairs, ipairs =
      type, setmetatable, error, pairs, ipairs
local find, match = string.find, string.match
local open = io.open
local logger = require("transformer.logger")
local execute = require("lasync").execute

local CommitApply = {}
CommitApply.__index = CommitApply

---
-- Inform the commit & apply context about a new 'set'
-- operation on the given path.
-- What exactly 'path' is, depends on who is calling newset().
-- For example it can be the filename of something on the filesystem
-- or it can be a UCI config and section name.
-- @param path On what the 'set' operation was performed.
function CommitApply:newset(path)
--  logger:debug("CommitApply:new*() on %s", path)
  local queued_actions
  if self.transaction then
    queued_actions = self.transaction_actions
  else
    queued_actions = self.queued_actions
  end
  for rule, action in pairs(self.rules) do
    if match(path, rule) then
--      logger:debug("rule match with %s", rule)
      if type(action) == "table" then
        for a in pairs(action) do
          queued_actions[a] = true
        end
      else
        queued_actions[action] = true
      end
    end
  end
end

---
-- Inform the commit & apply context about a new 'add'
-- operation on the given path.
-- What exactly 'path' is, depends on who is calling newadd().
-- For example it can be the filename of something on the filesystem
-- or it can be a UCI config and section name.
-- @param path On what the 'add' operation was performed.
CommitApply.newadd = CommitApply.newset

---
-- Inform the commit & apply context about a new 'delete'
-- operation on the given path.
-- What exactly 'path' is, depends on who is calling newdelete().
-- For example it can be the filename of something on the filesystem
-- or it can be a UCI config and section name.
-- @param path On what the 'delete' operation was performed.
CommitApply.newdelete = CommitApply.newset

---
-- Inform the commit & apply context about a new 'reorder'
-- operation on the given path.
-- What exactly 'path' is, depends on who is calling newreorder().
-- For example it can be the filename of something on the filesystem
-- or it can be a UCI config and section name.
-- @param path On what the 'reorder' operation was performed.
CommitApply.newreorder = CommitApply.newset

--- Clear the queued transaction actions and unset
-- the transactions state.
local function clearTransaction(self)
  self.transaction_actions = {}
  self.transaction = false
end

---
-- Execute all the actions that have been queued.
-- This happens asynchronously in the background.
function CommitApply:apply()
  logger:debug("CommitApply: applying queued actions")
  execute(self.queued_actions)
  self.queued_actions = {}
  clearTransaction(self)
end

--- Signal that a transaction is about to start.
-- If there are still actions queued from a previous transaction,
-- these are first discarded. Sets the transaction state to true.
function CommitApply:startTransaction()
  logger:debug("CommitApply: starting transaction")
  clearTransaction(self)
  self.transaction = true
end

--- Signal that a transaction completed successfully.
-- Copies the transaction actions to the queued actions and
-- unsets the transaction state.
function CommitApply:commitTransaction()
  logger:debug("CommitApply: committing transaction")
  for k,_ in pairs(self.transaction_actions) do
    self.queued_actions[k] = true
  end
  clearTransaction(self)
end

--- Signal that a transaction failed.
-- Clears the transactions actions and unsets the transaction state.
function CommitApply:revertTransaction()
  logger:debug("CommitApply: reverting transaction")
  clearTransaction(self)
end

local function load_rule_file(file, rules)
  local f, err = open(file)
  if not f then
    error(err)
  end
  local i = 0
  for line in f:lines() do
    i = i + 1
    -- Although a rule file isn't a Lua file it seems people
    -- think they can add Lua comment lines. Such lines won't
    -- do any harm but let's ignore them completely.
    if not match(line, "^%s*%-%-") then
      local rule, action = match(line, "^([^%s]+)%s+(.+)")
      if not rule or not action then
        -- don't trace on lines only containing whitespace
        if match(line, "^%s*$") == nil then
          logger:error("%s:%d is invalid, ignored", file, i)
        end
      else
        local existing_action = rules[rule]
        if existing_action then
          if type(existing_action) == "table" then
            existing_action[action] = true
          elseif existing_action ~= action then
            rules[rule] = { [existing_action] = true, [action] = true }
          end
        else
          rules[rule] = action
        end
      end
    end
  end
  logger:info("%d rule(s) loaded from %s", i, file)
  f:close()
end

local M = {
  ---
  -- Create a new commit & apply context and load
  -- the rules present in the given location.
  -- @param commitpath Location where to load commit & apply rules from.
  --                   All files with .ca extension will be loaded.
  --                   Invalid lines in a file are simply ignored.
  -- @return A context or throws an error otherwise.
  new = function(commitpath)
    -- load the rules found in 'commitpath'
    local rules = {}
    for file in lfs.dir(commitpath) do
      if find(file, "%.ca$") then
        load_rule_file(commitpath .. "/" .. file, rules)
      end
    end
    return setmetatable({ rules = rules, queued_actions = {}, transaction_actions = {}, transaction = false }, CommitApply)
  end
}

return M
