#!/usr/bin/env lua
--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, ipairs, unpack, tonumber, pcall = require, ipairs, unpack, tonumber, pcall

local transformer  -- our instance of Transformer

local uloop = require("uloop")
uloop.init()

local logger = require("transformer.logger")
local uds = require("tch.socket.unix")
local max_size = uds.MAX_DGRAM_SIZE
local bit = require("bit")
local oredflags = bit.bor(uds.SOCK_NONBLOCK, uds.SOCK_CLOEXEC)
local sk

-- enclose option parsing code in separate block so the
-- code can be GC'd after execution
do
  sk = uds.dgram(oredflags)
  sk:bind("transformer")
  -- read in the uci config and add it to defconfig
  local function do_config(defconfig)
    local config = defconfig or {}

    local uci = require 'uci'
    -- The global UCI_CONFIG can be set when running tests. If set we want to
    -- use it. Otherwise it's nil and the context is created with the default conf_dir.
    local cursor = uci.cursor(UCI_CONFIG)
    local uci_config = cursor:get_all("transformer.@main[0]")
    if uci_config then
      if uci_config.mappath then
        config.mappath = uci_config.mappath
      end
      if uci_config.commitpath then
        config.commitpath = uci_config.commitpath
      end
      if uci_config.dbdir then
        config.persistency_location = uci_config.dbdir
      end
      if uci_config.dbname then
        config.persistency_name = uci_config.dbname
      end
      if uci_config.log_level then
        config.log_level = tonumber(uci_config.log_level)
      end
      if uci_config.log_stderr then
        config.log_stderr = (tonumber(uci_config.log_stderr) == 1)
      end
      if uci_config.ignore_patterns then
        config.ignore_patterns = uci_config.ignore_patterns
      end
      if uci_config.vendor_patterns then
        config.vendor_patterns = uci_config.vendor_patterns
      end
      if uci_config.unhide_patterns then
        config.unhide_patterns = uci_config.unhide_patterns
      end
    end
    return config
  end

  local config = {
    mappath = '/usr/share/transformer/mappings',
    commitpath = '/usr/share/transformer/commitapply',
    persistency_location = '/etc',
    persistency_name = 'transformer.db',
    log_level = 3,
    log_stderr = false,
    ignore_patterns = nil,
    vendor_patterns = nil,
    unhide_patterns = nil,
  }
  config = do_config(config)
  logger.init(config.log_level, config.log_stderr)
  local api = require("transformer.api")
  local errmsg
  transformer, errmsg = api.init(config)
  if not transformer then
    logger:critical(errmsg)
    return
  end
  api.init = nil  -- we won't call init() anymore so allow the code to be GC'd
end

local fault = require("transformer.fault")
local msg = require("transformer.msg").new()
local tags = msg.tags
local retrieve_data = msg.retrieve_data
local GPV_RESP = tags.GPV_RESP
local SPV_RESP = tags.SPV_RESP
local ERROR    = tags.ERROR
local ADD_RESP = tags.ADD_RESP
local DEL_RESP = tags.DEL_RESP
local GPN_RESP = tags.GPN_RESP
local RESOLVE_RESP = tags.RESOLVE_RESP
local SUBSCRIBE_RESP = tags.SUBSCRIBE_RESP
local UNSUBSCRIBE_RESP = tags.UNSUBSCRIBE_RESP
local GPL_RESP = tags.GPL_RESP
local GPC_RESP = tags.GPC_RESP
local GPV_NO_ABORT_RESP = tags.GPV_NO_ABORT_RESP

local tch_evloop = require("tch.socket.evloop")
local tch_timerfd = require("tch.timerfd")

