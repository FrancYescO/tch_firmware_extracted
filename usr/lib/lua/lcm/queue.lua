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

local uloop = require("uloop")
local operations = require("lcm.operations")
local db = require("lcm.db")
local logger = require("tch.logger").new("queue")
local ubus = require("lcm.ubus")
local uds = require("tch.socket.unix")
local posix = require("tch.posix")
local concat, remove = table.concat, table.remove
local exit = os.exit
local ipairs = ipairs

local s_errorcodes = require("lcm.errorcodes")
local s_socketname = "lcm.queue"
local s_queue = {}
local s_operation_in_progress = false
local s_sockets = {}

local function fork_and_run(item)
  local pid = posix.fork()
  if pid ~= 0 then
    -- parent doesn't need to do anything
    -- TODO: for robustness we should probably keep track of
    -- the child process so we can kill it if it doesn't end
    -- within a reasonable time (or it dies immediately without
    -- connecting to the master). Otherwise our queue gets stuck.
    return
  end
  -- child process
  logger:notice("child process")
  -- TODO: disabled for now; seems to cause instabilities
--  ubus.reinit()  -- child should use its own ubus connection to be able to invoke methods in the master
  local sk = uds.stream()  -- TODO: SOCK_NONBLOCK?
  assert(sk:connect(s_socketname))  -- TODO: if assert fires the child dies immediately and we won't know about it
  local fd = sk:fd()
  posix.dup2(fd, 0) -- stdin
  posix.dup2(fd, 1) -- stdout
  posix.dup2(fd, 2) -- stderr
  local rc, errormsg = item.operation(item.operationID, item.pkg)
  if not rc then
    -- communicate error message to master process
    sk:send(errormsg)
  end
  sk:close()
  logger:notice("child process exiting")
  exit()
end

local function process_queue()
  -- is there currently an operation in progress?
  if s_operation_in_progress then
    logger:debug("process_queue: operation in progress")
    return
  end
  -- check the queue
  local item = s_queue[1]
  if not item then
    logger:debug("process_queue: nothing in queue")
    -- nothing in the queue
    return
  end
  -- trigger operation on package
  if item.data then
    local operationID = item.operationID
    -- process result of finished step of operation
    local next_state = item.operation(operationID, item.pkg, item.data)
    item.data = nil
    if not next_state then
      -- done with this package operation; remove from queue
      logger:debug("operation complete on %s:%s (cur_state:%s)", item.pkg.execenv, item.pkg.URL, item.pkg.state)
      remove(s_queue, 1)
      -- if this item was the last item using that operation ID send out an event
      -- to signal that operation has completed
      if operationID ~= (s_queue[1] and s_queue[1].operationID) then
        ubus.send_event("operation.complete", { operationID = operationID })
      end
    else
      item.pkg:set_state(next_state, operationID)
    end
    -- start next step of the operation
    -- TODO: check first if pkg is still relevant; a previous queue item
    -- might have been to remove it
    return process_queue()
  end
  -- start next step of the operation
  s_operation_in_progress = true
  item.pkg:clear_error()
  item.data = nil
  return fork_and_run(item)
end

local function sk_read_cb(fd)
  local descriptors = s_sockets[fd]
  local sk = descriptors.sk
  while true do
    local new_data, errmsg = sk:recv()
    if new_data then
      if #new_data ~= 0 then
        -- store received data until done
        local data = descriptors.data
        data[#data + 1] = new_data
        logger:debug("received data %s", new_data)
      else
        logger:debug("peer of %d closed connection", fd)
        -- close sockets
        descriptors.uloop_sk:delete()
        sk:close()
        s_sockets[fd] = nil
        -- store received data in package and call next operation
        local item = s_queue[1]
        item.data = concat(descriptors.data)
        s_operation_in_progress = false
        process_queue()
        break
      end
    elseif errmsg == "WOULDBLOCK" then
      break
    else
      logger:error("recv() failed on %d: %s", fd, errmsg)
      descriptors.uloop_sk:delete()
      sk:close()
      s_sockets[fd] = nil
      break
    end
  end
end

local function sk_accept_cb(fd)
  local descriptors = s_sockets[fd]
  local conn_sk = assert(descriptors.sk:accept())
  local conn_fd = conn_sk:fd()
  logger:debug("accepted from %d: %d", fd, conn_fd)
  local uloop_sk = assert(uloop.fd_add(conn_fd, sk_read_cb, uloop.ULOOP_READ + uloop.ULOOP_EDGE_TRIGGER))
  s_sockets[conn_fd] = { sk = conn_sk, uloop_sk = uloop_sk, data = {} }
end

do
  local sk = uds.stream(uds.SOCK_NONBLOCK + uds.SOCK_CLOEXEC)
  assert(sk:bind(s_socketname))
  assert(sk:listen())
  local fd = sk:fd()
  local uloop_sk = assert(uloop.fd_add(fd, sk_accept_cb, uloop.ULOOP_READ + uloop.ULOOP_EDGE_TRIGGER))
  s_sockets[fd] = { sk = sk, uloop_sk = uloop_sk }
end

---------------------------------------------------------------------
local M = {}

function M.add(pkgs, operation_name)
  local operation = operations[operation_name]
  if not operation then
    logger:error("unsupported operation %s", operation_name)
    return nil, s_errorcodes.INTERNAL_ERROR, "unsupported operation"
  end
  local operationID = db.generateID()
  for _, pkg in ipairs(pkgs) do
    logger:notice("adding %s:%s (current state: %s, operation: %s)",
                  pkg.execenv, pkg.URL or pkg.name or "(no identification)", pkg.state, operation_name)
    -- put in queue
    s_queue[#s_queue + 1] = { pkg = pkg, operationID = operationID, operation = operation, data = "" }
  end
  -- process next item from queue if possible
  process_queue()
  return operationID
end

return M
