local runtime = {} 
local cb
local actionlist

local M = {}
local weektimems = 604800000 -- in second

function M.init (rt, actlist)
    runtime = rt
    actionlist = actlist
end

function M.start()
    local conn = runtime.ubus
    -- check connection with ubus
    if not conn then
        error("Failed to connect to ubusd")
    end 

    -- register for ubus events
    local events = {}

    events['time.changed'] = function(msg)
    if msg ~= nil then
        local newtout, stoptime, stopday

        -- traverse all actions since multiple actions may share the same timer, while has different utimer instance.
        for actname,action in pairs(actionlist) do
            for timeridx, timer in pairs(action.timerlist) do
                local oldtlfound = false -- per action and timer variable
                local newtlfound = false -- per action and timer variable

                for didx, day in ipairs(action[timer].dayorder) do
                    -- must in time order so that passed timeslot will not be invoked
                    for tidx,time in ipairs(action[timer][day].timeorder) do
                        action[timer][day][time]:update(day, time)

                        -- check for time update timeslot scenarios:
                        -- 1. out from a timeslot
                        -- 2. into a timeslot
                        -- 3. still in the same timeslot
                        -- 4. still not in any timeslot
                        if (oldtlfound == false or newtlfound == false) and action[timer][day][time].cbtype == "start" then
                            stopday = action[timer][day][time].pairday
                            stoptime = action[timer][day][time].pairtime

                            if stopday ~= nil and stoptime ~= nil and action[timer][stopday] ~= nil and action[timer][stopday][stoptime] ~= nil and action[timer][stopday][stoptime].cbtype == "stop" then
                                -- stop daytime could be behind of today, then update its timeout here to calculate the timeslot
                                action[timer][stopday][stoptime]:update(stopday, stoptime)

                                if action[timer][stopday][stoptime].tout - action[timer][day][time].tout < 0 then
                                    if action[timer][day][time].active == true then
                                        -- 3. update still in the same timeslot, do nothing.
                                        oldtlfound = true
                                        runtime.logger:notice("update time, still in the same time slot: "..actname.."."..timer.." "..day..":"..time.."-"..stopday..":"..stoptime)
                                    else
                                        -- 2. update into a timeslot, trigger its start_time action immediately.
                                        --    in case update from another timeslot into a new timeslot, the previous timeslot stop_time is ensured
                                        --    to be triggered firstly since its smaller timeout value.
                                        newtout = action[timer][day][time].tout - weektimems
                                        action[timer][day][time].tout = newtout
                                        if action[timer][day][time].utimer ~= nil then
                                            action[timer][day][time].utimer:set(newtout)
                                        end
                                        newtlfound = true
                                        runtime.logger:notice("update time, into the time slot: "..actname.."."..timer.." "..day..":"..time.."-"..stopday..":"..stoptime.." start timeout="..tostring(newtout/1000).."s")
                                    end
                                elseif action[timer][day][time].active == true and action[timer][stopday][stoptime].tout - action[timer][day][time].tout > 0 then
                                    -- 1. update out from a timeslot, trigger its stop_time action immediately.
                                    -- update stoptime here for case stop daytime is ahead of today, for which update chance passed.
                                    newtout = action[timer][stopday][stoptime].tout - weektimems
                                    action[timer][stopday][stoptime].tout = newtout
                                    if action[timer][stopday][stoptime].utimer ~= nil then
                                        action[timer][stopday][stoptime].utimer:set(newtout)
                                    end
                                    -- still set stoptime.active=true for case stop daytime is behind of today, for which still will be updated.
                                    action[timer][stopday][stoptime].active = true
                                    oldtlfound = true
                                    runtime.logger:notice("update time, out from the time slot: "..actname.."."..timer.." "..day..":"..time.."-"..stopday..":"..stoptime.." sotp timeout="..tostring(newtout/1000).."s")
                                end
                            else
                                runtime.logger:notice("no stop pair of start time "..actname.."."..timer.." "..day..":"..time)
                            end
                        end
                        -- other scenario not in above belongs to 4. update still not in any timeslot, do nothing.
                    end
                end
            end -- action.timerlist
        end
    end
    end

    -- TODO: monitor kernel time notify event instead of "time.changed" event.

    -- TODO: if some tod action needs to prevent object configuration overwriting during a schedule
    -- it can monitor the object relevant event here, and trigger the action script to revert, e.g.,
    -- events["wireless.ssid"] = function(msg)
    --     if wireless ssid state is changed, then check wifitod action[timer] in current timeslot, 
    --     if the action's allowoverwrite=0, and the ssid is monitored, then revert object configuration
    -- end

    conn:listen(events)

    runtime.uloop.run()
end

return M

