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
-- A module that contains all CLI event loop logic.
--
-- @module core.event_loop

local require, setmetatable, pairs = require, setmetatable, pairs

local tch_evloop = require("tch.socket.evloop")
local tch_timerfd = require("tch.timerfd")
local format = string.format
local concat = table.concat

--- @type CliEventLoop
local CliEventLoop = {} -- metatable to hold event loop function definitions
CliEventLoop.__index = CliEventLoop

--- Function to create the main read callback function.
-- This read callback function should be hooked to the standard input file descriptor.
-- @tparam CliEventLoop cli_event_loop A table representation of the CLI event loop.
-- @treturn function A read callback function that can be called on user input.
local function create_input_read_cb(cli_event_loop)
  local io_handler = cli_event_loop.io_handler
  return function (evloop, input_socket)
    -- As long as a user hasn't entered, line will be nil.
    -- readLine will not block, it will return immediately if nothing is entered.
    local line = io_handler:readLine()
    -- TODO wrap the calls to io_handler in pcalls
    -- TODO model internal commands as real commands instead of catching them here.
    if line then
      if line == "exit" then
        cli_event_loop.state = "exit"
        evloop:close()
      elseif line == "reload" then
        cli_event_loop.state = "reload"
        evloop:close()
      elseif line == "help" then
        io_handler.reader:reset()
        io_handler:showhelp()
      elseif line then
        -- Not one of the 3 core commands, pass to the io_handler for further handling
        io_handler.reader:reset() -- TODO show processing progress, not prompt while processing.
        io_handler:process(line)
      end
    end
  end
end

--- Function to register a new event socket to the event loop.
-- @string socketname A name to represent the socket internally.
-- @tparam sk socket The new socket to add to the event loop.
-- @tparam function read_cb The callback function that will be called when the socket has data ready to be read.
-- @tparam function write_cb Callback function that will be called when the socket is ready to send more data.
function CliEventLoop:registerEventSocket(socketname, socket, read_cb, write_cb)
  self.sockets[socketname] = socket
  self.evloop:add(socket, read_cb, write_cb)
end

--- Function to unregister an existing event socket from the event loop.
-- This will remove the socket from the underlying evloop and close the socket.
-- @string socketname The name used to represent the socket internally.
function CliEventLoop:unregisterEventSocket(socketname)
  if self.state == "reload" or self.state == "exit" then
    -- CliEventLoop:destroy() will already close the socket
    return
  end
  local socket = self.sockets[socketname]
  if socket then
    self.sockets[socketname] = nil
    self.evloop:remove(socket)
    socket:close()
  end
end

--- Function to add the standard input file descriptor to the event loop.
-- The callback of the input file descriptor contains the actual processing of the CLI input.
function CliEventLoop:addInputSocket()
  self.evloop:add(1, create_input_read_cb(self))
end

local function create_timer_cb(cli_event_loop)
  local max_session_time = 300 -- TODO make this configurable per user
  local session_time = 0
  return function (evloop, input_socket)
    local missed = tch_timerfd.read(input_socket)
    session_time = session_time + missed
    if not cli_event_loop.session:check_active() or session_time >= max_session_time then
      cli_event_loop.state = "exit"
      evloop:close()
    end
  end
end

function CliEventLoop:addTimerSocket()
  local tfd = tch_timerfd.create()
  self.tfd = tfd
  local real_fd = tch_timerfd.fd(tfd)
  self.evloop:add(real_fd, create_timer_cb(self))
  tch_timerfd.settime(tfd, 1)
end

--- Function to run the event loop.
-- This will start the underlying evloop and block until an event occurs.
-- @treturn boolean True if the event loop finished in the 'reload' state, false otherwise.
function CliEventLoop:run()
  if #self.args > 0 then
    local line = concat(self.args, " ")
    self.io_handler:process(line)
  end
  self.state = "continue"
  local ok, errmsg
  while self.state == "continue" do
    -- evloop will block until an event occurs.
    ok, errmsg = self.evloop:run()
    if not ok then
      self.io_handler:println("Evloop error: %s", errmsg)
      self.state = "error"
    end
  end
  return self.state == "reload"
end

--- Function to destroy the event loop.
-- If the event loop was not quit by the 'reload' or 'exit' command, make sure the
-- underlying evloop is closed.
function CliEventLoop:destroy()
  for socketname, socket in pairs(self.sockets) do
    socket:close()
    self.sockets[socketname] = nil
  end
  if self.state ~= "reload" and self.state ~= "exit" then
    self.evloop:close()
  end
  if self.tfd then
    tch_timerfd.close(tch_timerfd.fd(self.tfd))
    self.tfd = nil
  end
  self.state = nil
end

---
-- @section end
local M = {}

--- Initialize a new CLI event loop
-- @tparam table io_handler The input/output handler of the CLI.
-- @treturn CliEventLoop A new CLI event loop.
M.init = function(io_handler, cli_session, args)
  local evloop = tch_evloop.evloop()
  if not evloop then
    return nil, "failed to create an Event loop"
  end
  local self = {
    logger = io_handler.log,
    evloop = evloop,
    sockets = {},
    state = "initialized",
    io_handler = io_handler,
    session = cli_session,
    args = args,
  }
  return setmetatable(self, CliEventLoop)
end

return M