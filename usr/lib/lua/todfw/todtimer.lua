local ipairs, pairs, error, print = ipairs, pairs, error, print
local M = {}
local strfind = string.find
local strsub = string.sub
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
    self.utimer:set(timeout)
    runtime.logger:info("time changed, update timer " .. self.actname .. " " .. day .. "_" .. time .. " timeout=" .. tostring(timeout/1000) .. "s")
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

-- check whether currently it's in some timeslot, if so trigger its start_time action.
-- for action without stop time i.e. no revert behaviour, no conception of timeslot.
-- Note: we don't force to check the timeslot overlap because as the tod framework it allows to define action
-- only has start time i.e. no revert behaviour. Then for timer of this kind of action, the start time could
-- be continuous without stop time in between. Therefore, it's for the specific action script to support (or not) 
-- the logic of embedded/overlap timeslot. This tod framework only invokes action at specific time.
function checktimeslot(actname, timer)
    local starttime, newtout, startday
    local intimeslot = false

    for didx,day in ipairs(timer.dayorder) do
        if intimeslot == true then
            break
        end

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
                            runtime.logger:error(actname.." day time table of "..startday.." is nil")
                        end
                    elseif tidx > 1 then
                        starttime = timer[day].timeorder[tidx-1]
                        startday = day
                    end

                    if startday ~= nil and timer[startday] ~= nil and timer[startday][starttime].cbtype == "start" then
                        timer[startday][starttime].pairday = day
                        timer[startday][starttime].pairtime = t
                        timer[day][t].pairday = startday
                        timer[day][t].pairtime = starttime
                        runtime.logger:info("find timeslot "..actname.." "..startday.."_"..starttime.."-"..day.."_"..t)

                        if timer[day][t].tout - timer[startday][starttime].tout < 0 then
                            if timer[startday][starttime].active == true then
                                -- reload still in the same timeslot, do nothing
                                runtime.logger:notice("reload still in the same time slot, do nothing "..actname.." "..startday.."_"..starttime.."-"..day.."_"..t)
                            else
                                -- reload into the timeslot, set start timeout to minus so that it will be triggered immediately
                                newtout = timer[startday][starttime].tout - (weektimes * 1000)
                                timer[startday][starttime].tout = newtout
                                timer[startday][starttime].utimer:set(newtout)
                                runtime.logger:notice("reload into timeslot, "..actname.." "..startday.."_"..starttime.."-"..day.."_"..t.." start timeout="..tostring(newtout/1000).."s")
                            end
                        elseif timer[day][t].tout - timer[startday][starttime].tout > 0 then
                            if timer[startday][starttime].active == true then
                                -- reload out from the timeslot, set stop timeout to minus so that it will be triggered immediately
                                newtout = timer[day][t].tout - (weektimes * 1000)
                                timer[day][t].tout = newtout
                                timer[day][t].utimer:set(newtout)
                                runtime.logger:notice("reload out from timeslot, "..actname.." "..startday.."_"..starttime.."-"..day.."_"..t.." stop timeout="..tostring(newtout/1000).."s")
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end

function starttimer(actionname, day, time, callbacktype, activedaytime)
    local timertable
    local aname = actionname  -- must pass new variable to each utimer each time
    local ulooptimer
    local timeout
    local isactive = false

    if activedaytime ~= nil then
        local activeday, activetime
        local p = strfind(activedaytime, "_")
        local dep = p - 1
        local tsp = p + 1
        activeday = strsub(activedaytime, 1, dep)
        activetime = strsub(activedaytime, tsp, -1)

        if day == activeday and time == activetime then
            isactive = true
        end
    end

    timeout = wdtimeout(day, time)

    ulooptimer = runtime.uloop.timer(function() cb(aname, day, time) end, timeout)

    timertable = {utimer = ulooptimer, cbtype = callbacktype, tout = timeout, actname = aname, active = isactive}
    setmetatable(timertable, TodTimer)
    runtime.logger:info("start action "..actionname.." "..day.."_"..time.." "..callbacktype.." timeout="..tostring(timeout/1000) .. "s")

    return timertable
