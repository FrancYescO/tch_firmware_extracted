--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local ippattern = {
	ipv4 = 'inet (%d+%.%d+%.%d+%.%d)/(%d+)',
	ipv6 = 'inet6 ([%x:]+)/(%d+) scope global',
}
cujo.config = {
	startup = function () end,
	cloudsrcaddr = function()
		if not cujo.config.cloud_iface then return end
		return assert(netcfg:getdevaddr(cujo.config.cloud_iface))
	end,
	getdevaddr = function(iface, ipv, cidr)
		local cmd = cujo.config.ip .. ' -' .. ipv:sub(4, 4) .. ' a s ' .. iface
		local handle = assert(io.popen(cmd))
		local output = handle:read'a'
		handle:close()
		if output == nil then
			return nil
		end
		local address, subnet = output:match(ippattern[ipv])
		if cidr and address ~= nil then
			address = address .. '/' .. subnet
		end
		return address
	end,
	backoff = {
		initial = 5,
		factor = 6,
		range = 0.5,
		max = 15 * 60,
	},
	maxcloudmessages = 30,
	lookupjobs = 4,
	urlcheckertimeout = 3,
	rabidctl = {},
	job = {
		timeout = 5,
		pollingtime = 0.001,
	},
	warmcache = {
		ttl = 60 * 60 * 24,
		retryinterval = 60 * 5,
	},
	cloudurl = {},
	cloud_iface_required = true,
	nf = {
		appblock = {maxentries = 1024},
		conn = {maxentries = 512},
		http = {maxentries = 1024, ttl = 2 * 60},
		netlink = {port = 1337, family = 24},
		threat = {
			cache = {maxentries = 1024},
			pending = {maxentries = 128, ttl = 60},
			whitelist = {maxentries = 1024, ttl = 60 * 60},
		},
		traffic = {
			maxentries = 200,
			pollinterval = 5,
		},
		appdata = {
			maxentries = 30,
			timeout = 5,
		},
		trackerblock = {maxentries = 512},
	},
	traffic = {
		timeout = 5,
		maxpending = 150,
		maxflows = 150,
		maccachesize = 20,
		dnscachesize = 20,
		msgflows = 200,
		linespersecond = 10000,
		interval = 1,
		nf_conntrack_available = true,
		conntracklines = function()
			local fd = nil
			if cujo.config.traffic.nf_conntrack_available then
				fd = io.open('/proc/net/nf_conntrack')
			end
			if fd == nil then
				if cujo.config.traffic.nf_conntrack_available then
					cujo.log:config("falling back to conntrack tool")
				end
				fd = io.popen(cujo.config.conntrack .. ' -L 2> /dev/null')
				cujo.config.traffic.nf_conntrack_available = false
			end
			local f, state, ctrl = fd:lines()
			return function ()
				local ok, line = pcall(f, state, ctrl)
				if not ok then
					ok, line = pcall(f, state, ctrl)
				end
				-- Empty lines are to be expected in conntrack -L output
				if ok and not line or line == '' then
					fd:close()
					return
				end
				if not ok then
					fd:close()
					cujo.log:warn('Failed to read conntrack: ', line)
					return
				end
				if cujo.config.traffic.nf_conntrack_available then
					-- nf_conntrack has a slightly different format
					line = line:match('ipv%d%s+%d+ (.*)')
				end
				return line
			end
		end,
		get_fastpath_bytes = nil
	},
	appblock = {},
	chain_table = 'filter',
	chain_prefix = 'CUJO_',
	set_prefix = 'cujo_',
	lan_ifaces = {},
	nets = {},
	external_nf_rules = false,
	safebro = {
		lookup_threshold = 350.0,
		lookup_timeout_callback = function(time_taken, url)
			cujo.log:warn("url checker slow ", time_taken, " ms for '", url:sub(0, 5), "...'")
		end,
		config_change_callback = function(enable, settings)
			cujo.log:safebro('safebro settings updated ', settings)
		end,
	},
	trackerblock = {
		report_period = 300,
		report_max_entries = 200
	},
	cloud = {
		route_callback = function(got, custom, route)
			if not got then return end
			if custom then
				cujo.log:config('custom cloud endpoint used '.. route)
			else
				cujo.log:config('default cloud endpoint used '.. route)
			end
		end,
	}
}

local ipver = {ip4 = 'ipv4', ip6 = 'ipv6'}
function cujo.config.connkill(ipv, sip, dip, proto, port)
	local t = {'-D'}
	if ipv then cujo.util.append(t, '-f', ipver[ipv]) end
	if sip then cujo.util.append(t, '-s', sip) end
	if dip then cujo.util.append(t, '-d', dip) end
	if proto then
		cujo.util.append(t, '--proto', proto)
		if port then cujo.util.append(t, '--dport', port) end
	end
	local ok, err = cujo.jobs.exec(cujo.config.conntrack, t)
	if not ok and err ~= 1 then
		error('conntrack exited (code ' .. err .. ')')
	end
