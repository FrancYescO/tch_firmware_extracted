local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local match, format, gsub, untaint, find  = string.match, string.format, string.gsub, string.untaint, string.find
local tostring = tostring
local hostpath  =  "rpc.hosts.host."
local action_path = "uci.tod.action."
local timer_path = "uci.tod.timer."
local lease = {
  ["1800"] = "0h 30'" ,
  ["3600"] = "1h 00'" ,
  ["5400"] = "1h 30'" ,
  ["7200"] = "2h 00'" ,
  ["14400"] = "4h 00'"
}

local function convert2Sec(value)
  if value == nil or value == "" then return -1 end
  local  hour, min = value:match("(%d+):(%d+)")
  local secs = hour*3600 + min*60
  return tonumber(secs)
end

local modf = math.modf
local function updateDuration(time)
  if not time or time == 0 then
    return "00:00"
  end
  local days = modf(time /86400)
  local hours = modf(time / 3600)-(days * 24)
  local minutes = modf(time /60) - (days * 1440) - (hours * 60)
  local seconds = time
  return string.format("%02d:%02d", hours, minutes)
end

local function devices_data_format(host, type)
  local connected_devs = {
    total_num = 0,
  }
  local numbers = 0
  local history_devs = {
    total_num = 0,
    device_history_list = "end"
  }
  local family_devs = {
    total_num = 0,
  }
  local count0 = 0
  local count1 = 0
  local count2 = 0
  for i,v in ipairs(host) do
    if not host[v.paramindex] then
      local stop_enabled = v.stop_enabled or "0"
      local boost_enabled  = v.boost_enabled or "0"
      local boost_duration = v.boost_duration  or "5400"
      local stop_duration = v.stop_duration or "5400"
      local last_connect_timer = os.date("%Y-%m-%dT%H:%M", tonumber(post_helper.secondsToTime(v.connectedtime)))
      if v.devicetype == "1" then
        family_devs.total_num = family_devs.total_num + 1
        family_devs["dev_"..(count2).."_name"] = v.hostname
        family_devs["dev_"..(count2).."_mac"] = v.macAddress
        family_devs["dev_"..(count2).."_ip"] = v.ipaddress
        family_devs["dev_"..(count2).."_icon"] = v.deviceicon
        family_devs["dev_"..(count2).."_online"] = v.state
        family_devs["dev_"..(count2).."_last_connection"] = last_connect_timer
        family_devs["dev_"..(count2).."_network"] = "network1"
        family_devs["dev_"..(count2).."_parental"] = v.deviceparental or "0"
        family_devs["dev_"..(count2).."_boost_scheduled"] = boost_enabled
        family_devs["dev_"..(count2).."_boost_mon"] = v.boost_Mon or "0"
        family_devs["dev_"..(count2).."_boost_tue"] = v.boost_Tue or "0"
        family_devs["dev_"..(count2).."_boost_wed"] = v.boost_Wed or "0"
        family_devs["dev_"..(count2).."_boost_thu"] = v.boost_Thu or "0"
        family_devs["dev_"..(count2).."_boost_fri"] = v.boost_Fri or "0"
        family_devs["dev_"..(count2).."_boost_sat"] = v.boost_Sat or "0"
        family_devs["dev_"..(count2).."_boost_sun"] = v.boost_Sun or "0"
        family_devs["dev_"..(count2).."_boost_duration"] = boost_duration
        family_devs["dev_"..(count2).."_boost_start"] = v.boost_start or "00:00"
        family_devs["dev_"..(count2).."_stop_scheduled"] = stop_enabled
        family_devs["dev_"..(count2).."_stop_mon"] = v.stop_Mon or "0"
        family_devs["dev_"..(count2).."_stop_tue"] = v.stop_Tue or "0"
        family_devs["dev_"..(count2).."_stop_wed"] = v.stop_Wed or "0"
        family_devs["dev_"..(count2).."_stop_thu"] = v.stop_Thu or "0"
        family_devs["dev_"..(count2).."_stop_fri"] = v.stop_Fri or "0"
        family_devs["dev_"..(count2).."_stop_sat"] = v.stop_Sat or "0"
        family_devs["dev_"..(count2).."_stop_sun"] = v.stop_Sun or "0"
        family_devs["dev_"..(count2).."_stop_duration"] = stop_duration
        family_devs["dev_"..(count2).."_stop_start"] = v.stop_start or "00:00"
        family_devs["dev_"..(count2).."_type_of_connection"] = v.interfacetype
        --family_devs["dev_"..(count2).."_routine"] = (boost_enabled == "1" or stop_enabled == "1") and "1" or "0"
        family_devs["dev_"..(count2).."_routine"] = v.boost_routine
        count2 = count2 + 1
      end
      if v.state == "1" then
        connected_devs.total_num = connected_devs.total_num + 1
        connected_devs["dev_"..(count0).."_name"] = v.hostname
        connected_devs["dev_"..(count0).."_mac"] = v.macAddress
        connected_devs["dev_"..(count0).."_ip"] = v.ipaddress
        if  v.devicetype == "1" then
          connected_devs["dev_"..(count0).."_family"] = "1"
        else
          connected_devs["dev_"..(count0).."_family"] = "0"
        end
        connected_devs["dev_"..(count0).."_type_of_connection"] = v.interfacetype
        connected_devs["dev_"..(count0).."_network"] = "network1"
        connected_devs["dev_"..(count0).."_icon"] = v.deviceicon
        connected_devs["dev_"..(count0).."_boost"] = boost_enabled
        connected_devs["dev_"..(count0).."_boost_remaining"] = boost_duration
        connected_devs["dev_"..(count0).."_stop"] = stop_enabled
        connected_devs["dev_"..(count0).."_stop_remaining"] = stop_duration
        connected_devs["connected_device_list"] = "end"
        count0 = count0 + 1
      end
      if v.state == "0" then
        history_devs.total_num = history_devs.total_num + 1
        history_devs["dev_"..(count1).."_name"] = v.hostname
        history_devs["dev_"..(count1).."_mac"] = v.macAddress
        history_devs["dev_"..(count1).."_last_connection"] = last_connect_timer
        history_devs["dev_"..(count1).."_ip"] = v.ipaddress
        history_devs["device_history_list"] = "end"
        count1 = count1 + 1
      end
    end
  end
  if type == "connected" then
    return connected_devs
  elseif type == "history" then
    return history_devs
  elseif  type == "family" then
    return  family_devs
  end
