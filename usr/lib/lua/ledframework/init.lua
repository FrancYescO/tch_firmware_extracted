local pairs, error, print = pairs, error, print
local smm = require('ledframework.statemachine')
local acm = require('ledframework.ledaction')
local ptm = require('ledframework.patternaction')
local ubus = require('ledframework.ubus')

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

    ubus.start(function(event)
        -- Infobutton: if received state_on event, shut off LEDs, skip actions
        if event == 'infobutton_state_on' then
            suspend()
        elseif event == 'infobutton_state_off' then
            resume()
        end

        -- Pattern event comes
        for k in pairs(pts) do
            if pts[k]:activate(event) then
                pts[k]:applyAction(event)
                for ledname, ledv in pairs(pts[k]:getLeds()) do
                    local relatedPatterns = nil
                    local currentState = sms[ledname]:getState()
                    relatedPatterns = sms[ledname]:getPatterns(currentState)
                    if relatedPatterns == nil then
                        trs[ledname]:applyAction(currentState)
                    else
                        local pattern_found = false
                        for key, pattern in pairs(relatedPatterns) do
                            if k == pattern then
                                pattern_found = true
                            end
                        end
                        if pattern_found == false then
                            trs[ledname]:applyAction(currentState)
                        end
                    end
                end
            elseif pts[k]:deactivate(event) then
                for ledname, ledv in pairs(pts[k]:getLeds()) do
                    trs[ledname]:applyAction(sms[ledname]:getState())
                end
            end
        end
        -- Individual LEDs event comes
        local refresh_needed = false
        for k in pairs(sms) do
            if sms[k]:update(event) == true or infoButtonResuming == true then
                if infoButtonState == false then
                    local relatedPatterns = nil
                    local currentState = sms[k]:getState()
                    relatedPatterns = sms[k]:getPatterns(currentState)
                    if pts == nil
                       or relatedPatterns == nil then
                        trs[k]:applyAction(currentState)
                    else
                       local applyaction = true
                       for key, pattern in pairs(relatedPatterns) do
                           if pts[pattern] ~= nil and pts[pattern]:isActive() then
                               pts[pattern]:restoreCurrentState()
                               refresh_needed = true
                               applyaction = false
                           end
                       end
                       if applyaction == true then
                              trs[k]:applyAction(currentState)
                       end
                    end
                end
            end
        end
        if refresh_needed == true then
            for k in pairs(sms) do
                local relatedPatterns = nil
                local currentState = sms[k]:getState()
                relatedPatterns = sms[k]:getPatterns(currentState)
                if pts == nil
                   or relatedPatterns == nil then
                    trs[k]:applyAction(currentState)
                else
                   local applyaction = true
                   for key, pattern in pairs(relatedPatterns) do
                       if pts[pattern] ~= nil and pts[pattern]:isActive() then
                           applyaction = false
                       end
                   end
                   if applyaction == true then
                          trs[k]:applyAction(currentState)
                   end
                end
            end
        end

        -- Infobutton: after resuming done, recover it
        if infoButtonResuming == true then
            infoButtonResuming = false
        end
    end)

end

return M
