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
    --       timer = { 
    --                 dayorder = {[1] = day1, [2] = day2, ...} -- day ascending order from Sun to Sat
    --                 day1 = { -- individual day timer is for recurrence weekdays only
    --                          timeorder = {[1] = time1, [2] = time2, ...} -- time ascending order
    --                          time1 = { 
    --                                    utimer = uloop_timer_instance,
    --                                    cbtype = start_or_stop,
    --                                    tout = time_out_value, --msec
    --                                    actname = action_sectionname1
    --                                    pairday = day -- for start time, this item indicates stop day in pair and vice versa, nil for no pair.
    --                                    pairtime = time -- for start time, this item indicates stop time in pair and vice versa, nil for no pair.
    --                                    active = true_or_false -- for start timer, true means in this timeslot,
    --                                                           -- for stop timer, it means the stop action needs to be triggered immediatelly.
    --                          }
    --                 }
    --                 duration = 0 -- indicate stop time is at how many days later from start time day. default is 0
    --       }
    --   }
    -- }
    local actlist = {}
    local runtime = {}
    local conn

    local script_cb = function(actionname, day, time)
        local action = actlist[actionname]
        local daytb = action.timer[day]
        local timertb = daytb[time]
        local cursor = uci.cursor()
        local result

        if timertb.cbtype == "start" then
            local stopday, stoptime

            -- run the start script
            result = action.script:start(runtime, actionname, action.object)

            stopday = timertb.pairday
            stoptime = timertb.pairtime

            if stopday ~= nil and stoptime ~= nil and action.timer[stopday] ~= nil and action.timer[stopday][stoptime] ~= nil and action.timer[stopday][stoptime].cbtype == "stop" then
                -- only mark active=true if it's within a start and stop timeslot
                timertb.active = true

                -- save the timeslot active status into configuration
                cursor:set(config, actionname, "activedaytime", day.."_"..time)
                cursor:commit(config)
                runtime.logger:info("save start time active status "..actionname.." "..day.."_"..time)
            else
                runtime.logger:notice("no stop pair of start time "..actionname.." "..day.."_"..time)
            end
        elseif timertb.cbtype == "stop" then
            local startday, starttime

            -- run the stop script
            result = action.script:stop(runtime, actionname, action.object)
            timertb.active = false

            -- find corresponding start time of this timeslot and set active=false
            startday = timertb.pairday
            starttime = timertb.pairtime
            if startday ~= nil and starttime ~= nil and action.timer[startday] ~= nil and action.timer[startday][starttime] ~= nil and action.timer[startday][starttime].cbtype == "start" then
                action.timer[startday][starttime].active = false
                cursor:delete(config, actionname, "activedaytime")
                cursor:commit(config)
            else
                runtime.logger:notice("no start pair of stop time "..actionname.." "..day.."_"..time)
            end
        end

        if result ~= true then
            runtime.logger:error("action " .. actionname .. " timer " .. day .. "_" .. time .. " callback script failed")
        end

        -- reset the timer with new timeout of next week this time
        if timertb.tout < 0 then
            local newtout = weektimems + timertb.tout
            timertb.utimer:set(newtout)
            timertb.tout = newtout
        else 
            timertb.utimer:set(weektimems)
            timertb.tout = weektimems
        end

        runtime.logger:info("invoke "..actionname.." "..timertb.cbtype.." "..day.."_"..time)
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
            if acttb == nil or acttb.timer == nil or acttb.timer == "" or acttb.object == nil or acttb.object == "" or acttb.script == nil or acttb.script == "" then
                logger:error("missing config parameter for " .. actname)
            end 

            if acttb.enabled == "1" then
                actlist[actname] = todaction.start(actname, acttb)
            end
        end

        -- Start the uloop with event monitoring and timer
        todasync.start()
    else
        logger:notice("no action configured")
    end

end

return M
