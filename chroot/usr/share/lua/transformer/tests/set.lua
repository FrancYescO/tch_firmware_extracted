--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, ipairs, next = require, ipairs, next

require("lunit")
local proxy = require("datamodel")

local assert_true,       assert_nil,       assert_not_nil,       assert_table =
      lunit.assert_true, lunit.assert_nil, lunit.assert_not_nil, lunit.assert_table
local assert_equal =
      lunit.assert_equal

module(... or 'set', lunit.testcase, package.seeall)


-- Test setting a single parameter
function test_set_one_path()
  local results
  local error
  results, error = proxy.set("Users.User.1.Username", "user4")
  assert_true(results)
  assert_nil(error)
  assert_true(proxy.apply())
  
  results, error = proxy.get("Users.User.1.Username")
  assert_not_nil(results)
  assert_nil(error)
  assert_table(results)
  assert_equal(1, #results)
  assert_equal("Users.User.1.", results[1].path)
  assert_equal("Username", results[1].param)
  assert_equal("user4", results[1].value)
  assert_equal("string", results[1].type)
end

-- Test setting multiple parameters in a single call
function test_set_multiple_paths()
  local results
  local error
  results, error = proxy.set({["Users.User.2.Username"] = "user5",
    ["Users.User.3.Username"] = "user6"})
  assert_true(results)
  assert_nil(error)
  assert_true(proxy.apply())
  
  results, error = proxy.get("Users.User.2.Username", "Users.User.3.Username")
  assert_not_nil(results)
  assert_nil(error)
  assert_table(results)
  assert_equal(2, #results)
  local expected = {
    ["Users.User.2.Username"] = "user5",
    ["Users.User.3.Username"] = "user6"
  }
  for _, entry in ipairs(results) do
    local path = entry.path..entry.param
    local expected_value = expected[path]
    assert_not_nil(expected_value)
    assert_equal(expected_value, entry.value)
    assert_equal("string", entry.type)
    expected[path] = nil
  end
  assert_nil(next(expected))
end

-- Test setting an invalid parameter
function test_set_error()
  local results, error
  results, error = proxy.get("Users.User.2.Username")
  local original_value = results[1].value
  results, error = proxy.set({["Users.User.2.Username"] = original_value.."_changed",
    ["Users.User.3.nonexisting"] = "user9"})
  assert_true(results ~= true)
  assert_not_nil(error)
  assert_equal("Users.User.3.nonexisting", error[1].path)
  assert_true(proxy.apply())
  
  results, error = proxy.get("Users.User.2.Username")
  assert_not_nil(results)
  assert_nil(error)
  assert_table(results)
  assert_equal(1, #results)
  assert_equal("Users.User.2.", results[1].path)
  assert_equal("Username", results[1].param)
  assert_equal(original_value, results[1].value)
  assert_equal("string", results[1].type) 
end
