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
    local acttimer = self.timer

    -- cancel all uloop timer
    if acttimer ~= nil then
        for d,dtb in pairs(acttimer) do
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
    local acttimer =  {}

    acttimer.name = actiontb.timer
    acttimer.weekdays = cursor:get(config .. "." .. actiontb.timer .. ".weekdays")
    acttimer.start_time = cursor:get(config .. "." .. actiontb.timer .. ".start_time")
    acttimer.stop_time = cursor:get(config .. "." .. actiontb.timer .. ".stop_time")
    acttimer.duration = cursor:get(config .. "." .. actiontb.timer .. ".duration")

    action.script = load(actiontb.script, runtime)
    runtime.logger:info("load script " .. action.script:name())

    if actiontb.object == nil then
        action.object = "" -- if no object specified, means the action needs not
    else
        action.object = actiontb.object
    end

    -- TODO: action.allowoverwrite = actiontb.allowoverwrite

    action.timer = todtimer.start(actionname, acttimer, actiontb.activedaytime)

    if action.timer ~= nil then
        setmetatable(action, TodAction)
    else
        runtime.logger:error("fails to create action " .. actionname)
        action = nil
    end

    cursor:unload(config)

    return action
end

return M
