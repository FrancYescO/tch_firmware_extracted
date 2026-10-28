--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, ipairs = require, ipairs
local gsub = string.gsub

local lunit = require("lunit")
local proxy = require("datamodel")

local assert_number,       assert_table,       assert_nil,       assert_equal =
      lunit.assert_number, lunit.assert_table, lunit.assert_nil, lunit.assert_equal
local assert_true,       assert_string =
      lunit.assert_true, lunit.assert_string

module(... or 'subscribe', lunit.testcase, package.seeall)

local subscriptions = {}
local SUBTYPE_UPDATE = 1
local SUBTYPE_ADD = 2
local SUBTYPE_DEL = 3
local address = "testaddress"

local function subscribe_success(path, subtype, options)
  options = options or 0
  local id, nonevented = proxy.subscribe(path, address, subtype, options)
  assert_number(id)
  assert_table(nonevented)
  local sub = {
    id = id;
    nonevented = nonevented;
  }
  subscriptions[#subscriptions+1] = sub
  return sub
end

local function subscribe_failure(path, subtype, options)
  options = options or 0
  local id, err = proxy.subscribe(path, address, subtype, options)
  assert_nil(id)
  assert_string(err)
  return err
end

local function unsubscribe_success(subscription_id)
  local ok, err = proxy.unsubscribe(subscription_id)
  assert_true(ok)
  assert_nil(err)
end

local function unsubscribe_failure(subscription_id)
  local ok, err = proxy.unsubscribe(subscription_id)
  assert_nil(ok)
  assert_string(err)
  return err
end

local function unsubscribe_all(subscriptions)
  for _, sub in ipairs(subscriptions) do
    proxy.unsubscribe(sub.id)
  end
end

function setup()
  subscriptions = {}
end

function teardown()
  unsubscribe_all(subscriptions)
  subscriptions = {}
end

local fullpath = "Users.User.1.Username"
local partialpath = "Users.User.1."
local non_evented_path = "Users.User.1.CreationTime"
local falsepath = "Users.User.1.FAKE"

function test_subscribe_full()
  local sub = subscribe_success(fullpath, SUBTYPE_UPDATE)
  assert_equal(0, #sub.nonevented)
  unsubscribe_success(sub.id)
end

function test_subscribe_partial()
  local sub = subscribe_success(partialpath, SUBTYPE_UPDATE)
  assert_equal(1, #sub.nonevented)
  assert_equal(non_evented_path, sub.nonevented[1])
  unsubscribe_success(sub.id)
end

function test_subscribe_false()
  local err = subscribe_failure(falsepath, SUBTYPE_UPDATE)
  assert_equal("Invalid path Users.User.1.FAKE", err)
end

function test_unsubscribe_false()
  local err = unsubscribe_failure(12345)
  assert_equal("Invalid subscription id 12345", err)
end
