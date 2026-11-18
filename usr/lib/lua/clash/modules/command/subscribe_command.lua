--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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
-- A module that implements the subscribe command.
--
-- @module modules.command.subscribe_command
--
local require, type, next, ipairs, tostring =
      require, type, next, ipairs, tostring

---- Functions made available from the CLI environment
local print, register, unregister, add_socket, remove_socket =
      print, register, unregister, add_socket, remove_socket

local proxy = require("helper.transformer")
local tch_uuid = require("tch.uuid")
local uds = require("tch.socket.unix")
local msg = require('transformer.msg').new()
local event_tag = msg.tags.EVENT
local bit = require("bit")
local oredflags = bit.bor(uds.SOCK_NONBLOCK, uds.SOCK_CLOEXEC)

local socketname
local subscriptions = {}

local function event_mask2type(event_mask)
  local type = "unknown"
  if event_mask == 1 then
    type = "set"
  elseif event_mask == 2 then
    type = "add"
  elseif event_mask == 4 then
    type = "delete"
  end
  return type
end

local function do_subscribe(args)
  if not args.path then
    return nil, "Missing path"
  end
  local typemask = 7 -- all events (set/add/delete)
  local optionsmask = 1
  if args.own_events then
    optionsmask = 0
  end

  local id, paths = proxy.subscribe(args.path, socketname, typemask, optionsmask)
  if not id then
    print("ERROR: %s",paths)
    return
  end
  subscriptions[#subscriptions + 1] = id
  print("Subscription id: %d", id)
  if paths and type(paths)=="table" and next(paths) then
    print("Non evented paths:")
    for _,path in ipairs(paths) do
      print("        %s", path)
    end
  end
end

local function event_cb(_, event_socket)
  local data, from = event_socket:recvfrom()
  while data do
    local tag = msg:init_decode(data)
    if tag == event_tag then
      local event = msg:decode()
      if event then
        print("EVENT: id=%s, type=%s, path=%s", event.id, event_mask2type(event.eventmask), event.path)
      end
    end
    data, from = event_socket:recvfrom()
  end
  if not data then
    if from ~= "WOULDBLOCK" then
      print("socket receive error: %s", tostring(from))
    end
  end
end

local usage_msg = [[
  Subscribe to changes on a data model path.
    -o,--own_events   Show events that were generated from the CLI.
    <path> (datamodel_path) The data model path to watch.
]]

-- Table representation of the subscribe command module
local command = {
  name = "subscribe",
  usage_msg = usage_msg,
  action = do_subscribe,
}

local M = {}

M.name = command.name

--- Function to initialize the subscribe command module.
-- This will register the subscribe command module with the CLI core.
M.init = function()
  subscriptions = {}
  socketname = tch_uuid.uuid_generate()
  local socket = uds.dgram(oredflags)
  socket:bind(socketname)
  add_socket(socketname, socket, event_cb)
  register(command)
end

--- Function to destroy the subscribe command module.
-- This will unregister the subscribe command module from the CLI core.
M.destroy = function()
  remove_socket(socketname)
  unregister(command)
  socketname = nil
  for _,subscr_id in ipairs(subscriptions) do
    -- If the unsubscribe fails, we ignore it.
    proxy.unsubscribe(subscr_id)
  end
  subscriptions = {}
end

return M
