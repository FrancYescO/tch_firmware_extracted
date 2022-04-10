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

module(... or 'del', lunit.testcase, package.seeall)


-- The same tests are also found in web-framework-sample-tch
-- Test deleting an user instance to in Users.User.
function test_del_user()
  local addpath = "Users.User."
  local result, error = proxy.add(addpath)
  assert_not_nil(result)
  assert_nil(error)
  assert_true(type(result)=="string")
  assert_true(proxy.apply())

  local instance = result
  local path = "Users.User."..instance.."."
  local result2, error2 = proxy.del(path)
  assert_true(result2)
  assert_nil(error2)
  assert_true(proxy.apply())

  local results, error3 = proxy.get(path)
  assert_nil(results)
  assert_not_nil(error3)
  assert_match("invalid instance", error3)
end

--- Non regression test for DE2426
function test_add2_del1st_user()
  local useraddpath = "Users.User."

  local function addUserWithName(name)
    local result, error = proxy.add(useraddpath)
    local instance = result
    assert_not_nil(result)
    assert_nil(error)
    assert_equal("string", type(result))
    result, error = proxy.set(useraddpath .. instance .. ".Username", name)
    assert_not_nil(result)
    assert_nil(error)
    assert_equal("boolean", type(result))
    assert_true(proxy.apply())
    return instance
  end

  -- Add the first user
  local instance1 = addUserWithName("user1")
  -- Add the second user
  local instance2 = addUserWithName("user2")

  -- Delete the first user
  local path = useraddpath..instance1.."."
  local result, error = proxy.del(path)
  assert_true(result)
  assert_nil(error)
  assert_true(proxy.apply())

  -- Get the second user
  path = useraddpath..instance2..".Username"
  result, error = proxy.get(path)
  assert_true(result ~= nil)
  assert_true(error == nil)
  assert_equal(1, #result)
  assert_equal("Users.User."..instance2..".", result[1].path)
  assert_equal("Username", result[1].param)
  assert_equal("user2", result[1].value)
  assert_equal("string", result[1].type)
end

-- Test deleting an instance with an invalid path
function test_del_invalidPath()
  local delpath = "Users.User"
  local result, error = proxy.del(delpath)
  assert_nil(result)
  assert_not_nil(error)
  assert_match("invalid exact path Users.User", error)
end

-- Test deleting an instance with an invalid path
function test_del_invalidPath2()
  local delpath = "Users.User.1.Username"
  local result, error = proxy.del(delpath)
  assert_nil(result)
  assert_not_nil(error)
  assert_match("exact_path not supported on Users.User.", error)
end

-- Test calling the delete function with an empty path
function test_del_noArguments()
  local result, error = proxy.del()
  assert_nil(result)
  assert_not_nil(error)
  assert_match("not string argument", error)
end

-- Test calling the delete function with an invalid path
function test_del_notStringArgument()
  local results, error = proxy.del(42)
  assert_nil(results)
  assert_not_nil(error)
  assert_match("not string argument", error)
end
