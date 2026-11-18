--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require = require

local lunit = require("lunit")
local proxy = require("datamodel")

local assert_not_nil,       assert_nil,       assert_true,       assert_string =
      lunit.assert_not_nil, lunit.assert_nil, lunit.assert_true, lunit.assert_string
local assert_table,       assert_match =
      lunit.assert_table, lunit.assert_match

module(... or 'add', lunit.testcase, package.seeall)

-- The same tests are also found in web-framework-sample-tch
-- Test adding a new user instance to Users.User.
function test_add_user()
  local addpath = "Users.User."
  local result, error = proxy.add(addpath)
  assert_not_nil(result)
  assert_nil(error)
  assert_string(result)
  assert_true(proxy.apply())

  local instance = result
  local path = "Users.User."..instance.."."
  local results, error2 = proxy.get(path)
  assert_not_nil(results)
  assert_nil(error2)
  assert_true(#results > 1)
  assert_table(results)
end

-- Test adding a new instance to an invalid path
function test_add_invalidPath()
  local addpath = "Users.User"
  local result, error = proxy.add(addpath)
  assert_nil(result)
  assert_not_nil(error)
  assert_match("invalid exact path Users.User", error)
end

-- Test adding a new instance to an invalid path
function test_add_invalidPath2()
  local addpath = "Users.User.1."
  local result, error = proxy.add(addpath)
  assert_nil(result)
  assert_not_nil(error)
  assert_match("instance not supported on Users.User.1.", error)
end

-- Test calling the add function with an empty path
function test_add_noArguments()
  local result, error = proxy.add()
  assert_nil(result)
  assert_not_nil(error)
  assert_match("not string argument", error)
end

-- Test calling the add function with an invalid path
function test_add_notStringArgument()
  local results, error = proxy.add(42)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("not string argument", error)
end

-- Test adding multiple new user instances to Users.User.
-- A unique key should be generated for each one.
function test_add_multiple()
  for i = 1, 10 do
  local addpath = "Users.User."
  local result, error = proxy.add(addpath)
  assert_not_nil(result)
  assert_nil(error)
  assert_string(result)
  assert_true(proxy.apply())

  local instance = result
  local path = "Users.User."..instance.."."
  local results, error2 = proxy.get(path)
  assert_not_nil(results)
  assert_nil(error2)
  assert_true(#results > 1)
  assert_table(results)
  end
end
