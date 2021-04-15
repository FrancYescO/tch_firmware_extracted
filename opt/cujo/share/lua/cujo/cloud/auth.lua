--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local module = {
	ongetroute = cujo.util.createpublisher(),
}

if cujo.config.cloud.route_callback ~= nil then
	module.ongetroute:subscribe(cujo.config.cloud.route_callback)
end

local customurlconnected = true
local function getroute()
	if not cujo.config.cloudurl.routes then
		return nil, 'cloud url routes not configured'
	end
	if customurlconnected then
		for _, route in ipairs(cujo.config.cloudurl.routes) do
			local url = route .. cujo.config.serial
			if cujo.config.firmware_name then
				url = url .. '?firmware_name=' .. cujo.config.firmware_name
			end
			local body, code = cujo.https.request{
				url = url,
				create = cujo.https.connector.simple(
					cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
			}
			if body and code == 200 then
				customurlconnected = true
				module.ongetroute(true, true, route)
				return body
			end
			module.ongetroute(false, true, route, code)
			cujo.log:warn("failed to fetch custom cloud url= '", route, "' : ", code)
		end
	end
	if cujo.config.cloudurl.default_route ~= nil then
		cujo.log:warn("attempting to fetch default routing url ")
		for _, route in ipairs(cujo.config.cloudurl.default_route) do
			local url = route .. cujo.config.serial
			if cujo.config.firmware_name then
				url = url .. '?firmware_name=' .. cujo.config.firmware_name
			end
			local body, code = cujo.https.request{
				url = url,
				create = cujo.https.connector.simple(
					cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
			}
			if body and code == 200 then
				customurlconnected = false
				module.ongetroute(true, false, route)
				return body
			end
			module.ongetroute(false, false, route, code)
			cujo.log:warn("unable to get cloud route through '", url, "' : ", code)
		end
	end
	return nil, 'unable to route'
end

local serial = 'serial=' .. cujo.config.serial

local auth = {}

function auth.ident() return {serial, 'api=' .. cujo.cloud.apiversion} end

function auth.secret(baseurl)
	local reply, code = cujo.https.request{
		url = baseurl .. '/token-auth',
		multipart = {
			serial = cujo.config.serial,
			certificate = assert(cujo.config.cloudurl.certificate),
		},
		create = cujo.https.connector.simple(
			cujo.config.tls, nil, cujo.config.cloudsrcaddr()),
	}
	if not reply then return nil, code end
	if code ~= 200 then
		return nil, string.format('http status %d response %s', code, reply)
	end
	return {'token=' .. reply, 'api=' .. cujo.cloud.apiversion}
end

local authentication = assert(cujo.config.cloudurl.authentication,
	'undefined authentication method')
local method = assert(auth[authentication],
	'invalid authentication method')

function module.auth()
	local baseurl, err = getroute()
	if not baseurl then return nil, err end
	local params, err = method(baseurl)
	if not params then return nil, err end
	return baseurl .. '/stomp?' .. table.concat(params, '&')
end

return module
