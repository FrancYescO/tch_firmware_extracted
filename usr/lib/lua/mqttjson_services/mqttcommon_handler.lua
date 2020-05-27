-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.


-- This table contains the list of common functions used for the MQTT API's request/response interaction.
local M = {}

local statusCode = require("mqttjson_services.mqttAPIconstants")
local match, find, gsub, format = string.match, string.find, string.gsub, string.format

--Generates random key for new rule
--@returns 16 digit random key.
function M.getRandomKey()
  local bytes
  local key = ("%02X"):rep(8)
  local fd = io.open("/dev/urandom", "r")
  if fd then
    bytes = fd:read(8)
    fd:close()
  end
  return key:format(bytes:byte(1, 8)) or ""
end

-- Checks the values are equal or matched
function M.isEqual(val1, val2)
  if val1 and val2 then
    if (val1 == val2) or match(val1, val2) then
      return true
    elseif val2 and find(val2, "%-") then
      val2 = gsub(val2, "-", "%%-")
      if val1 and match(val1, val2) then
        return true
      end
    end
  end
end

-- Checks the given parameter is white-listed
function M.isWhiteListed(reqParam, whiteListParams)
  if reqParam then
    for _, dmPath in pairs(whiteListParams or {}) do
      if M.isEqual(reqParam, dmPath) then
        return statusCode.successCode
      end
    end
  end
  return statusCode.generalError, "Given parameter or input format is Incorrect"
end

-- Requiring special behaviour files from the path specified.
local lfs = require 'lfs'

--- Function to check mode of a file
-- @return file mode
local function fileType(fileName)
  return lfs.attributes(fileName, "mode")
end

-- Returns true if file is a hidden
local function hiddenFile(fileName)
  return fileName:match("^%.")
end

--- Function to list avalibale features(files) present in the path.
-- removes extension(.lua) from the file name.
-- @return table
function M.dirWalk(path)
  local featuresTable = {}
  if path then
    for fileName in lfs.dir(path) do
      if fileName and fileType(path .. fileName) == "file" and not hiddenFile(fileName) then
        featuresTable[#featuresTable + 1] = match(fileName, "^(%S*)(.lua)$")
      end
    end
  end
  return featuresTable
end

return M
