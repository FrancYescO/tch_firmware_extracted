local pairs = pairs
local u = require('ubus')
local uci = require('uci')
local uloop = require('uloop')
local l2was = require('wansensingfw.l2wasmachine')
local l3was = require('wansensingfw.l3wasmachine')
local worker = require('wansensingfw.wasworker')
local washelper= require('wansensingfw.washelper')
local repeatedcheck=require('wansensingfw.repeatedcheck')
local timedevent=require('wansensingfw.timedevent')
local scripthelper=require('wansensingfw.scripthelpers')
local async = require('wansensingfw.wasasync')
local logger = require('tch.logger')
local M = {}

local log_config = {
    level = 4
}

function M.start(global, l2config, l3config, wconfig)
    local x = uci.cursor()
    local myruntime = {}
    local states = {}
    local l2states = {}
    local l3states = {}
    local workers = {}
    local l2type
    local c
    local cState, nState

    local function event_cb(event)
       logger:debug("Event [ " .. event .. " ] received in " .. cState .. " state") 

       --1) update the wansensing state machine
       nState = states[cState]:update(event)

       if l2states[nState] then
          -- continue on level 2
          states=l2states
       elseif l3states[nState] then
          -- continue on level 3
          states=l3states
       else
          logger:error("Stopping there main script of [" .. cState .. "] returns not existing state: " .. tostring(nState))
          os.exit(1)
       end

       -- entering a new state ?
       if nState ~= cState then
          cState = nState
          states[cState]:entry()
       end

       --2) deliver events towards the workers
       --   the timeout event belongs to State objects, let's skip them
       if event ~= "timeout" then
          for _,v in pairs(workers) do
             v:update(event)
          end
       end

       -- since the wansensing state machine will now wait for the next event
       -- it is a good time to do garbage collection
       collectgarbage()
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
    logger.init("wansensing", log_config.level)

    -- initialize uloop
    uloop.init()

    -- make the connection with ubus
    c = u.connect()

    -- intialize async
    async.init({uloop = uloop, ubus = c, uci = uci, logger = logger} , event_cb)

    timedevent.setruntime({uloop = uloop, logger = logger, event_cb=event_cb})

    repeatedcheck.setruntime({uloop = uloop, logger = logger})

    -- initialize the scripthelpers
    scripthelper.init({ubus = c, uci = uci, logger = logger, repeatedcheck=repeatedcheck, timedevent=timedevent, event_cb=event_cb})

    -- popultate the runtime
    myruntime={uloop = uloop, async = async,  ubus = c, uci = uci, logger = logger, scripth = scripthelper}

    -- create the L2 sensing states
    l2was.setruntime(myruntime)

    for k,v in pairs(l2config) do
       if v == nil or v.mains == nil then
          logger:error('error in start, missing config parameter for ' .. k)
       end

       local l2s = l2was.init(k, v)
       l2states[k] = l2s
    end

    -- create the L3 sensing states

    l3was.setruntime(myruntime)

    for k,v in pairs(l3config) do
       if v == nil or v.mains == nil then
          logger:error('error in start, missing config parameter for ' .. k)
       end

       local l3s = l3was.init(k, v)
       l3states[k] = l3s
    end

    -- create the workers
    worker.setruntime(myruntime)

    for k,v in pairs(wconfig) do
       if v == nil or v.mains == nil then
          logger:error('error in start, missing config parameter for ' .. k)
       end

       if v.enable == '1' then
          local worker = worker.init(k, v)
          workers[k] = worker
       end
    end

    -- restore the saved l2type (used if we take of with a layer3 state)
    l2type = global.l2type

    logger:notice("Kickoff using state " .. nState .. " with initial delay " .. tostring(global.initdelay))
    if l2states[nState] then
       states = l2states
    elseif l3states[nState] then
       states = l3states
    else
       logger:error("Stopping there initmode [" .. nState .. "] does not exist")
       os.exit(1)
    end
    -- entering a new state ?
    if nState ~= cState then
       cState = nState
       states[cState]:entry()
       -- create the volatile state information
       washelper.open_state(uci)
       washelper.set_state(uci, states[cState]:getName())

       --fire a first timeout once the initdelay expires
       async.timerstart(global.initdelay * 1000)
    end

    --2) start the workers
    for _,v in pairs(workers) do
       logger:notice("Starting worker : " .. v.name)
       v:start()
    end

    async.start()
end

return M
