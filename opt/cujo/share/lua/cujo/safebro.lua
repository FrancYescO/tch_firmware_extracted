--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2020 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo, globals cujo.safebro

local json = require 'json'
local Queue = require 'loop.collection.Queue'
local tabop = require 'loop.table'

local shims = require 'cujo.shims'
local util = require 'cujo.util'

local module = {
    threat = util.createpublisher(),
    warmcache_state = 'absent',
    config_state = 'absent',
}

local fakeresponse = {
    score = 100,
    reason = 999999999,
    categories = {},
    cachedomain = false
}

local sbfeatures = {'reputation', 'profiles', 'trackerblock'}
local lookupqueue = Queue()

-- Cache of HTTPS connections to the urlchecker.
local connector = nil

-- Inform the kernel side of a urlchecker result. Also used for the warmcache.
local function setresponse(domain, score, reason, categories, cachedomain, callback)
    local msg = string.format('threat.setresponse(%q,{%d,%d,{%s}},%s)',
        domain, score, reason, table.concat(categories, ','), cachedomain)
    cujo.nf.dostring(msg, callback)
end

-- luacheck is correct in that this initializer is only written to, but it's
-- a more convenient default than nil.
local warmcache_interrupt = {} -- luacheck: ignore 331

local warmcache_timer_stop = nil

local function warmcache_stop()
    warmcache_interrupt.triggered = true
    if warmcache_timer_stop ~= nil then
        warmcache_timer_stop()
        warmcache_timer_stop = nil
    end
end

local function handle_warmcache_chunks(chunks_iter, lastpos, count, callback)
    local url, score, rawcats, pos = chunks_iter()
    if url == nil then
        callback(lastpos, count)
        return
    end

    local categories = {}
    for category in string.gmatch(rawcats, '%s*(%d*)%s*,?') do
        table.insert(categories, tonumber(category))
    end
    setresponse(url, score, fakeresponse.reason, categories, true, function()
        handle_warmcache_chunks(chunks_iter, pos, count + 1, callback)
    end)
end