end

function createtimerofday(timer, startstoplist, actionname, day, callbacktype, duration, activedaytime)
    local time, hep

    if startstoplist == nil or startstoplist == "" then
        -- if no explicit start or stop time, assume it's once action in that day
        runtime.logger:notice("no "..callbacktype.." time in timer of "..actionname)
    else
        -- start_time and stop_time in uci are list type
        for k,t in pairs(startstoplist) do
            hep = strfind(t, ":")

            if hep == nil or hep > 3 then
                if callbacktype == "start" then
                    time = defstarttime
                    runtime.logger:error("start time format error " .. t .. " use default " .. defstarttime)
                elseif callbacktype == "stop" then
                    time = defstoptime
                    runtime.logger:error("stop time format error " .. t .. " use default " .. defstoptime)
                end
            elseif hep == 1 then
                time = "00" .. t
            elseif hep == 2 then
                time = "0" .. t  -- prefixing '0' for format x:yy ensure time ascending order in table
            else
                time = t
            end

            if callbacktype == "stop" then
                if timer[day] ~= nil and timer[day].timeorder ~= nil and duration == 0 then
                    for i,ordert in ipairs(timer[day].timeorder) do
                        if timer[day][ordert].cbtype == "start" and time < ordert then
                            -- if stop time is earlier than the earliest start time in the day, then assume the stop time is in next day
                            duration = 1
                            runtime.logger:info(actionname .. " " .. day .. " stop time " .. time .. " is earlier than start time, assume the stop time is in next day as duration=0")
                        end
                    end
                end

                if duration > 0 then
                    day = getdurationday(day, duration)
                end
            end

            if timer[day] == nil then
                timer[day] = {}
                timer[day].timeorder = {}
                table.insert(timer.dayorder, day)
            end

            if timer[day][time] ~= nil then
                -- collision action on the same day and time
                runtime.logger:error("collision actions at the same daytime "..actionname.." "..day.."_"..time.." of "..callbacktype.." and "..timer[day][time].cbtype)
            else
                timer[day][time] = starttimer(actionname, day, time, callbacktype, activedaytime)
                table.insert(timer[day].timeorder, time)
                table.sort(timer[day].timeorder)
            end
        end
    end

    return true
end

function M.start(actionname, acttimer, activedaytime)
    local timer = nil
    local today = os.date("%a")
    local duration

    -- weekdays of timer must not be nil
    if acttimer.weekdays == nil then
        runtime.logger:error("weekdays of timer " .. acttimer.name .. " is nil")
        return nil
    end

    if acttimer.duration == nil or acttimer.duration == "" then
        duration = 0
    else
        duration = tonumber(acttimer.duration)
        if duration < 0 or duration > 7 then
            runtime.logger:error(actionname .. " " .. day .. " duration " .. duration .. " is out of range[0, 7], force to 0 ")
            duration = 0
        end
    end

    timer = {}
    timer.dayorder = {}

    for k, day in pairs(acttimer.weekdays) do
        if day == "All" then
            for wday,dayidx in pairs(weekday) do
                -- must parse start time firstly
                createtimerofday(timer, acttimer.start_time, actionname, tostring(wday), "start", duration, activedaytime)
                createtimerofday(timer, acttimer.stop_time, actionname, tostring(wday), "stop", duration, activedaytime)
            end

            -- no need to parse other days if 'All' weekday configured
            break
        else
            -- must parse start time firstly
            createtimerofday(timer, acttimer.start_time, actionname, day, "start", duration, activedaytime)
            createtimerofday(timer, acttimer.stop_time, actionname, day, "stop", duration, activedaytime)
        end
    end

    table.sort(timer.dayorder, weekdaycompare)

    checktimeslot(actionname, timer)

    return timer
end

return M