end

local function get_devices_columns(status_type)
  local devices_columns = {}
  local hosts = content_helper.convertResultToObject(hostpath, proxy.get(hostpath))
  for i,v in ipairs(hosts) do
    local type, icon, parental = "0", "7", "0"
    if v.DeviceType ~= "" then
      type, icon, parental = v.DeviceType:match("^(.*):(%d*):(%d*)$")
      type = (type == "family") and "1" or "0"
      icon = (icon and icon ~= "") and icon or "7"
      parental = (parental and parental ~= "") and parental or "0"
    end
    local ipaddress = ""
    if v.DhcpLeaseIP ~= "" then
      ipaddress = v.DhcpLeaseIP
    elseif v.IPAddress ~= "" then
      ipaddress = v.IPAddress:match("^%d+%.%d+%.%d+%.%d+") or v.IPAddress:match("^%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*") or ""
    end

    if not hosts[v.paramindex] then
      local HostName = format("Device" .."%s",v.paramindex)
      devices_columns[#devices_columns+1] = {
        state = v.State,
        hostname = v.FriendlyName == "" and HostName or v.FriendlyName,
        ipaddress = ipaddress,
        macAddress = v.MACAddress,
        port = v.Port,
        connectedtime = v.ConnectedTime,
        devicetype = type,
        deviceicon = icon,
        deviceparental = parental,
        interfacetype = (find(v.L2Interface,"eth") ~= nil) and "0" or "1" ,
      }
    end
  end

  local actions = content_helper.convertResultToObject(action_path, proxy.get(action_path))
  local timers = content_helper.convertResultToObject(timer_path, proxy.get(timer_path))
  for k,v in ipairs(actions) do
    for index, value in ipairs(devices_columns) do
      local routine_stop_time = ""
      local routine_start_time = ""
      if find(v.object, value.macAddress) then
        local update_index = ""
        local timer_index = proxy.get(action_path  .. v.paramindex .. ".timers.@1.value")[1].value
        local wt = {
          start = untaint(timer_path .. "@" ..  timer_index  .. ".start_time"),
          stop = untaint(timer_path .. "@" ..  timer_index  .. ".stop_time"),
        }
        local ce = {
          enabled = untaint(action_path  .. v.paramindex  .. ".enabled"),
        }
        local cr = {
          routine = untaint(timer_path .. "@" ..  timer_index  .. ".routine"),
        }
        content_helper.getExactContent(wt)
        content_helper.getExactContent(ce)
        content_helper.getExactContent(cr)
        local stop_time_weekdays = wt.stop
        local stop_time = match(stop_time_weekdays, "%w+:(%d+:%d+)")
        local start_time_weekdays = wt.start
        local start_time = match(start_time_weekdays, "%w+:(%d+:%d+)")
        if find(v.paramindex, "routine") and status_type == "family" then
          if find(v.paramindex , "boost_action_routine") then
            update_index = "boost_"
          elseif find(v.paramindex , "stop_action_routine") then
            update_index = "stop_"
          else
            update_index = update_index
          end
          if find(start_time_weekdays,"All") then
            value[update_index .."Mon"] = "1"
            value[update_index .."Tue"] = "1"
            value[update_index .."Wed"] = "1"
            value[update_index .."Thu"] = "1"
            value[update_index .."Fri"] = "1"
            value[update_index .."Sat"] = "1"
            value[update_index .."Sun"] = "1"
          else
            value[update_index .."Mon"] = find(start_time_weekdays,"Mon") and "1" or "0"
            value[update_index .."Tue"] = find(start_time_weekdays,"Tue") and "1" or "0"
            value[update_index .."Wed"] = find(start_time_weekdays,"Wed") and "1" or "0"
            value[update_index .."Thu"] = find(start_time_weekdays,"Thu") and "1" or "0"
            value[update_index .."Fri"] = find(start_time_weekdays,"Fri") and "1" or "0"
            value[update_index .."Sat"] = find(start_time_weekdays,"Sat") and "1" or "0"
            value[update_index .."Sun"] = find(start_time_weekdays,"Sun") and "1" or "0"
          end
          if convert2Sec(stop_time) < convert2Sec(start_time) then
            value[update_index .."duration"] = tostring(convert2Sec(stop_time) + 24 *3600 - convert2Sec(start_time))
          else
            value[update_index .."duration"] = tostring(convert2Sec(stop_time) - convert2Sec(start_time))
          end
          value[update_index .."start"] = start_time
          value[update_index .."enabled"] = ce.enabled
          value[update_index .."routine"] = cr.routine
        end

        if find(v.paramindex, "online") and status_type == "connected" then
          local routine_timer_index = gsub(v.paramindex, "action_online", "routine")
          local routine_action_index = gsub(v.paramindex, "action_online", "action_routine")
          local rt = {
            enabled = untaint(action_path  .. routine_action_index  .. ".enabled"),
            start_time = untaint(timer_path .. routine_timer_index .. ".start_time"),
            stop_time = untaint(timer_path .. routine_timer_index .. ".stop_time"),
          }
          if find(v.paramindex , "boost_action_online") then
            local qos_classify_path = "uci.qos.classify."
            local qos_srcmac = content_helper.convertResultToObject(qos_classify_path, proxy.get(qos_classify_path))

            update_index = "boost_"
            value[update_index .."enabled"] = "0"
            if type(qos_srcmac) == "table"then
              for k,v in ipairs(qos_srcmac) do
                if v.srcmac == value.macAddress then
                  value[update_index .."enabled"] = "1"
                  for k,v in ipairs(timers) do
                    if v.paramindex == routine_timer_index then
                      content_helper.getExactContent(rt)
                    end
                  end
                end
              end
            end
          elseif find(v.paramindex , "stop_action_online") then
            local tod_host_path = "uci.tod.host."
            local tod_hosts = content_helper.convertResultToObject(tod_host_path, proxy.get(tod_host_path))
            update_index = "stop_"
            value[update_index .."enabled"] = "0"
            if type(tod_hosts) == "table"then
              for k,v in ipairs(tod_hosts) do
                if v.id == value.macAddress then
                  value[update_index .."enabled"] = v.enabled
                  if v.enabled == "1" then
                    for k,v in ipairs(timers) do
                      if v.paramindex == routine_timer_index then
                        content_helper.getExactContent(rt)
                      end
                    end
                  end
                end
              end
            end
          else
            update_index = update_index
          end
          if value[update_index .."enabled"] == "0" then
            value[update_index .."duration"] = "0"
          else
            local current_time = os.date("%H:%M:%S", os.time())
            local cts = convert2Sec(current_time)
            local ops = convert2Sec(start_time)
            ops = (ops > cts) and ops or ops + 86400
            rt.start_time = match(rt.start_time, "(.*:%d+:%d+)")
            rt.stop_time = match(rt.stop_time, "(.*:%d+:%d+)")
            if rt.enabled == "0" or rt.start_time == "" or rt.start_time == nil or rt.stop_time == nil or rt.stop_time == "" then
              value[update_index .."duration"] = ops - cts
            else
              local weekdays = match(rt.start_time, "(.*):%d+:%d+")
              local rss = convert2Sec(match(rt.start_time, "%w+:(%d+:%d+)"))
              local rps = convert2Sec(rt.stop_time)
              rps = (rps > rss) and rps or rps + 86400
                local current_weekday = os.date("%a", os.time())
                if (weekdays == "All" or find(weekdays, current_weekday)) and (rss < ops)  and (cts < rps) then
                  value[update_index .."duration"] = rps - cts
                else
                  value[update_index .."duration"] = ops - cts
                end
            end
          end
        end
      end
    end
  end
  return devices_data_format(devices_columns, status_type)
