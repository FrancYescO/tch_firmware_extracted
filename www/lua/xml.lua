local M = {}
local proxy = require("datamodel")
local table, string, tonumber, tostring, ipairs, pairs, open = table, string, tonumber, tostring, ipairs, pairs, io.open
local xmlStr = ""

-- The param of the node name for single object query(the default value is Device).
local configurationData = "Device"

-- Read the template of xml
local function readXmlTemplate(xmlType)
  local src
  local schemaPath= "/www/snippets/TIWLS_schema.xml"
  if xmlType == "widget" then
    schemaPath = "/www/snippets/TIWLS_widget_schema.xml"
  end
  -- read the whole contents of the xml file
  local fh = open (schemaPath)
  if fh then
    src = fh:read("*a")
    fh:close()
  end
  return src
end

-- Set the value of session variable "configurationData"
local function setConfigurationData(value)
  if value then
    configurationData = value
  end
end

-- Generate the tag start
-- Ex: <name> or <name id="num">
local function generateTagStart(name, num)
  if num then
    return string.format("<%s id=\"%s\">", name, num)
  end
  return string.format("<%s>", name)
end

-- Generate the tag end
-- Ex: </name>
local function generateTagEnd(name)
  return string.format("</%s>", name)
end

-- To create the tag for params by path
-- Ex: <path><param>value</param></path>
-- or <path id="1"><param>value</param></path>
local function getTag(tagName, paramVal, num)
  local tagStart = generateTagStart(tagName, num)
  local tagEnd = generateTagEnd(tagName)
  local tagVal = string.format("<%s/>", tagName)
  if paramVal and paramVal ~= "" then
    tagVal = tagStart .. paramVal .. tagEnd
  end
  return tagVal
end

-- To get the multi instance path
local function getMultiPath_T(pathStr, realPath, xmlType)
  local stack = {}
  local path

  local str = string.gsub(realPath, "{i}", function() return "%d+" end)

  if xmlType then
    str = str ..".%d+"
  end

  local data = proxy.getPL(pathStr ..".")
  if data then
    for _, v in ipairs(data) do
      path = string.match(v.path, str)
      if path then
        stack[path] = path
      end
    end
  end
  return stack
end

-- To intergrate the groups of the path and params
local function setMultiObjects_T(path_T, param_T)
  local set = {}
  for _, v in pairs(path_T) do
    table.insert(set, {path=v, param=param_T})
  end
  return set
end

-- get all the multi instance groups
local function getMultiObjects_T(set)
  local path = set["path"]
  local param = set["param"]
  local xmlType = set["xmlType"]
  local pathStack, multiStack, tmpStack = {}, {}, {}
  local pathTop
  local count = string.find(path, "{i}")
  if not count then
    pathStack = getMultiPath_T(path, path, xmlType)
  else
    for s in string.gmatch(path, "[^.]+") do
      if s ~= "{i}" then
        if #pathStack>0 then
          for i in pairs(pathStack) do
            pathStack[i] = pathStack[i] ..".".. s
          end
        else
          table.insert(pathStack, s)
        end
      else
        while #pathStack>0 do
          pathTop = table.remove(pathStack)
          multiStack = getMultiPath_T(pathTop, path, xmlType)
        end
        pathStack = multiStack
        break
      end
    end
  end
  local objects_T = setMultiObjects_T(pathStack, param)
  return objects_T
end


-- get param tag by the data
local function getParamsTagByData(path, params_T)
  local paramStr, paramVal, paramName = "", "", ""
  local paramTmp
  local flag
  for _, name in ipairs(params_T) do
    local data = proxy.get(path .."." ..name)
    if data then
      paramVal = data[1].value

      -- handling xml escape characters
      paramVal = string.gsub(paramVal, "&", "&amp;")
      paramVal = string.gsub(paramVal, "<", "&lt;")
      paramVal = string.gsub(paramVal, ">", "&gt;")
      paramVal = string.gsub(paramVal, "\"", "&quot;")

      paramName = name
      paramTmp = getTag(paramName, string.untaint(paramVal))
      paramStr = paramStr .. paramTmp
    else
      paramTmp = getTag(name, "")
      paramStr = paramStr .. paramTmp
    end
  end
  return paramStr
