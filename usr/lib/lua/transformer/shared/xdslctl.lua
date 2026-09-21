-- helper functions to wrap xdslctl utility from broadcom
local cmdhelper = require("transformer.shared.cmdhelper")
local uci_helper = require("transformer.mapper.ucihelper")

local popen = io.popen
local match = string.match
local tonumber, tostring, ipairs = tonumber, tostring, ipairs

local logger = require("transformer.logger")
local log = logger.new("rpc.xdsl", 2)

local M = {}
local strToBoolean = {
  ["Off"]      = 0,
  ["On"]       = 1,
  ["Enabled"]  = 1,
  ["Disabled"] = 0
}
-- if table is accessed with unknown/nil index/key, return ""
setmetatable(strToBoolean, { __index = function() return "" end })

local function toBoolean(str)
  return strToBoolean[str]
end

-- for timewindows related to stats
-- converts days, hours, min, sec -> sec
local function timeToSecs(str)
  local totalsecs = 0
  local days = match(str, "(%d+)%sdays")
  if days then
    totalsecs = totalsecs + tonumber(days)*86400
  end
  local hours = match(str,"(%d+)%shours")
  if hours then
    totalsecs = totalsecs + tonumber(hours)*3600
  end
  local min = match(str,"(%d+)%smin")
  if min then
    totalsecs = totalsecs + tonumber(min)*60
  end
  local sec = match(str,"(%d+)%ssec")
  if sec then
    totalsecs = totalsecs + tonumber(sec)
  end
  return tostring(totalsecs)
end

-- parsing tables for cmdhelper.parseCmd
-- for xdslctl profile --show
local xdslctlprofile={command="xdslctl profile --show",lookup={
  ["mod_g.dmt"]={pat="^%s+G.Dmt%s+(%S+)",act=toBoolean},
  ["mod_g.lite"]={pat="^%s+G.lite%s+(%S+)",act=toBoolean},
  ["mod_t1.413"]={pat="^%s+T1%.413%s+(%S+)",act=toBoolean},
  ["mod_adsl2"]={pat="^%s+ADSL2%s+(%S+)",act=toBoolean},
  ["mod_annexl"]={pat="^%s+AnnexL%s+(%S+)",act=toBoolean},
  ["mod_adsl2plus"]={pat="^%s+ADSL2%+%s+(%S+)",act=toBoolean},
  ["mod_annexm"]={pat="^%s+AnnexM%s+(%S+)",act=toBoolean},
  ["mod_vdsl2"]={pat="^%s+VDSL2%s+(%S+)",act=toBoolean},
  ["phonelinepair"]={pat="^%s+(%S+)%spair"},
  ["cap_bitswap"]={pat="^%s+bitswap%s+(%S+)",act=toBoolean},
  ["cap_sra"]={pat="^%s+sra%s+(%S+)",act=toBoolean},
  ["cap_trellis"]={pat="^%s+trellis%s+(%S+)",act=toBoolean},
  ["cap_sesdrop"]={pat="^%s+sesdrop%s+(%S+)",act=toBoolean},
  ["cap_cominmgn"]={pat="^%s+CoMinMgn%s+(%S+)",act=toBoolean},
  ["cap_24k"]={pat="^%s+24k%s+(%S+)",act=toBoolean},
  ["cap_phyrexmt"]={pat="^%s+phyReXmt%(Us/Ds%)%s+([^%s/]+)/(%S+)",act=toBoolean,subkeys={"us","ds"}},
  ["cap_tpstc"]={pat="^%s+TpsTc%s+(%S+)"},
  ["cap_monitortone"]={pat="^%s+monitorTone:%s+(%S+)",act=toBoolean},
  ["cap_dynamicd"]={pat="^%s+dynamicD:%s+(%S+)",act=toBoolean},
  ["cap_dynamicf"]={pat="^%s+dynamicF:%s+(%S+)",act=toBoolean},
  ["cap_sos"]={pat="^%s+SOS:%s+(%S+)",act=toBoolean},
  ["cap_trainingmargin"]={pat="^%s+Training Margin%(Q4 in dB%):%s+(%S+)"}
}}

