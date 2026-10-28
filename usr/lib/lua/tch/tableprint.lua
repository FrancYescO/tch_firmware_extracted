--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this lua-tch component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- A convenience function to prettyprint a table.
--
-- Load the module via `require`; it returns the prettyprint
-- function. Then simply call it with a table argument. It will
-- also work with non-table arguments.
--
-- It uses the standard `print` function to output everything. If
-- you want to use a different output function the simplest solution
-- is to reassign the global `print` function to your logging function,
-- then load this module and restore it afterwards.
--
-- By default the output function is invoked with _one_ string argument
-- that contains newlines. This ensures a readable output with the
-- standard `print` function and the override used in the nginx Lua module.
-- If you use a different output function that doesn't cope well with
-- these newlines (syslog for example) then you can set the environment
-- variable `TABLEPRINT\_NO\_NEWLINES`. In that case the output function
-- is called for every line in the output.
--
-- **Warning: the prettyprinter doesn't check for loops in a table!**
-- @module tch.tableprint
-- @usage
-- -- Use a custom print function, namely log(),
-- -- by temporarily changing the global print() function.
-- local _print = print
-- print = log
-- local tprint = require("tch.tableprint")
-- print = _print  -- restore print()
-- local t = { some = "table", 4, 3 }
-- tprint(t)
-- tprint("some string")  -- also works
-- tprint(43)  -- also works
-- tprint(true)  -- again, this works as well
local ipairs, pairs, type, tostring, print, concat,       format =
      ipairs, pairs, type, tostring, print, table.concat, string.format

local function keystr(k)
  return type(k) == "number" and ("[" .. k .. "]") or k
end

local function to_string(v)
  local istainted = string.istainted
  if istainted and istainted(v) then
    return string.untaint(v)
  end
  return tostring(v)
end

local function tprint(t, msg, space)
  space = space or ""
  if type(t) == "table" then
    msg[#msg + 1] = format("%s{", space)
    for k,v in pairs(t) do
      local t_v = type(v)
      if t_v == "number" or t_v == "string" then
        msg[#msg + 1] = format("%s  %s = %s,", space, keystr(k), v)
      elseif t_v == "nil" then
        msg[#msg + 1] = format("%s  %s = nil,", space, keystr(k))
      elseif t_v == "table" then
        msg[#msg + 1] = format("%s  %s = ", space, keystr(k))
        tprint(v, msg, space .. "  ")
      elseif t_v == "boolean" then
        msg[#msg + 1] = format("%s  %s = %s,", space, keystr(k), v and "true" or "false")
      else
        msg[#msg + 1] = format("%s  %s = %s (%s)", space, keystr(k), to_string(v), t_v)
      end
    end
    msg[#msg + 1] = space .. "}"
  else
    msg[#msg + 1] = to_string(t)
  end
end

local function print_with_newlines(t)
  local msg = {}
  tprint(t, msg)
  print(concat(msg, "\n"))
end

local function print_separately(t)
  local msg = {}
  tprint(t, msg)
  for _, s in ipairs(msg) do
    print(s)
  end
end

if os.getenv("TABLEPRINT_NO_NEWLINES") then
  return print_separately
end

return print_with_newlines
