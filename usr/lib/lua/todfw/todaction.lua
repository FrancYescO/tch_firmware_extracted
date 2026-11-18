local pairs, error, print = pairs, error, print
local todhelper = require('todfw.todhelper')
local load = todhelper.load
local config = "tod"


local M = {}
local runtime = {}
local cursor
local todtimer
local actlist

local TodAction = {}
TodAction.__index = TodAction

function TodAction:cancel()
    local actiontimer = self.timer

    -- cancel all uloop timer
    if actiontimer ~= nil then
        for d,dtb in pairs(actiontimer) do
            if d ~= "dayorder" and d ~= "duration" and dtb ~= nil then
                for t, ttb in pairs(dtb) do
                    if t ~= "timeorder" and ttb ~= nil then
                        ttb:cancel()
                    end
                end
            end
        end
    end

    actlist[actionname] = nil
end

function M.init(rt, actionlist)
    runtime = rt
    cursor = runtime.uci.cursor()
    todtimer = runtime.todtimer
    actlist = actionlist
end

function M.start(actionname, actiontb)
    local action = {}
    local ucitimer =  {}
    local valid_activedaytime = {}
    local validaction = false
    local obsolete_active_ts_nb = 0
    local t_enabled, periodic

    action.script = load(actiontb.script, runtime)
    runtime.logger:info("load script " .. action.script:name())

    if actiontb.object == nil then
        action.object = "" -- if no object specified, means the action needs not
    else
        action.object = actiontb.object
    end

    -- TODO: action.allowoverwrite = actiontb.allowoverwrite

    action.timerlist = {}

    -- Iterates all timers since one action can binds to multiple timers
    if actiontb.timers ~= nil and next(actiontb.timers) ~= nil then
        for _,timer in pairs(actiontb.timers) do
            t_enabled = cursor:get(config .. "." .. timer .. ".enabled")

            -- by default assume timer is enabled
            if t_enabled == nil or t_enabled == '1' then
                ucitimer.name = timer
                ucitimer.start_time = cursor:get(config .. "." .. timer .. ".start_time")
                ucitimer.stop_time = cursor:get(config .. "." .. timer .. ".stop_time")
                periodic = cursor:get(config .. "." .. timer .. ".periodic")

                -- by default assume timer is periodic
                if periodic == nil or periodic == '1' then
                    ucitimer.periodic = true
                else
                    ucitimer.periodic = false
                end

                action[timer] = todtimer.start(actionname, ucitimer, actiontb.activedaytime, valid_activedaytime)

                if action[timer] ~= nil then
                    validaction = true
                    table.insert(action.timerlist, timer)
                end
            end
        end
    end

    -- Once a activedaytime record is found in current timer configuration, it will be removed from the list.
    -- So, after parsing all timers, the remained activedaytime record is obsolete whose timer has been modified.
    if actiontb.activedaytime ~= nil and next(actiontb.activedaytime) ~= nil then
        obsolete_active_ts_nb = table.getn(actiontb.activedaytime)
    end

    if next(action.timerlist) ~= nil then
        for _,timer in pairs(action.timerlist) do
            -- Check valid timeslot of the action after the action's all timers have been parsed.
            -- The obsolete_active_ts_nb represent the number of active timeslot records which have no
            -- corresponding matched timeslot now. In checktimeslot, obsolete_active_ts_nb can be subtracted
            -- if current time is within a timeslot which has no corresponding active record in action configuration.
            -- And this case indicates that the obsolete active timeslot was changed while current time is still in new timeslot.
            obsolete_active_ts_nb = todtimer.checktimeslot(action[timer], obsolete_active_ts_nb, valid_activedaytime)
        end
    end

    while obsolete_active_ts_nb > 0 do
        -- Invoke the stop action if there are more idle obsolete active timeslots than current real active timeslots.
        -- It's because that the previous active timeslot has been modified and phased out.
        action.script:stop(runtime, actionname, action.object)
        obsolete_active_ts_nb = obsolete_active_ts_nb - 1
    end 

    if validaction == true then
        setmetatable(action, TodAction)

        -- Update the activedaytime list according to newly changed timers, and remove these obsolete activedaytime records.
        if next(valid_activedaytime) ~= nil then
            cursor:set(config, actionname, "activedaytime", valid_activedaytime)
        else
            cursor:delete(config, actionname, "activedaytime")
        end
        cursor:commit(config)
    else
        runtime.logger:error("fails to create action " .. actionname)
        action = nil
    end

    cursor:unload(config)

    return action
end

function M.stop(actionname, actiontb)
    local active_timeslot_nb = table.getn(actiontb.activedaytime)
    local action = {}

    action.script = load(actiontb.script, runtime)

    if actiontb.object == nil then
        action.object = "" -- if no object specified, means the action needs not
    else
        action.object = actiontb.object
    end 

    -- Stop these active timeslots since action was stoped.
    while active_timeslot_nb > 0 do
        action.script:stop(runtime, actionname, action.object)
        active_timeslot_nb = active_timeslot_nb - 1
    end

    -- Remove active timeslots records since action was stoped.
    if next(actiontb.activedaytime) ~= nil then
        cursor:delete(config, actionname, "activedaytime")
        cursor:commit(config)
    end

end
return M
