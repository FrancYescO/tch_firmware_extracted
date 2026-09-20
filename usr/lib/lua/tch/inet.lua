-- Copyright (c) 2016 Technicolor

---
-- Common IP address functions
--
-- @module tch.inet

local posix = require 'tch.posix'

local AF_INET = posix.AF_INET
local AF_INET6 = posix.AF_INET6
local inet_pton = posix.inet_pton

local M = {}

--- is the given address a valid IPv4 address
-- @tparam string ip the IP address string to test
-- @return true if it is a valid IPv4 address or nil plus error
--   message in case it is not
function M.isValidIPv4(ip)
	local r, err = inet_pton(AF_INET, ip)
	if r then
		return true
	end
	return nil, err
end

--- is the given address a valid IPv6 address
-- @tparam string ip the IP address string to test
-- @return true fi it is a valid IPv6 address or nil plus error 
--   message in case it is not
function M.isValidIPv6(ip)
	local r, err = inet_pton(AF_INET6, ip)
	if r then
		return true
	end
	return nil, err
end

return M
