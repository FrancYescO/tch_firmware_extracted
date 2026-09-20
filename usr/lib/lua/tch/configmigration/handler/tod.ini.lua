--require("tch.tableprint")
local uci_helper = require("transformer.mapper.ucihelper")
local ch = require("tch.configmigration.convert_helper")
local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")
local log_level = require("tch.configmigration.config").log_level
local logger = require("transformer.logger")
local log = logger.new("configmigration:tod.ini", log_level)

local gmatch = string.gmatch
local match = string.match
local format = string.format

local M = {}

local function add_section()
   local ucicmd = {}
   ucicmd.uci_config = "tod"
   ucicmd.uci_sectype = "host"
   ucicmd.action = "add"

   append_commit_list(ucicmd.uci_config)
   touci.touci(ucicmd)
end

--For one scheduleid, if there are many days, at most two days: one is weekday, one is weekend
local function get_time(tod_days)
    local wkstart_time = nil
    local wkstop_time = nil
    local wkendstart_time = nil
    local wkendstop_time = nil
    local each_daytime = {year=2015, month=1, day=16, sec=0, }
    local tmpweekday = ""

    for i=1, #tod_days do
        --if config two timerange for same weekday, means config wrong
        if ("" ~= tmpweekday) and (tmpweekday == tod_days[i].weekday) then
            log:critical("Bad configuration.")
            return nil
        end

        if (tod_days[i].weekday == "workweek") then
            tmpweekday = "workweek"
            each_daytime["hour"] = tod_days[i].starth
            each_daytime["min"] = tod_days[i].startm
            wkstart_time = os.time(each_daytime)
            each_daytime["hour"] = tod_days[i].endh
            each_daytime["min"] = tod_days[i].endm
            wkstop_time = os.time(each_daytime)
        elseif (tod_days[i].weekday == "weekend") then
            tmpweekday = "weekend"
            each_daytime["hour"] = tod_days[i].starth
            each_daytime["min"] = tod_days[i].startm
            wkendstart_time = os.time(each_daytime)
            each_daytime["hour"] = tod_days[i].endh
            each_daytime["min"] = tod_days[i].endm
            wkendstop_time = os.time(each_daytime)
        else -- the weekday is "all" with other config, means wrong cfg
             log:critical("Bad configuration, config all week and other cfg together.")
             return nil
        end
    end

    return wkstart_time, wkstop_time, wkendstart_time, wkendstop_time
end

local function add_list(weekday, tod_setindex)
    local ucicmd = {}
    ucicmd.uci_config = "tod"
    ucicmd.uci_secname = "@host["..tod_setindex.."]"
    ucicmd.uci_option = "weekdays"
    ucicmd.action = "add_list"

    if "all" == weekday then
        ucicmd.value = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
    elseif "workweek" == weekday then
        ucicmd.value = {"Mon", "Tue", "Wed", "Thu", "Fri"}
    else --weekend
        ucicmd.value = {"Sat", "Sun"}
    end

    append_commit_list(ucicmd.uci_config)
    touci.touci(ucicmd)
end

--For migration, to merge the time range under below rule
--1.In legacy, if workdays and weekends have the same time range, we migrate to Homeware and apply to the whole week.
--2.In legacy, if workdays and weekends have different time ranges, we migrate to Homeware and apply to workdays only.
local function is_the_same_timerange(wkstart_time, wkstop_time, wkendstart_time, wkendstop_time)
    if (0 == os.difftime(wkendstart_time, wkstart_time)) and (0 == os.difftime(wkstop_time, wkendstop_time)) then
        return true
    end

    return false
end

local function get_spec_time(tod_days)
    local tod_starttime = nil
    local tod_stoptime = nil

    if ("table" ~= type(tod_days)) then
        log:critical("Bad parameter type.")
        return nil
    end

    if (#tod_days == 1) then
        tod_starttime = format("%d:%02d", tod_days[1].starth, tod_days[1].startm)
        tod_stoptime = format("%d:%02d", tod_days[1].endh, tod_days[1].endm)

        return true, { {weekday = tod_days[1].weekday, starttime = tod_starttime, stoptime = tod_stoptime} }
    elseif (#tod_days == 2) then
        local wkstart_time = nil
        local wkstop_time = nil
        local wkendstart_time = nil
        local wkendstop_time = nil

        wkstart_time, wkstop_time, wkendstart_time, wkendstop_time = get_time(tod_days)
        if not wkstart_time or not wkstop_time or not wkendstart_time or not wkendstop_time then
           return nil
        end

        if is_the_same_timerange(wkstart_time, wkstop_time, wkendstart_time, wkendstop_time) then
           tod_starttime = format("%d:%02d", tod_days[1].starth, tod_days[1].startm)
           tod_stoptime = format("%d:%02d", tod_days[1].endh, tod_days[1].endm)
           return true, { {weekday = "all", starttime = tod_starttime, stoptime = tod_stoptime } }
        else
           local t = {}
           for k,v in ipairs(tod_days) do
               t[k] = { weekday = v.weekday,
                        starttime = format("%d:%02d", v.starth, v.startm),
                        stoptime = format("%d:%02d", v.endh, v.endm), }
           end
           return true, t
        end
    else
        log:critical("Bad configuration.")
    end

    return nil
end

function M.convert(g_user_ini)
    local section_string = g_user_ini["tod.ini"]
    local tod_setindex = 0

    for id in gmatch(section_string, "schedule add id=(%d+) type=accesscontrol") do
        local eachhostmac = nil
        local eachhoststate = nil

        eachhostmac, eachhoststate = match(section_string, "schedule modify scheduleid="..id.." mode=timerange reference=Hosts.Host.([%w:]+).*state=(%a+)")
        if eachhostmac and eachhoststate then
           --for each schedule id, there maybe many day ids
           local tod_days = {}

           for dayid, weekday in gmatch(section_string, "schedule dayadd scheduleid="..id.." id=(%d+) weekday=(%l+)") do
               local tod_eachday = {}

               tod_eachday.dayid = dayid
               tod_eachday.weekday = weekday
               tod_eachday.starth, tod_eachday.startm, tod_eachday.endh, tod_eachday.endm = match(section_string, "schedule timeadd scheduleid="..id.." dayid="..dayid.." id=%d+ starthour=(%d+) startminute=(%d+) endhour=(%d+) endminute=(%d+) action=.*")

               if tod_eachday.starth and tod_eachday.startm and tod_eachday.endh and tod_eachday.endm then
                   tod_days[#tod_days+1] = tod_eachday
               end
           end

           --if the tod_days is not null, means get whole config
           if (#tod_days > 0) then
              local ret, tod_entries = get_spec_time(tod_days)
              if ret and tod_entries then --means config right
                 for _,v in ipairs(tod_entries) do
                     --add a section:eg. uci add tod host
                     add_section()

                     --to set all the option
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "_key", uci_helper.generate_key())
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "id", eachhostmac)
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "start_time", v.starttime)
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "type", "mac")--need test
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "enabled", ch.convert_bool(nil, eachhoststate))
                     ch.set_each_section("tod", "@host["..tod_setindex.."]",  "mode", "block") --need test
                     ch.set_each_section("tod", "@host["..tod_setindex.."]", "stop_time", v.stoptime)

                     add_list(v.weekday, tod_setindex)

                     tod_setindex = tod_setindex + 1
                 end
              end
           end
        end
    end
end

return M
