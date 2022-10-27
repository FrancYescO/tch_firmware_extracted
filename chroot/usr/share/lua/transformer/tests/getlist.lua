--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

require("lunit")
local proxy = require("datamodel")

module(... or 'getlist', lunit.testcase, package.seeall)


local find = string.find
function validate_user(username, pattern)
  if find(username, pattern) == nil then
    return false
  end
  return true
end

-- Test getting a single parameter
function test_get_one_path()
  local results, errors = proxy.getPL("Users.User.1.Username")
  assert_true(results ~= nil)
  assert_true(errors == nil)
  assert_equal(1, #results)
  local p = results[1]
  assert_equal("Users.User.1.", p.path)
  assert_equal("Username", p.param)
  p.path = nil
  p.param = nil
  assert_nil(next(p))
end

-- Test getting multiple parameters in a single call
function test_get_multiple_paths()
  local results, errors = proxy.get("Users.User.1.Username",
    "Users.User.2.Username","Users.User.3.Username")
  assert_true(results ~= nil)
  assert_true(errors == nil)
  assert_equal(3, #results)
  local expected = {
    ["Users.User.1.Username"] = true,
    ["Users.User.2.Username"] = true,
    ["Users.User.3.Username"] = true,
  }
  for _, entry in ipairs(results) do
    local path = entry.path..entry.param
    local expected_value = expected[path]
    assert_not_nil(expected_value)
    expected[path] = nil
  end
  assert_nil(next(expected))
end

-- Test getting all parameters in a single call
function test_get_all()
  local results, errors = proxy.getPL("Users.")
  assert_true(results ~= nil)
  assert_true(errors == nil);
  assert_true(#results ~= 0)
  
  for _, entry in ipairs(results) do
    assert_string(entry.path)
    assert_string(entry.param)
  end
end

function test_get_empty_SI()
  local results, errors = proxy.getPL("Users.Empty.")
  assert_not_nil(results)
  assert_nil(errors)
  assert_equal(0, #results)
end

function test_get_noentries_MI()
  local results, errors = proxy.getPL("Users.EmptyMI.")
  assert_not_nil(results)
  assert_nil(errors)
  assert_equal(0, #results)
end
