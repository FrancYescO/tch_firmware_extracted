-- Copyright (c) 2019 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.

-- Script connects to specified IOT Thing
-- Receives an MQTT Messages which contains the TR069 datamodel parameter
-- Sends an MQTT Message response of the specified TR069 datamodel parameter
-- The TR069 datamodel parameter can be IGD or Device2 datamodel.
-- The script is derived from the existing orchestra agent.

--- Payload from the Cloud is processed to perform appropriate action.
-- Based on the request, corresponding set/add/del actions are done here.
-- And the output response is framed into a table in the response_hanlder.lua and then published back to Cloud.
--
-- @module request_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log

local process = require("tch.process")
local popen = process.popen

local find = string.find
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub

--- Handles the proxy.apply(): Checks the type of Request and performs proxy.apply()
-- @function proxyApply
-- @param requestType Typeof the given request either "add/set/setApply"
local function proxyApply(requestType)
  if mqtt_lookup.mqtt_constants.proxyApplyType[requestType] then
    proxy.apply()
  end
end

--- Handles the command in mqtt request with type execute
-- @function handleExecuteCommand
-- @param req Parameter from the given Request Message for execute action
-- @param data data for framing the response
-- @return data table of data for framing the response message
local function handleExecuteCommand(req, data)
  local argumentCache = {}
  local command, arguments = match(req.parameter, "^(%S*)%s*(.*)")
  for argument in gmatch(arguments, "%S+") do
    argumentCache[#argumentCache + 1] = argument
  end
  data.status, data.errMsg = popen(command, argumentCache)
  data.status = data.status and mqtt_lookup.mqtt_constants.successCode or mqtt_lookup.mqtt_constants.setError
  return data
end

--- Hanldes the dynamic 'add/set/setApply' request messages, where the instance value
-- will be assigned to the dependant parameters dynamically
-- @param reqParam Parameter from the given Request Message for 'add/set/setApply' action
-- @param asignParam Table containing data for dynamic request handling
-- @return reqParam updated parameter with the instance value
local function checkDynamicParam(reqParam, assignParam)
  if reqParam then
    if not(next(assignParam)) and find(reqParam, "=") and find(reqParam, "$") then
      return match(reqParam, "^(%S*)%s%=%s(%S*)$")
    elseif next(assignParam) then
      if find(reqParam, "=") and find(reqParam, "$") then
        local basePath, dynVar = match(reqParam, "^(%S*)%s%=%s(%S*)$")
        for path, inst in pairs(assignParam) do
          if find(basePath, path) and find(basePath, inst.name) then
            basePath = gsub(basePath, inst.name, inst.value)
            return basePath, dynVar
          end
        end
        return basePath, dynVar
      else
        for path, inst in pairs(assignParam) do
          if find(reqParam, path) and find(reqParam, inst.name) then
            reqParam = gsub(reqParam, inst.name, inst.value)
            if match(reqParam, "%$") then
              return checkDynamicParam(reqParam, assignParam), match(reqParam, "^%S*%.(%$%S*)%.%S*")
            end
            return reqParam
          end
        end
      end
    end
    return reqParam
  end
end

--- Modifies the instance name of the datamodel
-- @function updateInstValue
-- @param path Datamodel path
-- @param instVal cureent instance value of the given datamodel path
-- @return instVal upated instance value
local function updateInstValue(path, instVal)
  if path and type(path) == "string" then
    if not match(path, "%.$") then
      return path
    end
    if instVal and type(instVal) == "string" then
      local dmPath, errMsg = proxy.get(path .. instVal .. ".")
      if dmPath and not errMsg then
        return instVal
      elseif not dmPath then
        dmPath, errMsg = proxy.get(path .. "@" .. instVal.. ".")
        return dmPath and "@" .. instVal
      end
    end
  end
end

--- Handles the datamodel command in MQTTAPI request
-- @function handleDatamodelCommand
-- @param req Parameter from the request message
-- @param data Return status of the given request message
-- @param dmPath Datamodel path of the parameter
-- @param asignParam Table containing data for dynamic request handling
-- @return data Table containing data for framing the response
local function handleDatamodelCommand(req, data, dmPath, assignParam)
  local dynVar
  req.parameter, dynVar = checkDynamicParam(req.parameter, assignParam)

  if mqtt_lookup.mqtt_constants.validationReqType[req.type] then
    data.status, data.errMsg = mqtt_lookup.mqttcommon.validateValue(req, dmPath)
  end

  if data.status == mqtt_lookup.mqtt_constants.successCode then
    data.status, data.errMsg = proxy[mqtt_lookup.mqtt_constants.requestTypes[req.type]](req.parameter, req.value)
    proxyApply(req.type)

    -- Dynamic handling of add/set/setApply actions
    if not data.errMsg and data.status and dynVar then
      local instName = updateInstValue(req.parameter, data.status) or data.status
      assignParam[req.parameter] = { ["name"] = dynVar, ["value"] = instName }
    end
    data.status = data.status and mqtt_lookup.mqtt_constants.successCode or mqtt_lookup.mqtt_constants.setError
  end
  return data, assignParam
end

--- Handles the Request Message, where the request type should be "set/del/add/execute" and performs necessary actions on DUT
-- If the request type is "execute" then the given Linux Command is executed or
-- if the request type is "set/add/del" , then handles the respective Datamodel actions(set, add, del).
-- @function handleRequest
-- @param payload Request message from cloud.
-- @return status and error message
local function handleRequest(payload)
  local data = {}
  local assignParam = {}
  for _, req in pairs(payload or {}) do
    if not req.parameter then
      break -- no parameter found, go to next payload instance
    end
    if not mqtt_lookup.mqtt_constants.requestTypes[tostring(req.type)] then
      -- no valid request type found, stop and return error
      data.status = mqtt_lookup.mqtt_constants.invalidTypeError
      data.errMsg = "Request type not recognized"
      break
    end
    log:debug("Action : "..tostring(req.type))
    log:debug("parameter : "..tostring(req.parameter))
    if mqtt_lookup.config.disableWhiteList == 0 then
      data.status, data.errMsg, dmPath = mqtt_lookup.mqttcommon.isWhiteListed(req.parameter, mqtt_lookup.config.requestWhiteList)
    else
      data.status, data.errMsg, dmPath = mqtt_lookup.mqtt_constants.successCode, nil, req.parameter
    end
    if data.status == mqtt_lookup.mqtt_constants.successCode then
      if req.type == "execute" then
        data = handleExecuteCommand(req, data)
      else
        data = handleDatamodelCommand(req, data, dmPath, assignParam)
      end
    end
    if data.errMsg then
      data.errMsg = data.errMsg and data.errMsg[1] and data.errMsg[1].errmsg or data.errMsg
      break
    end
    if data.status ~= mqtt_lookup.mqtt_constants.successCode then
      break
    end
  end
  return data
end

--- The get/set/add/del datamodel requests from the Cloud/TPS containing the topic command "cmd" will be redirected this function to perform required datamodel actions.
-- @function cmd
-- @param payload request message from Cloud
-- @param lookup table containing config data for the module parameter
-- @return table
function M.cmd(lookup, payload)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  local reqStatus = {}
  if payload and payload["req-parameter"] and next(payload["req-parameter"]) then
    reqStatus = handleRequest(payload["req-parameter"])
  end
  return mqtt_lookup.response_handler.frameResponse(lookup, payload, reqStatus)
end

return M