end

local service_connected_device = {
  name = "connected_device_list"
}

service_connected_device.get  = function()
  return get_devices_columns("connected")
end

local service_family_device = {
  name = "family_device_list"
}

service_family_device.get = function()
  return  get_devices_columns("family")
end

local service_device_history = {
  name = "device_history_list"
}

service_device_history.get  = function()
  return  get_devices_columns("history")
end

local function get_weekdays(args, mode)
  local index = mode:match("^(.*_)routine$")
  if not index then
    return ""
  end

  local weekdays = {}
  if args[index .. "mon"] == "1" then weekdays[#weekdays+1] = "Mon" end
  if args[index .. "tue"] == "1" then weekdays[#weekdays+1] = "Tue" end
  if args[index .. "wed"] == "1" then weekdays[#weekdays+1] = "Wed" end
  if args[index .. "thu"] == "1" then weekdays[#weekdays+1] = "Thu" end
  if args[index .. "fri"] == "1" then weekdays[#weekdays+1] = "Fri" end
  if args[index .. "sat"] == "1" then weekdays[#weekdays+1] = "Sat" end
  if args[index .. "sun"] == "1" then weekdays[#weekdays+1] = "Sun" end

  local weekstr = ""
  if #weekdays == 7 then
    weekstr = "All:"
  elseif #weekdays > 0 then
    weekstr = table.concat(weekdays, ",") .. ":"
  end

  return weekstr
end

local function do_online_checkbox(type, args)
  if type == "boost" then
    local boost_path = "uci.qos.classify."
    local boost_index = nil
    local boosted = "0"
    local boosts = content_helper.convertResultToObject(boost_path, proxy.get(boost_path))
    for i,v in ipairs(boosts) do
      if v.srcmac == args.mac and v.target == "Boost"  then
	boosted = "1"
        boost_index = v.paramindex
      end
    end
    if args.activate == "1" and not boost_index then
      --enable device boost
      boost_index = proxy.add(boost_path)
      proxy.set(format("%s%s.srcmac", boost_path, boost_index), args.mac)
      proxy.set(format("%s%s.order", boost_path, boost_index), "5")
      proxy.set(format("%s%s.target", boost_path, boost_index), "Boost")
    elseif args.activate == "0" and boosted == "1" then
      --boost deactivate
      proxy.del(format("%s%s.", boost_path,boost_index))
    end

  elseif type == "stop" then
    local stop_path = "uci.tod.host."
    local stop_index = nil
    local stopped = "0"
    local stops = content_helper.convertResultToObject(stop_path, proxy.get(stop_path))
    for i,v in ipairs(stops) do
      if v.id == args.mac  then
        stopped = v.enabled
        stop_index = v.paramindex
      end
    end
    if args.activate == "1" and not stop_index then
      stop_index = proxy.add(stop_path)
      proxy.set(format("%s%s.id", stop_path, stop_index), args.mac)
      proxy.set(format("%s%s.type", stop_path, stop_index), "mac")
      proxy.set(format("%s%s.mode", stop_path, stop_index), "block")
    end
    if stopped ~= args.activate  then
      proxy.set(format("%s%s.enabled", stop_path, stop_index), args.activate)
    end
  end
end

local function deviceTodInit(action, timer)
  local timerExist = proxy.get(timer_path .. "@" .. timer .. ".")
  local actionExist = proxy.get(action_path .. "@" .. action .. ".")
  local script = action:find("boost") and "boosttodscript" or "stoptodscript"
  if not timerExist then
    proxy.add(timer_path, timer)
  end
  if timer:find("online") then
    proxy.set(timer_path .. "@" .. timer .. ".periodic", "0")
  end
  if not actionExist then
    proxy.add(action_path, action)
    local actionTimerIndex = proxy.add(action_path .."@" .. action .. ".timers.")
    if actionTimerIndex then
      proxy.set(action_path .. "@" .. action .. ".timers."  .. "@" .. actionTimerIndex .. ".value", timer)
    end
  end
  if action ~= "" then
    proxy.set(action_path.."@" .. action .. ".script", script)
  end
  return true
end

local function deviceTodDataFormat(BSType, RTOLmode, args)
  local value = {}
  value["object"] = format("%s|%s","0", args.mac)
  value["start_time"] = os.date("%H:%M:%S", os.time())
  value["stop_time"] = "00:00"
  value["duration"] = tostring(untaint(args["counter"]))
  value["active"] = "1"
  value["weekdaysStart"] = get_weekdays(args, BSType .. "_" .. RTOLmode)
  value["weekdaysStop"] = value.weekdaysStart
  value["frequency"] = ""

  if RTOLmode == "routine" then
    value.start_time = args[BSType .. "_start"]
    value["duration"] = args[BSType .. "_duration"]
    if args["routine"] == "0" then
      value.active = "0"
    else
      value.active = args[BSType .. "_scheduled"] or "0"
    end
    value.object = format("%s|%s", "1", args.mac)
  elseif RTOLmode == "online" then
    value.start_time = match(value.start_time, "^%d+:%d+")
  end
  local stop_secs = convert2Sec(value.start_time) + tonumber(value.duration)
  if value.weekdaysStart == "" then
    value.weekdaysStart = os.date("%a", os.time()) .. ":"
    value.weekdaysStop = (stop_secs >= 24*3600) and (os.date("%a", os.time() + 24*3600) .. ":") or value.weekdaysStart
  end
  if find(value.weekdaysStart, "All") then
    value.frequency = "Daily"
  elseif find(value.weekdaysStart, "Sat,Sun") then
    value.frequency = "Weekends"
  elseif find(value.weekdaysStart, "Mon,Tue") then
    value.frequency = "Working days"
  end
  stop_secs = (stop_secs > 24*3600) and (stop_secs - 24*3600) or stop_secs
  value.stop_time = updateDuration(stop_secs)
  return value
end

local function device_boost_stop_update(args, mode)
  local todValue = {}
  local macIndex = gsub(args.mac , ":","_")
  local BSType = mode:find("boost") and "boost" or "stop"
  local RTOLmode = mode:find("routine") and "routine" or "online"
  local timerIndex = tostring(untaint(BSType .. "_" .. RTOLmode .. "_" .. macIndex))
  local actionIndex = tostring(untaint(BSType .. "_action_" .. RTOLmode .. "_" .. macIndex))
  --local deviceTodScript = (BSType == "boost") and "boosttodscript" or "stoptodscript"
  if RTOLmode == "online" and args.mac and args.activate then
    do_online_checkbox(BSType, args)
    if args.activate == "0" then
      --just deactivate, no need to deal with tod
      return
    end
  end
  deviceTodInit(actionIndex, timerIndex)
  local todValue = deviceTodDataFormat(BSType, RTOLmode, args)
  local paths = {}
  paths["uci.tod.action.@" .. actionIndex .. ".object"] =  todValue.object
  paths["uci.tod.action.@" .. actionIndex .. ".enabled"] = todValue.active
  paths["uci.tod.timer.@" .. timerIndex .. ".start_time"] = todValue.weekdaysStart .. todValue.start_time
  paths["uci.tod.timer.@" .. timerIndex .. ".start"] = todValue.start_time
  paths["uci.tod.timer.@" .. timerIndex .. ".stop_time"] = todValue.weekdaysStop .. todValue.stop_time
  paths["uci.tod.timer.@" .. timerIndex .. ".enabled"] = "1"
  paths["uci.tod.timer.@" .. timerIndex .. ".frequency"] = todValue.frequency
  paths["uci.tod.timer.@" .. timerIndex .. ".lease"]  = lease[tostring(untaint(todValue.duration))] or ""
  paths["uci.tod.timer.@" .. timerIndex .. ".routine"]  = args.routine and args.routine or "0"
  if  RTOLmode == "online" and args.activate == "1" and todValue.duration ~= "0" and todValue.duration ~= "-1" then
  --online tod to end the boost or stop when timeout
    paths["uci.tod.timer.@" .. timerIndex .. ".start_time"] = todValue.weekdaysStop .. todValue.stop_time
    paths["uci.tod.timer.@" .. timerIndex .. ".stop_time"] = ""
  end
  proxy.set(paths)
end

local service_stop_device = {
  name = "stop_device"
}

service_stop_device.set = function(args)
  device_boost_stop_update(args, "stop_online")
  proxy.apply()
  os.execute("sleep 1")
  return true
end

local service_boost_device = {
  name = "boost_device"
}

service_boost_device.set = function(args)
  device_boost_stop_update(args,"boost_online")
  proxy.apply()
  os.execute("sleep 1")
  return true
end

local service_family_device_add = {
  name = "family_device_add"
}

local function family_device_update(args, host_index)
  local family_device_status ={}
  device_boost_stop_update(args, "boost_routine")
  device_boost_stop_update(args, "stop_routine")

  if tonumber(host_index) > 0 then
    if args.icon_id == "" or args.icon_id == "00" or args.icon_id == nil then
      args.icon_id = "7"
    end
    local devtype = format("family:%s:%s", args.icon_id, args.parental_ctl)
    family_device_status[hostpath .. (host_index) .. ".DeviceType"] = devtype
    family_device_status[hostpath .. (host_index) .. ".FriendlyName"] = args.family_name
    proxy.set(family_device_status)
  end
  proxy.apply()
  return true
end

service_family_device_add.set = function(args)
  local family_device_status ={}
  local host_index = 0
  local hosts = content_helper.convertResultToObject(hostpath, proxy.get(hostpath))
  local dev_type = ""
  for k,v in ipairs(hosts) do
    if v.MACAddress == args.mac then
      host_index = v.paramindex
      dev_type = v.DeviceType
    end
  end
  if args.stop_scheduled == nil then
    local type, icon, parental = "0", "7", "0"
    if dev_type ~= "" then
      type, icon, parental = dev_type:match("^(.*):(%d*):(%d*)$")
      icon = (icon and icon ~= "") and icon or "7"
      parental = (parental and parental ~= "") and parental or "0"
    end
    proxy.set(hostpath .. (host_index) .. ".DeviceType", "family:" .. icon .. ":" .. parental)
  else
    family_device_update(args, host_index)
  end
  proxy.apply()
  return true
end

local service_family_device_del = {
  name = "family_device_del"
}
service_family_device_del.set = function(args)
  local hosts = content_helper.convertResultToObject(hostpath, proxy.get(hostpath))
  for k,v in ipairs(hosts) do
    if v.MACAddress == args.mac then
      local devtype = proxy.get(hostpath .. (v.paramindex) .. ".DeviceType")[1].value
      devtype = gsub(devtype, "family", "")
      proxy.set(hostpath .. (v.paramindex) .. ".DeviceType", devtype)
      break
    end
  end

  local mac_index = gsub(untaint(args.mac) , ":","_")
  local paths = {}
  paths["uci.tod.timer.@boost_routine_" .. mac_index .. ".routine"] = "0"
  paths["uci.tod.timer.@stop_routine_" .. mac_index .. ".routine"] = "0"
  paths["uci.tod.action.@boost_action_routine_" .. mac_index .. ".enabled"] = "0"
  paths["uci.tod.action.@stop_action_routine_" .. mac_index .. ".enabled"] = "0"
  proxy.set(paths)
  proxy.apply()
  return true
end

local service_generic_device_edit = {
  name = "generic_device_edit"
}

service_generic_device_edit.set = function(args)
  local generic_device_info = {}
  local hosts = content_helper.convertResultToObject(hostpath, proxy.get(hostpath))
  for k,v in ipairs(hosts) do
    if v.MACAddress == args.mac then
      local devtype = proxy.get(hostpath .. (v.paramindex) .. ".DeviceType")[1].value
      local icon_id = args.icon_id or "7"
      local deviceparental = match(devtype, ":(%d+)$") or "0"
      devtype =  ":" .. icon_id .. ":" .. deviceparental
      generic_device_info[untaint(hostpath .. (v.paramindex) .. ".FriendlyName")] = args.name
      generic_device_info[untaint(hostpath .. (v.paramindex) .. ".DeviceType")] = devtype
      proxy.set(generic_device_info)
      proxy.apply()
      break
    end
  end
  return true
end

register(service_connected_device)
register(service_family_device)
register(service_device_history)
register(service_stop_device)
register(service_boost_device)
register(service_family_device_add)
register(service_family_device_del)
register(service_generic_device_edit)
