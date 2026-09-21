local pairs, error, print = pairs, error, print
local comm = require('ledframework.common')
local smm = require('ledframework.statemachine')
local acm = require('ledframework.ledaction')
local ptm = require('ledframework.patternaction')
local ubus = require('ledframework.ubus')
local posix = require("tch.posix")
local syslog = comm.syslog

local M = {}

-- infoButtonState - true: infobutton is pressed, led status will be off
--                   false: default state, infobutton is released, led status will not be off 
-- infoButtonResuming - true: after infobutton is released, recover all of leds status to orginal state
--                    - false: default state
local infoButtonState = false
local infoButtonResuming = false

function M.start(ledconfig, patternconfig)
    local pts, sms, trs = {}, {}, {}

    if patternconfig ~= nil then
    for k, v in pairs(patternconfig) do
        print('Processing pattern ' .. k)
        if v == nil or v.state == nil or v.transitions == nil or v.actions == nil then
            error({ errcode = 9003, errmsg = 'error in start, missing pattern config parameter for ' .. k})
        end
        local pm = ptm.init(v.state, v.transitions, v.actions)
        pts[k] = pm
    end
    end

    for k,v in pairs(ledconfig) do
        print('Processing ' .. k)

        if v == nil or v.initial == nil or v.initial == '' or v.transitions == nil or v.actions == nil then
            error({ errcode = 9003, errmsg = 'error in start, missing led config parameter for ' .. k})
        end

        -- initialize state machine
        local sm = smm.init(v.transitions, v.initial, v.patterns_depend_on)
        -- initialize led actions by state
        local ac = acm.init(v.actions)
        -- initialize pattern dependencies
        if v.patterns_depend_on ~= nil then
            for action, patterns in pairs(v.patterns_depend_on) do
                if patterns ~= nil then
                    for pattern_key, pattern_value in pairs(patterns) do
                        if pattern_value ~= nil and pts[pattern_value] ~= nil then
                            pts[pattern_value]:addLed(k)
                        end
                    end
                end
            end
        end

        -- set initial led action
        ac:applyAction(v.initial)

        sms[k] = sm
        trs[k] = ac
    end

    -- Infobutton: suspend the leds, no actions anymore
    function suspend()
        infoButtonState = true
        infoButtonResuming = false

        for k in pairs(sms) do
            sms[k]:suspend()
        end

    end


    -- Infobutton: recover the current state of leds
    function resume()
        infoButtonState = false
        infoButtonResuming = true

        for k in pairs(sms) do
            sms[k]:resume()
        end

    end

    local function findRelatedPatterns(led_statemachine)
        local currentState = led_statemachine:getState()

        if type(currentState)=="function" then
             currentState=currentState()
        end
        return led_statemachine:getPatterns(currentState) or {}
    end

    local function getCurrentState(led_statemachine)
        return led_statemachine:getState()
    end

    local function getCurrentAction(led_statemachine)
        local currentAction = led_statemachine:getAction()

        if type(currentAction)=="function" then
            currentAction=currentAction()
        end
        return currentAction
    end

    local function getLastActiveAction(led_statemachine)
        local currentAction = led_statemachine:getActiveAction()

        if type(currentAction)=="function" then
            currentAction=currentAction()
        end
        return currentAction
    end

    local lastActivePattern=nil
    ubus.start(function(event)
        -- Infobutton: if received state_on event, shut off LEDs, skip actions
        if event == 'infobutton_state_on' then
            suspend()
        elseif event == 'infobutton_state_off' then
            resume()
        elseif event == 'led_brightness_changed' then
            comm.updateBrightness()
        end
        syslog(posix.LOG_DEBUG,'LED callback with event \''..(event or 'nil')..'\'')

        -- Pattern event comes
        for k in pairs(pts) do
            if pts[k]:activate(event) then 
                if lastActivePattern and lastActivePattern ~= k then pts[lastActivePattern]:setInactive() end 
                syslog(posix.LOG_DEBUG,'LED pattern \''..k..'\' activate on event \''..(event or 'nil')..'\';Applying pattern actions')
                lastActivePattern = k
                pts[k]:applyAction(event)
                for ledname, ledv in pairs(pts[k]:getLeds()) do
                    local currentAction = getLastActiveAction(sms[ledname])
                    local relatedPatterns = findRelatedPatterns(sms[ledname])
                    local pattern_found = false
                    for key, pattern in pairs(relatedPatterns) do
                        if k == pattern then
                            pattern_found = true
                            break
                        end
                    end
                    if not pattern_found then
                        syslog(posix.LOG_DEBUG,'LED no related pattern found for led \''..ledname..'\';Applying last active transition action: \''..(currentAction or 'nil')..'\'')
                        trs[ledname]:applyAction(currentAction)
                    end
                end
            elseif pts[k]:deactivate(event) then
                if lastActivePattern == k then lastActivePattern=nil end 
                syslog(posix.LOG_DEBUG,'LED pattern \''..k..'\' deactivate on event \''..(event or 'nil')..'\';Applying pattern actions')
                pts[k]:applyAction(event)
                for ledname, ledv in pairs(pts[k]:getLeds()) do
                    local currentAction = getLastActiveAction(sms[ledname])
                    syslog(posix.LOG_DEBUG,'LED pattern deactivate for led \''..ledname..'\';Applying last active transition action: \''..(currentAction or 'nil')..'\'')
                    trs[ledname]:applyAction(currentAction)
                end
            end
        end
        -- Individual LEDs event comes
        local refresh_needed = false
        for k in pairs(sms) do
            if sms[k]:update(event) or infoButtonResuming then
                if not infoButtonState then
                    local currentAction = getCurrentAction(sms[k])
                    local currentState = getCurrentState(sms[k])
                    local relatedPatterns = findRelatedPatterns(sms[k])
                    syslog(posix.LOG_DEBUG,'LED \''..k..'\' update on event \''..(event or 'nil')..'\'; State: \''..(currentState or 'nil')..'\', Action: \''..(currentAction or 'nil')..'\'')
                    local applyaction = true
                    for key, pattern in pairs(relatedPatterns) do
                        if pts[pattern] and pts[pattern]:isActive() then
                            pts[pattern]:restoreCurrentState()
                            refresh_needed = true
                            applyaction = false
                        end
                    end
                    if applyaction then
                        trs[k]:applyAction(currentAction)
                    end
                end
            end
        end
        if refresh_needed then
            for k in pairs(sms) do
                local currentAction = getCurrentAction(sms[k])
                local applyaction = true
                local relatedPatterns = findRelatedPatterns(sms[k])
                for key, pattern in pairs(relatedPatterns) do
                    if pts[pattern] and pts[pattern]:isActive() then
                        applyaction = false
                        break
                    end
                end
                if applyaction then
                    trs[k]:applyAction(currentAction)
                end
            end
        end

        -- Infobutton: after resuming done, recover it
        if infoButtonResuming then
            infoButtonResuming = false
        end
    end)

end

return M
