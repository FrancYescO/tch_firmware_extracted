-- Copyright (c) 2020 Technicolor
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
-- Based on the request, corresponding transformer's get actions are done here.
-- And the output response is framed into a table and published back to Cloud.
--
-- @module response_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log

local match = string.match
local find = string.find
local sub, gsub = string.sub, string.gsub
local process = require("tch.process")
local popen = process.popen

local dmData = {}
local instances = {}
local partialPath = {}
local partialParams = {}
local filteredInstances = {}
local unavailableParams = {}

-- Saves the instance values of first parameter in JSON request
local firstInstanceTable = {}
local firstParam = true

-- Verifies the current Path is already available in the known instances
local function availableInst(curPath, basePathVar)
  for path in pairs(instances) do
    if not basePathVar and path == curPath then
      return true
    elseif basePathVar and (match(path, curPath) or match(curPath, path)) then
      return true
    end
  end
end

-- Gets the given Datamodel BasePath
local function getDMData(path)
  if not dmData[path] then
    local value, errMsg = proxy.get(path)
    if errMsg then
      return nil, errMsg
    end
    dmData[path] = value
  end
end

-- Loads the individual object from the given the BasePath
local function getMultiInstances(basePathVar)
  for pPath in pairs(partialPath) do
    local _, errMsg = getDMData(pPath)
    if errMsg then
      return nil, errMsg
    end
  end

  for basePath, data in pairs(dmData) do
    local basePathValue = basePath
    if basePathValue and find(basePathValue, "%-") then
      basePathValue = gsub(basePathValue, "%-", "%%-")
    end
    for _, instTable in pairs(data or {}) do
      for params, value in pairs(instTable or {}) do
        if params == "path" and value and not availableInst(value, basePathVar) then
          instances[value] = true
          local valuePath = value
          if valuePath and find(valuePath, "%-") then
            valuePath = gsub(valuePath, "%-", "%%-")
          end
          if basePathVar then
            if find(value, basePathValue) then
              local inst = gsub(value, basePathValue, "")
              local index = inst and find(inst, "%.")
              inst = inst and index and inst:sub(0, index -1)
              if inst then
                filteredInstances[ inst ] = basePathVar
              end
            elseif find(basePath, valuePath) then
              local inst = gsub(basePath, valuePath, "")
              filteredInstances[ inst ] = basePathVar
            end
          end
        end
      end
    end
  end
end

-- Response table for Partial Path with its corresponding Param is framed
local function framePartialParams(pPath, inst, pParam, midPath)
  local index = midPath and find(inst, midPath)
  if index then
    inst = inst:sub(0, index - 1)
  end
  local dmResult = {}
  for _, dmVal in pairs(dmData) do
    for _, data in pairs(dmVal or {}) do
      if inst and pParam and data.path and data.param then
        if midPath and mqtt_lookup.mqttcommon.isEqual(data.path, inst .. midPath) and pParam == data.param then
	  if match(midPath, "%.$") then
            dmResult[ #dmResult + 1] = {
              gwParameter = data.path .. data.param,
              value = data.value
            }
          else
            dmResult = {
              gwParameter = data.path .. data.param,
              value = data.value
            }
          end
        elseif pPath and not midPath then
          local subPath = match(inst, "^"..pPath.."(%S*)%.$")
          if (subPath and not match(subPath, "%.")) and data.path == inst and pParam == data.param then
            dmResult = {
              gwParameter = data.path .. data.param,
              value = data.value
            }
          elseif not subPath and data.path == inst and pParam == data.param then
            dmResult = {
              gwParameter = data.path .. data.param,
              value = data.value
            }
          end
        end
      end
    end
  end
  return dmResult
end

