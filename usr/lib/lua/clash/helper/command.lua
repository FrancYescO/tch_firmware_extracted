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

local require, type, pairs, tostring = require, type, pairs, tostring
local gmatch, format = string.gmatch, string.format

local M = {}

local proxy = require("helper.transformer")
local uds = require("tch.socket.unix")
local bit = require("bit")
local oredflags = bit.bor(uds.SOCK_NONBLOCK, uds.SOCK_CLOEXEC)

local session_op
local event_address

local print

local function rename_option(option, args)
  if option and option ~= "" then
    local option_without_dashes = option:match("^%-*([^%-]+.*)$")
    -- Explicit nil check needed, since an option value can be false in the args table.
    if option ~= option_without_dashes and args[option_without_dashes] ~= nil then
      args[option] = args[option_without_dashes]
      args[option_without_dashes] = nil
    end
  end
end

M.rename_args = function(usage_msg, args)
  for line in gmatch(usage_msg, "[^\r\n]+") do
    if line:match("^%s*%-") then
      -- This is an option line, we need to rename some arguments.
      local option = line:match("^%s*(%-[^%s]+)")
      -- If there is a comma, the longer option takes precedence.
      local option1, option2 = option:match("^([^,]+),?([^,]*)$")
      rename_option(option1, args)
      rename_option(option2, args)
    end
  end
  return args
end

local function close(event_loop, sk)
  event_loop:remove(sk)
  sk:close()
end

local function read(event_loop, sk)
  local data, errmsg = sk:recv()
  if data then
    -- note that `data` shall not be nil, but zero length upon orderly shutdown of peer
    if #data ~= 0 then
      print(data)
      -- With large chunks, more data may be present; report that we want to continue reading
      return true
    else
      -- Peer has nothing more to send; properly close file descriptors
      close(event_loop, sk)
    end
  elseif errmsg == "WOULDBLOCK" then
    -- No more data to read on non-blocking socket; do nothing
  else
    print(format("socket error: %s", errmsg or ""))
    close(event_loop, sk)
  end
end

local function read_cb(event_loop, sk)
  while true do
    -- Keep reading as long as data may be expected - see read() for conditions
    if not read(event_loop, sk) then
      break
    end
  end
end

local function accept_cb(event_loop, sk)
  local conn_sk = sk:accept(oredflags)
  event_loop:add(conn_sk, read_cb)
end

M.start_listen_socket = function(add_socket, print_function, sessionid)
  print = print_function
  session_op = "Command.Session.@"..sessionid.."."
  local event_socket, errmsg = uds.stream(oredflags)
  if not event_socket then
    return nil, "Unable to open a stream socket"
  end
  event_address = "clash"..sessionid
  local ok
  ok, errmsg = event_socket:bind(event_address)
  if not ok then
    return nil, "Unable to bind on address: " .. event_address
  end
  ok, errmsg = event_socket:listen()
  if not ok then
    return nil, "Unable to set socket in listening state"
  end
  add_socket(event_address, event_socket, accept_cb)
end

M.launch_command = function(cmd_name, args)
  if not session_op or not event_address or not cmd_name then
    return nil, "Invalid launch state"
  end
  local command_op = session_op .. cmd_name .. "."
  local ok, errmsg = proxy.getPN(command_op, true)
  if ok then
    args["command_socket"] = event_address
    local set_arguments = {}
    for argname, argvalue in pairs(args) do
      if type(argvalue) == "boolean" then
        argvalue = argvalue and "1" or "0"
      end
      set_arguments[command_op..argname] = tostring(argvalue)
    end
    ok, errmsg = proxy.set(set_arguments)
    if not ok then
      return nil, "Unable to set command arguments"
    else
      ok, errmsg = proxy.set(command_op.."launch_command", "1")
      if not ok then
        return nil, "Unable to launch command"
      end
    end
  else
    return nil, "Command not found in datamodel"
  end
  return true
end

--this function check if the data model path of the command is available
M.check_clash_dm_availability = function(cmd_name)
  if not session_op or not cmd_name then
    return nil, "Unable to verify clash datamodel state"
  end
  local command_op = session_op .. cmd_name .. "."
  local result, errmsg = proxy.getPN(command_op, true)
  if result then
    return true
  end
end

M.rename_args_and_launch_command = function(cmd_name, usage_msg, args)
  local args = M.rename_args(usage_msg,args)
  return M.launch_command(cmd_name,args)
end

return M