end

function parse_runtime_settings_str(settings_str)
	-- parse the string into a table
	local features = {}
	for token in string.gmatch(settings_str, "[,%S]+") do
		local eq_loc = string.find(token, "=")
		if eq_loc then
			local k = token:sub(0, eq_loc-1)
			local v = token:sub(eq_loc+1)
			features[k] = v
		else
			features[token] = true
		end
	end

	-- return the results
	return features
end

-- Get custom runtime settings from the environment

local runtime_settings_str = os.getenv('CUJO_RUNTIME_SETTINGS')
runtime_settings_str = runtime_settings_str and runtime_settings_str or ""

cujo.config.runtime_settings = parse_runtime_settings_str(runtime_settings_str)


-- load parameters.lua

do
	local mod = 'cujo.config.parameters'
	local path = assert(package.searchpath(mod, package.path))
	local env = setmetatable({config = cujo.config}, {__index = _G})
	assert(loadfile(path, 'bt', env))()
end

local function load_ifaces(env)
	local ifaces_str = os.getenv(env)
	if ifaces_str == nil then
		return nil
	end

	local ifaces = {}
	for iface in string.gmatch(ifaces_str, '%S+') do
		ifaces[#ifaces + 1] = iface
	end
	if #ifaces == 0 then
		cujo.log:warn('invalid ', env, '="', ifaces_str,
			      '", expected whitespace-separated values')
		return nil
	end
	return ifaces
end
local wan_ifaces = load_ifaces('CUJO_WAN_IFACES')
local lan_ifaces = load_ifaces('CUJO_LAN_IFACES')
local cloud_ifaces = load_ifaces('CUJO_CLOUD_IFACE')
if wan_ifaces ~= nil then cujo.config.wan_ifaces = wan_ifaces end
if lan_ifaces ~= nil then cujo.config.lan_ifaces = lan_ifaces end
if cloud_ifaces ~= nil then
	if #cloud_ifaces > 1 then
		cujo.log:error('too many values in CUJO_CLOUD_IFACE, using only the first one')
	end
	cujo.config.cloud_iface = cloud_ifaces[1]
end

local netcfg = cujo.net.newcfg()

if cujo.config.gateway_ip == nil then
	local iface = assert(cujo.config.lan_ifaces[1])
	cujo.config.gateway_ip = assert(netcfg:getdevaddr(iface))
	cujo.config.gateway_mac = assert(netcfg:getdevhwaddr(iface))
end
if cujo.config.serial == nil then
	cujo.config.serial = string.gsub(cujo.config.gateway_mac, ':', ''):lower()
end

cujo.log:config('identity serial number is ', assert(cujo.config.serial))

cujo.log:config('default gateway is ', cujo.config.gateway_ip,
           ' (MAC=', cujo.config.gateway_mac, ')')

function cujo.config.cloudsrcaddr()
	if not cujo.config.cloud_iface_required then
		return
	end
	if not cujo.config.cloud_iface then
		cujo.cloud.onauth(false, "No network")
		return
	end
	local ifaceaddr = netcfg:getdevaddr(cujo.config.cloud_iface)
	if not ifaceaddr then
		cujo.cloud.onauth(false, "Network is unreachable over " .. cujo.config.cloud_iface)
		assert(false, "Network is unreachable over " .. cujo.config.cloud_iface)
	end
	return ifaceaddr
end

if cujo.config.privileges then
	local permission = require'cujo.permission'
	if cujo.config.privileges.user or cujo.config.privileges.group then
		if cujo.config.privileges.capabilities then
			assert(permission.keepcaps())
		end
		if cujo.config.privileges.group then
			assert(permission.setgroup(cujo.config.privileges.group))
		end
		if cujo.config.privileges.user then
			assert(permission.setuser(cujo.config.privileges.user))
		end
	end
	if cujo.config.privileges.capabilities then
		assert(cujo.config.privileges.capabilities == "process"
		    or cujo.config.privileges.capabilities == "ambient", "illegal capability mode")
		local requiredcaps = { "net_admin", "net_raw", "net_bind_service" }
		assert(permission.setupcaps(table.unpack(requiredcaps)))
		if cujo.config.privileges.capabilities == "ambient" then
			for _, capname in ipairs(requiredcaps) do
				assert(permission.setambientcap(capname))
			end
		end
	end
end
