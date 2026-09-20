--- vodafone_helper module
--  @module vodafone_helper
--  @usage local vdf_helper = require('vodafone_helper')
--  @usage require('vodafone_helper')

local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local bit = require("bit")
local string, table = string, table
local math = math
local match, find, gmatch, format, lower, istainted = string.match, string.find, string.gmatch, string.format, string.lower, string.istainted
local concat = table.concat
local sort = table.sort
local tonumber = tonumber
local ipairs = ipairs
local M = {}
local intl = require("web.intl")
local function log_gettext_error(msg)
 ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext
local content_helper  =  require("web.content_helper")

gettext.textdomain('webui-core')

-- Translation initialization. Every function relying on translation MUST call setlanguage to ensure the current
-- language is correctly set (it will fetch the language set by web.web and use it)
-- We create a dedicated context for the web framework (since we cannot easily access the context of the current page)
local function setlanguage()
   gettext.language(ngx.header['Content-Language'])
end

function M.getDays()
  setlanguage()
  daysMap = setmetatable({
    Mon = { index = 1, text = T"Mon" },
    Tue = { index = 2, text = T"Tue" },
    Wed = { index = 3, text = T"Wed" },
    Thu = { index = 4, text = T"Thu" },
    Fri = { index = 5, text = T"Fri" },
    Sat = { index = 6, text = T"Sat" },
    Sun = { index = 7, text = T"Sun" }
  }, untaint_mt)
  return daysMap
end

function M.getDayTable()
  dayTable = {
    ["Mon, Tue, Wed, Thu, Fri, Sat, Sun"] = { value = "Every Day",     text = T"Every Day"},
    ["Mon, Tue, Wed, Thu, Fri"]           = { value = "Every Workday", text = T"Every Workday"},
    ["Sat, Sun"]                          = { value = "All Weekend",   text = T"All Weekend"},
  }
  return dayTable
end

function M.getDayTypes()
  dayTypesTable = {
    ["Every Day"]     = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"},
    ["Every Workday"] = {"Mon", "Tue", "Wed", "Thu", "Fri"},
    ["All Weekend"]   = {"Sat", "Sun"}
  }
  return dayTypesTable
end
-- @function numToIPv4
-- @param ip IPv4 address in decimal format
-- @return IPv4address(dotted quad)
function M.numToIPv4(ip)
  if type(ip) == "number" then
    local num2ip = bit.band(ip, 255)
    ip = bit.rshift(ip,8)
    for i=1,3 do
      num2ip = bit.band(ip,255) .. "." .. num2ip
      ip = bit.rshift(ip,8)
    end
    return num2ip
  end
end

-- Splitting IPv4 and IPv6 addresses
-- @function splitIP
-- @param ip String having IPv4 and IPv6 addresses combined
-- @return IPv4 and IPv6 addressess
function M.splitIP(ip)
  if ip then
    local ip4, ip6 = match(ip, "(%d+.%d+.%d+.%d+)%s?(.*)")
    return ip4 or "", ip6 or ""
  else
    return "",""
  end
end

