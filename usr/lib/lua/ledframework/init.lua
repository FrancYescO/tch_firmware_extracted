local pairs, error, print = pairs, error, print
local smm = require('ledframework.statemachine')
local acm = require('ledframework.ledaction')
local ubus = require('ledframework.ubus')

local M = {}

-- infoButtonState - true: infobutton is pressed, led status will be off
--                   false: default state, infobutton is released, led status will not be off 
-- infoButtonResuming - true: after infobutton is released, recover all of leds status to orginal state
--                    - false: default state
local infoButtonState = false
local infoButtonResuming = false

function M.start(config)
    local sms, trs = {}, {}

    for k,v in pairs(config) do
        print('Processing ' .. k)

        if v == nil or v.initial == nil or v.initial == '' or v.transitions == nil or v.actions == nil then
            error({ errcode = 9003, errmsg = 'error in start, missing config parameter for ' .. k})
        end

        -- initialize state machine
        local sm = smm.init(v.transitions, v.initial)
        -- initialize led actions by state
        local ac = acm.init(v.actions)

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

        for k in pairs(sms) do
            if sms[k]:update(event) == true or infoButtonResuming == true then
				if infoButtonState == false then
                	trs[k]:applyAction(sms[k]:getState())
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