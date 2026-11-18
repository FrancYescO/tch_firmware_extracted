local pairs, error, print = pairs, error, print
local ubus = require('ubus')
local uci = require('uci')
local uloop = require('uloop')
local logger = require('transformer.logger')
local todaction = require('todfw.todaction')
local todtimer = require('todfw.todtimer')
local todasync = require('todfw.todasync')
local config = "tod"

local M = {}

local log_config = {
    level = 4,
    stderr = false
}

local weektimems = 604800000 -- in msec

function M.start(global, actionconfig)
    -- action list structure:
    -- { action_sectionname1 = { 
    --       script = script_instance_table,
    --       object = object_section_name,
    --       TODO: allowoverwrite = 1_or_0, --whether allows other channel overwriting
    --       timerlist = {timer1, timer2, timer3}
    --       timer1 = { -- timer instance 1
    --           dayorder = {[1] = day1, [2] = day2, ...} -- day ascending order from Sun to Sat
    --           day1 = { -- individual day timer is for recurrence weekdays only
    --               timeorder = {[1] = time1, [2] = time2, ...} -- time ascending order
    --               time1 = { 
    --                   utimer = uloop timer instance,
    --                   cbtype = start or stop,
    --                   tout = timeout value, --msec
    --                   actionname = action sectionname1
    --                   timername = timer sectionname1
    --                   pairday = day -- for start time, this item indicates stop day in pair and vice versa, nil for no pair.
    --                   pairtime = time -- for start time, this item indicates stop time in pair and vice versa, nil for no pair.
    --                   active = true or false -- for start timer, true means current moment is in this timeslot,
    --                                          -- for stop timer, it means the stop action needs to be triggered immediatelly.
    --                   periodic = true or false -- for ture, the timer circulates weekly; for false, the timer runs once this week only.
    --               }
    --           }
    --       }
    --       timer2 = { -- timer instance 2 }
    --       timer3 = { -- timer instance 3 }
    --   }
    -- }
    local actlist = {}
    local runtime = {}
    local conn

    local script_cb = function(actionname, timername, day, time)
        local action = actlist[actionname]
        local timertb = action[timername]
        local daytb = timertb[day]
        local timetb = daytb[time] -- timetb is a embeded structure in timertb, refers to above overall data structure relationship
        local cursor = uci.cursor()
        local result

        if timetb.cbtype == "start" then
            local stopday, stoptime

            -- run the start script
            result = action.script:start(runtime, actionname, action.object)

            stopday = timetb.pairday
            stoptime = timetb.pairtime

            if stopday ~= nil and stoptime ~= nil and timertb[stopday] ~= nil and timertb[stopday][stoptime] ~= nil and timertb[stopday][stoptime].cbtype == "stop" then
                local activetimerlist = cursor:get(config, actionname, "activedaytime")
                local timerrecorded = false

                -- mark active=true only if it's within a start and stop timeslot
                timetb.active = true

                -- save the timeslot active status into configuration
                if activetimerlist == nil then
                    activetimerlist = {}
                else
                    for timeridx,acttimerstr in pairs(activetimerlist) do
                        if acttimerstr == timername..":"..day..":"..time then
                            timerrecorded = true
                            break
                        end
                    end
                end

                if timerrecorded == false then
                    table.insert(activetimerlist, timername..":"..day..":"..time)
                    cursor:set(config, actionname, "activedaytime", activetimerlist)
                    cursor:commit(config)
                end
                runtime.logger:info("save start time active status "..actionname.." "..timername..":"..day..":"..time)
            else
                runtime.logger:notice("no stop pair of start time "..actionname.." "..timername..":"..day..":"..time)
            end
        elseif timetb.cbtype == "stop" then
            local startday, starttime

            -- run the stop script
            result = action.script:stop(runtime, actionname, action.object)
            timetb.active = false

            -- find corresponding start time of this timeslot and set active=false
            startday = timetb.pairday
            starttime = timetb.pairtime
            if startday ~= nil and starttime ~= nil and timertb[startday] ~= nil and timertb[startday][starttime] ~= nil and timertb[startday][starttime].cbtype == "start" then
                local activetimerlist = cursor:get(config, actionname, "activedaytime")

                timertb[startday][starttime].active = false

                if activetimerlist ~= nil and activetimerlist ~= "" then
                    for timeridx,acttimerstr in pairs(activetimerlist) do
                        if acttimerstr == timername..":"..startday..":"..starttime then
                            table.remove(activetimerlist, timeridx)
                        end
                    end
                end

                if activetimerlist == nil then
                    cursor:delete(config, actionname, "activedaytime")
                else
                    cursor:set(config, actionname, "activedaytime", activetimerlist)
                end
                cursor:commit(config)
            else
                runtime.logger:notice("no start pair of stop time "..actionname.." "..timername..":"..day..":"..time)
            end
        end

        if result ~= true then
            runtime.logger:error("action "..actionname.."."..timername..":"..day..":"..time.." callback script failed")
        end

        -- reset the timer with new timeout of next week this time
        if timetb.periodic == true then
            if timetb.tout < 0 then
                local newtout = weektimems + timetb.tout
                timetb.utimer:set(newtout)
                timetb.tout = newtout
            else
                timetb.utimer:set(weektimems)
                timetb.tout = weektimems
            end
        elseif timetb.periodic == false then
            if timetb.cbtype == "start" and timetb.active == false then
                -- aperiodic timer, cancel the start timer if it has no corresponding timeslot.
                timetb.utimer:cancel()
                timetb.utimer = nil
                runtime.logger:info("cancel "..actionname.." "..timetb.cbtype.." "..timername..":"..day..":"..time)

                -- turn off aperiodic timer, it must be reenabled explicitly if user wants to trigger it again.
                cursor:set(config, timername, "enabled", '0')
                cursor:commit(config)
            elseif timetb.cbtype == "stop" then
                local startday, starttime
                local has_incompleted_timeslot = false
                startday = timetb.pairday
                starttime = timetb.pairtime
                
                if startday ~= nil and starttime ~= nil and timertb[startday] ~= nil and timertb[startday][starttime] ~= nil and timertb[startday][starttime].cbtype == "start" and timertb[startday][starttime].active == false then
                    -- only cancel the start timer when its corresponding stop timer has been triggered, i.e. timeslot passed.
                    timertb[startday][starttime].utimer:cancel()
                    timertb[startday][starttime].utimer = nil
                    runtime.logger:info("cancel "..actionname.." start "..timername..":"..day..":"..time)
                end

                -- aperiodic timer, cancel the uloop timer once its action was triggered
                timetb.utimer:cancel()
                timetb.utimer = nil
                runtime.logger:info("cancel "..actionname.." "..timetb.cbtype.." "..timername..":"..day..":"..time)

                -- turn off aperiodic timer if all its timeslot has been triggered, it must be reenabled explicitly if user wants to trigger it again.
                for didx,day in ipairs(timertb.dayorder) do
                    if timertb[day] ~= nil and timertb[day] ~= "" then
                        for tidx,t in ipairs(timertb[day].timeorder) do
                            if timertb[day][t].utimer ~= nil then
                                has_incompleted_timeslot = true
                                break
                            end
                        end
                    end
                end

                if has_incompleted_timeslot == false then
                    cursor:set(config, timername, "enabled", '0')
                    cursor:commit(config)
                end
            end
        end

        runtime.logger:info("invoke "..actionname.." "..timetb.cbtype.." "..timername..":"..day..":"..time)
    end

    -- read the configured tracelevel
    if global.tracelevel then
       local tracelevel = tonumber(global.tracelevel)
       if (tracelevel >= 1 and tracelevel <= 6) then
          log_config.level = tonumber(global.tracelevel)
       end
    end

    -- setup the log facilities
    logger.init(log_config.level, log_config.stderr)
    logger = logger.new("timeofday", log_config.level)

    --init uloop
    uloop.init()

    -- make the connection with ubus
    conn = ubus.connect()

    runtime = {ubus = conn, uci = uci, uloop = uloop, logger = logger, todtimer = todtimer}

    todaction.init(runtime, actlist)
    todtimer.init(runtime, script_cb, actlist)
    todasync.init(runtime, actlist)

    -- parse action list and setup corresponding timer
    if actionconfig ~= nil and actionconfig ~= "" and next(actionconfig) ~= nil then
        for actname,acttb in pairs(actionconfig) do
            if acttb == nil or acttb.timers == nil or acttb.timers == "" or acttb.script == nil or acttb.script == "" then
                logger:error("missing mandatory config parameter for " .. actname)
            else
                if acttb.enabled == "1" then
                    actlist[actname] = todaction.start(actname, acttb)
                elseif acttb.enabled == "0" and acttb.activedaytime ~= nil then
                    -- stop the action if it was started
                    todaction.stop(actname, acttb)
                end
            end
        end

        -- Start the uloop with event monitoring and timer
        todasync.start()
    else
        logger:notice("no action configured")
    end

end

return M