local function sendto(sk, msg, from)
  local ok, errmsg = sk:sendto(msg:retrieve_data(), from)
  if not ok and errmsg == "WOULDBLOCK" then
    -- The sending queue of our socket is full. Create an evloop so we
    -- can wait for the socket to become writable again. To prevent blocking
    -- indefinitely, we add a timer to the event loop that will timeout after
    -- 15 seconds.
    local evloop = tch_evloop.evloop()
    if not evloop then
      logger:critical("Failed to create an event loop during sending. Dropping datagram.")
      return
    end
    local tfd = tch_timerfd.create()
    local real_fd = tch_timerfd.fd(tfd)
    -- Add the timer to the event loop.
    evloop:add(real_fd, function()
      errmsg = "No write callback possible after 15 seconds"
      evloop:close()
    end)
    tch_timerfd.settime(tfd, 15)
    -- Add the socket to the event loop with a callback for when it becomes writable again.
    evloop:add(sk, nil, function()
      ok, errmsg = sk:sendto(msg:retrieve_data(), from)
      evloop:close()
    end)
    evloop:run()
    tch_timerfd.close(real_fd)
  end
  if not ok then
    logger:critical("Sendto %s failed: %s. Dropping datagram.", from, tostring(errmsg))
  end
end

local function encode_wrapper(type, sk, from, ...)
  local success = msg:encode(...)
  if not success then
    -- The additional data does not fit in the dgram.
    -- Send what we have.
    sendto(sk, msg, from)
    msg:init_encode(type, max_size)
    success = msg:encode(...)
    if not success then
      -- The given values don't fit in a single message, throw an error.
      error("Too much data to fit in one single dgram.")
    end
  end
end

local GPV_cb_env = {}
local function GPV_cb(ppath, pname, pvalue, ptype)
  encode_wrapper(GPV_RESP, sk, from, ppath, pname, pvalue, ptype)
end
setfenv(GPV_cb, GPV_cb_env)

local function handle_GPV(sk, from, uuid, req)
  -- prepare environment for GPV callback
  GPV_cb_env.sk = sk
  GPV_cb_env.from = from
  msg:init_encode(GPV_RESP, max_size)
  -- do GPV for each path we received
  local rc, errcode, errmsg = transformer:getParameterValues(uuid, false, req, GPV_cb)
  if not rc then
    -- an error occurred: discard any data already queued, send an
    -- error message to the client and stop the GPV
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  end
  -- send any data still left in the buffer with the 'last' flag set
  msg:mark_last()
  sendto(sk, msg, from)
end

local GPV_NO_ABORT_cb_env = {}
local function GPV_NO_ABORT_cb(ppath, pname, pvalue, ptype, errcode, errmsg)
  if errmsg then
    ptype = 'error'
    pvalue = errmsg
    -- Ignoring errcode for now
  end
  encode_wrapper(GPV_NO_ABORT_RESP, sk, from, ppath, pname, pvalue, ptype)
end
setfenv(GPV_NO_ABORT_cb, GPV_NO_ABORT_cb_env)

local function handle_GPV_NO_ABORT(sk, from, uuid, req)
  -- prepare environment for GPV_NO_ABORT callback
  GPV_NO_ABORT_cb_env.sk = sk
  GPV_NO_ABORT_cb_env.from = from
  msg:init_encode(GPV_NO_ABORT_RESP, max_size)
  -- do GPV for each path we received, don't abort on error
  local rc, errcode, errmsg = transformer:getParameterValues(uuid, true, req, GPV_NO_ABORT_cb)
  if not rc then
    -- an error occurred: discard any data already queued, send an
    -- error message to the client and stop the GPV_NO_ABORT
    -- This should be a very rare case and signals an internal error. We need to keep the error path
    -- since we can not guarantee success in all possible scenario's.
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  end
  -- send any data still left in the buffer with the 'last' flag set
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_SPV(sk, from, uuid, req)
  local ok, errors = transformer:setParameterValues(uuid, req)
  msg:init_encode(SPV_RESP, max_size)
  if errors then
    for _, err in ipairs(errors) do
      local path, code, errmsg = unpack(err)
      encode_wrapper(SPV_RESP, sk, from, code, errmsg, path)
    end
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_APPLY(uuid, req)
  transformer:apply(uuid)
end

