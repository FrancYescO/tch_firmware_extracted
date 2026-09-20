local M = {}
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")

local uinetwork = require("web.uinetwork_helper")
local string = string
local tonumber = tonumber
local r_hosts_ac
local ngx = ngx

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

local function hosts_ac_ip2mac(t)
  if not t then return nil end
  for k,v in pairs(t) do
      local mac = string.match(k, "%[%s*([%x:]+)%s*%]")
      if mac then
         t[k] = mac
      end
  end
  return t
end

local function revert_kv(t)
  local nt = {}
  if type(t) ~= "table" then return nt end
  for k,v in pairs(t) do
      nt[v] = k
  end
  return nt
end

function M.get_hosts_ac()
  -- convert auto-complete table from IP to MAC
  return hosts_ac_ip2mac(uinetwork.getAutocompleteHostsListIPv4())
end

local function tod_aggregate(data)
    return ui_helper.createSimpleCheckboxSwitch("enabled", data[1], nil)
end

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { string.match(value, timepattern) }
    if #time == 2 then
       local hour = tonumber(time[1])
       local min = tonumber(time[2])
       if hour < 0 or hour > 23 then
          return nil, T"Invalid hour, must be between 0 and 23"
       end
       if min < 0 or min > 59 then
          return nil, T"Invalid minutes, must be between 0 and 59"
       end
       if key == "stop_time" then
          local start = string.gsub(string.untaint(object["start_time"]),":","")
          local stop = string.gsub(string.untaint(object["stop_time"]),":","")
          if tonumber(start) > tonumber(stop) then
             return nil, T"The time range is incorrect"
          end
       end

       return true
    else
       return nil, T"Invalid time (must be hh:mm)"
    end
end

local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local gVCS = post_helper.getValidateCheckboxSwitch()
local vSIM = post_helper.validateStringIsMAC

local function theWeekdays()
    return {
      { "Mon", T"Mon." },
      { "Tue", T"Tue." },
      { "Wed", T"Wed." },
      { "Thu", T"Thu." },
      { "Fri", T"Fri." },
      { "Sat", T"Sat." },
      { "Sun", T"Sun." },
    }
end

local function getWeekDays(value, object, key)
    local getValidateWeekDays = gVIC(theWeekdays())
    local ok, msg = getValidateWeekDays(value, object, key)

    if not ok then
        return ok, msg
    end
    local canary
    local canaryvalue = ""
    for k,v in ipairs(object[key]) do
        if v == canaryvalue then
            canary = k
        end
    end
    if canary then
        table.remove(object[key], canary)
    end
    return true
end

local function tod_sort_func(a, b)
  return a["id"] < b["id"]
end

function M.mac_to_hostname(mac)
  local hostname = ""
  if not mac then return hostname end
  local dev_detail_info = r_hosts_ac[mac]
  if dev_detail_info then
     hostname = string.match(dev_detail_info, "(%S+)%s+%(") or "Unknown-"..mac
  else
     hostname = "Unknown-"..mac
  end
  return hostname
end

-- since tod_default.type is "mac", the "id" will be MAC, we try to convert it
-- to friendly name, otherwise, add "Unknown-" prefix.
local function tod_mac_to_hostname(tod_data)
  if type(tod_data) ~= "table" then
     return
  end
  for _,v in ipairs(tod_data) do
      -- index is '2' due to in tod_columns, the one header = "Hostname" is 2.
      v[2] = M.mac_to_hostname(string.untaint(v[2]))
  end
end

function M.getTod()
  setlanguage()

  local todmodes = {
    { "allow", T"Allow" },
    { "block", T"Block" },
  }

  -- ToD forwarding rules
  local tod_columns = {
    {
        header = T"Status",
        name = "enabled",
        param = "enabled",
        type = "light",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[1]
    {
        header = T"Hostname",
        name = "id",
        param = "id",
        type = "text",
        readonly = true,
        attr = { input = { class="span3" } },
    }, --[2]
    {
        header = T"Start Time",
        name = "start_time",
        param = "start_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[3]
    {
        header = T"Stop Time",
        name = "stop_time",
        param = "stop_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[4]
    {
        header = T"Mode",
        name = "mode",
        param = "mode",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[5]
    {
        header = T"Day of weeks",
        name = "weekdays",
        param = "weekdays",
        values = theWeekdays(),
        type = "checkboxgroup",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[6]
    {   -- NOTE: don't foget update M.getTod() when change position
        header = "", --T"ToD",
        legend = T"Time of day access control",
        name = "timeofday",
        --param = "enabled",
        type = "aggregate",
        synthesis = nil, --tod_aggregate,
        subcolumns = {
            {
                header = T"Enabled",
                name = "enabled",
                param = "enabled",
                type = "checkboxswitch",
                default = "1",
                attr = { checkbox = { class="inline" } },
            },
            {   -- NOTE: don't foget update M.getTod() when change position
                header = T"Hostname",
                name = "id",
                param = "id",
                type = "text",
                attr = { input = { class="span2", maxlength="17"}, autocomplete=M.get_hosts_ac() },
            },
            {
                header = T"Mode",
                name = "mode",
                param = "mode",
                type = "select",
                values = todmodes,
                default = "allow",
                attr = { select = { class="span2" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Day of week",
                name = "weekdays",
                param = "weekdays",
                type = "checkboxgroup",
                values = theWeekdays(),
                attr = { checkbox = { class="inline" } },
            },
        }
    }, --[7]
  }

  local tod_valid = {
    ["mode"]        = gVIES(todmodes),
    ["start_time"]  = validateTime,
    ["stop_time"]   = validateTime,
    ["weekdays"]    = getWeekDays,
    ["enabled"]     = gVCS,
    ["id"]          = vSIM,
  }

  local tod_default = {
    ["type"] = "mac",
  }

  local host_ac = M.get_hosts_ac()
  -- hot-update hostname autocomplete list when refresh page each time
  tod_columns[7].subcolumns[2].attr.autocomplete = host_ac
--[[
example:
  r_hosts_ac = {
                 ["00:13:46:e7:4a:a4"] = "BJNGDRND00757 (10.0.0.78) [00:13:46:e7:4a:a4]",
                 ["d4:be:d9:92:99:51"] = "10.0.0.202 [d4:be:d9:92:99:51]",
               }
--]]
  r_hosts_ac = revert_kv(host_ac)

  return {
    columns = tod_columns,
    valid   = tod_valid,
    default = tod_default,
    sort_func = tod_sort_func,
    mac_to_hostname = tod_mac_to_hostname,
  }
end

return M
