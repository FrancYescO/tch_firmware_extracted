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

module(... or 'gpn', lunit.testcase, package.seeall)


local find = string.find

-- Check whether a path contains the specified pattern.
function validate_path(path, pattern)
  local patternStart, patternEnd = find(path, pattern, 0, true)
  if patternStart == nil then
    return false
  end
  return true
end

-- Check whether a path contains the specified pattern. The path can only
-- reside in the next level of the provided pattern
function validate_path_nextlevel(path, pattern)
  local patternStart, patternEnd = find(path, pattern, 0, true)
  if patternStart == nil then
    return false
  end
  -- And extra dot is allowed only at the end of the path
  patternStart, patternEnd = find(path, ".", patternEnd + 1, true)
  if patternStart ~= nil and patternEnd ~= #path then
    return false
  end
  return true
end

-- Check whether a path is correctly (non-)writable
function validate_writable(path, writable)
  local expected = {
    ["Username"] = true,
    ["Password"] = true,
    ["Enable"] = true,
    ["CreationTime"] = false,
  }
  for key, entry in pairs(expected) do
    local patternStart, patternEnd = find(path, key, 0, true)
    if patternStart ~= nil and writable ~= entry then
      return false
    end
  end
  return true
end

function setup()
  proxy = require("datamodel")
end

function teardown()
  proxy = nil;
end

-- Same tests are present in web-framework-sample-tch
-- Test getting the parameter names of all parameters in the specified path
-- (next level is not enabled)
function test_gpn()
  local requested = "Users.User."
  local results, errors = proxy.getPN(requested, false)
  assert_true(results ~= nil)
  assert_true(errors == nil)
  assert_true(#results > 0)
  for _, entry in ipairs(results) do
    assert_not_nil(entry.path)
    assert_not_nil(entry.name)
    local path = entry.path..entry.name
    assert_true(validate_path(path, requested))
    assert_true(validate_writable(path, entry.writable))
  end
end

-- Test getting the parameter names of all parameters in the specified path
-- (next level is enabled)
function test_gpn_nextlevel()
  local requested = "Users.User."
  local results, errors = proxy.getPN(requested, true)
  assert_true(results ~= nil)
  assert_true(errors == nil)
  assert_true(#results > 0)
  for _, entry in ipairs(results) do
    assert_not_nil(entry.path)
    assert_not_nil(entry.name)
    local path = entry.path..entry.name
    assert_true(validate_path_nextlevel(path, requested))
    assert_true(validate_writable(path, entry.writable))
  end
end

function test_gpn_invalidPath()
  local getpath = "USERS.User."
  local results, error = proxy.getPN(getpath, false)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("invalid path USERS.User.", error)
end

function test_gpn_noArguments()
  local results, error = proxy.getPN()
  assert_nil(results)
  assert_not_nil(error)
  assert_match("no data", error)
end

function test_gpn_notStringArgument()
  local results, error = proxy.getPN(42)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("not string argument", error)
end

function test_gpn_notBooleanArgument()
  local getpath = "USERS.User."
  local results, error = proxy.getPN(getpath, 42)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("not boolean argument", error)
end

function test_gpn_one()
  local path = "Users.User.1.Username"
  local results, error = proxy.getPN(path, false)
  assert_not_nil(results)
  assert_nil(error)
  assert_equal(1, #results)
  assert_true(validate_path(results[1].path .. results[1].name, path))
  assert_true(validate_writable(results[1].path .. results[1].name, results[1].writable))
end

function test_gpn_nextlevel_invalid()
  local path = "Users.User.1.Username"
  local results, error = proxy.getPN(path, true)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("GPN on exact path and level~=2", error)
end