end

-- Get the path start position of the xml, from left to right like aaa.bbb.1
-- Find the start position like <path> or <path id="num">
-- then find another start position like <pathChild> or <pathChild id="num">
local function getPathPositionStart(pathStack)
  local pathPosition, index, resultIdx = 1, 1, 1
  while index <= #pathStack do
    local path = pathStack[index]
    local tagStart = generateTagStart(path)
    --if it is multi object, the next child node is number
    if pathStack[index+1] and tonumber(pathStack[index+1]) then
      index = index + 1
      local nodeNum = pathStack[index]
      tagStart = generateTagStart(path, nodeNum)
    end
    resultIdx = index
    local posStart = string.find(xmlStr, tagStart, pathPosition)
    if not posStart or posStart<pathPosition then
      resultIdx = resultIdx - 1
      if tonumber(pathStack[index]) then
        resultIdx = resultIdx - 1
      end
      break
    end
    pathPosition = posStart
    index = index + 1
  end
  if pathPosition == 1 then
    pathPosition = nil
  end
  return resultIdx, pathPosition
end

-- Get the path end position of the xml
-- To find the pattern like "</path>" after the start position
local function getPathPositionEnd(path, pathStartPos)
  local pathTagEnd = generateTagEnd(path)
  return string.find(xmlStr, pathTagEnd, pathStartPos)
end

-- To find whether the path exist in the xml file
-- If unexist, return nil
local function findPath(pathTagStart, pathStartPos)
  return string.find(xmlStr, pathTagStart, pathStartPos)
end

