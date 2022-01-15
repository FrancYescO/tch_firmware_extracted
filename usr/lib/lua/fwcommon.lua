local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local format, gsub = string.format, string.gsub
local concat, sort = table.concat, table.sort
local date, time = os.date, os.time
local fw_config = { config = "fastweb" }
local act_config = { config = "tod" }

local Common = {}
Common.__index = Common

local function get_section_name(mac, idtype, prefixs)
  local name = {}
  if type(prefixs) == "table" then
    name[#name+1] = concat(prefixs, "_")
  elseif type(prefixs) == "string" then
    name[#name+1] = prefixs
  end
  if idtype then
    name[#name+1] = idtype
  end
  if mac then
    name[#name+1] = gsub(mac, ":", "")
  end
  return concat(name, "_")
end

local function check_section(self, config, added)
  if self.get(config) == "" then
    if added then
      self.add(config)
    end
    return false
  end
  return true
end

local function set_section(self, config, option, value)
  check_section(self, config, true)
  if option then
    if type(option) == "table" then
      config.options = option
    elseif value then
      config.options = {}
      config.options[option] = value
    end
  end
  return self.set(config)
end

-- Boost/Stop
local qos_config = {
  config = "qos",
  sectiontype = "classify",
  options = {
    order = "5",
    target = "Boost",
  }
}

local host_config = {
  config = "tod",
  sectiontype = "host",
  options = {
    type = "mac",
    mode = "block",
  }
}

local end_prefix = "end"

local Frequency = setmetatable({
  ["Do not repeat"] = "",
  ["Weekends"] = "Sat,Sun",
  ["Working days"] = "Mon,Tue,Wed,Thu,Fri",
  ["Daily"] = "All",
}, {__index = function() return "" end})

local Lease = setmetatable({
  ["1800"] = "0h 30'",
  ["3600"] = "1h 00'",
  ["5400"] = "1h 30'",
  ["7200"] = "2h 00'",
  ["14400"] = "4h 00'",
  ["-1"] = "None",
}, {__index = function() return "" end})

local Activity = {"boost", "stop"}

local function get_time_minute(timedate)
  if type(timedate) == "string" then
    local h, m = timedate:match("(%d+):(%d+)")
    return h*60 + m
  end
  return 0
end

local function get_stop_time(start, duration)
  local sh, sm = start:match("(%d+):(%d+)")
  local lh, lm = Lease[tostring(duration)]:match("(%d+)h (%d+)'")
  local m = tonumber(sm)+tonumber(lm)
  local h = tonumber(sh)+tonumber(lh)
  local offset = 0
  if m >= 60 then
    m = m - 60
    h = h + 1
  end
  if h >= 24 then
    h = h - 24
    offset = 86400-1
  end
  return format("%02d:%02d", h, m), offset
end

local function set_routine_tod_timer(self, config, start, stop, frequency)
  local t1 = get_time_minute(start)
  local t2 = get_time_minute(stop)
  local current = time()
  local end_config = {
    config = "tod",
    sectiontype = "timer",
    sectionname = get_section_name(nil, config.sectionname, end_prefix),
    options = {
      enabled = "0",
      periodic = "",
      start_time = "",
      stop_time = ""
    }
  }
  check_section(self, end_config, true)
  config.options.enabled = "1"
  config.options.periodic = "1"
  if t1 <= t2 or frequency == "Daily" then
    --"Weekends", "Working days" and "Daily"
    if Frequency[frequency] ~= "" then
      config.options.start_time = format("%s:%s", Frequency[frequency], start)
      config.options.stop_time  = format("%s:%s", Frequency[frequency], stop)
    else
      local day = date("%a", current)
      config.options.periodic = "0"
      config.options.start_time = format("%s:%s", day, start)
      config.options.stop_time  = format("%s:%s", day, stop)
    end
  elseif t1 > t2 and Frequency[frequency] == "Mon,Tue,Wed,Thu,Fri" then
    config.options.start_time = format("Mon,Tue,Wed,Thu:%s", start)
    config.options.stop_time  = format("Tue,Wed,Thu,Fri:%s", stop)
    end_config.options.enabled = "1"
    end_config.options.periodic = "1"
    end_config.options.start_time = format("Fri:%s", start)
    end_config.options.stop_time  = format("Fri:24:00")
  elseif t1 > t2 and Frequency[frequency] == "Sat,Sun" then
    config.options.start_time = format("Sat:%s", start)
    config.options.stop_time  = format("Sun:%s", stop)
    end_config.options.enabled = "1"
    end_config.options.periodic = "1"
    end_config.options.start_time = format("Sun:%s", start)
    end_config.options.stop_time  = format("Sun:24:00")
  elseif t1 > t2 and Frequency[frequency] == "" then
    config.options.periodic = "0"
    config.options.start_time = format("%s:%s", date("%a", current), start)
    config.options.stop_time  = format("%s:%s", date("%a", current+86400-1), stop)
  end

  self.set(config)
  self.set(end_config)
end
function Common:SetBoost(mac, enabled)
  qos_config.options.srcmac = mac
  qos_config.sectionname = get_section_name(mac, qos_config.sectiontype)
  if enabled == true or enabled == "1" then
    self.add(qos_config)
    self.set(qos_config)
  else
    self.del(qos_config)
  end
end

function Common:SetStop(mac, enabled)
  host_config.options.id = mac
  host_config.sectionname = get_section_name(mac, host_config.sectiontype)
  if enabled == true or enabled == "1" then
    if not check_section(self, host_config, true) then
      self.set(host_config)
    end
  end
  host_config.options.enabled = enabled
  self.set(host_config, "enabled")
end

function Common:SetOnlineStatus(mac, activity, enabled)
  if activity == "boost" then
    self:SetBoost(mac, enabled)
    if enabled == true or enabled == "1" then
      self:SetStop(mac, "0")
    end
  elseif activity == "stop" then
    self:SetStop(mac, enabled)
    if enabled == true or enabled == "1" then
      self:SetBoost(mac, "0")
    end
  end
end

local function config_webui_name()
  fw_config.sectiontype = nil
  fw_config.sectionname = "webui"
  fw_config.options = {}
end

local function config_device_name(mac)
  fw_config.sectiontype = "device"
  fw_config.sectionname = get_section_name(mac, fw_config.sectiontype)
  fw_config.options = {}
end

local function config_timer_name(mac, prefixs)
  fw_config.sectiontype = "timer"
  fw_config.sectionname = get_section_name(mac, fw_config.sectiontype, prefixs)
  fw_config.options = {}
end

function Common:GetFWWebUI(option)
  config_webui_name()
  return self.get(fw_config, option)
end

function Common:SetFWWebUI(option, value)
  config_webui_name()
  return set_section(self, fw_config, option, value)
end

function Common:GetFWDeviceAll(mac)
  config_device_name(mac)
  return self.getall(fw_config)
end

function Common:GetFWDevice(mac, option)
  config_device_name(mac)
  return self.get(fw_config, option)
end

function Common:SetFWDevice(mac, option, value)
  config_device_name(mac)
  local options = {}
  if type(option) == "table" then
    option.mac = mac
    options = option
  elseif type(option) == "string" then
    options[option] = value
    options.mac = mac
  end
  return set_section(self, fw_config, options)
end

function Common:GetFWTimerAll(mac, prefixs)
  config_timer_name(mac, prefixs)
  return self.getall(fw_config)
end

function Common:GetFWTimer(mac, prefixs, option)
  config_timer_name(mac, prefixs)
  return self.get(fw_config, option)
end

function Common:SetFWTimer(mac, prefixs, option, value)
  config_timer_name(mac, prefixs)
  return set_section(self, fw_config, option, value)
end

local function get_diff_time(t1, t2)
  local diff = -1
  local th1, tm1 = t1:match("(%d+):(%d+)")
  local th2, tm2 = t2:match("(%d+):(%d+)")
  if th1 and tm1 and th2 and tm2 then
    if th2 >= th1 then
      diff = (th2 - th1) * 60 + tm2 - tm1
    else
      diff = (th2 + 24 - th1) * 60 + tm2 - tm1
    end
  end
  return diff
end

local function convert_timer(timer)
  local utc_time
  local current = time()
  local current_hm = date("%H:%M", current)
  local current_time = format("%s:%s", date("%a", current), current_hm)
  if timer.stop_time == "" and timer.start_time and timer.start_time ~= "" then
    local diff = get_diff_time(current_time, timer.start_time)
    if diff > 0 and diff <= 240 then
      utc_time = current + diff * 60
    end
  end
  return utc_time
end

function Common:UpdateFWTimerStop(mac, prefixs)
  local stop_utc_time

  act_config.sectiontype = "timer"
  act_config.sectionname = get_section_name(mac, act_config.sectiontype, prefixs)
  act_config.options = {}

  local timer = self.getall(act_config)
  if timer.enabled and timer.enabled ~= "0" then
    local utc_time = convert_timer(timer)
    if utc_time then
      stop_utc_time = utc_time
      self:SetFWTimer(mac, prefixs, "stop", stop_utc_time)
    end
  end

  return stop_utc_time
end

function Common:SetBSTimer(mac, mode, activity, duration, start, frequency)
  local options = {}
  --Set ToD configuration
  act_config.sectiontype = "timer"
  act_config.sectionname = get_section_name(mac, act_config.sectiontype, {mode, activity})
  act_config.options = {}
  check_section(self, act_config, true)

  if type(duration) == "string" and duration ~= "" then
    if mode == "routine" and type(start) == "string" and start ~= ""
      and type(frequency) == "string" and frequency ~= "" then
      set_routine_tod_timer(self, act_config, start, get_stop_time(start, duration), frequency)
    elseif mode == "online" then
      local current = time()
      local _start = date("%H:%M", current)
      local _stop, offset = get_stop_time(_start, duration)
      act_config.options.enabled = "1"
      act_config.options.periodic = "0"
      act_config.options.start_time = format("%s:%s", date("%a", current+offset), _stop)
      options.start = current
      options.stop = current + duration

      --Set Fastweb configuration
      self:SetFWTimer(mac, {mode, activity}, options)
    end
  end
  self.set(act_config)
end

function Common:SetBSAction(mac, mode, activity, enabled)
  -- Set ToD configuration
  act_config.sectiontype = "action"
  act_config.sectionname = get_section_name(mac, act_config.sectiontype, {mode, activity})
  act_config.options = {}

  local object = format("1|%s", mac)
  if mode == "online" then
    object = format("0|%s", mac)
    self:SetOnlineStatus(mac, activity, enabled)
  end
  if not check_section(self, act_config, true) then
    local tname = {}
    tname[#tname+1] = get_section_name(mac, "timer", {mode, activity})
    tname[#tname+1] = get_section_name(nil, tname[1], end_prefix)
    act_config.options.script = format("%stodscript", activity)
    act_config.options.timers = tname
    act_config.options.object = object
  end

  act_config.options.enabled = enabled
  self.set(act_config)

  --Set Fastweb configuration
  self:SetFWTimer(mac, {mode, activity}, "enabled", enabled)
end

local function update_fwstop_time(self, status, mac, activity)
  if status == "1" then
    act_config.sectiontype = "action"
    act_config.sectionname = get_section_name(mac, act_config.sectiontype, {"routine", activity})
    act_config.options = {}
    local timers = self.get(act_config, "activedaytime")
    if timers and timers[1] then
      local section = timers[1]:match("^([^:]*)")
      act_config.sectiontype = "timer"
      act_config.sectionname = section
      --get stop time from tod timer config
      local stop_time = self.get(act_config, "stop_time")
      local f, h, m = stop_time:match("^([^:]*):(%d+):(%d+)")
      local current = time()
      local t = date("*t", current)
      t.hour = h or 0
      t.min = m or 0
      t.sec = 0
      local stop = time(t)
      if stop < current then
        stop = stop + 86400
      end
      self:SetFWTimer(mac, {"online", activity}, "stop", stop)
    end
  else
    self:SetFWTimer(mac, {"online", activity}, "stop", "")
  end
end

function Common:GetBoostStatus(mac)
  qos_config.sectionname = get_section_name(mac, qos_config.sectiontype)
  local status = check_section(self, qos_config) and "1" or "0"
  update_fwstop_time(self, status, mac, "boost")
  return status
end

function Common:GetStopStatus(mac)
  host_config.sectionname = get_section_name(mac, host_config.sectiontype)
  local status = (self.get(host_config, "enabled") == "1") and "1" or "0"
  update_fwstop_time(self, status, mac, "stop")
  return status
end

function Common:DisableDeviceRoutine(mac)
  self:SetFWDevice(mac, "routine", "0")
  for _,act in ipairs(Activity) do
    if self:GetFWTimer(mac, {"routine", act}, "enabled") == "1" then
      self:SetBSAction(mac, "routine", act, "0")
    end
  end
end

-- Parental Control
local pc_config = {
  config = "parental",
  sectionname = "general",
  options = {
    enable = "0",
  },
}

local url_config = {
  config = "parental",
  sectiontype = "URLfilter",
  options = {
    action = "DROP",
    site = "",
  }
}

local pc_mode = "parental_ctl_mode"
local pc_prefix = "URL"
local pc_ctl = "parental_ctl"
local url_list = "urls"
local id_pattern = "^(%d+)|"
local url_list_pattern = "^(%d+)|(%d*)|(.*)$"

local Action = {
  ["0"] = "ACCEPT",
  ["1"] = "DROP",
}

local function get_pc_mac_list(self)
  local macs = {}
  fw_config.sectiontype = "device"
  self.each(fw_config, function(s)
   if s.parental_ctl == "1" then
     macs[s.mac] = true
   end
 end)
 return macs
end

local function get_url_list(self)
  config_webui_name()
  local urls = self.get(fw_config, url_list)
  return urls ~= "" and urls or {}
end

local function get_url_id(self)
  local all = {}
  local id
  local urls = get_url_list(self)
  for _, url in pairs(urls) do
    id = tonumber(url:match(id_pattern))
    if id then
      all[id] = id
    end
  end
  return tostring(#all+1)
end

function Common:GetParentalCtlMode()
  local mode = self:GetFWWebUI(pc_mode)
  return mode == "1" and "1" or "0"
end

function Common:GetParentalCtlStatus()
  return self.get(pc_config, "enable")
end

function Common:SetParentalCtlStatus(enabled)
  pc_config.options.enable = enabled
  return self.set(pc_config)
end

-- sorted by site
local function ssort(a,b)
  local sa = a:match("^%d+|%d*|(.*)$")
  local sb = b:match("^%d+|%d*|(.*)$")
  return sa < sb
end

local function update_url_list(self, id, option, value)
  local enabled = ""
  local site = ""
  local urls = get_url_list(self)
  local index = #urls+1

  for i, url in pairs(urls) do
    if (url:match(id_pattern) == id) then
      index = i
      break
    end
  end

  if option then -- update or add a url
    if type(option) == "table" then
      enabled = option.action
      site = option.site
    elseif option == "action" then
      enabled = value
    elseif option == "site" then
      site = value
    else
      return true
    end
    if index <= #urls then -- existed, update the url
      if enabled ~= "" then
        urls[index] = gsub(urls[index], "|[^|]*|" , format("|%s|", enabled))
      end
      if site ~= "" then
        urls[index] = gsub(urls[index], "|[^|]*$" , format("|%s", site))
      end
    else -- not existed yet, add the url
      urls[#urls+1] = format("%s|%s|%s", id, enabled, site)
    end
  else -- delete a url
    if index <= #urls then
      for i = index, (#urls-1) do
        urls[i] = urls[i+1]
      end
      urls[#urls] = nil
    end
  end

  sort(urls, ssort)
  config_webui_name()
  set_section(self, fw_config, url_list, urls)
end

local function url_action(self, action, id, ...)
  local mode = self:GetParentalCtlMode()
  if mode == "1" then
    for mac in pairs(get_pc_mac_list(self)) do
      url_config.sectionname = get_section_name(mac, id, pc_prefix)
      if action == set_section then
        local _, _, option, value = ...
        local options = {}
        if type(option) == "table" then
          option.mac = mac
          options = option
        elseif type(option) == "string" then
          options[option] = value
          options.mac = mac
        end
        action(self, url_config, options)
      else
        action(...)
      end
    end
  else
    url_config.sectionname = get_section_name(nil, id, pc_prefix)
    action(...)
  end
end

function Common:AddURL()
  local id = get_url_id(self)
  update_url_list(self, id, "action", "1")
  url_action(self, self.add, id, url_config)
  return id
end

function Common:DelURL(id)
  update_url_list(self, id)
  url_action(self, self.del, id, url_config)
end

function Common:SetURL(id, option, value)
  if option == "site" then
    value = value:gsub("^http.*://", "")
  elseif option.site then
    option.site = option.site:gsub("^http.*://", "")
  end

  update_url_list(self, id, option, value)

  if option == "action" and (value == "0" or value == "1") then
    value = Action[value]
  elseif option.action and (option.action == "0" or option.action == "1") then
    option.action = Action[option.action]
  end
  url_action(self, set_section, id, self, url_config, option, value)
end

function Common:GetURL(id, option)
  local value
  local urls = get_url_list(self)
  local key, enabled, site
  for _, url in pairs(urls) do
    key, enabled, site = url:match(url_list_pattern)
    if (key == id) then
      if option == "action" then
        value = enabled == "0" and "0" or "1"
      elseif option == "site" then
        value = site
      end
      break
    end
  end

  return value
end

function Common:GetAllURLs()
  local urls = {}
  local key, enabled, site
  local url_list = get_url_list(self)

  local index = 1
  for _, url in pairs(url_list) do
    key, enabled, site = url:match(url_list_pattern)
    urls[index] = {}
    urls[index].id = key
    urls[index].uri = site
    urls[index].enabled = enabled == "0" and "0" or "1"
    index = index + 1
  end

  return urls
end

function Common:SetParentalCtlMode(mode)
  local premode = self:GetParentalCtlMode()
  -- when parent control mode is modified, the URLFilter configuration should be reconfigured
  if premode ~= mode then
    self:SetFWWebUI(pc_mode, mode)
    self.each(url_config, function(s)
      url_config.sectionname = s['.name']
      self.del(url_config)
    end)

    local urls = get_url_list(self)
    local key, enabled, site
    for _, url in pairs(urls) do
      key, enabled, site = url:match(url_list_pattern)
      local options = {
        action = enabled == "0" and "0" or "1",
        site = site
      }
      self:SetURL(key, options)
    end
  end
end

function Common:SetDeviceParentalCtl(mac, enabled)
  local mode = self:GetParentalCtlMode()
  if mode == "1" then
    local preenabled = self:GetFWDevice(mac, pc_ctl)
    if preenabled ~= enabled then
      if enabled == "0" then  -- delete URL sections when ParentalControlEnable changes from "1" to "0"
        self.each(url_config, function(s)
          if s['.name']:find(gsub(mac, ":", "")) then
            url_config.sectionname = s['.name']
            self.del(url_config)
          end
        end)
      else  -- add URL sections when ParentalControlEnable changes from "0" to "1"
        local urls = self:GetAllURLs()
        local options = {}
        for _, url in pairs(urls) do
          url_config.sectionname = get_section_name(mac, url.id, pc_prefix)
          options = {
            mac = mac,
            site = url.uri,
            action = Action[url.enabled]
          }
          set_section(self, url_config, options)
        end
      end
    end
  end
  self:SetFWDevice(mac, pc_ctl, enabled)
end

-- LED
local ledname = "led"

function Common:SetLedTimer(start, stop)
  local options = {}
  --Set ToD configuration
  act_config.sectiontype = "timer"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, ledname)
  act_config.options = {}

  if type(stop) == "string" and stop:match("%d%d:%d%d") then
    act_config.options.stop_time  = format("All:%s", stop)
    options.stop = stop
  end
  if type(start) == "string" and start:match("%d%d:%d%d") then
    act_config.options.start_time = format("All:%s", start)
    options.start = start
  end
  self.set(act_config)

  --Set Fastweb configuration
  self:SetFWTimer(nil, ledname, options)
end

function Common:SetLedAction(enabled)
  -- Set ToD configuration
  act_config.sectiontype = "action"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, ledname)
  act_config.options = {}
  act_config.options.enabled = enabled
  self.set(act_config)

  --Set Fastweb configuration
  self:SetFWTimer(nil, ledname, "enabled", enabled)
end


function Common:CheckTimeSlot(start, stop)
  local t1 = get_time_minute(start)
  local t2 = get_time_minute(stop)
  local ct = get_time_minute(date("%H:%M", time()))
  if (t1 < t2 and t1 <= ct and ct <= t2)
    or (t1 > t2 and (t1 <= ct or ct <= t2)) then
    return true, t1 <= t2
  else
    return false, t1 <= t2
  end
end

local dhcp_config = {
  config = "dhcp",
  sectiontype = "host",
  options = {}
}

function Common:GetAllDHCPHost()
  local host = {}
  self.each(dhcp_config, function(s)
    host[#host+1] = s
  end)
  return host
end

function Common:SetDHCPHost(mac, ip)
  dhcp_config.options.mac = mac
  dhcp_config.options.ip = ip
  dhcp_config.sectionname = get_section_name(mac, dhcp_config.sectiontype)
  if not check_section(self, dhcp_config, true) then
    self.set(dhcp_config)
  end
end

function Common:DelDHCPHost(mac)
  dhcp_config.sectionname = get_section_name(mac, dhcp_config.sectiontype)
  self.del(dhcp_config)
end

local bl_config = {
  config = "firewall",
  sectiontype = "rule",
  options = {
    dest_port = "80",
    src = "lan",
  }
}

local BLTarget = setmetatable({
  allow = "ACCEPT",
  block = "DROP",
}, {__index = function() return "DROP" end })

local bl_mode = "black_list_mode"
local bl_prefix = "black_list"
local bl_blocks = "bl_restricted"
local bl_pattern = "^black_list"

function Common:GetBlackListMode()
  local mode = self:GetFWWebUI(bl_mode)
  return mode == "allow" and "allow" or "block"
end

function Common:SetBlackListMode(mode)
  local premode = self:GetBlackListMode()
  -- when black mode is modified
  if premode ~= mode then
    self:SetFWWebUI(bl_mode, mode)
    bl_config.options.target = BLTarget[mode]
    self.each(bl_config, function(s)
      if s['.name']:match(bl_pattern) then
        bl_config.sectionname = s['.name']
        self.set(bl_config, "target")
      end
    end)
    bl_config.sectionname = get_section_name(nil, bl_config.sectiontype, bl_blocks)
    if mode == "allow" then
      bl_config.options.enabled = "1"
      bl_config.options.target = "DROP"
      bl_config.options.src_mac = nil
      set_section(self, bl_config)
    else
      self.del(bl_config)
    end
  end
end

function Common:GetBlackListDevice()
  local devices = {}
  local index = 1
  self.each(bl_config, function(s)
    if s['.name']:match(bl_pattern) then
      devices[index] = {}
      devices[index].mac = s.src_mac
      devices[index].enabled = s.enabled
      index = index + 1
    end
  end)
  return devices
end

function Common:SetBlackListDevice(mac, enabled)
  bl_config.options.src_mac = mac
  bl_config.options.enabled = enabled
  bl_config.options.target = BLTarget[self:GetBlackListMode()]
  bl_config.sectionname = get_section_name(mac, bl_config.sectiontype, bl_prefix)
  check_section(self, bl_config, true)
  self.set(bl_config)

  -- if an ACCEPT section is going to take effect in the allow mode, move the DROP section to the tail (delete and re-create)
  if enabled == "1" and (self:GetBlackListMode() == "allow") then
    bl_config.sectionname = get_section_name(nil, bl_config.sectiontype, bl_blocks)
    self.del(bl_config)
    bl_config.options.enabled = "1"
    bl_config.options.target = "DROP"
    bl_config.options.src_mac = nil
    set_section(self, bl_config)
  end
end

function Common:DelBlackListDevice(mac)
  bl_config.sectionname = get_section_name(mac, bl_config.sectiontype, bl_prefix)
  self.del(bl_config)
end

function Common:GetDeviceBlackListStatus(mac)
  local value = "0"
  bl_config.sectionname = get_section_name(mac, bl_config.sectiontype, bl_prefix)
  if self.get(bl_config) ~= "" then
    value = self.get(bl_config, "enabled") == "1" and "1" or "0"
  end
  return value
end

local wlguestname = "guest_restriction"

local firewall_zone_config = {
  config = "firewall",
  sectiontype = "zone",
  sectionname = "Guest",
  options = {
    forward = "",
  }
}
local firewall_defaultrule_config = {
  config = "firewall",
  sectiontype = "defaultrule",
  sectionname = "defaultoutgoing_Guest",
  options = {
    target= "",
  }
}

local function set_wlguest_firewall(self, actionfwd)
  firewall_zone_config.options.forward = actionfwd
  self.set(firewall_zone_config)
  firewall_defaultrule_config.options.target = actionfwd
  self.set(firewall_defaultrule_config)
end

function Common:SetWlGuestTimer(enabled, duration)
  local options = {}
  --Set ToD configuration
  act_config.sectiontype = "timer"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, wlguestname)
  act_config.options = {}
  check_section(self, act_config, true)

  if enabled == "1" and duration ~= "-1" then
    act_config.options.enabled = "1"
    local current = time()
    local _start = date("%H:%M", current)
    local _stop, offset = get_stop_time(_start, duration)
    act_config.options.start_time = format("%s:%s", date("%a", current+offset), _stop)
    options.start = current
    options.stop = current + tonumber(duration)
  else
    act_config.options.enabled = "0"
    act_config.options.start_time = ""
    options.start = ""
    options.stop = ""
  end
  options.lease = Lease[duration]
  self.set(act_config)
  --Set Fastweb configuration
  self:SetFWTimer(nil, wlguestname, options)
end

function Common:SetWlGuestAction(filter)
  --Set ToD configuration
  act_config.sectiontype = "action"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, wlguestname)
  act_config.options = {}
  check_section(self, act_config, true)
  local actionfwd = "ACCEPT"
  local allowtype = "all"
  allowtype = filter:lower()
  if allowtype:match("web") then
    actionfwd = "DROP"
  end
  act_config.options.object = allowtype
  set_wlguest_firewall(self, actionfwd)
  self.set(act_config)
end

function Common:GetWlGuestObject()
  act_config.sectiontype = "action"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, wlguestname)
  act_config.options = {}
  return self.get(act_config, "object")
end

local econame = "wifidisable"
function Common:GetEcoInfo()
  return self:GetFWTimerAll(nil, econame)
end

function Common:CheckEcoTimeSlot()
  local flag = false
  local info = self:GetEcoInfo()
  if info.enabled == "1" and info.start ~= "" and info.stop ~= "" then
    local day = date("%a")
    local frequency = Frequency[info.frequency]
    local bslot, bstate = self:CheckTimeSlot(info.start, info.stop)
    local bday = frequency:find(day) or frequency == "All"

    if info.enabled and bslot and bday and (bstate or (day ~= "Fri" and day ~= "Sun") or self:CheckTimeSlot(info.start, "24:00")) then
      flag = true
    end
  end
  return flag
end

function Common:SetEcoTimer(enabled, start, stop, frequency)
  local options = {}
  --Set ToD configuration
  act_config.sectiontype = "timer"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, econame)
  act_config.options = {}
  check_section(self, act_config, true)

  act_config.options.enabled = enabled
  if enabled == "1" then
    set_routine_tod_timer(self, act_config, start, stop, frequency)
    options.start = start
    options.stop = stop
    options.frequency = frequency
  end
  self.set(act_config)
  --Set Fastweb configuration
  self:SetFWTimer(nil, econame, options)
end

function Common:SetEcoAction(enabled)
  -- Set ToD configuration
  act_config.sectiontype = "action"
  act_config.sectionname = get_section_name(nil, act_config.sectiontype, econame)
  act_config.options = {}

  if not check_section(self, act_config, true) then
    local tname = {}
    tname[#tname+1] = get_section_name(nil, "timer", econame)
    tname[#tname+1] = get_section_name(nil, tname[1], end_prefix)
    act_config.options.script = "wifitodscript"
    act_config.options.timers = tname
  end

  act_config.options.enabled = enabled
  self.set(act_config)

  --Set Fastweb configuration
  self:SetFWTimer(nil, econame, "enabled", enabled)
end

local ledfw_config = { config = "ledfw", sectionname = "ambient", options = {} }
function Common:GetLedActive()
  local value = self.get(ledfw_config,"active")
  return value == "1" and "1" or "0"
end

function Common:SetLedActive(active)
  if active then
    ledfw_config.options.active = active
  end
  return self.set(ledfw_config)
end


local M = {}

function M.SetProxy(proxy)
  local _proxy = {
    get = proxy.get,
    getall = proxy.getall,
    set = proxy.set,
    add = proxy.add,
    del = proxy.del,
    each = proxy.each,
  }

  setmetatable(_proxy, Common)
  return _proxy
end


return M
