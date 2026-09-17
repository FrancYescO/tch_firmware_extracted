local ipairs, pairs, error, print = ipairs, pairs, error, print
local M = {}
local strfind = string.find
local strsub = string.sub
local strlen = string.len
local runtime = {}
local actionlist
local cb

-- weekday in order of time standard, must not be changed
local weekday = {Sun = 0, Mon = 1, Tue = 2, Wed = 3, Thu = 4, Fri = 5, Sat = 6}
local defstarttime = "00:00"
local defstoptime = "23:59:59"
local weektimes = 604800 -- in second
local daytimes = 86400 -- in second

local TodTimer = {}
TodTimer.__index = TodTimer

function TodTimer:update(day, time)
    -- Reset the utimer with day time according to changed system time.
    local timeout

    timeout = wdtimeout(day, time)

    if self.active == true and self.cbtype == "stop" then
        -- stop timer active=true means it should be triggered immediatelly
        timeout = timeout - (weektimes * 1000)
    end

    self.tout = timeout

    if self.utimer ~= nil then
        -- for aperiodic timer, the utimer will be canceled after triggered once.
        self.utimer:set(timeout)
        runtime.logger:info("time changed, update timer "..self.actionname.."."..self.timername.." "..day..":"..time.." timeout=" .. tostring(timeout/1000).."s")
    end
end

function TodTimer:cancel()
    self.utimer:cancel()
end

function M.init(rt, script_cb, actlist)
    runtime = rt
    cb = script_cb
    actionlist = actlist
end

function M.gettime(time)
    local hour, min, sec
    local hep, msp, mep, ssp

    hep = strfind(time, ":") - 1 -- hour ends position
    msp = hep + 2  -- min starts position
    mep = strfind(time, ":", msp) -- if sec was specified, mark the min ends position
    if mep == nil then
        mep = -1
    else
        mep = mep - 1
        ssp = mep + 2  -- if sec was specified, mark the sec starts position
    end

    hour = tonumber(strsub(time, 1, hep))
    min = tonumber(strsub(time, msp, mep))
    if mep > 0 then
        sec = tonumber(strsub(time, ssp, -1))
        if sec == nil then
            sec = 0
        end
    else
        sec = 0
    end

    return hour, min, sec
end

function wdtimeout(day, time)
    local diffdays, actdayidx
    local acthour, actmin, actsec
    local todayidx = tonumber(os.date("%w"))

    for k,v in pairs(weekday) do
        if day == tostring(k) then
            actdayidx = v
        end
    end

    if actdayidx >= todayidx then
        diffdays = actdayidx - todayidx
    else
        diffdays = 7 - todayidx + actdayidx
    end

    acthour, actmin, actsec = M.gettime(time)

    local curtime = os.date("*t")
    -- set day=1 to ease the calculation, no need to consider number of days in month
    local baseday = {year=curtime.year, month=curtime.month, day=1, hour=curtime.hour, min=curtime.min, sec=curtime.sec}
    local actdate = 1 + diffdays
    local actday = {year=curtime.year, month=curtime.month, day=actdate, hour=acthour, min=actmin, sec=actsec}

    local difftime = (os.time(actday) - os.time(baseday)) 
    if difftime == 0 then
        difftime = difftime + 1
    elseif difftime < 0 then
        difftime = weektimes + difftime
    end

    return difftime * 1000
end

function getdurationday(day, duration)
    local ndidx = weekday[day] + duration
    if ndidx > 6 then
        ndidx = ndidx - 7
    end

    for day,i in pairs(weekday) do
        if ndidx == i then
            return day
        end
    end
end

function weekdaycompare(day1, day2)
    return weekday[day1] < weekday[day2]
end