-- Gets the required DataModel Path and its corresponding values
local function getMultiInstanceValues(pPath, midPath, pParam, apiParam, basePathVar, rspParam)
  if not partialPath[pPath] then
    partialPath[pPath] = true
    local _, errMsg = getMultiInstances(basePathVar)
    if errMsg then
      return nil, errMsg
    end
  end
  local paramsAvailable
  if not basePathVar and next(instances) then
    for inst in pairs(instances) do
      local exist = false
      if firstParam then
        exist = true
      end
      for _, firstInst in pairs(firstInstanceTable or {}) do
        local instancePattern = "^%S*%.(%S*)%.$"  -- get last string in path, between dots(".")
        -- The instance values stored in firstInstanceTable is compared with the instance of successive requested parameters.
        if not firstParam and (match(firstInst, instancePattern) == match(inst, instancePattern)) then
          -- if the instance matches, then set exist flag to true.
          exist = true
        end
      end
      if not partialParams[inst] then
        partialParams[inst] = {}
      end
      local getValue = exist and framePartialParams(pPath, inst, pParam, midPath)
      if getValue and next(getValue) then
        if firstParam then
          firstInstanceTable[#firstInstanceTable + 1] = inst
        end
        partialParams[inst][apiParam] = getValue
        -- Check if the gwParameter field and value field available for the current rspParameter
        if getValue.gwParameter and getValue.value then
          -- Data availability check for the non array of sub-values rspParameter
          paramsAvailable = true
        elseif getValue and type(getValue) == "table" then
          -- Data availability check for the array of sub-values rspParameter
          for _, arrParams in pairs(getValue) do
            if arrParams.gwParameter and arrParams.value then
              paramsAvailable = true
            end
          end
        end
      end
      -- Include the gwParameter field with the corresponding rspParameter
      -- and value field as empty in the parameters table of the response
      if exist and not paramsAvailable then
        if inst and pParam then
          if (not midPath) or (midPath and not match(inst, midPath)) then
            local paramPath = pPath
            if paramPath and find(paramPath, "%-") then
              paramPath = gsub(paramPath, "%-", "%%-")
            end
            local checkInst
            if paramPath and find(inst, paramPath) then
              checkInst = gsub(inst, paramPath, "")
            end
            local instVal
            if checkInst then
              instVal = match(checkInst, "[-@%w]+%.(%S*)$")
            end
            if checkInst and ((instVal and instVal == "") or not instVal) then
              local paramValue = {}
              if midPath then
                -- Data availability check for the array of sub-values rspParameter
                paramValue = {
                  gwParameter = inst .. midPath ..'[].' .. pParam
                }
              else
                -- Data availability check for the non array of sub-values rspParameter
                paramValue = {
                  gwParameter = inst .. pParam
                }
              end
              if not partialParams[inst] then
                partialParams[inst] = {}
              end
              partialParams[inst][apiParam] = paramValue
            end
          end
        end
      end
    end
  end
  if rspParam and not paramsAvailable then
    unavailableParams[ #unavailableParams + 1] = rspParam
  end
end

-- Gets the required BasePath and frames the output for array of available parameters
-- If 'compVal' is available, then from the list of array of sub-values,
-- only the required instance and its value should be returned
local function getArrayValues(pPath, pParam, compVal)
  local dmData, errMsg = proxy.get(pPath)
  if errMsg then
    return nil, errMsg
  end
  local arrayVal = {}
  for _, data in pairs(dmData) do
    if data.param == pParam and (not compVal or compVal == data.value) then
        arrayVal[ #arrayVal + 1 ] = {
          gwParameter = data.path .. data.param,
          value = data.value
        }
    end
  end
  -- Check if the gwParameter field and value field available for the current array of sub-values rspParameter
  if dmData and not next(arrayVal) and pPath and pParam then
    arrayVal['gwParameter'] = pPath .. "[]." .. pParam
  end
  return arrayVal
end

local function checkCompParam(assignVar, rspParams)
  if assignVar and rspParams then
    for _, rsp in pairs(rspParams or {}) do
      if  rsp.parameter and match(rsp.parameter, "%==") then
        local var = match(rsp.parameter, "^%S*%s%==%s(%S*)$")
        if assignVar == var then
          return true
        end
      end
    end
  end
end

-- Check if rsp-parameter contains the assignment or comparison operation
local function checkAssignComp(rspParams)
  local assignParam = {}
  local compParam = {}
  for _, rsp in pairs(rspParams or {}) do
    if rsp.parameter then
      local basePath, var
      if match(rsp.parameter, "%==") then
        -- Comparison operation
        basePath, var = match(rsp.parameter, "^(%S*)%s%==%s(%S*)$")
        if basePath and var then
          compParam[ basePath ] = var
          rsp.parameter = basePath
        end
      elseif match(rsp.parameter, "%=") then
        -- Assignment operation
        basePath, var = match(rsp.parameter, "^(%S*)%s%=%s(%S*)$")
        if basePath and var and match(var, "%$") then
          if checkCompParam(var, rspParams) then
            compParam[ basePath ] = var
          else
            assignParam[ basePath ] = var
          end
        elseif var and not match(var, "%$") then
          return
        end
      end
    end
  end
  return assignParam, compParam
end

local function getInstanceValue(curInst, baseInst)
  if baseInst then
    baseInst = gsub(baseInst, "-", "%%-")
    if baseInst and match(curInst, baseInst) then
      curInst = gsub(curInst, baseInst, "")
      local index = find(curInst, "%.")
      if index and curInst then
        local instVal = curInst:sub(0, index - 1)
        if instVal then
          instVal = gsub(instVal, "%.", "")
          baseInst = gsub(baseInst, "%%", "")
          return baseInst, instVal
        end
      end
    end
  end
end

--- Retrieves and adds the values for every dynamic variable in the response.
-- @function addDynVarValue
-- @param rspParam parameter from mqtt request.
-- @param dataPath DM path for the requested parameter
-- @param reqParamWords No.of mid parameters in DM path.
-- @param dmResult Table to store the response.
-- @return dmResult
local function addDynVarValue(rspParam, dataPath, reqParamWords, dmResult)
  local parameter, path = rspParam, dataPath
  -- Instance values for multiple variables are fetched by parsing the parameter and dataPath with dots.
  for i = 1, reqParamWords do
    local paramIdx = find(parameter, "%.")
    local pathIdx = find(path, "%.")
    if not paramIdx or not pathIdx then
      break
    end
    local instVar = sub(parameter, 1, paramIdx - 1)
    local instVal = sub(path, 1, pathIdx - 1)
    if not match(instVar, instVal) then
      dmResult[dataPath][instVar] = instVal
    end
    parameter = sub(parameter, paramIdx + 1)
    path = sub(path, pathIdx + 1)
  end
  return dmResult
end

--- Frames response for non-assignment/ non-comparison request with multiple dynamic variables.
-- @function frameMultipleVarResponse
-- @param rspParams Get request paramters from cloud.
-- @param result Table to store get response status.
-- @compParam Table of requested dm parameter with comparison value or variable.
-- @return result Table with status code and error message if any.
-- @return response Table with value of requested parameters.
-- @return true To indicate that the each parameter output with instances are unique.
local function frameMultipleVarResponse(rspParams, result, compParam)
  log:debug("Request with multiple dynamic variables")
  local dmResult = {}
  local response = {}
  local firstParam = true
  local assignVal = {}
  for _, rsp in pairs(rspParams or {}) do
    local paramsAvailable, cVal, assignVar
    if rsp.parameter then
      -- Check for parameter with assignment variable.
      if match(rsp.parameter, "%s%=%s") then
        -- Retrieves the parameter and assignment variable from rsp.parameter.
        -- Eg. 'sys.hosts.host.$id.MACAddress' and '$mac' will be retrieved from rsp.parameter 'sys.hosts.host.$id.MACAddress = $mac'.
        rsp.parameter, assignVar = match(rsp.parameter, "^(%S*)%s%=%s(%S*)$")
        assignVal[assignVar] = rsp.apiParameter
      else
        cVal = compParam and compParam[rsp.parameter]
      end
      local index = find(rsp.parameter, "%$" )
      -- Retrieve the base path i.e without dynamic variables and parameter name.
      -- Eg: basePath will be 'Device.WiFi.MultiAP.APDevice.' for the rsp.parameter 'Device.WiFi.MultiAP.APDevice.$agent.radio.$id.Channel'
      local basePath = index and sub(rsp.parameter, 1, index - 1) or match(rsp.parameter, "^(%S*%.)%S*$")
      -- Retrieve the parameter name from the dm path requuested.
      -- Eg: param will be 'Channel' for the path 'Device.WiFi.MultiAP.APDevice.$agent.radio.$id.Channel'
      local param = match(rsp.parameter, "^%S*%.(%S*)$")
      -- Dynamic variables are replaced with string pattern match.
      -- This pattern is used to fetch exact path and value from dm data.
      local instPattern = gsub(rsp.parameter, "%$%w*", "%%S*")
      local _, errMsg
      if basePath then
        _, errMsg = getDMData(basePath)
      else
        errMsg = "Basepath is nil for the rsp.parameter " .. rsp.parameter
      end
      if errMsg then
        log:error("Get request of '" ..rsp.parameter .."' failed with error:" ..errMsg)
        result.status = mqtt_lookup.mqtt_constants.getError
        result.error = errMsg
        break
      else
        result.status = mqtt_lookup.mqtt_constants.successCode
      end
      for _, data in pairs(dmData[basePath] or {}) do
        if data.path and data.param and data.param == param and match(data.path .. data.param, instPattern) then
          local _, reqParamWords = gsub(rsp.parameter, "%.", "%.")
          local _, gwParamWords = gsub(data.path .. data.param, "%.", "%.")
          if reqParamWords == gwParamWords then
            if (firstParam and match(rsp.parameter, "%$id")) or (cVal and assignVal[cVal]) then
              if not cVal or (cVal and cVal == data.value) then
                dmResult[data.path] = {}
                dmResult[data.path][rsp.apiParameter] = {
                  gwParameter = data.path .. data.param,
                  value = data.value
                }
                paramsAvailable = true
                dmResult = addDynVarValue(rsp.parameter, data.path, reqParamWords, dmResult)
              elseif cVal and assignVal[cVal] then
                for path in pairs(dmResult) do
                  if dmResult[path][assignVal[cVal]] and dmResult[path][assignVal[cVal]]["value"] and dmResult[path][assignVal[cVal]]["value"] == data.value then
                    if data.path ~= path then
                      dmResult[data.path] = {}
                      dmResult[data.path] = dmResult[path]
                      dmResult[path] = nil
                    end
                    dmResult[data.path][rsp.apiParameter] = {
                      gwParameter = data.path .. data.param,
                      value = data.value
                    }
                    paramsAvailable = true
                    dmResult = addDynVarValue(rsp.parameter, data.path, reqParamWords, dmResult)
                  end
                end
              end
            else
              for path in pairs(dmResult) do
                if match(path, data.path) then
                  dmResult[path][rsp.apiParameter] = {
                    gwParameter = data.path .. data.param,
                    value = data.value
                  }
                  paramsAvailable = true
                end
              end
            end
          end
        end
      end
      firstParam = false
      if not paramsAvailable then
        unavailableParams[ #unavailableParams + 1 ] = rsp.parameter
      end
    end
  end
  for _, value in pairs(dmResult) do
    response[ #response + 1 ] = value
  end
  return result, response, true
end

--- Gets the Parameter Value for Non Assginment/Comparison Request
-- @function getParamValue
-- @param rspParams Get request paramters from cloud.
-- @param parameters Table to store value of requested parameters.
-- @return result Table with status code and error message if any.
-- @return parameters Table with value of requested parameters.
local function getParamValue(rspParams, parameters)
  log:debug('Non Assginment/Comparison Request')
  local result = {}
  local instVariable = {}
  local directPathParams = {} -- To store Param data for rspParams which doesn't have "$id" in it, like "sys.time.CurrentLocalTime"
  firstParam = true
  firstInstanceTable = {}
  for _, rsp in pairs(rspParams or {}) do
    if rsp.parameter and match(rsp.parameter, "%$id") then
      -- Retrieve the path from the rsp.parameter till last dynamic variable.
      -- Eg 1: baseInst will be 'Device.WiFi.MultiAP.APDevice.$agent.Radio.$radio.AP.' for the rsp.parameter 'Device.WiFi.MultiAP.APDevice.$agent.Radio.$radio.AP.$id.SSID'
      -- Eg 2: baseInst will be 'Device.WiFi.MultiAP.APDevice.' for the rsp.parameter 'Device.WiFi.MultiAP.APDevice.$id.MACAddress'
      local baseInst = match(rsp.parameter, "^(%S*)%$")
      -- Check whether baseInst again have dynamic variable (Eg: $radio) in it to confirm mqtt get request with multiple dynamic variables.
      if match(baseInst, "^%S*%.%$%S*$") then
        -- Request with multiple dynamic variables.
        -- Eg: Device.WiFi.MultiAP.APDevice.$agent.Radio.$radio.AP.$ap.AssociatedDevice.$id.MACAddress
        return frameMultipleVarResponse(rspParams, result)
      end
      instVariable[baseInst] = "$id"
    end
    if rsp.parameter and match(rsp.parameter, "%=") then
      result.status = mqtt_lookup.mqtt_constants.getError
      break
    elseif rsp.parameter and rsp.apiParameter then
      log:debug("Get request for : "..tostring(rsp.parameter))
      local pPath, midPath, pParam
      if match(rsp.parameter, "%[%]") then
        pPath, midPath, pParam = match(rsp.parameter, "^(%S*%.)%$id%.(%S*)%[%]%.(%S*)$")
      elseif match(rsp.parameter, "%$id") then
        pPath, pParam = match(rsp.parameter, "^(%S*%.)%$id*%.(%S*)$")
        if not pPath and not pParam then
          return
        end
        if match(pParam, "%.") then
          midPath, pParam = match(pParam, "^(%S*)%.(%S*)$")
        end
      end
      if pPath and pParam then
        -- Partial Path getter request for rsp.parameter
        local _, errMsg = getMultiInstanceValues(pPath, midPath, pParam, rsp.apiParameter, nil, rsp.parameter)
        if errMsg then
          result.status = mqtt_lookup.mqtt_constants.getError
          result.error = errMsg
          break
        else
          result.status = mqtt_lookup.mqtt_constants.successCode
        end
      else
        local dmResult, errMsg
        if match(rsp.parameter, "%[%]") then
          -- Array of Parameters are available for rsp.parameter
          local pPath, pParam = match(rsp.parameter, "^(%S*)%[%]%.(%S*)$")
          dmResult, errMsg = getArrayValues(pPath, pParam)
          if dmResult and next(dmResult) then
            directPathParams[rsp.apiParameter] = dmResult
            result.status = mqtt_lookup.mqtt_constants.successCode
          end
        else
          dmResult, errMsg = proxy.get(rsp.parameter)
          if dmResult and dmResult[1] and dmResult[1].value then
            directPathParams[rsp.apiParameter] = {
              gwParameter = rsp.parameter,
              value = dmResult[1].value
            }
            result.status = mqtt_lookup.mqtt_constants.successCode
          end
        end
        if errMsg then
          result.error = errMsg
          result.status = mqtt_lookup.mqtt_constants.getError
          break
        end
      end
    end
    firstParam = false
  end

  if next(partialParams) then
    for inst, pParams in pairs(partialParams) do
      if pParams and next(pParams) then
        for partialInst in pairs(partialPath or {}) do
          local instName, instValue = getInstanceValue(inst, partialInst)
          if instVariable[instName] then
            pParams[instVariable[instName]] = instValue
          end
        end
        for apiParam, pTable in pairs(directPathParams or {}) do
          if apiParam and next(pTable) then
            pParams[apiParam] = pTable
          end
        end
        parameters[ #parameters + 1 ] = pParams
      end
    end
  elseif not next(parameters) and next(directPathParams) then
    parameters = { directPathParams }
  end
  return result, parameters
end

-- Loads the required Datamodel Path
local function getRequiredInstances(rspParams)
  for _, rsp in pairs(rspParams or {}) do
    if rsp.parameter and (match(rsp.parameter, "%=") or match(rsp.parameter, "%$id")) then
      local basePath = rsp.parameter
      local basePathVar
      if match(basePath, "%=") then
        -- For parameter with assignment variable, retrieves only the dmpath requested.
        -- Eg: for rsp.parameter of "sys.hosts.host.$id.MACAddress = $mac", basePath will be "sys.hosts.host.$id.MACAddress".
        basePath = match(basePath, "^(%S*)%s%=%s%$")
        rsp.parameter = basePath
      end
      if match(basePath, "%$id") then
        -- For parameter with dynamic variable as '$id', retrieves only the base dmpath.
        -- Eg: for rsp.parameter of "sys.hosts.host.$id.MACAddress", basePath will be "sys.hosts.host.".
        basePath = match(basePath, "^(%S*%.)%$id[%S*]")
        basePathVar = "$id"
      end
      if basePath and basePathVar then
        local _, errMsg = getMultiInstanceValues(basePath, nil, nil, nil, basePathVar)
        if errMsg then
          return nil, errMsg
        end
      end
    end
  end
end

-- Gets the exact individual param
local function getIndividualParam(dmParam)
  local dmResult, errMsg = proxy.get(dmParam)
  -- When the errMsg contains "invalid instance" message,
  -- include the gwParameter field with the corresponding dmParam
  -- and value field as empty in the parameters table in the response
  if errMsg and not match(string.lower(errMsg), "invalid instance") then
    return nil, errMsg
  end
  local dmValue = {}
  dmValue['gwParameter'] = dmParam
  if dmResult and dmResult[1] and dmResult[1].value then
    dmValue['value'] = dmResult[1].value
  end
  return dmValue
end

-- Gets the required data for the basePath if not available
local function getInstances(basePath, basePathVar)
  if not partialPath[basePath] then
    partialPath[basePath] = true
    local _, errMsg = getMultiInstances(basePathVar)
    if errMsg then
      return nil, errMsg
    end
  end
end

-- Gets the count of dynamic variable, comparison value and
-- comaprison parameters in the comparison operation
local function dynamicVar(compParam)
  local varID = 0
  local count = 0
  local varVal = 0
  for cParam, cVal in pairs(compParam) do
    count = count + 1
    if cVal and find(cVal, "%$") then
      varID = varID + 1
    elseif cVal and not find(cVal, "%$") then
      varVal = varVal + 1
    end
  end
  return varID, varVal, count
end

-- Checks the multiple comparison operation for the arry-of-subvales
local function checkCompArrayParam(dmParam, cVal)
  local arrPath, arrParam = match(dmParam, "(%S*)%[%]%.(%S*)$")
  local cResult, errMsg = getArrayValues(arrPath, arrParam, cVal)
  if not(cResult) then
    return false
  elseif not errMsg then
    for _, cmpArrVal in pairs(cResult or {}) do
      if cmpArrVal and type(cmpArrVal) == "table" then
        for listParam, listVal in pairs(cmpArrVal) do
          if listParam == pParam and listVal ~= cVal then
            return false
          end
        end
      elseif cmpArrVal and type(cmpArrVal) == "string" then
        return false
      end
    end
  end
  return true
end

-- Checks the multiple comparison operation of the parameters
local function checkMultiCompParam(cParam, id, inst, cVal)
  local dmParam
  if id and find(cParam, id) and inst then
    dmParam = gsub(cParam, id, inst)
  end
  local cResult, errMsg
  if dmParam and match(dmParam, "%[]") then
    return checkCompArrayParam(dmParam, cVal)
  elseif dmParam then
    cResult, errMsg = getIndividualParam(dmParam)
    if cResult and next(cResult) and cResult.value ~= cVal then
      return false
    end
  end
  return true
end

-- Gets the basePath, from the multiple comparison opertion in a single request
local function checkMultipleComparison(compParam, id, inst, pPath, basePath, curParam)
  local varID, varVal, count = dynamicVar(compParam)
  if varID == count or (varID ~= varVal and varVal == 1) then
    return true
  end
  local retVal = true
  if not inst and basePath and pPath then
    if find(pPath, basePath) then
      inst = gsub(pPath, basePath, "")
    end
    if inst and find(inst, "%.") then
      inst = gsub(inst, "%.", "")
    end
  end
  for cParam, cVal in pairs(compParam or {}) do
    if not checkMultiCompParam(cParam, id, inst, cVal) then
      return false
    end
  end
  return true
end

-- Frames the Response for the Partial Path getter request with:
-- 1. Assignment Parameter and its dependent parameters
-- 2. Asignement and Comparison Parameters and their dependant parameters
local function frameAssignCompResponse(rspParams, assignParam, compParam)
  local parameters = {}
  local assignmentVar = {}
  local comparisonPath = {}
  local comparisonVar = {}
  local compVariable = {}
  for _, rsp in pairs(rspParams or {}) do
    local paramsAvailable
    if rsp.parameter and rsp.apiParameter then
      log:debug("Get request for : "..tostring(rsp.parameter))
      if not next(filteredInstances) then
        if not match(rsp.parameter, "%$")then
          local dmData, errMsg = getIndividualParam(rsp.parameter)
          if errMsg then
            return nil, errMsg
          end
          if dmData then
            if not parameters[rsp.parameter] then
              parameters[rsp.parameter] = {}
            end
            parameters[rsp.parameter][rsp.apiParameter] = dmData
            if assignParam[rsp.parameter] then
              assignmentVar[assignParam[rsp.parameter]] = parameters[rsp.parameter][rsp.apiParameter].value
              filteredInstances[ rsp.parameter ] = assignParam[rsp.parameter]
            end
            -- Check if the gwParameter field and value field available for the current rspParameter
            if dmData.gwParameter and dmData.value then
              paramsAvailable = true
            end
          end
        end
      end
      for inst, id in pairs(filteredInstances or {} ) do
        if checkMultipleComparison(compParam, id, inst) then
          if not parameters[inst] then
            parameters[inst] = {}
          end
          if match(rsp.parameter, "%$id") or not match(rsp.parameter, "%$")then
            local basePath, param = match(rsp.parameter, "^(%S*)%$id(%S*)$")
            local dmParam = rsp.parameter
            if basePath and inst and param then
              dmParam = basePath .. inst .. param
            end
            local dmData, errMsg
            if dmParam then
              dmData, errMsg = getIndividualParam(dmParam)
            end
            if errMsg then
              return nil, errMsg
            end
            if dmData then
              parameters[inst][rsp.apiParameter] = dmData
              if match(rsp.parameter, "%$id") then
                parameters[inst]["$id"] = inst
              end
              -- Check if the gwParameter field and value field available for the current rspParameter
              if dmData.gwParameter and dmData.value then
                paramsAvailable = true
              end
            end
            if parameters[inst] and parameters[inst][rsp.apiParameter] and parameters[inst][rsp.apiParameter].value then
              if compParam[rsp.parameter] then
                compVariable[inst .. compParam[rsp.parameter]] = parameters[inst][rsp.apiParameter].value
              end
              if assignParam[rsp.parameter] then
                assignmentVar[inst .. assignParam[rsp.parameter]] = parameters[inst][rsp.apiParameter].value
              end
            end
          else
            -- Assignment Parameter and Comparison Parameter getter
            local path, param = match(rsp.parameter, "^(%S*%.%$%S*%.)(%S*)")
            if path and comparisonVar[inst .. path] and param then
              -- Get the dependent parameters of the Comparison Parameter
              local dmParam = comparisonVar[inst ..path] .. param
              local dmData,errMsg
              if dmParam then
                dmData, errMsg = getIndividualParam(dmParam)
              end
              if errMsg then
                return nil, errMsg
              end
              if dmData then
                parameters[inst][rsp.apiParameter] = dmData
                -- Check if the gwParameter field and value field available for the current rspParameter
                if dmData.gwParameter and dmData.value then
                  paramsAvailable = true
                end
              end
            else
              -- Retrives the dynamic variable from requested parameter.
              -- Eg. 1: Retrieves only '$ap' from rsp.parameter "rpc.wireless.ap.$ap.public"
              -- Eg. 2: Retrieves dynamic variable along with midpath like '$ap.wps' for parameter "rpc.wireless.ap.$ap.wps.admin_state"
              local dynVar = match(rsp.parameter, "(%$%S*)%.%S*")
              if dynVar and match(dynVar, "%.") then
                -- Retrieves only dynamic variable excluding midpath.
                -- Eg: If dynVar has midpath in it like '$ap.wps', retrieves only '$ap'.
                dynVar = match(dynVar, "^(%$%S*)%.%S*")
              elseif not dynVar then
                local dmData, errMsg = getIndividualParam(rsp.parameter)
                if errMsg then
                  return nil, errMsg
                end
                if dmData and next(dmData) then
                  parameters[inst][rsp.apiParameter] = dmData
                  -- Check if the gwParameter field and value field available for the current rspParameter
                  if dmData.gwParameter and dmData.value then
                    paramsAvailable = true
                  end
                end
              end
              if dynVar then
                if assignmentVar[ inst .. dynVar] then
                  -- Get the Assignment Parameter matching the given value
                  -- Retrieves the base path and parameter from the dm path requested.
                  -- Eg: basePath will be 'rpc.wireless.ap.' and param will be 'public' for rsp.parameter "rpc.wireless.ap.$ap.public".
                  local basePath, param = match(rsp.parameter, "^(%S*)%$%S*%.(%S*)$")
                  local dmParam
                  if basePath and assignmentVar[inst .. dynVar] ~= "" and param then
                    if basePath == "" then
                      dmParam = assignmentVar[inst .. dynVar] .. "." .. param
                    else
                      dmParam = basePath .. "@" .. assignmentVar[inst .. dynVar] .. "." .. param
                    end
                  end
                  local dmData, errMsg
                  if dmParam then
                    dmData, errMsg = getIndividualParam(dmParam)
                  end
                  if errMsg then
                    return nil, errMsg
                  end
                  if dmData then
                    parameters[inst][rsp.apiParameter] = dmData
                    if find(assignmentVar[ inst .. dynVar], "%.") then
                      parameters[inst][dynVar] = assignmentVar[ inst .. dynVar]
                    else
                      parameters[inst][dynVar] = "@" .. assignmentVar[ inst .. dynVar]
                    end
                    -- Check if the gwParameter field and value field available for the current rspParameter
                    if dmData.gwParameter and dmData.value then
                      paramsAvailable = true
                      if assignParam[rsp.parameter] then
                        assignmentVar[inst .. assignParam[rsp.parameter]] = dmData.value
                        filteredInstances[ dmData.gwParameter ] = assignParam[rsp.parameter]
                      end
                    end
                  end
                elseif compParam[rsp.parameter] then
                  -- Get request for Comparison Parameter matching the value of the given Comparison Variable
                  local basePath, midPath, param = match(rsp.parameter, "^(%S*)%$(%S*)%.(%S*)$")
                  if midPath and find(midPath, "%.") then
                    -- If rsp.parameter like "uci.tod.host.$id.weekdays.[].value" then
                    -- basePath = 'uci.tod.host.', midPath = 'id.weekdays.', param = 'value'
                    -- but we need midPath to be 'weekdays' only.
                    midPath = match(midPath, "[%.](.*)")
                  end
                  local _, errMsg = basePath and getInstances(basePath)
                  if errMsg then
                    return nil, errMsg
                  end
                  for _, data in pairs(dmData[basePath] or {}) do
                    if data.path and basePath and match(data.path, basePath) and param == data.param then
                      local path = match(rsp.parameter, "^(%S*%$%S*%.)(%S*)$")
                      if (inst and find(inst, "@") and data.value and inst == "@" .. data.value) or inst == data.value then
                        if path then
                          comparisonVar[ inst .. path ] = data.path
                        end
                      comparisonPath[inst] = data.path
                        local dmData, errMsg = getIndividualParam(data.path .. data.param)
                        if errMsg then
                          return nil, errMsg
                        end
                        if dmData then
                          parameters[inst][rsp.apiParameter] = dmData
                          parameters[inst][dynVar] = match(data.path, "%S*%.(%S*)%.$")
                          -- Check if the gwParameter field and value field available for the current rspParameter
                          if dmData.gwParameter and dmData.value then
                            paramsAvailable = true
                          end
                          break
                        end
                      else
                        for compData, compVal in pairs(compVariable) do
                          if (compParam[rsp.parameter] and compData == inst .. compParam[rsp.parameter]) and compVal and data.value == compVal then
                            local dmData, errMsg = getIndividualParam(data.path .. data.param)
                            if errMsg then
                              return nil, errMsg
                            end
                            if dmData then
                              if path then
                                comparisonVar[ inst .. path ] = data.path
                              end
                              comparisonPath[inst] = data.path
                              parameters[inst][rsp.apiParameter] = dmData
                              if midPath and data.path and basePath then
                                local instValue = gsub(data.path, basePath, "")
                                instValue = instValue and gsub(instValue, midPath, "")
                                instValue = instValue and gsub(instValue, "%.", "")
	                        if instValue then
                                  parameters[inst][dynVar] = instValue
                                end
                              end
                              -- Check if the gwParameter field and value field available for the current rspParameter
                              if dmData.gwParameter and dmData.value then
                                paramsAvailable = true
                              end
                              break
                            end
                          end
                        end
                      end
                    end
                  end
                else
                  -- Get the dependent Parameters of the Comparsion Parameter available with Sub-Paths
                  if rsp.parameter then
                    local basePath, midPath, param = match(rsp.parameter, "^(%S*)(%$%S*%.)(%S*)$")
                    local dmData, errMsg
                    if midPath and find(midPath, "%[%]") then
                      midPath = match(midPath, "^%$%S*%.(%S*%.)%[%]%.%S*$")
                      if comparisonPath[inst] and midPath and param then
                        dmData, errMsg = getArrayValues(comparisonPath[inst] .. midPath, param)
                      end
                    elseif midPath then
                      midPath = match(midPath, "^%$%S*%.(%S*%.)$")
                      local dmParam
                      if comparisonPath[inst] and midPath and param then
                        dmParam = comparisonPath[inst] .. midPath .. param
                      end
                      if dmParam then
                        dmData, errMsg = getIndividualParam(dmParam)
                      end
                    end
                    if errMsg then
                      return nil, errMsg
                    end
                    if dmData and next(dmData) then
                      parameters[inst][rsp.apiParameter] = dmData
                      -- Check if the gwParameter field and value field available for the current rspParameter
                      if dmData.gwParameter and dmData.value then
                        -- Data availability check for the array of sub-values rspParameter
                        paramsAvailable = true
                      elseif not dmData.gwParameter and not dmData.value and next(dmData) then
                        -- Data availability check for the non array of sub-values rspParameter
                        for _, arrParams in pairs(dmData) do
                          if arrParams and arrParams.gwParameter and arrParams.value then
                            paramsAvailable = true
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    if not paramsAvailable then
      unavailableParams[ #unavailableParams + 1] = rsp.parameter
    end
  end
  local params = {}
  for _, v in pairs(parameters) do
    params[ #params + 1 ] = next(v) and v
  end
  return params
end

-- Verifies the availabitlity of exact value or dependent variable for Comparison parameter
local function checkCompareParam(compParam)
  if next(compParam) then
    for _, val in pairs(compParam) do
      if find(val, "%$") then
        return
      end
    end
    return true
  end
end

-- Frames the response for the comparison parameters,
-- when the Comparison value is directly given
local function frameCompareParams(rspParams, compParam)
  local parameters = {}
  local instName = {}
  local reqInstPath = {}
  local instVariable = {}
  local directPathParams = {} -- To store Param data for rspParams which doesn't have "$id" in it, like "sys.time.CurrentLocalTime"
  for cParam, cVal in pairs(compParam) do
    local errMsg
    if cParam and not match(cParam, "%$id") then
      return nil, "Check the given Parameters"
    end
    local basePath, pParam = match(cParam, "^(%S*)%$id%.(%S*)$")
    local dmVal
    if basePath then
      dmVal, errMsg = getInstances(basePath)
      instVariable[basePath] = "$id"
    end
    if errMsg then
      return nil, errMsg
    end
    local midPath
    if pParam and find(pParam, "%[]") then
      midPath, pParam = match(pParam, "^(%S*)%[]%.(%S*)$")
    end
    for _, data in pairs(dmData[basePath]) do
      if data.path and data.param == pParam and data.value == cVal then
        if midPath then
	  -- For Comparison operation on array of subvalues param like 'uci.tod.host.$id.weekdays.[].value == Fri',
	  -- yields the value for data.path to be "uci.tod.host.@ASDF.weekdays.@XYZ." as a result of proxy.get().
	  -- But, for the other dependant params, we need data.path value to be "uci.tod.host.@ASDF.",
	  -- so trimming of the obtained data.path is handled here, where midPath would be value like "weekdays"
          local index = find(data.path, midPath)
	  if index then
            data.path = data.path:sub(0, index - 1)
	  end
        end
        if data.path and checkMultipleComparison(compParam, instVariable[basePath], nil, data.path, basePath, pParam) then
          reqInstPath[data.path] = true
          local _, instValue = getInstanceValue(data.path, basePath)
	  if instValue then
            instName[data.path] = instValue
          end
        end
      end
    end
  end

  for _, rsp in pairs(rspParams or {}) do
    local paramsAvailable
    if rsp.parameter and rsp.apiParameter then
      log:debug("Get request for : "..tostring(rsp.parameter))
      if match(rsp.parameter, "%$id") then
        if next(reqInstPath) then
          for inst in pairs(reqInstPath) do
            local pPath, pParam = match(rsp.parameter, "^(%S*)%$id%.(%S*)$")
            if pParam then
              local dmPath = inst .. pParam
              local dmData, errMsg
              if dmPath and match(dmPath, "%[%]") then
                local arrayPath, arrayParam = match(dmPath, "^(%S*)%[%]%.(%S*)$")
                local arrayData, arrayErr = getArrayValues(arrayPath, arrayParam, compParam[rsp.parameter])
                if arrayData and next(arrayData) then
                  dmData = arrayData
                elseif arrayErr then
                  errMsg = arrayErr
                end
              elseif dmPath then
                dmData, errMsg = getIndividualParam(dmPath)
              end
              if errMsg then
                return nil, errMsg
              else
                if not parameters[inst] then
                  parameters[inst] = {}
                end
                if dmData then
                  parameters[inst][rsp.apiParameter] = dmData
                  parameters[inst][instVariable[pPath]] = instName[inst]
                  -- Check if the gwParameter field and value field available for the current rspParameter
                  if dmPath and match(dmPath, "%[%]") then
                    -- Data availability check for the array of sub-values rspParameter
                    if dmData and next(dmData) then
                      for _, arrayParams in pairs(dmData) do
                         if type(arrayParams) == "table" and arrayParams.gwParameter and arrayParams.value then
                           paramsAvailable = true
                        end
                      end
                    end
                  else
                    -- Data availability check for the non array of sub-values rspParameter
                    if dmData.gwParameter and dmData.value then
                      paramsAvailable = true
                    end
                  end
                end
              end
            end
          end
        else
          return
        end
      else
        local dmData, errMsg = getIndividualParam(rsp.parameter)
        if errMsg then
          return nil, errMsg
        end
        if dmData then
          directPathParams[rsp.apiParameter] =  dmData
          -- Check if the gwParameter and value field available for the current rspParameter
          if dmData.gwParameter and dmData.value then
            paramsAvailable = true
          end
        end
      end
    end
    if not paramsAvailable then
      unavailableParams[ #unavailableParams + 1] = rsp.parameter
    end
  end

  local params = {}
  if next(parameters) then
    for _, data in pairs(parameters) do
      if next(directPathParams) then
        for apiParam, pTable in pairs(directPathParams) do
          data[apiParam] = pTable
        end
      end
      params[ #params + 1 ] = next(data) and data
    end
  elseif not(parameters) and next(directPathParams) then
    params = directPathParams
  end
  return params
end

-- Gets the value for Assignemt and Comparison Parameter and its related Parameters
local function getAssignCompValue(rspParams, assignParam, compParam)
  log:debug('Assignemt and Comparison Request')
  local result = {}
  local parameters = {}
  local errMsg

  -- Check for multiple dynamic variables in requested parameter.
  for _, rsp in pairs(rspParams or {}) do
    if rsp.parameter and match(rsp.parameter, "%$") then
      -- Checks if parameter has multiple dynamic variables i.e variable with $.
      -- Eg: Device.WiFi.MultiAP.APDevice.$agent.Radio.$radio.AP.$ap.AssociatedDevice.$id.MACAddress
      local baseInst = match(rsp.parameter, "^(%S*)%.%$")
      if baseInst and match(baseInst, "^%S*%.%$%S*$") then
        return frameMultipleVarResponse(rspParams, result, compParam)
      end
    end
  end

  local _, errMsg = getRequiredInstances(rspParams)
  if errMsg then
    result.status = mqtt_lookup.mqtt_constants.getError
    result.error = errMsg
    return result, parameters
  end

  if checkCompareParam(compParam) then
    -- Frames the response, when the Comparison Parameters with its exact value and related Parameters are available
    parameters, errMsg = frameCompareParams(rspParams, compParam)
  else
    -- Frames the response, when Assignment Parameters, Assignment and Comparison Parameters with dependent variable are present
    parameters, errMsg = frameAssignCompResponse(rspParams, assignParam, compParam)
  end
  if errMsg then
    result.status = mqtt_lookup.mqtt_constants.getError
    result.error = errMsg
  else
    result.status = mqtt_lookup.mqtt_constants.successCode
  end
  return result, parameters
end

-- Checks if the value of "$id" is duplicated
local function checkDuplicate(curParam, curVal, curInst, parameters)
  for inst, pTable in pairs(parameters) do
    if inst ~= curInst then
      for apiParam, apiVal in pairs(pTable or {}) do
        if apiParam == curParam and apiVal == curVal then
          return inst
        end
      end
    end
  end
end

-- Checks the duplicate values for base-object's instance value(like value for "$id" or "*")
-- and combines those objects, if they are duplicated
local function combineDuplicateObjects(parameters, basePathVariable)
  local params = {}
  if next(parameters) then
    for curInst, pTable in pairs(parameters) do
      for pIndex, pValue in pairs(pTable or {}) do
        if type(pValue) == "string" and pIndex == basePathVariable then
          local duplicateInst = checkDuplicate(pIndex, pValue, curInst, parameters)
          if duplicateInst then
            for duplicateIndex, duplicateParams in pairs(parameters[duplicateInst] or {}) do
              parameters[curInst][duplicateIndex] = {}
              parameters[curInst][duplicateIndex] = duplicateParams
            end
            parameters[duplicateInst] = {}
          end
        end
      end
    end
    for _, dmData in pairs(parameters) do
      if next(dmData) then
        params[ #params + 1 ] = dmData
      end
    end
  end
  return params
end

-- Checks if any of the request parameter contains "*" - Dynamic Character
local function updateRequestParam(paramTable)
  local dynCharParam = {}
  for rspIndex, rspTable in pairs(paramTable) do
    for rspName, rspValue in pairs(rspTable) do
      if rspName == "parameter" and find(rspValue, "[%*]") then
        dynCharParam[rspValue] = "*"
      end
    end
  end
  return dynCharParam
end

-- Gets the required instances for the basePath
-- and returns the Object's instance Values
local function getInstanceValues(basePathParam)
  local basePath, midPath, instVar, pParam = match(basePathParam, "([%w-.]+)[*]([%w-.]+)([$%w]+)(.*)")
  pParam = pParam and gsub(pParam, "%.", "")
  local objValues = {}
  if basePath and midPath and pParam then
    local _, errMsg = getDMData(basePath)
    if errMsg then
      return nil, errMsg
    else
      for _, data in pairs(dmData[basePath] or {}) do
        if data.param == pParam and match(data.path, basePath) and match(data.path, midPath) then
          local instValue = gsub(data.path, basePath, "")
          local index = instValue and find(instValue, midPath)
          instValue = instValue and instValue:sub(0, index - 1)
          if instValue then
            objValues[instValue] = true
          end
        end
      end
    end
  end
  return objValues
end

-- Replaces the Dynamic Character(like '*'), with the basepath's object value
local function updateInstace(rspParam, rspVariable, apiParam)
  local updatedParam = {}
  if rspParam then
    local instValues = getInstanceValues(rspParam)
    for inst in pairs(instValues or {}) do
      if inst and rspVariable and apiParam then
        local gwParameter = gsub(rspParam, rspVariable, inst)
        if gwParameter then
          updatedParam[ #updatedParam + 1 ] = {
            ["parameter"] = gwParameter,
            ["apiParameter"] = apiParam
          }
        end
      end
    end
  end
  return updatedParam
end

-- Function to check whether the whiteListParams are depended on blackListParams.
local function dependencyCheck(blackListParams)
 for _, rspParam in pairs(blackListParams or {}) do
   if rspParam then
     unavailableParams[ #unavailableParams + 1] = rspParam
     if match(rspParam, "%==") or match(rspParam, "%=") then
       return false
     end
   end
 end
 return true
end

-- Function to split Whitelist and Blacklist Params from Payload recieved and to update the payload(rsp-parameters) with whitelist params alone.
local function splitParams(rspParams, whiteListParams, blackListParams)
  local data = {}
  for parameter, rsp in pairs(rspParams or {}) do
    if rsp.parameter then
      data.status = mqtt_lookup.mqttcommon.isWhiteListed(rsp.parameter, mqtt_lookup.config.responseWhiteList)
      if data.status == mqtt_lookup.mqtt_constants.successCode then
        whiteListParams[ #whiteListParams + 1] = rsp.parameter
      elseif data.status == mqtt_lookup.mqtt_constants.generalError then
        blackListParams[ #blackListParams + 1 ] = rsp.parameter
        rspParams[parameter] = nil
      end
    end
  end
  return rspParams, whiteListParams, blackListParams
end

--- Handles the both request and response message
-- i.e., if the request contain the request type as "get" then the datamodel get operation is performed and then the necessary response is framed.
-- Also for the set/add/del request, frames the necessary successful/error response message.
-- @function frameResponse
-- @param payload Request Message from cloud.
-- @param reqStatus request status returned from handleRequest(payload) function.
-- @return table
function M.frameResponse(lookup, payload, reqStatus)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  local result = {}
  result.parameters = {}
  if not payload then
    log:warning("Payload is empty")
    result.error = "Given parameter or input format is Incorrect"
    return result
  end
  result.requestId = payload.requestId
  result.status = reqStatus.status or mqtt_lookup.mqtt_constants.generalError

  if reqStatus.errMsg then
    log:error('Error on Setter Request')
    result.error = reqStatus.errMsg
    return result
  end

  local getStatus
  if not mqtt_lookup.mqtt_constants.requestCodes[tostring(reqStatus.status)] and payload["rsp-parameter"] then
    local whiteListParams = {}
    local blackListParams = {}
    local blackListDependancy = true
    local uniqueInst
    if mqtt_lookup.config.disableWhiteList == 0 then
      payload["rsp-parameter"], whiteListParams, blackListParams = splitParams(payload["rsp-parameter"], whiteListParams, blackListParams)
      if next(blackListParams) then
        blackListDependancy = dependencyCheck(blackListParams)
      end
    end

    if blackListDependancy and payload["rsp-parameter"] then
      local parameters = {}
      log:debug('Getter Request')
      -- Check if rsp-parameter contains the assignment or comparison operation in it
      local assignParam, compParam = checkAssignComp(payload["rsp-parameter"])
      local basePathVariable = "$id"
      if (assignParam and next(assignParam)) or (compParam and next(compParam)) then
        getStatus, parameters, uniqueInst = getAssignCompValue(payload["rsp-parameter"], assignParam, compParam)
      else
        local dynamicCharParams = updateRequestParam(payload["rsp-parameter"])
        local updatedRSPParams = {}
        for _, rsp in pairs(payload["rsp-parameter"] or {}) do
          if rsp.parameter and dynamicCharParams[rsp.parameter] and rsp.apiParameter then
            basePathVariable = dynamicCharParams[rsp.parameter]
            local modifiedRSP = updateInstace(rsp.parameter, dynamicCharParams[rsp.parameter], rsp.apiParameter)
            if next(modifiedRSP) then
              for _, param in pairs(modifiedRSP) do
                updatedRSPParams[ #updatedRSPParams + 1 ] = param
              end
            end
          elseif rsp.parameter and rsp.apiParameter then
            updatedRSPParams[ #updatedRSPParams + 1 ] = rsp
          end
        end
        getStatus, parameters, uniqueInst = getParamValue(updatedRSPParams, parameters)
      end
      if parameters and next(parameters) and getStatus.status == mqtt_lookup.mqtt_constants.successCode then
        result.parameters = uniqueInst and parameters or combineDuplicateObjects(parameters, basePathVariable)
      elseif getStatus and getStatus.error then
        log:error('Error on Getter Request')
        result.error = getStatus.error
      end
      if next(unavailableParams) then
        local errMsg = "Non-Existing/BlackList Parameter(s): ".. table.concat(unavailableParams, ", ")
        result.error = result.error and result.error or errMsg
        if not getStatus.status then
          getStatus.status = mqtt_lookup.mqtt_constants.getError
        elseif getStatus.status == mqtt_lookup.mqtt_constants.successCode then
          getStatus.status = mqtt_lookup.mqtt_constants.partialGetError
        end
      end
    end
  end
  result.status = getStatus and getStatus.status or result.status
  if mqtt_lookup.mqtt_constants.requestCodes[tostring(result.status)] then
    result.error = result.error or "Given parameter or input format is Incorrect"
    log:warning(result.error)
  end
  -- To empty the cached data
  dmData = {}
  instances = {}
  partialPath = {}
  partialParams = {}
  filteredInstances = {}
  unavailableParams = {}
  return result
end

return M
