--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]
local require, ipairs = require, ipairs

local lunit = require("lunit")
local proxy = require("datamodel")

local assert_not_nil,       assert_equal,       assert_match,       assert_nil =
      lunit.assert_not_nil, lunit.assert_equal, lunit.assert_match, lunit.assert_nil
local assert_table,       assert_string =
      lunit.assert_table, lunit.assert_string

module(... or 'get_abort', lunit.testcase, package.seeall)

local function do_get_no_abort(requested_paths, expected_results, expected_errors)
  local results, errors = proxy.get(requested_paths)
  assert_not_nil(results)
  assert_equal(#expected_results, #results)
  if expected_errors then
    assert_not_nil(errors)
    assert_equal(#expected_errors, #errors)
  else
    assert_nil(errors)
  end
  for i in ipairs(results) do
    assert_table(results[i])
    assert_string(results[i].path)
    assert_string(results[i].param)
    assert_string(results[i].type)
    assert_string(results[i].value)
    assert_equal(expected_results[i].path, results[i].path)
    assert_equal(expected_results[i].param, results[i].param)
    assert_equal(expected_results[i].type, results[i].type)
    assert_equal(expected_results[i].value, results[i].value)
  end
  if expected_errors then
    for i in ipairs(errors) do
      assert_table(errors[i])
      assert_string(errors[i].path)
      assert_string(errors[i].param)
      assert_string(errors[i].errmsg)
      assert_nil(errors[i].type)
      assert_nil(errors[i].value)
      assert_equal(expected_errors[i].path, errors[i].path)
      assert_equal(expected_errors[i].param, errors[i].param)
      assert_match(expected_errors[i].errmsg, errors[i].errmsg)
    end
  end
end

-- Test getting a parameter with a get function that returns nil + error message.
function test_get_nil_parameter()
  local requested_paths = {"Tests.Errors.MI_nil_parameter.1.param1"}
  local expected_results = {}
  local expected_errors = {
    {
      path = "Tests.Errors.MI_nil_parameter.1.",
      param = "param1",
      errmsg = "some_error",
    },
  }
  -- Only the exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_parameter.1."
  -- Only partial error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_parameter.1.param1"
  requested_paths[2] =  "Tests.Type.StandardString"
  expected_results[1] = {
    path = "Tests.Type.",
    param = "StandardString",
    type = "string",
    value = "thisisastandardstring",
  }
  -- Exact error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_parameter.1."
  -- Partial error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] =  "Tests.Type.StandardString"
  requested_paths[2] = "Tests.Errors.MI_nil_parameter.1.param1"
  -- Exact good path and exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
end

-- Test getting a parameter with a get function that throws an error.
function test_get_error_parameter()
  local requested_paths = {"Tests.Errors.MI_error_parameter.1.param1"}
  local expected_results = {}
  local expected_errors = {
    {
      path = "Tests.Errors.MI_error_parameter.1.",
      param = "param1",
      errmsg = "a real error",
    },
  }
  -- Only the exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_parameter.1."
  -- Only partial error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_parameter.1.param1"
  requested_paths[2] =  "Tests.Type.StandardString"
  expected_results[1] = {
    path = "Tests.Type.",
    param = "StandardString",
    type = "string",
    value = "thisisastandardstring",
  }
  -- Exact error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_parameter.1."
  -- Partial error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] =  "Tests.Type.StandardString"
  requested_paths[2] = "Tests.Errors.MI_error_parameter.1.param1"
  -- Exact good path and exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
end

-- Test getting a parameter with an entries function that returns nil + error message.
function test_get_nil_entries()
  local requested_paths = {"Tests.Errors.MI_nil_entries.1.param1"}
  local expected_results = {}
  local expected_errors = {
    {
      path = "Tests.Errors.MI_nil_entries.1.param1",
      param = "",
      errmsg = "entries error",
    },
  }
  -- Only the exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_entries.1."
  expected_errors[1].path = "Tests.Errors.MI_nil_entries.1."
  -- Only partial error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_entries.1.param1"
  requested_paths[2] =  "Tests.Type.StandardString"
  expected_results[1] = {
    path = "Tests.Type.",
    param = "StandardString",
    type = "string",
    value = "thisisastandardstring",
  }
  expected_errors[1].path = "Tests.Errors.MI_nil_entries.1.param1"
  -- Exact error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_nil_entries.1."
  expected_errors[1].path = "Tests.Errors.MI_nil_entries.1."
  -- Partial error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] =  "Tests.Type.StandardString"
  requested_paths[2] = "Tests.Errors.MI_nil_entries.1.param1"
  expected_errors[1].path = "Tests.Errors.MI_nil_entries.1.param1"
  -- Exact good path and exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
end

-- Test getting a parameter with an entries function that throws an error.
function test_get_error_entries()
  local requested_paths = {"Tests.Errors.MI_error_entries.1.param1"}
  local expected_results = {}
  local expected_errors = {
    {
      path = "Tests.Errors.MI_error_entries.1.param1",
      param = "",
      errmsg = "entries%(%) error",
    },
  }
  -- Only the exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_entries.1."
  expected_errors[1].path = "Tests.Errors.MI_error_entries.1."
  -- Only partial error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_entries.1.param1"
  requested_paths[2] =  "Tests.Type.StandardString"
  expected_results[1] = {
    path = "Tests.Type.",
    param = "StandardString",
    type = "string",
    value = "thisisastandardstring",
  }
  expected_errors[1].path = "Tests.Errors.MI_error_entries.1.param1"
  -- Exact error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] = "Tests.Errors.MI_error_entries.1."
  expected_errors[1].path = "Tests.Errors.MI_error_entries.1."
  -- Partial error path and exact good path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[1] =  "Tests.Type.StandardString"
  requested_paths[2] = "Tests.Errors.MI_error_entries.1.param1"
  expected_errors[1].path = "Tests.Errors.MI_error_entries.1.param1"
  -- Exact good path and exact error path
  do_get_no_abort(requested_paths, expected_results, expected_errors)
end

function test_get_errors_mixed()
  local requested_paths = {
    "Tests.Errors.MI_nil_parameter.1.param1",
    "Tests.Errors.MI_error_parameter.1.param1",
    "Tests.Errors.MI_nil_entries.1.param1",
    "Tests.Errors.MI_error_entries.1.param1",
  }
  local expected_results = {}
  local expected_errors = {
    {
      path = "Tests.Errors.MI_nil_parameter.1.",
      param = "param1",
      errmsg = "some_error",
    },
    {
      path = "Tests.Errors.MI_error_parameter.1.",
      param = "param1",
      errmsg = "a real error",
    },
    {
      path = "Tests.Errors.MI_nil_entries.1.param1",
      param = "",
      errmsg = "entries error",
    },
    {
      path = "Tests.Errors.MI_error_entries.1.param1",
      param = "",
      errmsg = "entries%(%) error",
    },
  }
  do_get_no_abort(requested_paths, expected_results, expected_errors)
  requested_paths[5] =  "Tests.Type.StandardString"
  expected_results[1] = {
    path = "Tests.Type.",
    param = "StandardString",
    type = "string",
    value = "thisisastandardstring",
  }
  do_get_no_abort(requested_paths, expected_results, expected_errors)
end