-- for xdslctl info --show
local xdslctlinfo={command="xdslctl info --show",lookup={
  ["status"]={pat="^Status:%s+(%S+)"},
  ["lrtr"]={pat="^Last Retrain Reason:%s+(.*)$"},
  ["lips"]={pat="^Last initialization procedure status:%s+(.*)$"},
  ["maxrate"]={pat="^Max:%s+Upstream rate = (%d+) Kbps, Downstream rate = (%d+) Kbps",subkeys={"us","ds"}},
  ["currentrate"]={pat="^%a+:%s+(%S+),%s+Upstream rate = (%d+) Kbps, Downstream rate = (%d+) Kbps",subkeys={"channel","us","ds"}},
  ["linkpowerstate"]={pat="^Link Power State:%s+(.*)$"},
  ["mode"]={pat="^Mode:%s+(.*)$"},
  ["vdsl2profile"]={pat="^VDSL2 Profile:%s+(.*)$"},
  ["tpstc"]={pat="^TPS%-TC:%s+(.*)$"},
  ["trellis"]={pat="^Trellis:%s+U:(%S+)%s/D:(%S+)$",subkeys={"us","ds"}},
  ["linestatus"]={pat="^Line Status:%s+(.*)$"},
  ["trainingstatus"]={pat="^Training Status:%s+(.*)$"},
  ["snr"]={pat="^SNR %(dB%):%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["attn"]={pat="^Attn%(dB%):%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["pwr"]={pat="^Pwr%(dBm%):%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_msgc"]={pat="^MSGc:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_b"]={pat="^B:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_m"]={pat="^M:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_t"]={pat="^T:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_r"]={pat="^R:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_s"]={pat="^S:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_l"]={pat="^L:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_d"]={pat="^D:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_i"]={pat="^I:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_n"]={pat="^N:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["framing_k"]={pat="^K:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_ohf"]={pat="^OHF:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_ohferr"]={pat="^OHFErr:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_sf"]={pat="^SF:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_sferr"]={pat="^SFErr:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_rs"]={pat="^RS:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_rscorr"]={pat="^RSCorr:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_rsuncorr"]={pat="^RSUnCorr:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_hec"]={pat="^HEC:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_ocd"]={pat="^OCD:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_lcd"]={pat="^LCD:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_totalcells"]={pat="^Total Cells:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_datacells"]={pat="^Data Cells:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_dropcells"]={pat="^Drop Cells:%s+(%S+)"},
  ["counters_biterr"]={pat="^Bit Errors:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_es"]={pat="^ES:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_ses"]={pat="^SES:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_uas"]={pat="^UAS:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_as"]={pat="^AS:%s+(%S+)"},
  ["counters_inp"]={pat="^INP:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_inprein"]={pat="^INPRein:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_delay"]={pat="^delay:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_per"]={pat="^PER:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_or"]={pat="^OR:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_agr"]={pat="^AgR:%s+(%S+)%s+(%S+)",subkeys={"ds","us"}},
  ["counters_bitsw"]={pat="^Bitswap:%s+([^%s/]+)/(%S+)%s+([^%s/]+)/(%S+)",subkeys={"ds","dstot","us","ustot"}},
}}
-- xdslctl info --stats
local xdslctlstatstimewindows={command="xdslctl info --stats",lookup={
  ["total"]={pat="^Total time = (.*)$",act=timeToSecs},
  ["currentquarter"]={pat="^Latest 15 minutes time = (.*)$",act=timeToSecs},
  ["currentday"]={pat="^Latest 1 day time = (.*)$",act=timeToSecs},
  ["previousday"]={pat="^Previous 1 day time = (.*)$",act=timeToSecs},
  ["previousquarter"]={pat="^Previous 15 minutes time = (.*)$",act=timeToSecs},
  ["sincesync"]={pat="^Since Link time = (.*)$",act=timeToSecs}
}}

-- keys for M.stats
-- stats cannot be parsed via cmdhelper (different sections with the same
-- layout)
local xdslstatskeys={
 ["fec"]="FEC:%s+(%d+)%s+(%d+)",
 ["crc"]="CRC:%s+(%d+)%s+(%d+)",
 ["es"]="ES:%s+(%d+)%s+(%d+)",
 ["ses"]="SES:%s+(%d+)%s+(%d+)",
 ["uas"]="UAS:%s+(%d+)%s+(%d+)",
 ["los"]="LOS:%s+(%d+)%s+(%d+)",
 ["lof"]="LOF:%s+(%d+)%s+(%d+)",
 ["lom"]="LOM:%s+(%d+)%s+(%d+)",
 ["time"]=""
}
local timekeys = {"total", "currentquarter", "previousquarter", "currentday", "previousday", "sincesync"}
local counterkeys = {"fec", "crc", "es", "ses", "uas", "los", "lof", "lom"}
-- generic values table for cmdhelper.parseCmd
local values={}

local function valueListFromCmd(cmdlookup, keys, lineid)
  local getallvalues={}
  cmdhelper.parseCmd(cmdlookup, keys, getallvalues, lineid)
  return getallvalues
end

local function valueFromCmd(cmdlookup, key, subkey, defaultvalue)
  cmdhelper.parseCmd(cmdlookup, {key}, values)
  local val=values[key]
  if val~=nil then
    if subkey~=nil then
      if val[subkey]~=nil then
        return val[subkey]
      end
    else
      return val
    end
  end
  return defaultvalue
end

function copyTable(t)
  if type(t) ~= 'table' then return t end
  local mt = getmetatable(t)
  local res = {}
  for k,v in pairs(t) do
    if type(v) == 'table' then
      v = copyTable(v)
    end
    res[k] = v
  end
  setmetatable(res,mt)
  return res
end

--- function to get single value from xdslctl info --show
-- @param key       key (string) as in xdslctlinfo.lookup
-- @param subkey    subkey (string) as in xdslctlinfo.lookup[key].subkeys
function M.infoValue(key, subkey, defaultvalue, lineid)
  lineid = lineid or "line0"
  local infocmd = copyTable(xdslctlinfo)
  if lineid ~= "line0" then
    infocmd.command = string.gsub(infocmd.command, "xdslctl", "xdslctl1", 1)
  end
  return valueFromCmd(infocmd, key, subkey, defaultvalue)
end
--
--- function to get list of values from xdslctl info --show
-- @param keylist   array of keys (string) as in xdslctlinfo.lookup
function M.infoValueList(keylist, lineid)
  lineid = lineid or "line0"
  local infocmd = copyTable(xdslctlinfo)
  if lineid ~= "line0" then
    infocmd.command = string.gsub(infocmd.command, "xdslctl", "xdslctl1", 1)
  end
  return valueListFromCmd(infocmd, keylist, lineid)
end

--- function to get single value from xdslctl profile --show
-- @param key       key (string) as in xdslctlprofile.lookup
-- @param subkey    subkey (string) as in xdslctlprofile.lookup[key].subkeys
function M.profileValue(key, subkey, defaultvalue, lineid)
  lineid = lineid or "line0"
  local profilecmd = copyTable(xdslctlprofile)
  if lineid ~= "line0" then
    profilecmd.command = string.gsub(profilecmd.command, "xdslctl", "xdslctl1", 1)
  end
  return valueFromCmd(profilecmd, key, subkey, defaultvalue)
end

--- function to get list of values from xdslctl profile --show
-- @param keylist   array of keys (string) as in xdslctlprofile.lookup
function M.profileValueList(keylist)
  return valueListFromCmd(xdslctlprofile, keylist, lineid)
end

--- function to get list of values from xdslctl info --stats
-- @param keylist   array of keys (string) as defined in xdslctlstatstimewindows.lookup
function M.statsIntervalValueList(keylist, lineid)
  lineid = lineid or "line0"
  local timewindowscmd = copyTable(xdslctlstatstimewindows)
  if lineid ~= "line0" then
    timewindowscmd.command = string.gsub(timewindowscmd.command, "xdslctl", "xdslctl1", 1)
  end
  return valueListFromCmd(xdslctlstatstimewindows, keylist, lineid)
end

local function readuntil(f, pat)
  repeat
    local line = f:read("*l")
    if line then
      local m1, m2 = match(line, pat)
      if m1 then
        return m1, m2
      end
    end
  until not line
end

--- function to get a single value from xdslctl info --stats
-- @param section     The stats section (string), one of the keys in xdslctlstatstimewindows
-- @param key         The stat key (string), one of the keys in xdslstatskeys
-- @param direction   The direction for the stats, a string "us" (Upstream) or "ds"
--                    (Downstream)
function M.stats(section, key, direction, lineid)
  lineid = lineid or "line0"
  local pipe
  if lineid == "line0" then
    pipe = popen("xdslctl info --stats")
  else
    pipe = popen("xdslctl1 info --stats")
  end
  
  if not pipe then
    return ""
  end
  local sectionpat = xdslctlstatstimewindows.lookup[section].pat
  local keypat = xdslstatskeys[key]
  local v1, v2 = readuntil(pipe, sectionpat)
  if v1 then
    if key == "time" then
      pipe:close()
      return timeToSecs(v1)
    end
    v1, v2 = readuntil(pipe, keypat)
    if v1 then
      if direction == "us" then
        v1 = v2
      end
      pipe:close()
      return v1
    end
  end
  pipe:close()
  return ""
end

-- function to get all stats from xdslctl info --stats
--@@return An table with all the stats
function M.allstats(lineid)
  lineid = lineid or "line0"
  local pipe
  if lineid == "line0" then
    pipe = popen("xdslctl info --stats")
  else
    pipe = popen("xdslctl1 info --stats")
  end
  if not pipe then
    return ""
  end

  local stats = {}
  local timewindows = xdslctlstatstimewindows.lookup
  for _, timekey in ipairs(timekeys) do
    local time = readuntil(pipe, timewindows[timekey].pat)
    if not time then
      break
    end
    local timevalues = { time = time }
    for _, counterkey in ipairs(counterkeys) do
      local ds, us = readuntil(pipe, xdslstatskeys[counterkey])
      if ds then
        timevalues[counterkey] = { ds = ds, us = us}
      end
    end
    stats[timekey] = timevalues
  end
  pipe:close()
  return stats
end

--function to generate the table to pass to valueListFromCmd for retrieving the bitloading

function M.getBitLoading(lineid)
  lineid = lineid or "line0"
  local pipe
  if lineid == "line0" then
    pipe = popen("xdslctl info --Bits")
  else
    pipe = popen("xdslctl1 info --Bits")
  end
  if not pipe then
    return ""
  end

  -- BCM stores the last known Bitloading info. Even if the line is down, you'll
  -- retrieve the bitloading info from the last showtime (if any). So if the line
  -- is down,... only print 0.
  local linestatus = M.infoValue("status", nil, nil, lineid)
  local statsvalues = {}
  if linestatus == "Showtime" then
    local pat = "^%s+%d+%s+(%d+)"
    for line in pipe:lines() do
      local val = match(line, pat)
      if val then
        statsvalues[#statsvalues + 1] = val
      end
    end
  end
  pipe:close()
  return table.concat(statsvalues, ",")
end

function M.isBondingSupported()
  local supported = uci_helper.get_from_uci({config= "xdsl", sectionname="dsl0", option="bondingsupport", default="0"})
  if supported == "1" then
    return true
  end
  return false
end

return M
