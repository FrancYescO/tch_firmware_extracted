--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local open, popen, string = io.open, io.popen, string
local match, find = string.match, string.find
local logger = require("transformer.logger")
local uci = require("transformer.mapper.ucihelper")
local get_from_uci = uci.get_from_uci

local M = {}

--- Retrieves SFP flag
-- @return #number type is SFP flag 0/1
function M.readSFPFlag()
  local sfpFlag = get_from_uci({config = "env", sectionname = "rip", option = "sfp"})
  if sfpFlag == '1' then
      return 1
  end
  return 0
end

function M.getSfpctlFormat(option)
  local ctl = popen("sfpi2cctl -get -format " .. option)
  local output = ctl:read("*a")
  ctl:close()
  return output
end

--- Get SFP phy state
----@return #string PhyState is:
---- "connect" (sfp plugin and fiber connect)
---- "disconnect" (sfp unplugin or fiber disconnect)
function M.getSfpPhyState()
  local PhyState = "disconnect"
  local output = M.getSfpctlFormat("rssi")
  local value = match(output, "%d+")
  rssi_value = tonumber(value)
  if rssi_value then
      if ( rssi_value >= 40 ) or ( rssi_value <= 0) then
         PhyState = "disconnect"
      else
         PhyState = "connect"
      end
  end
  return PhyState
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
  local PhyState = M.getSfpPhyState()
  if PhyState == "connect" then
     local cmd = popen("sfp_get.sh --"..option)
     local output = cmd:read("*a")
     cmd:close()
     return output or ""
  else
     return ""
  end
end

function M.resetStatsGponSFP()
  os.execute("sfp_get.sh --counter_reset")
end

function M.getSfpVendName()
	local output = M.getSfpctlFormat("vendname")
	local name = match(output, "^.+:%[(.+)%]")
		if name then
			return name
		else
			return ""
		end
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
    Enable = '1',
    Status = M.getGponStatus(),
    OpticalSignalLevel = M.getGponLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getGponLevel("TransmitOpticalLevel"),
  }
end

function M.getTr181GponOpticals()
  return {
    Enable = '1',
    Status = M.getTr181GponStatus(),
    OpticalSignalLevel = M.getGponLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getGponLevel("TransmitOpticalLevel"),
  }
end

function M.getP2POpticals()
  return {
    Enable = '1',
    Status = "",
    OpticalSignalLevel = M.getP2PLevel("OpticalSignalLevel"),
    TransmitOpticalLevel = M.getP2PLevel("TransmitOpticalLevel"),
  }
end

--- Get GPON status
-- @return #string gpon status
function M.getGponStatus()
  local output = M.getGponSFP("state")
  if output == "" then
    return "Down"
  else
    return match(output, "(.-)%c") or "Down"
  end
end

function M.getTr181GponStatus()
  local status = M.getGponSFP("state")
  if match(status, "%(O5%)") then
    return "Up"
  else
    return "Down"
  end
end

function M.getTr181Status()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getTr181GponStatus()
  elseif type == "none" then
    return "Down"
  else
    return ""
  end
end

--- Get SFP status
-- @return #string SFP status 
function M.getStatus()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getGponStatus()
  elseif type == "none" then
    return "Down"
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

function M.getTr181Opticals()
  local type = M.getSFPType()
  if type == "gpon" then
    return M.getTr181GponOpticals()
  elseif type == "p2p" then
    return M.getP2POpticals()
  else
    return ""
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