-- Ccheck whether currently it's in some timeslot, if so trigger its start_time action.
-- For action without stop time i.e. no revert behaviour, no conception of timeslot.
-- Note: we don't force to check the timeslot overlap because as the tod framework it allows to define action
-- only has start time i.e. no revert behaviour. Then for this kind of action timer, the start time could
-- be continuous without stop time in between. Therefore, it's for the specific action script to support (or not) 
-- the logic of embedded/overlap timeslot. This tod framework only invokes action at specific time.
function M.checktimeslot(timer, obsolete_active_ts_nb, valid_activedaytime,force_restart)
    local starttime, newtout, startday
    local idle_obsolete_active_ts_nb = obsolete_active_ts_nb

    for didx,day in ipairs(timer.dayorder) do
        if timer[day] ~= nil and timer[day] ~= "" then
            for tidx,t in ipairs(timer[day].timeorder) do
                if timer[day][t].cbtype == "stop" then
                    if tidx == 1 then
                        if didx == 1 then
                            predidx = table.getn(timer.dayorder)
                        elseif didx > 1 then
                            predidx = didx - 1
                        end

                        startday = timer.dayorder[predidx]
                        if timer[startday] ~= nil then
                            starttime = timer[startday].timeorder[table.getn(timer[startday].timeorder)]
                        else
                            runtime.logger:error(timer[day][t].actionname.."."..timer[day][t].timername.." day time table of "..startday.." is nil")
                        end
                    elseif tidx > 1 then
                        starttime = timer[day].timeorder[tidx-1]
                        startday = day
                    end

                    -- if 'stop' time's previous time is 'start' then it's a timeslot,
                    -- otherwise this is standalone 'stop' in the timer.
                    if startday ~= nil and timer[startday] ~= nil and timer[startday][starttime].cbtype == "start" then
                        timer[startday][starttime].pairday = day
                        timer[startday][starttime].pairtime = t
                        timer[day][t].pairday = startday
                        timer[day][t].pairtime = starttime
                        runtime.logger:info("find timeslot "..timer[day][t].actionname.."."..timer[day][t].timername.." "..startday.."_"..starttime.."-"..day.."_"..t)

                        if timer[day][t].tout - timer[startday][starttime].tout < 0 then
                            if force_restart == 0 and timer[startday][starttime].active == true then
                                -- reload still in the same timeslot, do nothing
                                runtime.logger:notice("reload still in the same time slot, action has been started, do nothing now "..timer[day][t].actionname.."."..timer[day][t].timername.." "..startday.."_"..starttime.."-"..day.."_"..t)
                            elseif idle_obsolete_active_ts_nb > 0 then
                                -- reload in the timeslot which corresponds to a old active timeslot, do nothing
                                idle_obsolete_active_ts_nb = idle_obsolete_active_ts_nb - 1
                                table.insert(valid_activedaytime, timer[startday][starttime].timername..":"..startday..":"..starttime)
                                runtime.logger:notice("reload in time slot corresponds to old active timeslot, action has been started, do nothing now "..timer[day][t].actionname.."."..timer[day][t].timername.." "..startday.."_"..starttime.."-"..day.."_"..t)
                            else
                                -- reload into the timeslot, set start timeout to minus so that it will be triggered immediately
                                newtout = timer[startday][starttime].tout - (weektimes * 1000)
                                timer[startday][starttime].tout = newtout
                                timer[startday][starttime].utimer:set(newtout)
                                runtime.logger:notice("reload into timeslot, "..timer[day][t].actionname.."."..timer[day][t].timername.." "..startday.."_"..starttime.."-"..day.."_"..t.." start timeout="..tostring(newtout/1000).."s")
                            end
                        elseif timer[day][t].tout - timer[startday][starttime].tout > 0 then
                            if timer[startday][starttime].active == true then
                                -- reload out from the timeslot, set stop timeout to minus so that it will be triggered immediately
                                newtout = timer[day][t].tout - (weektimes * 1000)
                                timer[day][t].tout = newtout
                                timer[day][t].utimer:set(newtout)
                                runtime.logger:notice("reload out from timeslot, "..timer[day][t].actionname.."."..timer[day][t].timername.." "..startday.."_"..starttime.."-"..day.."_"..t.." stop timeout="..tostring(newtout/1000).."s")
                            end
                        end
                    end
                end
            end
        end
    end

    return idle_obsolete_active_ts_nb
end

function starttimer(uciactionname, ucitimername, day, time, callbacktype, activedaytime, valid_activedaytime, uciperiodic)
    local timertable
    local ulooptimer
    local timeout
    local isactive = false

    if activedaytime ~= nil then
        for k,atvdt in pairs(activedaytime) do
            local activetimer, activeday, activetime
            local tep = strfind(atvdt, ":") - 1
            local dep = strfind(atvdt, ":", tep + 2) - 1
            local tsp = dep + 2
            activetimer = strsub(atvdt, 1, tep)
            activeday = strsub(atvdt, tep + 2, dep)
            activetime = strsub(atvdt, tsp, -1)

            if ucitimername == activetimer and day == activeday and time == activetime then
                isactive = true
                -- 1.Find the activedaytime record which has corresponding timer configured in the action,
                -- and remove it from the list if found. Then the remained items at last means its original
                -- timeslot was modified and doesn't exist now. And the remained items should be processed.
                -- to check if revert action is needed depends on the current action status.
                -- 2.On the other hand, these items should also be removed from the action configuration.
                -- And only these valid items should be kept in the configuration record.
                table.insert(valid_activedaytime, atvdt)
                table.remove(activedaytime, k)
                break
            end
        end
    end

    timeout = wdtimeout(day, time)

    ulooptimer = runtime.uloop.timer(function() cb(uciactionname, ucitimername, day, time) end, timeout)

    timertable = {utimer = ulooptimer, cbtype = callbacktype, tout = timeout, actionname = uciactionname, timername = ucitimername, active = isactive, periodic = uciperiodic}
    setmetatable(timertable, TodTimer)
    runtime.logger:info("start action "..uciactionname.."."..ucitimername.." "..day.."_"..time.." "..callbacktype.." timeout="..tostring(timeout/1000) .. "s")

    return timertable