function tableToAttr(tbl)
  local attributes = {}
  for k, v in pairs(tbl) do
    if k ~= "checked" then
      attributes[#attributes+1] = format("%s='%s'", k, v)
    end
  end
  return table.concat(attributes, " ")
end

-- Brought createDropDown function from r17.4 to r17.1 as a part of code change.
-- createDropDown function brought from vdf_ui_helper.lua
function M.createDropDown(attr, options, selectedOption, additionalOptions)
  local dropDownoptions  = {}
  options = options and next(options) and options or {}
  additionalOptions = type(additionalOptions) == "table" and additionalOptions or {}
  selectedOption = selectedOption or ""
  for i, v in ipairs(additionalOptions) do
    local selected = v[1] == selectedOption and 'selected="selected"' or ''
    dropDownoptions[#dropDownoptions +1 ] = format('<option %s value="%s">%s</option>', selected, v[1], v[2])
  end
  for i, v in ipairs(options) do
    local selected = v[1] == selectedOption and 'selected="selected"' or ''
    dropDownoptions[#dropDownoptions +1 ] = format('<option %s value="%s">%s</option>', selected, v[1], v[2] or v[1])
  end
  dropDownoptions = table.concat(dropDownoptions, "\n")
  return format('<select %s>%s</select>', tableToAttr(attr), dropDownoptions)
end

-- Brought createRow function from r17.4 to r17.1 as a part of code change.
-- createRow function brought from vdf_ui_helper.lua

function M.createRow(row)
  row.rowClass = row.rowClass or "vdf-row"
  row.rowId = row.rowId or ""
  row.colLeftClass = row.colLeftClass or "left"
  row.colLeftId = row.colLeftId or ""
  row.colRightClass = row.colRightClass or "right"
  row.colRightId = row.colRightId or ""
  row.labelClass = row.labelClass or ""
  row.labelId = row.labelId or ""
  local html = format([[
      <div class="%s" id="%s">
          <div class="%s" id="%s">
              <span class="%s" id="%s">%s</span>
          </div>
          <div class="%s" id="%s">
              %s
          </div>
      </div>
    ]], row.rowClass, row.rowId, row.colLeftClass, row.colLeftId, row.labelClass, row.labelId, row.label, row.colRightClass, row.colRightId, row.element)
  return html
end

function M.createTextField(attr)
  return format('<input %s>', tableToAttr(attr))
end

-- Calculates DHCP start and end addresses
-- @function calculateDHCPStartAndLimitAddress
-- @param ipAddress ipAddress
-- @param netmask subnet mask
-- @param start DHCP start address
-- @param limit DHCP Limit address
-- @return DHCP startAddress, DHCP endAddress, network address
function M.calculateDHCPStartAndLimitAddress(ipAddress, netmask, start, limit)
  if start and limit and ipAddress and netmask then
    local network = bit.band(ipAddress, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local startAddress = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local endAddress = startAddress+limit - 1
    local limit = ipmax - network
    startAddress = M.numToIPv4(startAddress)
    if endAddress > ipmax then
      endAddress = ipmax
    end
    endAddress = M.numToIPv4(endAddress)
    network = M.numToIPv4(network)
    return startAddress, endAddress, network, limit
  end
end

-- Converts seconds to time in hours, minutes and seconds
-- @function secondsToHours
-- @param seconds Time in seconds
-- @return Time duration in hours, minutes and seconds
function M.secondsToHours(seconds)
  if seconds and type(seconds) == "number" then
    local uptimeSec = seconds
    local uptimeDays = math.floor(uptimeSec / 86400)     -- days = 24 hrs x 60 mins x 60 sec = 86400 & Truncate.
    local leftoverSecs = uptimeSec - (uptimeDays * 86400)
    local uptimeHours = math.floor(leftoverSecs/3600)     -- hrs = 60 mins x 60 sec = 3600 & Truncate .
    leftoverSecs = leftoverSecs - (uptimeHours * 3600)
    local uptime_minutes = math.floor (leftoverSecs / 60 )
    leftoverSecs = leftoverSecs - (uptime_minutes*60)
    local totalSec, totalMts, totalHrs
    if tonumber(uptimeHours) <= 9 then
      totalHrs = "0"..uptimeHours
    else
      totalHrs = uptimeHours
    end
    if tonumber(uptime_minutes) <= 9 then
      totalMts = "0"..uptime_minutes
    else
      totalMts = uptime_minutes
    end
    if tonumber(leftoverSecs) <= 9 then
      totalSec = "0"..leftoverSecs
    else
      totalSec = leftoverSecs
    end
    return totalHrs, totalMts, totalSec
  end
end

-- Converts seconds to uptime of DUT
-- @function secondsToUptime
-- @param seconds Time in seconds
-- @return uptime days, uptime hours, uptime minutes
function M.secondsToUptime(sec)
  if sec and type(sec) == "number" then
    local uptime_days = math.floor(sec / 86400)     -- days = 24 hrs x 60 mins x 60 sec = 86400 & Truncate.
    local leftover_secs = sec - (uptime_days * 86400)
    local uptime_hours = math.floor(leftover_secs/3600)     -- hrs = 60 mins x 60 sec = 3600 & Truncate .
    leftover_secs = leftover_secs - (uptime_hours * 3600)
    local uptime_minutes = math.floor ( leftover_secs / 60 )
    local uptime_seconds = sec % 60
    return uptime_days, uptime_hours, uptime_minutes, uptime_seconds
  end
end

-- Converts systemtime to date and time
-- @function systemTimeToDateandTime
-- @param sys_time Time in seconds
-- @return uptime days, uptime hours, uptime minutes and uptime seconds
function M.systemTimeToDateandTime(sys_time)
  local current_hour, current_minute, current_timezone
  local year, month, current_date
  if sys_time then
    local date, time = string.match(sys_time, "([%d%-]+)%T([%d%:]+)")
    year, month, current_date = string.match(date, "([%d]+)%-([%d]+)%-([%d]+)")
    local hour, minute = match(time, "([%d]+)%:([%d]+)")
    if tonumber(hour) > 12 then
      current_hour = hour-12
      current_timezone = "pm"
    else
      current_hour= hour
      current_timezone = "am"
    end
    current_minute = minute
    return year, month, current_date, current_hour, current_minute, current_timezone
  end
end

-- Validates URL
-- @function validateURL
-- @param url
-- @param proto [optional]
-- @return true if valid URL
function M.validateURL(url)
  if url then
    local protocol, domain = string.match(url, "([%w]+)://([^/]*)/?")
    if not protocol then
      domain = string.match(url, "([^/]*)/?")
    end
    if domain and (post_helper.validateStringIsIP(domain) or post_helper.validateStringIsDomainName(domain)) then
      return true
    end
  end
end

-- Validating hour and minute values of the provided time format(hh:mm:ss)
-- @function validateTime
-- @param value Time in hh:mm:ss format
-- @return true if valid
function M.validateTime(value)
    if not value then
      return nil, T"Invalid input"
    end
    local time_pattern = "^(%d+):(%d+)$"
    local hour, min = value:match(time_pattern)
    if min then
      hour = tonumber(hour)
      min = tonumber(min)
      if hour < 0 or 23 < hour then
        return nil, T"Invalid hour, must be between 0 and 23"
      end
      if min < 0 or 59 < min then
        return nil, T"Invalid minutes, must be between 0 and 59"
      end
      return true
    end
    return nil, T"Invalid time (must be hh:mm)"
end

-- Validates netmask
-- @function validateNetmask
-- @param netmask
-- @return true if valid netmask
function M.validateNetmask(netmask)
  netmask = post_helper.ipv42num(netmask)
  if not netmask then
    return nil
  end
  local ones = 0
  local expecting = 0
  for i = 0, 31 do
    local bitmask = bit.lshift(1, i)
    local result = bit.band(netmask, bitmask)
    if result == 0 then
      if expecting ~= 0 then
        return nil
      end
    else
      if expecting == 0 then
        expecting = 1
      end
      ones = ones + 1
    end
  end
  if ones > 32 then
    return nil
  end
  return true
end

local validDays = setmetatable({
  Mon = true,
  Tue = true,
  Wed = true,
  Thu = true,
  Fri = true,
  Sat = true,
  Sun = true
}, untaint_mt)

M.validDays = validDays

local dayTypes = setmetatable({
  ["Every Day"]     = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"},
  ["Every Workday"] = {"Mon", "Tue", "Wed", "Thu", "Fri"},
  ["All Weekend"]   = {"Sat", "Sun"}
}, untaint_mt)
-- Function to validate days or day type.
-- If valid it converts them to list of days.
-- @function validateDays
-- @param #table value a day or comma seperated days or day type
-- @param #table postObject postObject from cliet
-- @param #table key key of current value in postObject
-- @return #boolean true if value is valid day/days, nil if not
function M.validateDays(value, postObject, key)
  if not value then
    return nil
  end
  local selectedDays = dayTypes[value]
  if not selectedDays then
    selectedDays = {}
    for day in gmatch(value, "%a+") do
      if not validDays[day] then
        return nil
      end
      selectedDays[#selectedDays+1] = string.untaint(day)
    end
  end
  if postObject and key and postObject[key] then
    postObject[key] = selectedDays
  end
  return true
end

-- Function to check overlapping days
-- @function validateOverlappingDays
-- @param #table days1 a list of days
-- @param #table days2 another list of days
-- @return #boolean true if days not overlap, nil if days overlap
function M.validateOverlappingDays(days1, days2, postObject)
  days1 = concat(days1, " ")
  for _, day in ipairs(days2) do
    if find(days1, day) then
      return nil
    end
  end
  return true
end

-- Function to validate comma seperated IPs
-- @function validateCommaSeparatedIPs
-- @param #string comma seperated IPs
-- @return #boolean true if all IPs are valid, nil if anything is invalid
function M.validateCommaSeparatedIPs(IPs, validator)
  if not IPs then
    return nil
  end
  if type(validator) ~= "function" then
    validator = post_helper.validateStringIsIP
  end
  local validated
  for ip in gmatch(IPs, '[^,]+') do
    validated = true
    if not validator(ip) then
      return nil
    end
  end
  return validated or validator(ip)
end

-- Function to append strings in Uptime
--  @function timeFormat
--  @days, @hours, @minutes, @seconds Converted Value of uptime in respective format
function M.timeFormat(days, hours, minutes, seconds)
  local strDay = T"days"
  local strHour = T"hours"
  local strMin = T"minutes"
  local strSec = T"seconds"
  days = tonumber(days) or 0
  hours = tonumber(hours) or 0
  minutes = tonumber(minutes) or 0
  seconds = tonumber(seconds) or 0
  if (days > 0) then
    return format("%d %s %d %s %d %s %d %s", days, strDay, hours, strHour, minutes, strMin, seconds, strSec)
  elseif (hours > 0) then
    return format("%d %s %d %s %d %s", hours, strHour, minutes, strMin, seconds, strSec)
  elseif (minutes > 0) then
    return format("%d %s %d %s", minutes, strMin, seconds, strSec)
  elseif (seconds > 0) then
    return format("%d %s", seconds, strSec)
  end
  return nil
end

--Common overlap function, Overlap check done for two time range.
--@param two time range start and end values
--@return boolean
function M.overlapCheck(starta, enda, startb, endb)
  local overlap  = false
  if not starta or not enda or not startb or not endb then
    return nil
  end
  if (starta > enda  or startb > endb) then
    if (startb > endb) then
      local tmp = startb
      startb = starta
      starta = tmp
      tmp = endb
      endb = enda
      enda = tmp
    end
    if (((startb < enda) or (startb > starta)) or ((endb < enda ) or (endb > starta))) then
      overlap = true
     end
  else
      if (starta > startb) then
        local tmp = startb
        startb = starta
        starta = tmp
        tmp = endb
        endb = enda
        enda = tmp
      end
    if (((startb >= starta) and (startb <= enda )) or ((endb >= starta) and (endb <= enda))) then
      overlap = true
    end
  end
  if overlap then
    return nil
  end
  return true
end

--Function to validate name should contain only alphanumeric characters
--@param #value from post
--@return boolean
function M.validateScheduleName(scheduleName)
  if scheduleName then
    if scheduleName:match("^([%w%:%-]+)$") then
      local charLength = #scheduleName
      if charLength < 63 then
        return true
      end
    end
  end
  return nil
end

--Function to return entire daylist
--@param #dayType have values {Individual Days, All Weekend, Every Day, Every Workday}
--@return commma seprated daylist
function M.completeDays(dayType)
  if not dayType then
    return nil
  end
  local typeOfDay = M.getDayTypes
  typeOfDay = typeOfDay()
  local selectedDays = typeOfDay[dayType]
  local daysMap = M.getDays
  daysMap = daysMap()
  if not selectedDays then
    selectedDays = {}
    for day in gmatch(dayType, "[^,%s]+") do
      if not daysMap[day] or not daysMap[day].index then
        return nil
      end
      selectedDays[#selectedDays+1] = day
    end
  end
  return selectedDays
end

--Function to sort days based on index
--@param comma seprated days
--@return sorted days
function M.sortDays(daysTable)
  if not daysTable  or type(daysTable) ~= "table" then
    return nil
  end
  local daysMap = M.getDays()
  sort( daysTable , function (a, b) if not daysMap[a] or not daysMap[b] then return nil end return daysMap[a].index < daysMap[b].index end )
  return daysTable
end

-- Calculate Start and End IP from IP/CIDR
-- @function calculateIPRange
-- @param value in "<IP>/<CIDR>" format
-- @return #string - Start IP and End IP
function M.calculateIPRange(value)
  local ipv42num = post_helper.ipv42num
  local cidr2mask = post_helper.cidr2mask
  if not value then return nil end
  local ip, cidr = value:match("(.+)/(.+)")
  ip = ipv42num(ip)
  if not ip then return nil end
  local netmask = ipv42num(cidr2mask(cidr))
  local startIP = bit.band(ip, netmask)
  local endIP = bit.bor(startIP, bit.bnot(netmask))
  return M.numToIPv4(startIP), M.numToIPv4(endIP)
end

-- Check whether an IP is in given range or not
-- @function validateIPRange
-- @param #string Start IP (IPv4)
-- @param #string End IP (IPv4)
-- @return #boolean true if IP is in range nil if not
function M.validateIPRange(startIP, endIP)
  local ipv42num = post_helper.ipv42num
  return function(ip)
    if ip then
      if post_helper.validateStringIsIP(ip) and ipv42num(startIP) <= ipv42num(ip) and ipv42num(ip) <= ipv42num(endIP) then
        return true
      end
    end
  end
end

-- Splits IP into octets
-- @function splitIP
-- @param #string IPv4
-- @return #table array of octets
function M.split_IP_into_Octets(ip)
  if not post_helper.validateStringIsIP(ip) then
    return nil
  end
  local tmp_ip = {}
  for octet in ip:gmatch("%d+") do
    octet = tonumber(octet)
    tmp_ip[#tmp_ip+1] = octet
  end
  return tmp_ip
end

-- The object of this function is to return a predefined dummy value ******** if there is a password
-- @function createInputPassword
-- @param value
-- @return default_input_value
function  M.createInputPassword(value)
    local default_input_value = ""
    if (type(value) == "string" or istainted(value)) and #value > 0 then
        default_input_value = "********" -- if there is a password, we set it to a dummy value
    end
    return default_input_value
end

-- Convert hexadecimal number to binary
-- @param num : hexadecimal number
-- @param bits : binary bits length
-- return binary string
local function hexToBinary(num, bits)
  num = tonumber(num, 16)
  local digits = {} -- will contain the bits
  local rest
  for val = bits, 1, -1 do
    rest = math.fmod(num, 2)
    digits[val] = math.floor(rest)
    num = (num - rest)/2
  end
  if num == 0 then
    return digits
  end
end

-- Convert MACAddress to LinkLocal Address.
-- @param mac : MAC Address
-- return LinkLocal Address.
function M.macToLinkLocalAddress(mac)
  if not mac or  not post_helper.validateStringIsMAC(mac) then
    return nil
  end
  local macSplit, bitTable = {}, {}
  local binaryBits, first4Bit, last4Bit = "", "", ""
  -- Append ff:fe in middle of MAC Address
  local appendValue = ("%s%s%s"):format(mac:sub(1, 10-1), "ff:fe:", mac:sub(10))
  -- Spliting MAC Address and storing in table.
  for data in gmatch(appendValue, '([^:-]+)') do
    macSplit[#macSplit + 1] = data
  end
  -- For First bit of MAC Address is converted to binary number
  for i = 1, #macSplit[1] do
    binaryBits =  binaryBits .. concat(hexToBinary(macSplit[1]:sub(i, i), 4))
  end
  -- To invert bit at index 6(counting from 0)
  for i = 1, #binaryBits do
    if i ~= 7 then
      bitTable[#bitTable +1] = binaryBits:sub(i, i)
    else
      bitTable[#bitTable +1] = tonumber(binaryBits:sub(i, i)) == 1 and 0 or 1
    end
  end
  -- Spliting binary string into 4 bits
  for count, value in ipairs(bitTable) do
    if count <= 4  then
      first4Bit  = first4Bit .. value
    else
      last4Bit   = last4Bit .. value
    end
  end
  -- Converting first4Bit and last4Bit into hexadecimal number
  local hexStr = format("%X", tonumber(first4Bit, 2)) .. format("%X", tonumber(last4Bit, 2))
  -- Storing converted hexadecimal number into first position of macSplit table
  macSplit[1] = hexStr
  return lower("fe80::"..(concat(macSplit)):gsub(("."):rep(4),"%1:"):sub(1, -2))
end

local variant
M.getVariant = function()
  if not variant then
    local param = {
      variant = "uci.env.var.vodafone_variant",
    }
    content_helper.getExactContent(param)
    variant = param.variant
  end
  return variant
end

return M
