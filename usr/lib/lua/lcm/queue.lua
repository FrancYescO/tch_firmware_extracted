--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 -          Technicolor Delivery Technologies, SAS **
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

local require = require
local setmetatable = setmetatable

local db = require("lcm.db")
local logger = require("tch.logger").new("queue")
local ubus = require("lcm.ubus")
local json = require ("dkjson")
local remove = table.remove
local sort = table.sort
local ipairs = ipairs

local execute = require 'lcm.execute'

--$ require "lcm.ee_action"


local s_errorcodes = require("lcm.errorcodes")

local ActionQueue = {}
ActionQueue.__index = ActionQueue

local function newActionQueue()
  return setmetatable({
    items = {}
  }, ActionQueue)
end

function ActionQueue:loadInitialActions(initial_actions)
  local actions = {}
  for _, action in ipairs(initial_actions) do
    actions[#actions+1] = action
  end
  sort(actions, function(lhs, rhs) return lhs.sequence<rhs.sequence end)
  self.items = actions
end

local function queue_last_seqnr(queue)
  local seq = queue._last_seqnr
  if not seq or #queue.items == 0 then
    seq = 0
  end
  return seq
end

local function queue_next_sequence(queue)
  local seq = queue_last_seqnr(queue) + 1
  queue._last_seqnr = seq
  return seq
end

function ActionQueue:head()
  return self.items[1]
end

function ActionQueue:drop_head()
  local action = remove(self.items, 1)
  if action then
    action.package:remove_pending_action(action.sequence)
  end
end

function ActionQueue:operation_complete(operation_ID)
  -- the operation identified by operation_ID is complete if the next action (if any)
  -- uses a different operationID
  local next = self:head()
  if next then
    return operation_ID~=next.operation_ID
  end
  return true
end

local function log_action_creation(pkg, desired_end_state)
  logger:notice("adding %s:%s (current state: %s, operation: %s)",
     pkg.execenv,
     pkg.URL or pkg.name or "(no identification)",
     pkg.state,
     desired_end_state)
end

local function is_valid_action(pkg, desired_end_state)
  return pkg:can_have_end_state(desired_end_state)
end

local function create_action(pkg, desired_end_state, operation_ID)
  log_action_creation(pkg, desired_end_state)
  if is_valid_action(pkg, desired_end_state) then
    return {
      package = pkg,
      operation_ID = operation_ID,
      desired_end_state = desired_end_state,
    }
  end
end

local function unsupported_action(desired_end_state)
  logger:error("unsupported operation %s", desired_end_state)
  return nil, s_errorcodes.INTERNAL_ERROR, "unsupported operation"
end

local function generate_actions(pkgs, desired_end_state, operation_ID)
  local actions = {}
  for _, pkg in ipairs(pkgs) do
    local action = create_action(pkg, desired_end_state, operation_ID)
    if not action then
      return unsupported_action(desired_end_state)
    end
    actions[#actions+1] = action
  end
  return actions
end


local function update_action_package(action)
  local pkg = action.package
  pkg:clear_error()
  pkg:add_pending_action(action.sequence, action.operation_ID, action.desired_end_state)
end

local function append_action_to_queue(queue, action)
  local items = queue.items
  items[#items+1] = action
end

local function add_actions_to_queue(queue, actions)
  for _, action in ipairs(actions) do
    action.sequence = queue_next_sequence(queue)
    append_action_to_queue(queue, action)
    update_action_package(action)
  end
end

function ActionQueue:add(pkgs, desired_end_state, operation_ID)
  local actions, errcode, errmsg = generate_actions(pkgs, desired_end_state, operation_ID)
  if not actions then
    return nil, errcode, errmsg
  end
  add_actions_to_queue(self, actions)
  return true
end

local ActionProcessor = {}
ActionProcessor.__index = ActionProcessor

local function newActionProcessor(queue)
  return setmetatable({
    queue = queue
  }, ActionProcessor)
end

function ActionProcessor:trigger_processing()
  self:process()
end

local function log_external_operation_result(result)
  if result.data then
    logger:debug("next action data: %s", result.data)
  end
end

local function external_operation_done(result, processor)
  local queue = processor.queue
  log_external_operation_result(result)
  local next_action = queue:head()
  next_action.data = result.data or result.error
  processor.external_operation = nil
  processor:trigger_processing()
end

local function process_step(self)
  local queue = self.queue
  -- is there currently an operation in progress?
  if self.external_operation then
    logger:debug("process_queue: operation in progress")
    return
  end
  -- check the queue
  local next_action = queue:head()
  if not next_action then
    logger:debug("process_queue: nothing in queue")
    return
  end
  local package = next_action.package
  if package.state == next_action.desired_end_state or package.errormsg then
    -- Package has reached desired state or an error state; remove from queue
    logger:debug("operation %s on %s:%s (cur_state:%s)",
                 package.errormsg and "failed" or "complete",
                 package.execenv, package.URL,
                 package.state
    )
    queue:drop_head()
    if queue:operation_complete(next_action.operation_ID) then
      -- This just signals that we're done with the request, it in no way guarantees anything succeeded.
      ubus.send_event("operation.complete", { operationID = next_action.operation_ID })
    end
  elseif package:is_in_transient_state() and next_action.data then
    -- We have finished an external step and are ready to proceed. Process the returned
    -- data and determine the next state based on it.
    package:advance_state(next_action.operation_ID, next_action.desired_end_state, next_action.data)
    next_action.data = nil
  elseif package:is_in_transient_state() then
    next_action.data = nil
    local exop = execute.ExternalOperation("/usr/sbin/ee_action.lua")
    self.external_operation = exop
    exop:timeout(30)
    exop:onCompletion(external_operation_done, self)
    local encoded_package = json.encode(package) -- TODO: if encode fails we need to know about it.
    exop:invoke{encoded_package}
    return
  else
    package:advance_state(next_action.operation_ID, next_action.desired_end_state)
  end
  return true
end

function ActionProcessor:process()
  while process_step(self) do
  end
end

local ActionHandler = {}
ActionHandler.__index = ActionHandler

function ActionHandler:add(pkgs, desired_end_state)
  local operation_ID = db.generateID()
  local queued, errcode, errmsg = self.queue:add(pkgs, desired_end_state, operation_ID)
  if not queued then
    return nil, errcode, errmsg
  end
  self.processor:trigger_processing()
  return operation_ID
end

function ActionHandler:loadInitialActions(actions)
  self.queue:loadInitialActions(actions)
  self.processor:trigger_processing()
end

local function newActionHandler(queue, processor)
  return setmetatable({
    queue = queue,
    processor = processor,
  }, ActionHandler)
end

local M = {}

function M.ActionQueue()
  return newActionQueue()
end

function M.ActionProcessor(queue)
  return newActionProcessor(queue)
end

function M.init(queue, processor)
  queue = queue or newActionQueue()
  processor = processor or newActionProcessor(queue)
  return newActionHandler(queue, processor)
end

return M
