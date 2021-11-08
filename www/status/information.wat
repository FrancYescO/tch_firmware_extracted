local setmetatable = setmetatable
local date, time = os.date, os.time
local format, find, sub = string.format, string.find, string.sub
local untaint = string.untaint
local floor = math.floor
local content_helper = require("web.content_helper")
local api = require("fwapihelper")
local dm = require("datamodel")

local function convert_time(seconds)
  local d =  floor(seconds/86400)
  local h =  floor(seconds/3600)%24
  local m = floor(seconds/60)%60
  local s = seconds%60
  if (d > 0) then
    return format("%dday:%dh:%dm:%ds", d, h, m, s)
  elseif (h > 0) then
    return format("%dh:%dm:%ds", h, m, s)
  elseif (m > 0) then
    return format("%dm:%ds", m, s)
  else
    return format("%ds", s)
  end
end

local SystemInfo = {
  "lanip",
  "linerate_us",
  "linerate_ds",
  "wanmac",
  "wangw",
  "wan_model",
}

local function getSysInfo()
  local data = {
    model = "uci.env.var.prod_friendly_name",
    fw_version = "uci.version.version.@version[0].version",
    hw_version = "uci.env.rip.board_mnemonic",
  }

  local version = {
    prefix = "uci.versioncusto.override.fwversion_prefix",
    suffix = "uci.versioncusto.override.fwversion_suffix",
    override = "uci.versioncusto.override.fwversion_override"
  }

  content_helper.getExactContent(data)

  local sysinfo = api.GetSystemInfo()
  for _,v in ipairs(SystemInfo) do
    data[v] = sysinfo[v]
  end

  for k,v in ipairs(api.GetDnsServers()) do
    local dnsname = format("wandns%d", k)
    data[dnsname] = v
  end

  if data["fw_version"] then
    local fwversion
    content_helper.getExactContent(version)
    if version.override ~= "" and version.override ~= "override1" then
      fwversion = version.override
    else
      local pattern
      if version.override == "override1" then
        pattern = "%-"
      else
        pattern = "%-[^%-]*$"
      end
      local pos = find(data["fw_version"], pattern)
      if pos then
        fwversion = sub(data["fw_version"], 1, pos-1)
      end
    end
    if fwversion then
      data["fw_version"] = format("%s%s%s", version.prefix, fwversion, version.suffix)
    end
  end

  data["uptime"] = convert_time(content_helper.readfile("/proc/uptime","number",floor))
  data["date_info"] = date("%F %T", time())


  if data["wanmac"]:len() == 0 then
    data["wanmac"] = dm.get("uci.env.rip.eth_mac")[1].value
  end
  data["sysinfo"] = "end"
  return data
end

local service_sysinfo ={
  name = "sysinfo",
  get = getSysInfo,
}

local service_reset = {
  name = "reset",
  set = function(args)
    dm.set("rpc.system.reboot", "GUI")
    dm.apply()
    return true
  end
}

register(service_sysinfo)
register(service_reset)