local function handle_ADD(sk, from, uuid, req)
  local instance, errcode, errmsg = transformer:addObject(uuid, req.path, req.name)
  local data, datasize
  if not instance then
    -- send ERROR message
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  else
    -- send ADD response with instance number
    msg:init_encode(ADD_RESP, max_size)
    msg:encode(instance)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_DEL(sk, from, uuid, req)
  local ok, errcode, errmsg = transformer:deleteObject(uuid, req)
  local data, datasize
  if not ok then
    -- send ERROR message
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  else
    -- send DEL response
    msg:init_encode(DEL_RESP, max_size)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local GPN_cb_env = {}
local function GPN_cb(ppath, pname, writable)
  encode_wrapper(GPN_RESP, sk, from, ppath, pname, writable)
end
setfenv(GPN_cb, GPN_cb_env)

local function handle_GPN(sk, from, uuid, req)
  -- prepare environment for GPN callback
  GPN_cb_env.sk = sk
  GPN_cb_env.from = from
  msg:init_encode(GPN_RESP, max_size)
  -- do GPN for each path we received
  local rc, errcode, errmsg = transformer:getParameterNames(uuid, req.path, req.level, GPN_cb)
  if not rc then
    -- an error occurred: discard any data already queued, send an
    -- error message to the client and stop the GPN
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  end
  -- send any data still left in the buffer with the 'last' flag set
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_RES(sk, from, uuid, req)
  local path, errcode, errmsg = transformer:resolve(uuid, req.path, req.key)
  local data, datasize
  if not path then
    -- send ERROR message
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  else
    -- send RES response with resolved path
    msg:init_encode(RESOLVE_RESP, max_size)
    msg:encode(path)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_SUB(sk, from, uuid, req)
  local id, paths, errmsg = transformer:subscribe(uuid, req.path, req.address, req.subscription, req.options)
  local data, datasize
  if not id then
    -- send ERROR message
    msg:init_encode(ERROR, max_size)
    msg:encode(paths, errmsg)
  else
    -- send SUBSCRIBE response with subscription id and non-evented parameter paths
    msg:init_encode(SUBSCRIBE_RESP, max_size)
    msg:encode(id, paths)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_UNSUB(sk, from, uuid, req)
  local ok, errcode, errmsg = transformer:unsubscribe(uuid, req)
  local data, datasize
  if not ok then
    -- send ERROR message
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  else
    -- send UNSUBSCRIBE response
    msg:init_encode(UNSUBSCRIBE_RESP, max_size)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local GPL_cb_env = {}
local function GPL_cb(ppath, pname)
  encode_wrapper(GPL_RESP, sk, from, ppath, pname)
end
setfenv(GPL_cb, GPL_cb_env)

local function handle_GPL(sk, from, uuid, req)
  -- prepare environment for GPL callback
  GPL_cb_env.sk = sk
  GPL_cb_env.from = from
  msg:init_encode(GPL_RESP, max_size)
  -- do GPL for each path we received
  local rc, errcode, errmsg
  for _, path in ipairs(req) do
    rc, errcode, errmsg = transformer:getParameterList(uuid, path, GPL_cb)
    if not rc then
      -- an error occurred: discard any data already queued, send an
      -- error message to the client and stop the GPL
      msg:init_encode(ERROR, max_size)
      msg:encode(errcode, errmsg)
      break
    end
  end
  -- send any data still left in the buffer with the 'last' flag set
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_GPC(sk, from, uuid, req)
  local total_count = 0
  -- do GPC for each path we received
  local errcode, errmsg
  for _, path in ipairs(req) do
    local count
    count, errcode, errmsg = transformer:getCount(uuid, path)
    if not count then
      -- an error occurred, discard the result
      total_count = nil
      break
    end
    total_count = total_count + count
  end
  if total_count then
    msg:init_encode(GPC_RESP, max_size)
    encode_wrapper(GPC_RESP, sk, from, total_count)
  else
    msg:init_encode(ERROR, max_size)
    msg:encode(errcode, errmsg)
  end
  msg:mark_last()
  sendto(sk, msg, from)
end

local function handle_unknown(sk, from)
  msg:init_encode(ERROR, max_size)
  msg:encode(fault.INTERNAL_ERROR, "unsupported tag")
  msg:mark_last()
  sendto(sk, msg, from)
