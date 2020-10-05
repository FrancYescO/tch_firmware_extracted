local uc = require("uciconv")
local newConfig = uc.uci('new')
local oldConfig = uc.uci('old')
local format = string.format
local sort, concat = table.sort, table.concat

local led_timer  = "led_timer"
local led_action = "led_action"
local wifi_timer = "wifidisable_timer"
local end_wifi_timer = "end_wifidisable_timer"
local wifi_action = "wifidisable_action"
local guest_timer  = "guest_restriction_timer"
local guest_action = "guest_restriction_action"

local id_pattern = "^(%d+)|"
local time_pattern = "%d+:%d+"

local function get_section_name(prefix, mac, id)
  local name = {}
  if prefix then
    name[#name+1] = prefix
  end
  if id then
    name[#name+1] = id
  end
  if mac then
    name[#name+1] = mac:gsub(":","")
  end
  return concat(name, "_")
end

local function handleActivedaytime(action_name, old_timer_name, new_timer_name)
  local activedaytime = newConfig:get("tod", action_name, "activedaytime")
  if type(activedaytime) == "table" then
    for k, v in ipairs(activedaytime) do
      activedaytime[k] = v:gsub(old_timer_name, new_timer_name)
    end
    newConfig:set("tod", action_name, "activedaytime", activedaytime)
  end
end

local function handleLedTod()
  local ret = newConfig:rename("tod", "sleep_hours", led_timer)
  if not ret then -- r18.3 -> r18.3
    return
  end
  -- r17.2.c -> r18.3
  -- change led list timers
  newConfig:rename("tod", "ledtod", led_action)
  newConfig:set("tod", led_action, "timers", {led_timer})
  handleActivedaytime(led_action, "sleep_hours", led_timer)

  local led_action_enabled = newConfig:get("tod", led_action, "enabled")
  local led_timer_data = newConfig:get_all("tod", led_timer)
  if not led_timer_data then
    return
  end
  if led_action_enabled == "1" then
    local start_time = led_timer_data.start_time:match(time_pattern)
    local stop_time  = led_timer_data.stop_time:match(time_pattern)
    newConfig:set("fastweb", led_timer, "timer")
    newConfig:set("fastweb", led_timer, "enabled", led_action_enabled)
    newConfig:set("fastweb", led_timer, "start", start_time or "")
    newConfig:set("fastweb", led_timer, "stop", stop_time or "")
  end
end

local function handleWifiDisableTod()
  -- Rename for the timer and action
  local ret = newConfig:rename("tod", "timer_wifidisable", wifi_timer)
  if not ret then -- r18.3 -> r18.3
    return
  end
  -- r17.2.c -> r18.3
  newConfig:rename("tod", "action_wifidisable",wifi_action)
  local wifi_action_enabled = newConfig:get("tod", wifi_action, "enabled")
  local wifi_timer_data = newConfig:get_all("tod", wifi_timer)
  if not wifi_timer_data then
    return
  end
  local start_time = wifi_timer_data.start_time:match(time_pattern)
  local stop_time  = wifi_timer_data.stop_time:match(time_pattern)
  -- add the wifidisable timer to config fastweb
  newConfig:set("fastweb", wifi_timer, "timer")
  newConfig:set("fastweb", wifi_timer, "enabled", wifi_action_enabled or "")
  newConfig:set("fastweb", wifi_timer, "start", start_time or "")
  newConfig:set("fastweb", wifi_timer, "stop", stop_time or "")

  local wifi_frequency
  local weekend_enabled = newConfig:get("tod", "timer_wifidisable_weekend", "enabled")
  local workend_enabled = newConfig:get("tod", "timer_wifidisable_workend", "enabled")
  if wifi_timer_data.start_time:find("All") then
    wifi_frequency = "Daily"
  elseif weekend_enabled == "1" then
    wifi_frequency = "Weekends"
  elseif workend_enabled == "1" then
    wifi_frequency = "Working days"
  else
    wifi_frequency = "Do not repeat"
  end

  newConfig:set("fastweb", wifi_timer, "frequency", wifi_frequency)
  if weekend_enabled == "1" then
    newConfig:rename("tod", "timer_wifidisable_weekend", end_wifi_timer)
    newConfig:delete("tod", "timer_wifidisable_workend")
  else
    newConfig:rename("tod", "timer_wifidisable_workend", end_wifi_timer)
    newConfig:delete("tod", "timer_wifidisable_weekend")
  end

  -- change wifidisable action timers
  newConfig:set("tod", wifi_action, "timers", {wifi_timer, end_wifi_timer})
  handleActivedaytime(wifi_action, "timer_wifidisable", wifi_timer)
end

local function handleWifiGuestTod()
  local ret = newConfig:rename("tod", "timer_guest_restriction", guest_timer)
  if not ret then -- r18.3 -> r18.3
    return
  end
  -- r17.2.c -> r18.3
  -- change list timers
  newConfig:set("tod", "action_guest_restriction", "timers", {guest_timer})
  newConfig:rename("tod", "action_guest_restriction", guest_action)

  local timer_data = newConfig:get_all("tod", guest_timer)
  if timer_data and timer_data.enabled ~= "0" and timer_data.start_time then
    -- add the guest_restriction_timer to config fastweb
    newConfig:set("fastweb", guest_timer, "timer")
    newConfig:set("fastweb", guest_timer, "lease", timer_data.lease or "")
    -- remove option lease
    newConfig:set("tod", guest_timer, "lease", "")
  end
end

-- Handle boost/stop timers
local function handleBoostStopTimers()
  newConfig:foreach("tod", "timer", function(s)
    -- boost/stop timer name format in r17.2.c: boost_online_00_15_e9_ad_57_82
    local timer_type = s[".name"]:find("online") and "online" or "routine"
    local bs, mac = s[".name"]:match("^(%a+)_"..timer_type.."_(%x%x_%x%x_%x%x_%x%x_%x%x_%x%x)$")
    if bs and mac then
      -- new timer name format: online_boost_timer_0015e9ad5782
      local new_timer_name = timer_type .. "_" .. bs .. "_timer_" .. mac:gsub("_","")
      -- add the timer to config fastweb
      newConfig:set("fastweb", new_timer_name, "timer")
      if s.enabled ~= "0" and timer_type == "routine" then
        newConfig:set("fastweb", new_timer_name, "start", s.start or "")
        newConfig:set("fastweb", new_timer_name, "frequency", s.frequency or "")
        newConfig:set("tod", s[".name"], "frequency", "")
      end
      newConfig:set("fastweb", new_timer_name, "lease", s.lease or "")
      newConfig:set("tod", s[".name"], "start", "")
      newConfig:set("tod", s[".name"], "lease", "")
      if timer_type == "online" then
        newConfig:set("tod", s[".name"], "routine", "")
      end

      newConfig:rename("tod", s[".name"], new_timer_name)
    end
  end)
end

-- Hanidle boost/stop actions
local function handleBoostStopActions()
  newConfig:foreach("tod", "action", function(s)
    -- the section name in r17.2.c is in format boost_action_online_00_15_e9_ad_57_82
    local action_type = s[".name"]:find("online") and "online" or "routine"
    local bs, mac = s[".name"]:match("^(%a+)_action_"..action_type.."_(%x%x_%x%x_%x%x_%x%x_%x%x_%x%x)$")
    if bs and mac then
      local new_mac = mac:gsub("_","")
      local new_action_name = action_type .. "_" .. bs .. "_action_" .. new_mac
      local timer_name  = action_type .. "_" .. bs .. "_timer_" .. new_mac

      newConfig:set("tod", s[".name"], "timers", {timer_name})
      -- online timer needn't option 'enabled' in config fastweb
      -- online action doesn't have activedaytime
      if action_type == "routine" then
        newConfig:set("fastweb", timer_name, "enabled", s.enabled or "0")
        handleActivedaytime(s[".name"], bs .. "_routine_" .. mac, timer_name)
      end
      newConfig:rename("tod", s[".name"], new_action_name)
    end
  end)
end

-- Give names to the anonymous hosts in tod
local function handleHosts()
  newConfig:foreach("tod", "host", function(s)
    if s[".anonymous"] then
      local mac = s.id:gsub(":", "")
      newConfig:rename("tod", s[".name"], "host_" .. mac)
    end
  end)
end

-- handle user_friendly_name
local function handle_user_friendly_name()
  newConfig:foreach("user_friendly_name", "name", function(s)
    if not s.type or not s.mac then
      return
    end
    local device_section_name = get_section_name("device", s.mac)
    local group_name, icon_id, parental_ctl = s.type:match("(%w*):(%d*):(%d*)")

    newConfig:set("user_friendly_name", s[".name"], "type", "")
    -- add the device to config fastweb and set values
    newConfig:set("fastweb", device_section_name, "device")
    if group_name and icon_id and parental_ctl then
      group_name = group_name == "family" and "Family" or "Other"
      newConfig:set("fastweb", device_section_name, "mac", s.mac)
      newConfig:set("fastweb", device_section_name, "group_name", group_name)
      newConfig:set("fastweb", device_section_name, "icon_id", icon_id)
      newConfig:set("fastweb", device_section_name, "parental_ctl", parental_ctl)
    end
    -- set value for option routine
    local timer_name = get_section_name("routine_boost_timer", s.mac)
    local routine = newConfig:get("tod", timer_name, "routine")
    if routine then
      newConfig:set("fastweb", device_section_name, "routine", routine)
      newConfig:set("tod", timer_name, "routine", "")
      newConfig:set("tod", timer_name:gsub("boost", "stop"), "routine", "")
    end
  end)
end

-- handle qos. Give names to anonymous classifys
local function handleQosClassify()
  newConfig:foreach("qos", "classify", function(s)
    if s[".anonymous"] then
      newConfig:rename("qos", s[".name"], get_section_name("classify", s.srcmac))
    end
  end)
end

-- sorted by number
local function nsort(a,b)
  local na = tonumber(a:match(id_pattern))
  local nb = tonumber(b:match(id_pattern))
  return na < nb
end

-- handle parental. Give names to anonymous URLfilters and set list urls to fastweb.webui
local function handleParental()
  local sites = {}
  local len = 0
  local urls = {}
  local old_urls = newConfig:get("fastweb", "webui", "urls")
  newConfig:foreach("parental", "URLfilter", function(s)
    if (s[".anonymous"] or not old_urls) and s.site then
      if not sites[s.site] then
        len = len + 1
        sites[s.site] = len
        local enabled = s.action == "ACCEPT" and "0" or "1"
        urls[#urls + 1] = format("%s|%s|%s", len, enabled, s.site)
      end
      local id = sites[s.site]
      local section_name
      if s.mac then
        section_name = get_section_name("URL", s.mac, id)
      else
        section_name = get_section_name("URL", nil, id)
      end
      newConfig:rename("parental", s[".name"], section_name)
    end
  end)

  if #urls > 0 then
    sort(urls, nsort)
    for i = #urls + 1, 20 do
      urls[i] = format("%s|1|", i)
    end
    newConfig:set("fastweb", "webui", "urls", urls)
  end

  local old_ctl_mode = newConfig:get("fastweb", "webui", "parental_control_mode")
  if old_ctl_mode then
    newConfig:set("fastweb", "webui", "parental_ctl_mode", old_ctl_mode)
    newConfig:set("fastweb", "webui", "parental_control_mode", "")
  end
end

local function handleFwSetting()
  local key00_value = newConfig:get("fastweb", "webui", "key_00")
  local key01_value = newConfig:get("fastweb", "webui", "key_01")
  if key00_value and key01_value then
    newConfig:set("fastweb", "webui", "fw_setting", {"key_00|"..key00_value, "key_01|"..key01_value})
    newConfig:set("fastweb", "webui", "key_00", "")
    newConfig:set("fastweb", "webui", "key_01", "")
  end
end

local function handleRestrictedAccess()
  local restricted_mode
  newConfig:foreach("firewall", "rule", function(s)
    local section_name
    if s.name == "Dev_Deny_Access" or s.name == "Dev_Allow_Access" then
      newConfig:set("firewall", s[".name"], "name", "")
      if s.src_mac then
        section_name = get_section_name("black_list_rule", s.src_mac)
        newConfig:rename("firewall", s[".name"], section_name)
        if s.name == "Dev_Deny_Access" then
          restricted_mode = "block"
        end
      elseif s.name == "Dev_Deny_Access" then
        -- allow access mode
        newConfig:rename("firewall", s[".name"], "bl_restricted_rule")
        restricted_mode = "allow"
      end
    end
  end)
  if restricted_mode then
    newConfig:set("fastweb", "webui", "black_list_mode", restricted_mode)
  end
end

local function handleCallWaiting()
  local sectype = "CALL_WAITING"
  newConfig:foreach("mmpbx", "service", function(newsec)
    if newsec.type == sectype then
      oldConfig:foreach("mmpbx", "service", function(oldsec)
        if oldsec.type == sectype and newsec.device[1] == oldsec.device[1] then
          if newsec.provisioned ~= oldsec.provisioned then
            newConfig:set("mmpbx", newsec[".name"], "provisioned", oldsec.provisioned)
          end
          if newsec.activated ~= oldsec.activated then
            newConfig:set("mmpbx", newsec[".name"], "activated", oldsec.activated)
          end
        end
      end)
    end
  end)
end

local function handleMwan()
  local provisioning_code = newConfig:get("env", "var", "provisioning_code")
  if provisioning_code == "2PVC" then
    local download_from_data = newConfig:get("env", "var", "download_from_data")
    if download_from_data ~= "0" then
      -- remove cwmpd host
      newConfig:delete("mwan", "cwmpd_host")
    end
    -- remove curl host. The curl host exists in r17.2.c.
    newConfig:delete("mwan", "curl_host")
  end
end

local function handleBulkdataReferencetime()
  math.randomseed(os.time())
  newConfig:foreach("bulkdata", "profile", function(s)
    local time_reference = s.time_reference
    if time_reference == "0001-01-01T00:00:00Z" then
      local refer_second = math.random(1540000000,1549999999)
      local refer_time = os.date("%Y-%m-%dT%H:%M:%SZ", refer_second)
      newConfig:set("bulkdata", s[".name"], "time_reference", refer_time)
    end
  end)
end

local function handleBulkdataHttpUri()
  newConfig:foreach("bulkdata", "profile", function(s)
    -- make sure list http_uri has at least three items
    if type(s.http_uri) == "table" then
      if not s.http_uri[2] or not s.http_uri[3] then
        newConfig:set("bulkdata", s[".name"], "http_uri", {s.http_uri[1], s.http_uri[2] or '', ''})
      end
    else
      newConfig:set("bulkdata", s[".name"], "http_uri", {'', '', ''})
    end
  end)
end

handleLedTod()
handleWifiDisableTod()
handleWifiGuestTod()
handleBoostStopTimers()
handleBoostStopActions()
handleHosts()
handle_user_friendly_name()
handleQosClassify()
handleFwSetting()
handleParental()
handleRestrictedAccess()
handleCallWaiting()
handleMwan()
handleBulkdataReferencetime()
handleBulkdataHttpUri()

newConfig:commit("tod")
newConfig:commit("user_friendly_name")
newConfig:commit("qos")
newConfig:commit("parental")
newConfig:commit("firewall")
newConfig:commit("fastweb")
newConfig:commit("mmpbx")
newConfig:commit("mwan")
newConfig:commit("bulkdata")
