--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local util = require "cujo.util"

local module = {
    ongetroute = util.createpublisher(),
}

local customurlconnected = true

local function try_route(route, is_custom, callback)
    local url = route .. cujo.config.serial
    if cujo.config.firmware_name then
        url = url .. '?firmware_name=' .. cujo.config.firmware_name
    end
    cujo.https.request{
        url = url,
        create = cujo.https.connector.simple(
            cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
        on_done = function(body, code)
            if body and code == 200 then
                customurlconnected = is_custom
                module.ongetroute(true, is_custom, route)
                return callback(body)
            end
            module.ongetroute(false, is_custom, route, code)
            cujo.log:warn("unable to get cloud route through url='", url, "' : ", code)
            callback(nil)
        end
    }
end

local function try_default(callback)
    cujo.log:warn("attempting to fetch default routing url ")
    try_route(cujo.config.cloudurl.default_route, false, function(url)
        if url ~= nil then
            return callback(url)
        end
        callback(nil, 'unable to route')
    end)
end

local function getroute(callback)
    if not cujo.config.cloudurl.route then
        return nil, 'config.cloudurl.route not set'
    end
    if customurlconnected then
        try_route(cujo.config.cloudurl.route, true, function(url)
            if url ~= nil then
                return callback(url)
            end
            if cujo.config.cloudurl.default_route == nil then
                return callback(nil, 'unable to route')
            end
            try_default()
        end)
    else
        try_default()
    end
end

local serial

local auth = {}

function auth.ident(_, callback) return callback({serial, 'api=' .. cujo.cloud.apiversion}) end

function auth.secret(baseurl, callback)
    cujo.https.request{
        url = baseurl .. '/token-auth',
        multipart = {
            serial = cujo.config.serial,
            certificate = assert(cujo.config.cloudurl.certificate),
        },
        create = cujo.https.connector.simple(
            cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
        on_done = function(reply, code)
            if not reply then
                return callback(nil, code)
            end
            if code ~= 200 then
                return callback(nil, string.format('http status %d response %s', code, reply))
            end
            return callback({'token=' .. reply, 'api=' .. cujo.cloud.apiversion})
        end,
    }
end

local authentication
local method

function module.auth(callback)
    return getroute(function(baseurl, err)
        if not baseurl then
            return callback(nil, err)
        end
        return method(baseurl, function(params, err)
            if not params then
                return callback(nil, err)
            end
            return callback(baseurl .. '/stomp?' .. table.concat(params, '&'))
        end)
    end)
end

function module.initialize()
    if cujo.config.cloud.route_callback ~= nil then
        module.ongetroute:subscribe(cujo.config.cloud.route_callback)
    end

    serial = 'serial=' .. cujo.config.serial

    authentication = assert(cujo.config.cloudurl.authentication,
        'undefined authentication method')
    method = assert(auth[authentication],
        'invalid authentication method')
end

return module