local function load_warmcache(url, token, ttl)
    -- regex used to parse individual JSON objects out of the
    -- warmcache result sent from the cloud.
    --
    -- Assumes that it's all on one line.
    local jsonpat =
        '{"url": *"([^"]+)", *"score": *(%d+), *"categories": *%[([^%]]*)%]}()'

    -- Set warmcache_interrupt to a local object and only reference the
    -- local within here otherwise. That way if another warmcache load gets
    -- started, warmcache_interrupt can be overwritten to refer to the new
    -- loader, but we will still pick up the interrupt meant for us and just
    -- exit.
    local interrupt = {}
    warmcache_interrupt = interrupt

    cujo.log:safebro'loading new cache'
    module.warmcache_state = 'loading'
    local count = 0
    local left = ''
    cujo.https.request{
        url = url,
        headers = {Authorization = token},
        sink = function (chunk, errmsg, on_done)
            if interrupt.triggered then
                return cujo.log:safebro'cache load interrupted'
            end
            if not chunk then return 1 end
            chunk = left .. chunk
            local chunks_iter = string.gmatch(chunk, jsonpat)
            handle_warmcache_chunks(chunks_iter, nil, 0, function(lastpos, chunk_count)
                if lastpos then
                    left = string.sub(chunk, lastpos)
                end
                count = count + chunk_count
                if on_done then on_done() end
            end)
            return 1
        end,
        create = cujo.https.connector.simple(
            cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
        on_done = function(ok, code)
            local delay
            if not ok then
                delay = cujo.config.warmcache.retryinterval
                cujo.log:warn('failed to load cache (HTTP error ', code, ').',
                    ' Retry in ', delay, 's.')
            else
                delay = ttl or cujo.config.warmcache.ttl
                cujo.log:safebro('warm cache successfully downloaded with ',
                    count, ' entries')
                if not interrupt.triggered then
                    module.warmcache_state = 'loaded'
                end
            end
            if not interrupt.triggered then
                warmcache_timer_stop = shims.create_oneshot_timer("warmcache-loader", delay, function(stopped)
                    if not stopped then
                        load_warmcache(url, token, ttl)
                    end
                end)
            end
        end
    }
end

local function warmcache_start(url, token, ttl)
    if not url then return cujo.log:safebro'disabled' end

    shims.create_oneshot_timer("warmcache-loader", 0, function()
        load_warmcache(url, token, ttl)
    end)
end

local function anyactive()
    for _, feature in pairs(sbfeatures) do
        if cujo.safebro[feature].enable.wanted then return true end
    end
    return false
end

local function getfeatures()
    local features = {}
    for _, name in pairs(sbfeatures) do
        features[name] = cujo.safebro[name].enable.wanted
    end
    return features
end

local function init_connector()
    connector = tabop.memoize(function ()
        return cujo.https.connector.keepalive(
            cujo.config.tls,
            cujo.config.urlcheckertimeout, cujo.config.cloudsrcaddr())
    end, 'k')
end

local in_mutex = false
local config = nil
local rules_added = false

-- toggle_feature and module.configure can run concurrently, since the former is
-- triggered by rabidsh and the latter by cloud comms. Both typically want to do
-- things like modify and check the status of iptables rules, but doing that
-- concurrently can cause inconsistencies.
--
-- So use this "mutex" to prevent such concurrency.
local function mutex_do(f)
    local sleep = 0.1
    shims.create_stoppable_timer("mutex-awaiter", sleep, function()
        if in_mutex then
            return sleep
        end
        in_mutex = true
        f()
        in_mutex = false
        return nil
    end)
end

local function turn_on_everything(callback)
    -- Forget any existing connections in case we have a new endpoint.
    init_connector()

    mutex_do(function()
        -- config or anyactive() may have been reset by the time we enter this.
        if not config or not anyactive() then
            return callback()
        end

        warmcache_stop()
        warmcache_start(config.cacheurl, config.token, config.cachettl)

        config.features = getfeatures()
        if config.features.trackerblock == true and not config.trackerblock then
            cujo.log:warn("trackerblock is enabled but there are no trackerblock settings")
        end

        cujo.nf.dostring('safebro.config(' .. cujo.util.serialize(config) .. ')', function()
            if rules_added then
                return callback()
            else
                cujo.nfrules.set('safebro', function()
                    cujo.nfrules.check('safebro', function()
                        rules_added = true
                        return callback()
                    end)
                end)
            end
        end)
    end)
end

local function turn_off_everything(nf_rules, callback)
    mutex_do(function()
        -- config or anyactive() may have been reset by the time we enter this.
        if config and anyactive() then
            return callback()
        end

        warmcache_stop()
        cujo.nf.dostring('safebro.config({})')
        if nf_rules then
            cujo.nfrules.clear('safebro', function()
                cujo.nfrules.check_absent('safebro', function()
                    rules_added = false
                    return callback()
                end)
            end)
        else
            return callback()
        end
    end)
end

local function toggle_feature(feature_name, enable, callback)
    if enable then
        if config then
            return turn_on_everything(callback)
        else
            if rules_added then
                return callback()
            else
                cujo.nfrules.set('safebro', function()
                    cujo.nfrules.check('safebro', function()
                        rules_added = true
                        return callback()
                    end)
                end)
            end
        end
    elseif not anyactive() then
        return turn_off_everything(true, callback)
    else
        return cujo.nf.dostring(
            string.format('safebro.status.%s.enabled=false', feature_name),
            callback)
    end
end

function module.getconfig() return config end
function module.configure(settings)
    config = settings
    cujo.config.safebro.config_change_callback(nil, settings)
    cujo.safebro.trackerblock.configure(cujo.safebro['trackerblock'].enable.wanted, settings)

    local callback = function() module.config_state = 'applied' end
    module.config_state = 'applying'
    if config and anyactive() then
        turn_on_everything(callback)
    else
        turn_off_everything(false, callback)
    end
end

module.reputation = {
    enable = util.createenabler('reputation', function (self, enable, callback)
        return toggle_feature(self.name, enable, callback)
    end),
}

module.profiles = {
    enable = util.createenabler('profiles', function (self, enable, callback)
        return toggle_feature(self.name, enable, callback)
    end),
}

module.trackerblock = require "cujo.trackerblock"

module.trackerblock.stats = util.createpublisher()
module.trackerblock.enable = util.createenabler('trackerblock', function (self, enable, callback)
    cujo.safebro.trackerblock.configure(enable, config)
    return toggle_feature(self.name, enable, callback)
end)

function module.setprofiles(profiles)
        local newprofiles = cujo.util.serialize(profiles)
        cujo.nf.dostring('safebro.setprofiles(' .. newprofiles .. ')')
end

function module.setbypass(mac, add)
    cujo.nf.enablemac('threat.bypass', mac, add)
end

local function send_whitelist_batch(batch_data)
    cujo.nf.dostring('threat.addwhitelistbatch(' .. cujo.util.serialize(batch_data) .. ')')
end

function module.setwhitelist(data)
    local batch_size = 100
    local batch_data = {}
    for _, macsanddomains in pairs(data.whitelist or {}) do
        for _, mac in pairs(macsanddomains.macs) do
            local macnumber = tonumber(string.gsub(mac, ':', ''), 16)
            for _, domaindata in pairs(macsanddomains.entries) do
                table.insert(batch_data, {macnumber, domaindata.domain, domaindata.endTime})
                if #batch_data >= batch_size then
                    send_whitelist_batch(batch_data)
                    batch_data = {}
                end
            end
        end
    end
    if #batch_data ~= 0 then
        send_whitelist_batch(batch_data)
    end
end

function module.geturlscore(url, on_done)
    cujo.https.request{
        url = string.format('%s?url=%s', config.endpoint, url),
        headers = {Authorization = config.token, Connection = 'keep-alive'},
        create = connector[coroutine.running()],
        on_done = on_done,
    }
end

local function lookup(url, callback)
    if not config then
        cujo.log:error'URL lookup while not configured'
        return fakeresponse
    end
    start_time = shims.gettime()
    cujo.safebro.geturlscore(url, function(body, code)
        time_taken = (shims.gettime() - start_time) * 1000
        if not body or body == '' or code ~= 200 then
            cujo.log:error('URL lookup error "', url, '" : ', code, ' : ', body)
            return callback(fakeresponse)
        end

        local ok, response = pcall(json.decode, body)
        if not ok then
            cujo.log:error('URL lookup "', url, '" json decode error : ', response)
            return callback(fakeresponse)
        end

        if not response.score then
            cujo.log:error('URL lookup "', url, '" bad response : ',  body)
            return callback(fakeresponse)
        end

        if time_taken > cujo.config.safebro.lookup_threshold then
            cujo.config.safebro.lookup_timeout_callback(time_taken, url)
        end

        response.cachedomain = response.nocache ~= true
        response.reason = response.reason or fakeresponse.reason

        if response.score > fakeresponse.score then
            if response.score == 200 then
                cujo.log:status('URL lookup result pending "', url,
                    '" score out of range: ', response.score)
            else
                cujo.log:warn('URL lookup "', url, '" score out of range: ', response.score)
            end
            response.score = fakeresponse.score
            response.cachedomain = false
        end
        callback(response)
    end)
end

function module.initialize()
    cujo.nf.subscribe('lookup', function (entry)
        shims.concurrency_limited_do(lookupqueue, entry)
    end)
    cujo.nf.subscribe('notify', cujo.safebro.threat)

    init_connector()

    shims.concurrency_limited_setup(
        lookupqueue, cujo.config.lookupjobs,
        function(i) return string.format('safebro-lookup-%d', i) end,
        function(entry, callback)
            return lookup(entry.domain .. entry.path, function(response)
                setresponse(
                    entry.domain, response.score, response.reason,
                    response.categories or {}, response.cachedomain)
                return callback()
            end)
        end)
end

return module