-- Generate the xml
local function generateXml(pathStack, pathStr)
  local index, pathStartPos = getPathPositionStart(pathStack)
  local total = #pathStack
  while total>=index do
    if xmlStr ~= "" and total == index  then
      break
    end
    local parentPath = table.remove(pathStack)
    if not parentPath then
      break
    end
    total = total -1
    local nodeNum
    if tonumber(parentPath) then
      nodeNum = parentPath
      parentPath = table.remove(pathStack)
      total = total -1
    end
    local nextTagStart = generateTagStart(parentPath, nodeNum)
    local nextTagEnd = generateTagEnd(parentPath)
    pathStr = nextTagStart .. pathStr .. nextTagEnd
  end
  if xmlStr == "" then
    xmlStr = pathStr
    return
  end
  local path = table.remove(pathStack)
  if not path then
     path = "Device"
  end
  if tonumber(path) then
    path = table.remove(pathStack)
  end
  local pathEndPos = getPathPositionEnd(path, pathStartPos)
  if path == "Device" then
    local pathEndPosNext = pathEndPos + 1
    while pathEndPosNext do
      pathEndPosNext = getPathPositionEnd(path, pathEndPosNext)
      if pathEndPosNext then
        pathEndPos = pathEndPosNext
        pathEndPosNext = pathEndPosNext + 1
      end
    end
  end
  xmlStr = string.sub(xmlStr, 1, pathEndPos-1) .. pathStr .. string.sub(xmlStr, pathEndPos, #xmlStr)
end

-- Get data of the object to generate the xml file
-- The obj_T includes path and params as obj_T = {path=***,params={"***"...}}
local function getXmlByData(obj_T)
  local pathStr = ""
  local pathStack = {}
  local pathDetail = obj_T["path"]
  local params_T = obj_T["param"]

  -- process params as <param>val</param>
  pathStr = getParamsTagByData(pathDetail, params_T)
  for pathElem in string.gmatch(pathDetail, "[^.]+") do
    table.insert(pathStack, pathElem)
  end
  generateXml(pathStack, pathStr)
end

-- sort multi instance path
local function comparator(t1, t2)
  return string.lower(t1.path) < string.lower(t2.path)
end

-- Iterator Multi instance
local function iteratorMultiObj(multiObj_T)
  for _, obj_T in pairs(multiObj_T) do
    getXmlByData(obj_T)
  end
end

-- Iterator every object, including multi instance and single instance.
local function iteratorObjects(obj_T)
  local path = obj_T["path"]
  local isMultiObj = obj_T["xmlType"]
  if isMultiObj or path:find("{i}") then
    local multiObj_T = getMultiObjects_T(obj_T)
    table.sort(multiObj_T, comparator)
    iteratorMultiObj(multiObj_T)
  else
    getXmlByData(obj_T)
  end
end

-- Create the xml for the object groups
local function createXmlByObjects(objs)
  for _, obj_T in pairs(objs) do
    iteratorObjects(obj_T)
  end
end

local function parseargs(s, flag)
  local arg = {}
  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  if flag then
    return arg["base"]
  end
  if arg["id"] then
    return arg["name"]..".{"..arg["id"].."}"
  end
  return arg["name"]
end

local function collect(xmlType)
  local s = readXmlTemplate(xmlType)
  local ni, c, label, xarg, empty
  local i, j = 1, 1
  local xmlType = ""
  local stack, top, param, path  = {}, {}, {}, {}
  local isMulti
  while true do
    ni, j, c, label, xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
    if not ni then break end
      if label == "xs:extension" then
        if c ~= "/" then
          local arg = parseargs(xarg, true)
          isMulti = false
          if arg == "agcfg:istance_object" then
            isMulti = true
          end
        end
      elseif label == "xs:element" then
        if empty == "/" then    -- empty element tag
          local arg=parseargs(xarg)
          table.insert(param,arg)
        elseif c == "" then      -- start tag
          local arg = parseargs(xarg)
          table.insert(top,arg)
          local lastPath = ""
          if #path>0 then
            lastPath = path[#path].."."
          end
          table.insert(path, lastPath..arg)
        else    -- end tag
          if xmlType == "param" then
            local toclose = table.remove(top)
            table.insert(param, toclose)
            xmlType = ""
          else
            if #param>0 then
              local pathInfo = path[#path]
              local lastMultiIdx = string.find(pathInfo, ".{i}", (#pathInfo-4))
              if lastMultiIdx then
                pathInfo = string.sub(pathInfo, 1, (#pathInfo-4))
              end
              table.insert(stack, {path=pathInfo, param=param, xmlType=isMulti})
              param = {}
            end
          end
          table.remove(path)
        end
      elseif label == "xs:simpleType" then
        xmlType="param"
      elseif label == "xs:complexType" then
        if #param>0 and c~="/" then
          local pathInfo = path[#path-1]
          local lastMultiIdx = string.find(pathInfo, ".{i}", (#pathInfo-4))
          if lastMultiIdx then
            pathInfo = string.sub(pathInfo, 1, (#pathInfo-4))
          end
          table.insert(stack, {path=pathInfo, param=param, xmlType=isMulti})
          param = {}
        end
      end
      i = j+1
    end
  return stack
end

-- Write xml to /tmp/AGconfig.xml.
local function appendXml(xmlType)
  local xmlStart='<?xml version="1.0" encoding="UTF-8"?\>'
  local rootTag='<Device xmlns="http://www.telecomitalia.it/agconfig_agplus-m5"  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.telecomitalia.it/agconfig_agplus-m5" elementFormDefault="qualified" id="NewDataSet">'
  xmlStr = rootTag .. string.sub(xmlStr, 9, #xmlStr)
  return xmlStart ..tostring(xmlStr)
end

--Start to create xml .
function M.xmlCreate(objNode)
  local xmlType

  if objNode == "WidgetAssurance" then
    ObjNode = "Device"
    xmlType = "widget"
  end

  setConfigurationData(ObjNode)

  createXmlByObjects(collect(xmlType))

  local xmlStart = appendXml(xmlType)

  xmlStr = ""
  return xmlStart
end

return M
