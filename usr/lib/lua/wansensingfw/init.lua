local pairs = pairs
local u = require('ubus')
local uci = require('uci')
local uloop = require('uloop')
local l2was = require('wansensingfw.l2wasmachine')
local l3was = require('wansensingfw.l3wasmachine')
local washelper= require('wansensingfw.washelper')
local scripthelper=require('wansensingfw.scripthelpers')
local async = require('wansensingfw.wasasync')
local logger = require('transformer.logger')
local M = {}

local log_config = {
    level = 4,
    stderr = false
}

function M.start(global, l2config, l3config)
    local x = uci.cursor()
    local l2states = {}
    local l3states = {}
    local l2type
    local c
    local cState, nState

    local function event_cb(event)
        nState = states[cState]:update(event)

        if l2states[nState] then
            -- continue on level 2
            states=l2states
        elseif l3states[nState] then
            -- continue on level 3
            states=l3states
        else
            return
        end

        -- entering a new state ?
        if nState ~= cState then
            cState = nState
            states[cState]:entry()
        end
    end

    -- read the initial mode
    if global.initmode then
       nState = global.initmode
    end

    -- read the initial delay
    if global.initdelay then
       global.initdelay = tonumber(global.initdelay)
    else
       global.initdelay = 1
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
    logger = logger.new("wansensing", log_config.level)

    -- initialize uloop
    uloop.init()

    -- make the connection with ubus
    c = u.connect()

    -- intialize async
    async.init({uloop = uloop, ubus = c, uci = uci, logger = logger} , event_cb)

    -- initialize the scripthelpers
    scripthelper.init({ubus = c, uci = uci, logger = logger})

    -- create the L2 sensing states
    l2was.setruntime({async = async,  ubus = c, uci = uci, logger = logger, scripth = scripthelper})

    for k,v in pairs(l2config) do
        if v == nil or v.mains == nil then
            logger:error('error in start, missing config parameter for ' .. k)
        end

        local l2s = l2was.init(k, v)
        l2states[k] = l2s
    end

    -- create the L3 sensing states

    l3was.setruntime({async = async,  ubus = c, uci = uci, logger = logger, scripth = scripthelper})

    for k,v in pairs(l3config) do
        if v == nil or v.mains == nil then
            logger:error('error in start, missing config parameter for ' .. k)
        end

        local l3s = l3was.init(k, v)
        l3states[k] = l3s
    end

    -- restore the saved l2type (used if we take of with a layer3 state)
    l2type = global.l2type

    logger:notice("Kickoff using state " .. nState .. " with initial delay " .. tostring(global.initdelay))
    if l2states[nState] then
        states = l2states
    end
    if l3states[nState] then
        states = l3states
    end
    -- entering a new state ?
    if nState ~= cState then
        cState = nState
        --fire a first timeout once the initdelay expires
        async.timerstart(global.initdelay * 1000)
    end

    async.start()
end

return M
