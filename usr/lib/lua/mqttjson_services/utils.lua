#!/usr/bin/lua
---------------------------------------------------------------------------
-- Copyright (c) 2018 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
---------------------------------------------------------------------------


------------------------------------------------------
-- EXTERNAL DATA
------------------------------------------------------
local proxy = require('datamodel')

local M = {}
local mqtt_lookup = {}

function M.untaintVal(value)
    if string.untaint and string.istainted and string.istainted(value) then
      return string.untaint(value)
    else
      return value
    end
end

function M.get_instance_list(path)
    local data, errmsg, errcode = proxy.getPN(path, true)
    if not data then
        return nil, errmsg
    end

    local list = {}
    for _, entry in ipairs(data) do
        table.insert(list, entry.path)
    end

    return list
end

function M.get_path_value(path)
    local data, errmsg = proxy.get(path)
    if not data then
        return nil, errmsg
    end

    return M.untaintVal(data[1].value)
end

function M.get_all_subpaths(path)
    local data, errmsg = proxy.get(path)
    if not data then
        return nil, errmsg
    end

    results = {}
    for k, v in pairs(data) do
       results[v.path .. v.param] = M.untaintVal(v.value)
    end

    return results
end

function M.set_path_value(path, value)
    local ret, errmsg = proxy.set(path, value)
    if not ret then
        return nil, errmsg
    end

    return 1
end

function M.apply()
    local ret, errmsg = proxy.apply()
    if not ret then
        return nil, errmsg
    end

    return 1
end

function M.is_empty(a)
    if a == nil then
        return true
    end

    _type = type(a)
    if (_type == 'string') and (a == '') then
        return true
    elseif (_type == 'table') and (next(a) == nil) then
        return true
    end

    return false
end

function M.string_to_native(value)
    if value == "true" then
        return true
    end
    if value == "false" then
        return false
    end
    if tonumber(value) then
        return tonumber(value)
    end
    return value
end

function M.split(data, delimiter)
    local result = {}
    if not data then return result end
    local from  = 1
    local delim_from, delim_to = string.find(data, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(data, from , delim_from-1 ))
        from  = delim_to + 1
        delim_from, delim_to = string.find(data, delimiter, from)
    end
    local str = string.sub(data, from)
    if str and #str > 0 then
        table.insert(result, str)
    end
    return result
end


-- Get the uci value of the path
--
-- @param  path    Path to the needed uci parameter. eg "env.var.prod_number"
-- @return result  The value of the parameter at the given path

function M.get_uci_param(path)

    if M.is_empty(path) == true then
        error("Invalid path", 2)
    end

    local tokens = string.gmatch(path, "[^.]+")
    local conf   = tokens()
    local type   = tokens()
    local para   = tokens()
    local result = mqtt_lookup.cursor:get(conf, type, para)

    return result
end

function M.dump_table(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. M.dump_table(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function M.init(lookup)
  mqtt_lookup = lookup
end

return M
