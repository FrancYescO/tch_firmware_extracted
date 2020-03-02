--NG-96253 GPON-Diagnostics/Network needs to be lifted to TI specific functionalities
local open, popen, string = io.open, io.popen, string
local match, find = string.match, string.find
local logger = require("transformer.logger")

local M = {}

function M.getSfpctlFormat(option)
  local ctl = popen("sfpi2cctl -get -format " .. option)
  local output = ctl:read("*a")
  ctl:close()
  return output
end

--- Get the SFP type
-- @return #string type is gpon/p2p/none
function M.getSFPType()
  local type = "none"
  local output = M.getSfpctlFormat("vendpn")
  local value = match(output, "%[(.+)%]")
  if value then
      if find(value, "LTE3415") or find(value, "FDA2000") then
        type = "gpon"
      else
        type = "p2p"
      end
  end
  return type
end

--- Calls sfp_get.sh with the given option and returns the output
-- @param #string option value is as following
-- allstats             : All SFP stats
-- state                : ONU state
-- optical_info         : SFP optical info
-- bytes_sent           : SFP sent bytes 
-- bytes_rec            : SFP received bytes 
-- packets_sent         : SFP sent packets 
-- packets_rec          : SFP received packets 
-- errors_sent          : SFP sent errors 
-- errors_rec           : SFP received errors 
-- discardpackets_sent  : SFP sent discard  packets 
-- discardpackets_rec   : SFP received discard packets
function M.getGponSFP(option)
  local cmd = popen("sfp_get.sh --"..option)
  local output = cmd:read("*a")
  cmd:close()  
  return output or ""
end

function M.resetStatsGponSFP()
  os.execute("sfp_get.sh --counter_reset")
end

local statsEntries = {
  BytesSent = "bytes_sent",
  BytesReceived = "bytes_rec",
  PacketsSent = "packets_sent",
  PacketsReceived = "packets_rec",
  ErrorsSent = "errors_sent",
  ErrorsReceived = "errors_rec",
  DiscardPacketsSent = "discardpackets_sent",
  DiscardPacketsReceived = "discardpackets_rec",
}

local LevelEntries = {
  OpticalSignalLevel = "Rx Power",
  TransmitOpticalLevel = "Tx Power",
}

local function getGponMatch(output, param)
  local value = match(output, param..":%s+(.-)%c")
  return value or "0"
end

--- Get GPON separate statistics information
-- @param #string statistics item as following
--   BytesSent
--   BytesReceived
--   PacketsSent
--   PacketsReceived
--   ErrorsSent
--   ErrorsReceived
--   DiscardPacketsSent
--   DiscardPacketsReceived
-- @return #string statistics information
function M.getGponStats(param)
  local output = M.getGponSFP(statsEntries[param])
  return getGponMatch(output, param)
end

--- Get All GPON statistics information
-- @return #table includes tr181 statistics information
function M.getGponAllStats()
  local StatsValues = {}
  local output = M.getGponSFP("allstats")
  for param in pairs(statsEntries) do
    StatsValues[param] = getGponMatch(output, param)
  end
  return StatsValues
end

--- Get GPON OpticalSignalLevel or TransmitOpticalLevel value
-- @param #string level item "OpticalSignalLevel/TransmitOpticalLevel"
-- @return #string level value
function M.getGponLevel(param)
  local output = M.getGponSFP("optical_info")
  local level = getGponMatch(output, LevelEntries[param])
  if level ~= "0" then                               
    level = level:gsub("dBm", "")                     
  end                                                 
  return level
end

local P2PEntries = {
  TransmitOpticalLevel = { 
    option = "txpwr",
    match = "Txpwr",
  },
  OpticalSignalLevel = {
    option = "rssi",
    match = "Rssi"
  },
}

function M.getP2PLevel(param)
  local entry = P2PEntries[param]
  if entry then
    local output = M.getSfpctlFormat(entry["option"])
    local value = match(output, entry["match"] .. ":(.-)%sdBm")
    return value or "0"
  else
    return "0"
  end
end

function M.getGponOpticals()
  return {
    Status = M.getGponStatus(),
    OpticalSignalLevel = M.getGponLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getGponLevel("TransmitOpticalLevel"),
  }
end

function M.getP2POpticals()
  return {
    Status = "",
    OpticalSignalLevel = M.getP2PLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getP2PLevel("TransmitOpticalLevel"),
  }
end

--- Get GPON status
-- @return #string gpon status
function M.getGponStatus()
  local output = M.getGponSFP("state")
  return match(output, "(%S+)") or ""
end

--- Get SFP status
-- @return #string SFP status 
function M.getStatus()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponStatus()
  else
    return ""
  end
end

--- Get SFP OpticalSignalLevel or TransmitOpticalLevel value
-- @param #string level item "OpticalSignalLevel/TransmitOpticalLevel"
-- @return #string level value
function M.getLevel(param)
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponLevel(param)
  elseif type == "p2p" then
    return M.getP2PLevel(param)
  else
    return ""
  end
end

--- Get SFP separate statistics information
-- @param #string statistics item as following
--   BytesSent
--   BytesReceived
--   PacketsSent
--   PacketsReceived
--   ErrorsSent
--   ErrorsReceived
--   DiscardPacketsSent
--   DiscardPacketsReceived
-- @return #string statistics information
function M.getStats(param)
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponStats(param)
  else
    return "0"
  end
end

--- Get SFP Status,OpticalSignalLevel,TransmitOpticalLevel information
-- @return #table includes tr181 Status,OpticalSignalLevel,TransmitOpticalLevel information
function M.getOpticals()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponOpticals()
  elseif type == "p2p" then
    return M.getP2POpticals()
  else
    return ""
  end
end

--- Get All SFP statistics information
-- @return #table includes tr181 statistics information  
function M.getAllStats()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponAllStats()
  else
    return ""
  end
end

return M
