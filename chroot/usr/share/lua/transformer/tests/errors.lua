--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, module, package = require, module, package

local lunit = require("lunit")

local assert,       assert_true,       assert_equal,       assert_string =
      lunit.assert, lunit.assert_true, lunit.assert_equal, lunit.assert_string

local unix = require("tch.socket.unix")
local fault = require("transformer.fault")
local msg = require("transformer.msg").new()
local tags = msg.tags

module(... or 'errors', lunit.testcase, package.seeall)

local uuid = "5C902B1373C745CDBCBE4EC8EB47DAD9"
local sk

function setup()
  sk = assert(unix.dgram(unix.SOCK_CLOEXEC))
  assert(sk:connect("transformer"))
end

function teardown()
  sk:close()
end

function test_send_unexpected_tag()
  msg:init_encode(tags.GPV_RESP, unix.MAX_DGRAM_SIZE)
  assert_true(msg:encode("Users.User.1.", "Username", "user1", "string"))
  msg:mark_last()
  assert(sk:send(msg:retrieve_data()))
  local data = sk:recv()
  local tag, is_last = msg:init_decode(data)
  assert_equal(tags.ERROR, tag)
  assert_true(is_last)
  local resp = msg:decode()
  assert_equal(fault.INTERNAL_ERROR, resp.errcode)
  assert_string(resp.errmsg)
end

function test_not_last_dgram()
  msg:init_encode(tags.GPV_REQ, unix.MAX_DGRAM_SIZE, uuid)
  assert_true(msg:encode("Users.User.1.Username"))
  assert(sk:send(msg:retrieve_data()))
  local data = sk:recv()
  local tag, is_last = msg:init_decode(data)
  assert_equal(tags.ERROR, tag)
  assert_true(is_last)
  local resp = msg:decode()
  assert_equal(fault.INTERNAL_ERROR, resp.errcode)
  assert_string(resp.errmsg)
end