end

-- all supported messages and their handling function
local handlers = {
  [tags.GPV_REQ] = handle_GPV,
  [tags.SPV_REQ] = handle_SPV,
  [tags.APPLY]   = handle_APPLY,
  [tags.ADD_REQ] = handle_ADD,
  [tags.DEL_REQ] = handle_DEL,
  [tags.GPN_REQ] = handle_GPN,
  [tags.RESOLVE_REQ] = handle_RES,
  [tags.SUBSCRIBE_REQ] = handle_SUB,
  [tags.UNSUBSCRIBE_REQ] = handle_UNSUB,
  [tags.GPL_REQ] = handle_GPL,
  [tags.GPC_REQ] = handle_GPC,
  [tags.GPV_NO_ABORT_REQ] = handle_GPV_NO_ABORT,
  __index        = function()
    return handle_unknown
  end
}
setmetatable(handlers, handlers)

local function open_socket()
  while not sk do
    sk = uds.dgram(oredflags)
    if not sk:bind("transformer") then
      -- if the socket can not be bound we have to retry it as transformer is
      -- not functional without it. But to avoid hogging resources we wait
      -- some time before retrying.
      logger:critical("main: cannot bind socket")
      sk:close()
      os.execute("sleep 3")
    end
  end
end

local trlock = require("transformer.lock").Lock("transformer")
local ucihelper = require("transformer.mapper.ucihelper")

local function recv_msg()
  local data, from = sk:recvfrom()
  if not data then
    return false
  end
  local tag, is_last, uuid = msg:init_decode(data)
  local req = msg:decode()
  -- Note: we're currently assuming that all requests
  -- fit in one message. If not, this would complicate
  -- the handling logic quite a bit: the next call to
  -- recvfrom() is not guaranteed to give you the next
  -- datagram from that client; it could be a datagram
  -- from another client.
  if not is_last then
    handle_unknown(sk, from)
  else
    ucihelper.start()
    handlers[tag](sk, from, uuid, req)
  end
  return true
end

local rcv_error
local function sk_callback(fd, event)
  local ok, rcv_result
  -- With uloop in combination with ubus it's possible that while
  -- processing an incoming request (e.g. sending a response) it
  -- starts handling another request. For example: we're processing
  -- a Transformer request and as part of that processing a mapping
  -- does a call on ubus. If a ubus event comes in at that moment
  -- then uloop starts happily processing that event. We don't want
  -- this unpredictable behavior; one reason is that as part of
  -- processing a ubus event we can make changes to the datamodel
  -- (e.g. add/delete event) and doing that while a Transformer
  -- request is being processed could break tree navigation in
  -- very subtle ways.
  -- So we use the lock module to ensure that delayed processing
  -- is done as soon as the lock is released.
  trlock:lock()
  repeat
    ok, rcv_result = pcall(recv_msg)
  until (not ok) or (not rcv_result)
  trlock:unlock()

  if not ok then
    -- an error occured
    rcv_error = rcv_result
    uloop.cancel()
  end
end

local function main()
  local ok, rcv_result

  open_socket()
  -- save the return value of fd_add. If it gets garbage collected the socket
  -- is removed from uloop
  -- Use edge trigger to avoid recursive calls to the callback.
  local usock = uloop.fd_add(sk:fd(), sk_callback, uloop.ULOOP_READ + uloop.ULOOP_EDGE_TRIGGER)

  rcv_error = nil

  -- run the event loop and process events
  uloop.run()

  -- when done, remove the socket from uloop
  usock:delete()

  if rcv_error then
    error(rcv_error)
  end
end

while true do
  local rc, err = pcall(main)
  if not rc then
    sk:close()
    sk = nil
    local _, errmsg = pcall(tostring, err)  -- to be really safe pcall() the tostring function
    logger:critical("main loop - critical error occurred: err=%s", errmsg or "<no error msg>")
    -- for testing purposes be able to break out of the watchdog loop
    -- by using a special errorcode
    if type(err) == "table" and err.errorcode == 0x0DEFACED then
      error(err)
    end
  end
end

transformer:close()