end

function createtimerofday(uciactionname, ucitimername, day, clocktime, callbacktype, activedaytime, timer, valid_activedaytime, uciperiodic)
    local time, hep

    if clocktime == nil or clocktime == "" then
        -- if no explicit start or stop time, assume it's once action in that day
        runtime.logger:notice("no "..callbacktype.." time in timer of "..uciactionname)
    else
        -- only allows one start and stop clock in a timer
        hep = strfind(clocktime, ":")

        if hep == nil or hep > 3 then
            runtime.logger:error("time format error " .. callbacktype .. ": " .. clocktime)
        elseif hep == 1 then
            time = "00" .. clocktime  -- :min
        elseif hep == 2 then
            time = "0" .. clocktime  -- prefixing '0' for format x:min ensure time ascending order in table
        else
            time = clocktime
        end

        if timer[day] == nil then
            timer[day] = {}
            timer[day].timeorder = {}
            table.insert(timer.dayorder, day)
        end

        if timer[day][time] ~= nil then
            -- collision action on the same day and time
            runtime.logger:error("collision actions at the same daytime "..uciactionname.." "..day.."_"..time.." of "..callbacktype.." and "..timer[day][time].cbtype)
        else
            timer[day][time] = starttimer(uciactionname, ucitimername, day, time, callbacktype, activedaytime, valid_activedaytime, uciperiodic)
            table.insert(timer[day].timeorder, time)
            table.sort(timer[day].timeorder)
        end
    end

    return true
end

function timerparser(ucitimestr, ucitimername)
    local dayclock_separator = ":"
    local weekday_separator = ","
    local weekday_str
    local dsep, csp, dwsp, dwep
    local daytb = {}
    local clock

    dsep = strfind(ucitimestr, dayclock_separator) -- day string ends position
    if dsep == nil or dsep <= 3 then
        runtime.logger:error("weekdays of timer " .. ucitimername .. " is wrong format")
        return nil
    end

    dsep = dsep - 1
    csp = dsep + 2 -- clock string starts position

    clock = strsub(ucitimestr, csp, -1)
    if strfind(clock, ",") or strfind(clock, " ") or strlen(clock) > 8 then
        -- only one clock value can be set in a ucitimestr
        runtime.logger:error("weekdays of timer " .. ucitimername .. " is wrong format with clock time")
    end

    weekday_str = strsub(ucitimestr, 1, dsep)

    dwsp = 1 -- day word starts position
    repeat
        dwep = strfind(weekday_str, weekday_separator, dwsp) -- day word ends position

        if dwep == nil then -- only one item of weekdays
            dwep = dsep
        else
            dwep = dwep - 1
        end

        dayword = strsub(weekday_str, dwsp, dwep)
        if dayword == "All" then
            for day,idx in pairs(weekday) do
                table.insert(daytb, day)
            end
        else
            table.insert(daytb, dayword)
        end

        dwsp = dwep + 2
        while strsub(weekday_str, dwsp, dwsp) == " " do -- jump over blank
            dwsp = dwsp + 1
        end
    until dwsp >= csp
    table.sort(daytb, weekdaycompare)

    return daytb, clock
end

function M.start(uciactionname, ucitimer, activedaytime, valid_activedaytime)
    local timer = {}
    local today = os.date("%a")
    local startdays = {}
    local stopdays = {}
    local startclock
    local stopclock

    timer.dayorder = {}

    if ucitimer.start_time ~= nil and ucitimer.start_time ~= "" then
        startdays, startclock = timerparser(ucitimer.start_time, ucitimer.name)

        for k, day in ipairs(startdays) do
            -- must parse start time firstly
            createtimerofday(uciactionname, ucitimer.name, day, startclock, "start", activedaytime, timer, valid_activedaytime, ucitimer.periodic)
        end
    end

    if ucitimer.stop_time ~= nil and ucitimer.stop_time ~= "" then
        stopdays, stopclock = timerparser(ucitimer.stop_time, ucitimer.name)

        for k, day in ipairs(stopdays) do
            createtimerofday(uciactionname, ucitimer.name, day, stopclock, "stop", activedaytime, timer, valid_activedaytime, ucitimer.periodic)
        end
    end

    table.sort(timer.dayorder, weekdaycompare)

    return timer
end

return M
