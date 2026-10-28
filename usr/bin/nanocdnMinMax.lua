#!/usr/bin/env lua

local match , gsub = string.match, string.gsub
local proxy = require("datamodel")
local process = require("tch.process")
local sessionNumber = {}
local multicastBitrate = {}
local enabled = proxy.get("uci.system.mabr.enabled")[1].value

local function fileWrite(minOrMax, value)
   local file = io.open("/tmp/"..minOrMax, "w")
   file:write(value)
   file:close()
end

local function findingMinValue(tableValue)
  local key = next(tableValue)
  local min = tableValue[key]
  for index, value in pairs(tableValue) do
    if tonumber(tableValue[index]) < tonumber(min) then
      min = value
    end
  end
  return min
end

local function findingMaxValue(tableValue)
  local key = next(tableValue)
  local max = tableValue[key]
  for index, value in pairs(tableValue) do
    if tonumber(tableValue[index]) > tonumber(max) then
       max = value
    end
  end
  return max
end

local function main()
  if enabled == "1" then
    local count = 1
    repeat
      os.execute("rm -f /tmp/nanocdnstatus.xml")
      os.execute("wget http://192.168.1.1:18081/nanocdnstatus.xml -P /tmp/")
      local output = io.open("/tmp/nanocdnstatus.xml", "r")
      if output then
        for line in output:lines() do
          local startTag = line:match('<(%S+)')
          local remVal = line:gsub('<(%S+)', "")
          for index, value in remVal:gmatch('%s(%S+)%=%"(%-?%d+)%"') do
            local param = startTag..index
            if param == "sessionsnumber" then
              sessionNumber[count] = value
            elseif param == "multicastsbitrate" then
              multicastBitrate[count] = value
            end
          end
        end
        fileWrite("minSession", findingMinValue(sessionNumber))
        fileWrite("maxSession", findingMaxValue(sessionNumber))
        fileWrite("minBitRate", findingMinValue(multicastBitrate))
        fileWrite("maxBitRate", findingMaxValue(multicastBitrate))
        process.execute("sleep", {"60"})
        if count >= 15 then
          count = 1
        else
          count = count + 1
        end
      end
    until(proxy.get("uci.system.mabr.enabled")[1].value == "0")
  end
end

main()
