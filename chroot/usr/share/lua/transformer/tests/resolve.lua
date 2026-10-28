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

module(... or 'resolve', lunit.testcase, package.seeall)

local find = string.find
local sub = string.sub


-- Check whether a resolved path is valid.
function validate_resolved_path(path, pattern)
  local patternStart, patternEnd = find(path, pattern, 0, true)
  if patternStart == nil then
    return false
  end
  if tonumber(sub(path, patternEnd + 1)) == nil then
    return false
  end
  return true
end

-- Test resolving a type path
function test_resolve()
  local typePath = "Users.User.{i}."
  local key = "13619705455576"
  local result, error = proxy.resolve(typePath, key)
  assert_not_nil(result)
  assert_nil(error)
  assert_equal(type(result), "string")
  assert_true(validate_resolved_path(result, "Users.User."))
end

-- Test resolving an invalid type path
function test_resolve_invalidPath()
  local typePath = 42
  local key = "13619705455576"
  local result, error = proxy.resolve(typePath, key)
  assert_nil(result)
  assert_not_nil(error)
  assert_equal("invalid argument", error)
end

-- Test resolving an invalid type path
function test_resolve_invalidPath2()
  local typePath = "Users.User"
  local key = "13619705455576"
  local result, error = proxy.resolve(typePath, key)
  assert_not_nil(result)
  assert_nil(error)
  assert_equal("", result)
end

-- Test resolving an invalid type path
function test_resolve_invalidPath3()
  local typePath = "Users.User."
  local key = "13619705455576"
  local result, error = proxy.resolve(typePath, key)
  assert_not_nil(result)
  assert_nil(error)
  assert_equal("", result)
end

-- Test resolving an invalid key
function test_resolve_invalidKey()
  local typePath = "Users.User."
  local key = 42
  local result, error = proxy.resolve(typePath, key)
  assert_nil(result)
  assert_not_nil(error)
  assert_equal("invalid argument", error)
end

-- Test resolving an unkown key
function test_resolve_unknownKey()
  local typePath = "Users.User."
  local key = "4242424242424242"
  local result, error = proxy.resolve(typePath, key)
  assert_not_nil(result)
  assert_nil(error)
  assert_equal("", result)
end

-- Test calling the resolve function with an empty path
function test_resolve_noArguments()
  local result, error = proxy.resolve()
  assert_nil(result)
  assert_not_nil(error)
  assert_match("invalid argument", error)
end

