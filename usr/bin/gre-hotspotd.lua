#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2016 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************

local ubus = require("ubus")
local uloop = require("uloop")
local lfs = require("lfs")
local proxy = require("datamodel")
local logger = require("transformer.logger")
local sock = require("socket")

local hasxdslctl, xdslctl = pcall(require, "transformer.shared.xdslctl")

logger.init(6, false)
local log = logger.new("gre-hotspotd", 6)

local cursor = require("uci").cursor("/etc/config", "/var/state")
local cursor_persist = require("uci").cursor()

local default_states = {
	disabled = "Disabled",
	up = "Up",
	monitor_intf_down = "Error_MonitorIntfDown",
	ethwan_not_allowed = "Error_EthWanNotAllowed",
	xdsl_rate_too_low = "Error_xDSLRateTooLow",
	bridge_intf_down = "Error_BridgeIntfDown",
	gre_intf_down = "Error_GreIntfDown",
	private_ssid_down = "Error_PrivateWifiDeactivated",
	private_ssid_security_none = "Error_PrivateWifiSecurityLevelTooLow",
	-- States used only in tunnel case
	starting = "Starting",
	down = "Down",
	tunlink_intf_down = "Error_TunlinkIntfDown",
	unknown_peer_address = "Error_UnknownPeerAddress",
	unresponsive_peer = "Error_PeerNotRespondingToPings",
}
local global_states = { }

-- UBUS connection
local ubus_conn

-- Global state of the daemon
local global_enable = false

-- Hotspot status
local hotspots = { }

-- Tunnel status
local tunnels = { }
local tunnel_timer
local tunnel_starting_timeout = 30 -- seconds

-- Private SSID status
local private_ssid_name = "wl0"
local private_ssid_state
local private_ssid_encrypted

-- ETH WAN
local ethwan_name = "eth4"

-- Cache for all network interfaces
local all_interfaces = { }
local all_started_l3_devices = { }

-- Cache of upstream rates configured by this daemon
local configured_upstream_rates = { }

-- Run a command
local function run_command(s)
	log:info(s)
	return os.execute(s)
end

-- Helper that configures TBF queue discipline on an interface
local function configure_tbf_shaper(intf, rate)
	local cachedinfo = configured_upstream_rates[intf]
	if configured_upstream_rates[intf] ~= rate then
		if rate > 0 then
			-- Update soft shaper settings
			run_command("tc qdisc replace dev " .. intf .. " handle 1:0 root tbf burst 20kb latency 1000ms mtu 1514 rate " .. rate .. "kbit")
		else
			-- Delete soft shaper settings
			run_command("tc qdisc del dev " .. intf .. " root")
		end
		configured_upstream_rates[intf] = rate
	end
end

-- Helper that test reachability of an IP host through ping utility
-- addr         The IP (v4 or v6) address of the host
-- count        Number of echo requests to be sent
local function ping_peer(addr, count)
	return run_command("ping -W 1 -c " .. count .. " " .. addr) == 0
end

-- Helper that returns bridge of a specific wifi hotspot
local function get_hotspot_bridge(crs, config, wifi_ifaces)
	local bridge
	for _, wl in ipairs(wifi_ifaces) do
		local section = crs:get_all(config, wl)
		if section and section[".type"] == "wifi-iface" and section["network"] then
			if not bridge then
				bridge = section["network"]
			elseif section["network"] ~= bridge then
				return nil, "Wifi interfaces with different network assigned"
			end
		end
	end
	if not bridge then
		return nil, "No wifi interface with assigned network"
	end
	return bridge
end

-- Helper that returns GRE interface prefix for a specific GRE protocol
local function get_gre_proto_intf_prefix(greproto)
	local greprefix = ""

	if greproto == "gretap" then
		greprefix = "gre4t-"
	elseif greproto == "grev6tap" then
		greprefix = "gre6t-"
	end

	return greprefix
end

-- Helper that returns the GRE interface prefix when bridge member is a GRE port
local function is_gre_port(crs, config, member)
	local greprefix, greiface
	_, _, greiface = string.find(member, "^@([^.]+)")
	if greiface then
		local section = crs:get_all(config, greiface)
		if section and section[".type"] == "interface" then
			greprefix = get_gre_proto_intf_prefix(section["proto"])
		end
	else
		_, _, greprefix = string.find(member, "^(gre.*-)")
	end

	return (greprefix == "gre4t-" or greprefix == "gre6t-") and greprefix
end

-- Helper that returns GRE port of a specific bridge
local function get_gre_port(crs, config, bridge)
	local section = crs:get_all(config, bridge)
	local greprefix, greport

	if section and section[".type"] == "interface" and section["type"] == "bridge" then
		if type(section["ifname"]) == "string" then
			for member in string.gmatch(section["ifname"], "[^%s]+") do
				local ret = is_gre_port(crs, config, member)
				if ret then
					if greport then
						-- More than one GRE ports found, abort!
						greport = nil
						break
					end
					greprefix = ret
					greport = member
				end
			end
		elseif type(section["ifname"]) == "table" then
			for _, member in pairs(section["ifname"]) do
				local ret = is_gre_port(crs, config, member)
				if ret then
					if greport then
						-- More than one GRE ports found, abort!
						greport = nil
						break
					end
					greprefix = ret
					greport = member
				end
			end
		end
	end

	if greport and string.sub(greport,1,1) == "@" then
		greport = greprefix .. string.sub(greport,2)
	end

	return greport
end

-- Helper that returns GRE tunnel RX packets counter
local function get_tunnel_rx_packets(name)
	local rx_packets
	local tunnel = tunnels[name]
	if tunnel then
		local greprefix = get_gre_proto_intf_prefix(tunnel["proto"])
		local result = ubus_conn:call("network.device", "status", { ["name"] = greprefix .. name })

		if type(result) == "table" and type(result["statistics"]) == "table" then
			local k, v

			for k, v in pairs(result["statistics"]) do
				if k == "rx_packets" and type(v) == "number" then
					rx_packets = v
					break
				end
			end
		end
	end

	return rx_packets
end

-- Helper that sets the GRE port of a specific bridge
local function set_gre_port(crs, config, bridge, greport)
	local newvalue
	local oldvalue = crs:get(config, bridge, "ifname")

	-- Use interface aliases, netifd require them
	local greprefix
	_, _, greprefix, greport = string.find(greport, "^(gre.*-)(.+)$")
	if not greport or not (greprefix == "gre4t-" or greprefix == "gre6t-") then
		log:error("unexpected gre port format")
		return
	end
	greport = "@" .. greport
	
	-- Add the new greport to the bridge and preserve the non-gre bridge members
	if type(oldvalue) == "string" then
		newvalue = greport
		for member in string.gmatch(oldvalue, "[^%s]+") do
			if not is_gre_port(crs, config, member) then
				newvalue = newvalue .. " " .. member
			end
		end
	elseif type(oldvalue) == "table" then
		newvalue = { greport }
		for _, member in pairs(oldvalue) do
			if not is_gre_port(crs, config, member) then
				newvalue[#newvalue + 1] = member
			end
		end
	else
		newvalue = greport
	end

	-- Store the new set of bridge members
	crs:set(config, bridge, "ifname", newvalue)
end

-- Update GRE tunnel cached settings
local function update_tunnel_cache(section)
	local name = section[".name"]

	if name then
		local tunnel = tunnels[name]

		if not tunnel then
			tunnel = { }
			tunnels[name] = tunnel
		end

		tunnel["proto"] = section["proto"]
		tunnel["tunlink"] = section["tunlink"]
		tunnel["peeraddr"] = section["peeraddr"]
		tunnel["peer6addr"] = section["peer6addr"]
	end
end

-- Helper that returns GRE type, interface, tunnel link and VLAN of a specific GRE bridge port
-- Valid greport values are:
--   - netifd gre(v6)tap interface names
--   - netifd 8021q/8021ad device names
--   - Linux gre(v6)tap interface names, with or without VLAN tag in dot notation (e.g. gre4t-name or gre6t-name.12)
local function get_gre_setup(crs, config, greport)
	local greprefix, grename, vlanid
	local section = crs:get_all(config, greport)

	if not section then
		_, _, greprefix, grename, vlanid = string.find(greport, "^(gre.*-)(.*)[.](%d+)$")
		if greprefix == nil then
			_, _, greprefix, grename = string.find(greport, "^(gre.*-)(.*)$")
		end

		if greprefix == "gre4t-" or greprefix == "gre6t-" then
			section = crs:get_all(config, grename)
		end
	end

	if section then
		if greprefix == nil and section[".type"] == "device" and string.find(section["ifname"], "^gre.*-") == 1 and
					 (tostring(section["type"]):lower() == "8021q" or tostring(section["type"]):lower() == "8021ad") then
			_, _, grename = string.find(section["ifname"], "^gre.*-(.*)$")

			if grename then
				-- Update tunnel state with fresh data retrieved from UCI
				vlanid = section["vid"] or "1"
				section = crs:get_all(config, grename)
			
				if section and (section["proto"] == "gretap" or section["proto"] == "grev6tap") then
					update_tunnel_cache(section)

					return section["proto"], grename, vlanid, true
				end
			end
		elseif section[".type"] == "interface" and
			(greprefix and greprefix == get_gre_proto_intf_prefix(section["proto"]) or
			 (section["proto"] == "gretap" or section["proto"] == "grev6tap")) then

			-- Update tunnel state with fresh data retrieved from UCI
			update_tunnel_cache(section)

			return section["proto"], section[".name"], (vlanid or "0"), false
		end
	end
end

-- Helper that returns an attribute from all_interfaces cache
--    intf        the interface name
--    attr        the specific attribute to be retrieved
local function get_interface_cached_attribute(intf, attr)
	local attributes = all_interfaces[intf]
	if attributes then
		return attributes[attr]
	end

	return nil
end

-- Helper that finds a started interface over the specified L3 device that have a certain attribute
--    l3device        the L3 device
--    attr            additional attribute that interface must have
local function find_started_interface(l3device, attr)
	for name, attributes in pairs(all_interfaces) do
		if attributes["l3_device"] == l3device and attributes["up"] and attributes[attr] then
			return name
		end
	end
	return nil
end

-- Helper that returns the IPv4 and IPv6 interfaces correspondent to intf
--    intf        the interface name
local function get_started_ipv4v6_interfaces(crs, config, intf)
	local attributes = all_interfaces[intf]

	if not attributes then
		-- Interface not started yet, use UCI to retrieve the link to parent interface
		local parent = crs:get(config, intf, "ifname")
		if parent and string.sub(parent,1,1) == "@" then
			parent = string.sub(parent,2)
			attributes = all_interfaces[parent]
			local l3_device = attributes and attributes["l3_device"]
			if l3_device and attributes["up"] and (attributes["has_ipv4"] or attributes["has_ipv6"]) then
				return (attributes["has_ipv4"] and parent), (attributes["has_ipv6"] and parent)
			end
		end
		return nil
	end

	-- look up for started interfaces that have the same l3_device and supports the right protocols
	local ipv4, ipv6
	local l3_device = attributes["l3_device"]
	if l3_device then
		local interfaces = all_started_l3_devices[l3_device]
		if interfaces then
			ipv4 = interfaces["ipv4"]
			ipv6 = interfaces["ipv6"]
		end
	end

	return ipv4, ipv6
end

-- cached value of xDSL upstream & downstream rate in kbit/sec
local xdsl_upstream_rate, xdsl_downstream_rate

-- placeholder to store hotspot's xDSL-rate-too-low conditions
local hotspot_xdsl_rate_too_low = { }

-- Helper that retrieve the current xDSL upstream and downstream rates in kbit/sec
local function get_xdsl_rates()
	if hasxdslctl then
		local rates = xdslctl.infoValue("currentrate")

		xdsl_upstream_rate = tonumber(rates["us"])
		xdsl_downstream_rate = tonumber(rates["ds"])
	end
end

-- Returns current xDSL upstream rate in kbit/sec
local function get_xdsl_upstream_rate()
	if xdsl_upstream_rate == nil then
		get_xdsl_rates()
	end
	return xdsl_upstream_rate or 0
end

-- Returns current xDSL downstream rate in kbit/sec
local function get_xdsl_downstream_rate()
	if xdsl_downstream_rate == nil then
		get_xdsl_rates()
	end
	return xdsl_downstream_rate or 0
end

-- Checks whether or not current xDSL upstream and downstream rates correspond to the configured tunnel or hotspot policy
--      name    tunnel or hotspot name
--      setup   tunnel or hotspot state
local function check_xdsl_rate_policy(name, setup)
	local min_downstream_rate = setup["min-xdsl-downstream-rate"]

	if type(min_downstream_rate) ~= "number" or min_downstream_rate <= 0 then
		min_downstream_rate = nil
	end

	local min_upstream_rate = setup["min-xdsl-upstream-rate"]
	if type(min_upstream_rate) ~= "number" or min_upstream_rate <= 0 then
		min_upstream_rate = nil
	end

	local rate_hysteresis = setup["xdsl-rate-hysteresis"]
	if type(rate_hysteresis) ~= "number" or rate_hysteresis <= 0 then
		rate_hysteresis = nil
	end

	if rate_hysteresis then
		-- This parameter was introduced to avoid fast hotspot on/off switches
		if min_downstream_rate then
			if hotspot_xdsl_rate_too_low[name] then
				min_downstream_rate = min_downstream_rate + rate_hysteresis
			else
				min_downstream_rate = min_downstream_rate - rate_hysteresis
			end
		end
		if min_upstream_rate then
			if hotspot_xdsl_rate_too_low[name] then
				min_upstream_rate = min_upstream_rate + rate_hysteresis
			else
				min_upstream_rate = min_upstream_rate - rate_hysteresis
			end
		end
	end

	if (min_downstream_rate and min_downstream_rate > get_xdsl_downstream_rate()) or
	   (min_upstream_rate and min_upstream_rate > get_xdsl_upstream_rate()) then
		hotspot_xdsl_rate_too_low[name] = true
		return false
	elseif min_downstream_rate or min_upstream_rate then
		hotspot_xdsl_rate_too_low[name] = false
		return true
	else
		hotspot_xdsl_rate_too_low[name] = nil
		return true
	end
end

local function get_bool_option(option, default_value)
	if type(option) == "boolean" then
		return option
	elseif type(option) == "string" then
		if option == "true" or option == "on" or option == "enabled" or option == "1" then
			return true
		elseif option == "false" or option == "off" or option == "disabled" or option == "0" then
			return false
		end
	end
	return default_value
end

local function validate_wifi_ifaces(name, wifi_ifaces, confhotspots)
	if not name or not wifi_ifaces then
		return "Required parameters are missing"
	end
	for _, wl in ipairs(wifi_ifaces) do
		if wl == private_ssid_name then
			return "Private SSID not allowed in hotspot setups"
		end
		for n, s in pairs(confhotspots) do
			if name ~= n then
				for _, wl2 in ipairs(s["wifi-iface"]) do
					if wl == wl2 then
						return  "Wifi interface " .. wl .. " already used by hotspot " .. n
					end
				end
			end
		end
	end
end

local function validate_gre_settings(name, gre_iface, vlan_id, confhotspots)
	if not gre_iface then
		return "Bridge port is not GRE"
	else
		local n, s
		for n, s in pairs(confhotspots) do
			if name ~= n and gre_iface == s["gre-iface"] and vlan_id == s["vlan-id"] then
				return  "GRE interface " .. s["gre-bridge-port"] .. " already used by hotspot " .. n
			end
		end
	end
end

local function get_configuration()
	local config
	local confhotspots = { }

	-- Load global setup
	config = "gre_hotspotd"
	cursor:load(config)
	global_enable = get_bool_option(cursor:get(config, "global", "enable"), true)
	global_states = {}
	for name, setup in pairs(default_states) do
		global_states[name] = cursor:get(config, "global", name) or setup
	end

	-- Load GRE tunnels setup
	tunnels = {}
	cursor:foreach(config, "tunnel", function(s)
		if type(s["peers"]) == "string" then
			s["peers"] = { s["peers"] }
		end

		tunnels[s[".name"]] = {
			["enable"] = get_bool_option(s["enable"], true), -- Presence of enable flag is used to distinguish between managed and unmanaged tunnel entries
			["peers"] = s["peers"],
			["ping-peer"] = get_bool_option(s["ping_peer"], false),
			["ping-count"] = tonumber(s["ping_count"]) and math.floor(s["ping_count"]) or 0,
			["ping-retry-interval"] = tonumber(s["ping_retry_interval"]) and math.floor(s["ping_retry_interval"]) or 0,
			["ping-silent-peer-interval"] = tonumber(s["ping_silent_peer_interval"]) and math.floor(s["ping_silent_peer_interval"]) or 0,
			["xdsl-rate-hysteresis"] = tonumber(s["xdsl_rate_hysteresis"]) and math.floor(s["xdsl_rate_hysteresis"]),
			["min-xdsl-downstream-rate"] = tonumber(s["min_xdsl_downstream_rate"]) and math.floor(s["min_xdsl_downstream_rate"]),
			["min-xdsl-upstream-rate"] = tonumber(s["min_xdsl_upstream_rate"]) and math.floor(s["min_xdsl_upstream_rate"]),
			["upstream-rate"] = tonumber(s["upstream_rate"]) and math.floor(s["upstream_rate"]),
			["upstream-percentage"] = tonumber(s["upstream_percentage"]) and math.floor(s["upstream_percentage"]),
		}
	end)

	-- Load GRE hotspots setup
	cursor:foreach(config, "hotspot", function(s)
		if type(s["wifi_iface"]) == "string" then
			s["wifi_iface"] = { s["wifi_iface"] }
		end
		local errstring = validate_wifi_ifaces(s[".name"], s["wifi_iface"], confhotspots)
		if errstring then
			log:error("hotspot " .. s[".name"] .. ": " .. errstring)
			return
		end

		confhotspots[s[".name"]] = {
			["wifi-iface"] = s["wifi_iface"],
			["enable"] = get_bool_option(s["enable"], true),
			["monitor-iface"] = (s["monitor_iface"] or false),
			["check-private-wifi"] = get_bool_option(s["check_private_wifi"], true),
			["check-private-wifi-encryption"] = get_bool_option(s["check_private_wifi_encryption"], true),
			["allow-ethwan-mode"] = get_bool_option(s["allow_ethwan_mode"], true),
			["xdsl-rate-hysteresis"] = tonumber(s["xdsl_rate_hysteresis"]) and math.floor(s["xdsl_rate_hysteresis"]),
			["min-xdsl-downstream-rate"] = tonumber(s["min_xdsl_downstream_rate"]) and math.floor(s["min_xdsl_downstream_rate"]),
			["min-xdsl-upstream-rate"] = tonumber(s["min_xdsl_upstream_rate"]) and math.floor(s["min_xdsl_upstream_rate"]),
			["upstream-rate"] = tonumber(s["upstream_rate"]) and math.floor(s["upstream_rate"]),
			["upstream-percentage"] = tonumber(s["upstream_percentage"]) and math.floor(s["upstream_percentage"]),
		}
	end)
	cursor:unload(config)

	-- Get bridge interfaces of all hotspots
	config = "wireless"
	cursor:load(config)
	for name, setup in pairs(confhotspots) do
		setup["bridge"], errmsg = get_hotspot_bridge(cursor, config, setup["wifi-iface"])
		if not setup["bridge"] then
			log:error("hotspot " .. name .. ": " .. errmsg)
			confhotspots[name] = nil
		end
	end
	cursor:unload(config)

	-- Get bridge GRE port, VLAN-ID and other GRE settings
	config = "network"
	cursor_persist:load(config)
	for name, setup in pairs(confhotspots) do
		if get_interface_cached_attribute(setup["bridge"], "up") then
			setup["gre-bridge-port"] = get_gre_port(cursor_persist, config, setup["bridge"])
			if not setup["gre-bridge-port"] then
				log:error("hotspot " .. name .. ": Invalid bridge setup")
				confhotspots[name] = nil
			end
		end
	end
	for name, setup in pairs(confhotspots) do
		if setup["gre-bridge-port"] then
			_, setup["gre-iface"], setup["vlan-id"] = get_gre_setup(cursor_persist, config, setup["gre-bridge-port"])
			local errstring = validate_gre_settings(name, setup["gre-iface"], setup["vlan-id"], confhotspots)
			if errstring then
				log:error("hotspot " .. name .. ": " .. errstring)
				confhotspots[name] = nil
			end
		end
	end
	for name, setup in pairs(tunnels) do
		if not setup["proto"] then
			local greiface
			_, greiface = get_gre_setup(cursor_persist, config, name)
			if greiface ~= name then
				log:error("tunnel " .. name .. ": No such gre(v6)tap interface")
				tunnels[name] = nil
			end
		end
	end
	cursor_persist:unload(config)

	return confhotspots
end

local function valid_managed_peer_tunnel_state(state)
	return state == global_states.up or state == global_states.starting or state == global_states.tunlink_intf_down or
	       state == global_states.unresponsive_peer or state == global_states.unknown_peer_address
end

-- Update tunnels state
local function update_tunnels_state(do_ubus_operations)
	local config, state
	local uci_state_changed
	local start_tunnels, stop_tunnels = { }, { }
	local next_tunnel_timer

	do_ubus_operations.start_interfaces = start_tunnels
	do_ubus_operations.stop_interfaces = stop_tunnels

	-- reset cached value of xDSL upstream & downstream rates
	xdsl_upstream_rate = nil
	xdsl_downstream_rate = nil

	config = "network"
	cursor_persist:load(config)
	for name, tunnel in pairs(tunnels) do
		if tunnel["enable"] ~= nil and not (global_enable and tunnel["enable"]) then
			if get_interface_cached_attribute(name, "up") then
				stop_tunnels[#stop_tunnels + 1] = name
			end
			state = global_states.disabled
			tunnel["timestamp"] = os.time()
		elseif get_interface_cached_attribute(tunnel["tunlink"] or "wan", "is_over_xdsl") and not check_xdsl_rate_policy(name, tunnel) then
			if get_interface_cached_attribute(name, "up") then
				stop_tunnels[#stop_tunnels + 1] = name
			end
			state = global_states.xdsl_rate_too_low
			tunnel["timestamp"] = os.time()
		elseif tunnel["peers"] then
			-- Check if the tunnel refresh timer has expired
			local timestamp
			if tunnel["state"] == global_states.starting then
				if os.time() >= tunnel["timestamp"] + tunnel_starting_timeout then
					tunnel["refresh-state"] = true
				end
			elseif tunnel["state"] == global_states.up then
				if not get_interface_cached_attribute(name, "up") then
					tunnel["refresh-state"] = true
				elseif tunnel["ping-peer"] and tunnel["ping-count"] > 0 and tunnel["ping-silent-peer-interval"] > 0 and
				   os.time() >= tunnel["timestamp"] + tunnel["ping-silent-peer-interval"] then
					-- Check if current peer was active lately
					local rx_packets = get_tunnel_rx_packets(name)
					if (tunnel["rx-packets"] or 0) ~= rx_packets then
						tunnel["rx-packets"] = rx_packets
						tunnel["timestamp"] = os.time()
					else
						tunnel["refresh-state"] = true
					end
				end
			elseif tunnel["state"] == global_states.unresponsive_peer or tunnel["state"] == global_states.unknown_peer_address then
				if tunnel["ping-peer"] and tunnel["ping-count"] > 0 and tunnel["ping-retry-interval"] > 0 and
				   os.time() >= tunnel["timestamp"] + tunnel["ping-retry-interval"] then
					tunnel["refresh-state"] = true
				end
			end

			if tunnel["refresh-state"] or not valid_managed_peer_tunnel_state(tunnel["state"]) then
				local allowed_families = { }
				local intf_ipv4, intf_ipv6

				if tunnel["tunlink"] then
					intf_ipv4, intf_ipv6 = get_started_ipv4v6_interfaces(cursor_persist, config, tunnel["tunlink"])
					allowed_families["inet"] = (intf_ipv4 ~= nil)
					allowed_families["inet6"] = (intf_ipv6 ~= nil)
				else
					allowed_families["inet"] = true
					allowed_families["inet6"] = true
				end

				if allowed_families["inet"] or allowed_families["inet6"] then
					-- Find an usable peer address
					local peer, valid_addr
					local ping_disabled = not (tunnel["ping-peer"] and tunnel["ping-count"] > 0)
					for idx, addr in ipairs(tunnel["peers"]) do
						local query_response = sock.dns.getaddrinfo(addr)

						if query_response and idx == 1 and tunnel["state"] == global_states.up then
							-- To avoid flip-flops while checking reachability of silent peers
							-- currently selected address must be checked first
							local selected_addr = (tunnel["proto"] == "gretap" and tunnel["peeraddr"] or tunnel["peer6addr"])
							for idx, rr in ipairs(query_response) do
								if selected_addr == rr["addr"] then
									if idx > 1 then
										table.remove(query_response, idx)
										table.insert(query_response, 1, rr)
									end
									break
								end
							end
						end

						if query_response and query_response[1] then
							valid_addr = true

							for _, rr in ipairs(query_response) do
								if allowed_families[rr["family"]] and (ping_disabled and rr["addr"] or ping_peer(rr["addr"], tunnel["ping-count"])) then
									peer = { address = rr["addr"], family = rr["family"] }
									break
								end
							end

							if peer then
								-- Promote the responsive peer
								if idx > 1 then
									table.remove(tunnel["peers"], idx)
									table.insert(tunnel["peers"], 1, addr)
								end
								break
							end
						end
					end

					if peer then
						local greportprefix

						if peer.family == "inet" then
							if tunnel["peeraddr"] ~= peer.address or tunnel["proto"] ~= "gretap" or tunnel["tunlink"] ~= intf_ipv4 then
								cursor_persist:set(config, name, "peeraddr", peer.address)
								tunnel["peeraddr"] = peer.address
								cursor_persist:delete(config, name, "peer6addr")
								tunnel["peer6addr"] = nil
								cursor_persist:set(config, name, "proto", "gretap")
								tunnel["proto"] = "gretap"
								greportprefix = "gre4t-"
								if intf_ipv4 then
									cursor_persist:set(config, name, "tunlink", intf_ipv4)
									tunnel["tunlink"] = intf_ipv4
								end
							end
						else
							if tunnel["peer6addr"] ~= peer.address or tunnel["proto"] ~= "grev6tap" or tunnel["tunlink"] ~= intf_ipv6 then
								cursor_persist:set(config, name, "peer6addr", peer.address)
								tunnel["peer6addr"] = peer.address
								cursor_persist:delete(config, name, "peeraddr")
								tunnel["peeraddr"] = nil
								cursor_persist:set(config, name, "proto", "grev6tap")
								tunnel["proto"] = "grev6tap"
								greportprefix = "gre6t-"
								if intf_ipv6 then
									cursor_persist:set(config, name, "tunlink", intf_ipv6)
									tunnel["tunlink"] = intf_ipv6
								end
							end
						end

						if greportprefix then
							-- Settings have changed, make sure tunnel gets restarted
							uci_state_changed = true
							if get_interface_cached_attribute(name, "up") then
								stop_tunnels[#stop_tunnels + 1] = name
							end
							start_tunnels[#start_tunnels + 1] = name

							-- Update hotspot GRE bridge ports according to the (possibly new) GRE interface proto
							for _, setup in pairs(hotspots) do
								if setup["gre-iface"] == name and setup["bridge"] then
									local greport = greportprefix .. name
									if setup["vlan-id"] ~= "0" then
										greport = greport .. "." .. setup["vlan-id"]
									end
									set_gre_port(cursor_persist, config, setup["bridge"], greport)
									setup["gre-bridge-port"] = greport
								end
							end

							state = global_states.starting
						elseif get_interface_cached_attribute(name, "up") then
							state = global_states.up
						else
							if tunnel["state"] ~= global_states.starting or
							   os.time() >= tunnel["timestamp"] + tunnel_starting_timeout then
								start_tunnels[#start_tunnels + 1] = name
							end
							state = global_states.starting
						end
					else
						-- Delete exisiting peeraddr when no peers are found
						cursor_persist:delete(config, name, "peer6addr")
						tunnel["peer6addr"] = nil
						cursor_persist:delete(config, name, "peeraddr")
						tunnel["peeraddr"] = nil
						uci_state_changed = true

						if get_interface_cached_attribute(name, "up") then
							stop_tunnels[#stop_tunnels + 1] = name
						end
						state = valid_addr and global_states.unresponsive_peer or global_states.unknown_peer_address
					end
				else
					if get_interface_cached_attribute(name, "up") then
						stop_tunnels[#stop_tunnels + 1] = name
					end
					state = global_states.tunlink_intf_down
				end
				tunnel["timestamp"] = os.time()
			elseif tunnel["state"] == global_states.starting and get_interface_cached_attribute(name, "up") then
				state = global_states.up
				tunnel["timestamp"] = os.time()
			else
				state = tunnel["state"]
			end
		elseif get_interface_cached_attribute(name, "up") then
			state = global_states.up
			tunnel["timestamp"] = os.time()
		elseif tunnel["enable"] then
			if tunnel["state"] ~= global_states.starting or
			   os.time() >= tunnel["timestamp"] + tunnel_starting_timeout then
				-- everything is OK now (xDSL rate, enable flag, ...), start the tunnel
				start_tunnels[#start_tunnels + 1] = name
				tunnel["timestamp"] = os.time()
			end
			state = global_states.starting
		else
			state = global_states.down
			tunnel["timestamp"] = os.time()
		end

		-- Reset the tunnel refresh timer
		local timestamp
		if state == global_states.starting then
			timestamp = tunnel["timestamp"] + tunnel_starting_timeout
		elseif state == global_states.up then
			if tunnel["ping-peer"] and tunnel["ping-count"] > 0 and tunnel["ping-silent-peer-interval"] > 0 then
				timestamp = tunnel["timestamp"] + tunnel["ping-silent-peer-interval"]
			end
		elseif state == global_states.unresponsive_peer or state == global_states.unknown_peer_address then
			if tunnel["ping-peer"] and tunnel["ping-count"] > 0 and tunnel["ping-retry-interval"] > 0 then
				timestamp = tunnel["timestamp"] + tunnel["ping-retry-interval"]
			end
		end

		if timestamp and (not next_tunnel_timer or timestamp < next_tunnel_timer) then
			next_tunnel_timer = timestamp
		end

		local l3_device = get_interface_cached_attribute(name, "l3_device")
		if state == global_states.up and l3_device then
			local upstream_rate

			if get_interface_cached_attribute(tunnel["tunlink"] or "wan", "is_over_xdsl") and type(tunnel["upstream-percentage"]) == "number" and
					tunnel["upstream-percentage"] > 0 and tunnel["upstream-percentage"] <= 100 then
				-- Get upstream percentage, available only on xDSL interfaces
				-- compute upstream rate correspondent to the configured upstream percentage
				upstream_rate = math.floor(tunnel["upstream-percentage"] * get_xdsl_upstream_rate() / 100)
			elseif type(tunnel["upstream-rate"]) == "number" and tunnel["upstream-rate"] > 0 then
				-- Get absolute upstream rate
				upstream_rate = tunnel["upstream-rate"]
			end

			-- Apply upstream rate on GRE tunnel interface
			if upstream_rate then
				configure_tbf_shaper(l3_device, upstream_rate)
			else
				configured_upstream_rates[l3_device] = nil
			end
		end

		if state ~= tunnel["state"] then
			if tunnel["state"] then
				log:notice("Tunnel " .. name .. " state changed from " .. tunnel["state"] .. " to " .. state)
			end
			tunnel["state"] = state
		end
		tunnel["refresh-state"] = nil
	end

	if uci_state_changed then
		cursor_persist:commit(config)
		do_ubus_operations.reload_network = true
	end
	cursor_persist:unload(config)

	-- Reset the tunnel refresh timer
	if next_tunnel_timer then
		next_tunnel_timer = (next_tunnel_timer - os.time()) * 1000
		if next_tunnel_timer <= 0 then
			next_tunnel_timer = 100
		end
		tunnel_timer:set(next_tunnel_timer)
	end
end

-- Invalidate cached state of peer managed tunnels that use a certain L3 interface as tunlink
local function refresh_tunnels_using_tunlink(l3_device)
	for name, tunnel in pairs(tunnels) do
		if tunnel["peers"] then
			if get_interface_cached_attribute(tunnel["tunlink"] or "wan", "l3_device") == l3_device then
				tunnel["refresh-state"] = true
			end
		end
	end
end

-- Retrieve the tunlink of a certain tunnel. 
-- Returns "wan" if tunnel isn't known or has no tunlink.
local function get_tunnel_tunlink(name)
	local tunnel = tunnels[name]

	return tunnel and tunnel["tunlink"] or "wan"
end

-- Update hotspots state
local function update_hotspots_state(reset_cached_xdsl_rate, do_ubus_operations)
	local config, state
	local uci_state_changed

	if reset_cached_xdsl_rate then
		-- reset cached value of xDSL upstream & downstream rates
		xdsl_upstream_rate = nil
		xdsl_downstream_rate = nil
	end

	config = "wireless"
	cursor:load(config)
	cursor_persist:load(config)
	for name, setup in pairs(hotspots) do
		if not global_enable or not setup["enable"] then
			state = global_states.disabled
		elseif not setup["allow-ethwan-mode"] and get_interface_cached_attribute(setup["monitor-iface"] or get_tunnel_tunlink(setup["gre-iface"]), "lowest_device") == ethwan_name then
			state = global_states.ethwan_not_allowed
		elseif get_interface_cached_attribute(setup["monitor-iface"] or get_tunnel_tunlink(setup["gre-iface"]), "is_over_xdsl") and not check_xdsl_rate_policy(name, setup) then
			state = global_states.xdsl_rate_too_low
		elseif setup["monitor-iface"] and not get_interface_cached_attribute(setup["monitor-iface"], "up") then
			state = global_states.monitor_intf_down
		elseif not get_interface_cached_attribute(setup["bridge"], "up") then
			state = global_states.bridge_intf_down
		elseif not get_interface_cached_attribute(setup["gre-iface"], "up") then
			state = global_states.gre_intf_down
		elseif setup["check-private-wifi"] and not private_ssid_state then
			state = global_states.private_ssid_down
		elseif setup["check-private-wifi-encryption"] and not private_ssid_encrypted then
			state = global_states.private_ssid_security_none
		else
			state = global_states.up
		end

		local greport = setup["gre-bridge-port"]
		if state == global_states.up and greport then
			local upstream_rate

			if get_interface_cached_attribute(setup["monitor-iface"] or get_tunnel_tunlink(setup["gre-iface"]), "is_over_xdsl") and type(setup["upstream-percentage"]) == "number" and
					setup["upstream-percentage"] > 0 and setup["upstream-percentage"] <= 100 then
				-- Get upstream percentage, available only on xDSL interfaces
				-- compute upstream rate correspondent to the configured upstream percentage
				upstream_rate = math.floor(setup["upstream-percentage"] * get_xdsl_upstream_rate() / 100)
			elseif type(setup["upstream-rate"]) == "number" and setup["upstream-rate"] > 0 then
				-- Get absolute upstream rate
				upstream_rate = setup["upstream-rate"]
			end

			-- Apply upstream rate on GRE bridge port
			if upstream_rate then
				configure_tbf_shaper(greport, upstream_rate)
			else
				configured_upstream_rates[greport] = nil
			end
		end

		if state ~= setup["state"] then
			if setup["state"] then
				log:notice("Hotspot " .. name .. " state changed from " .. setup["state"] .. " to " .. state)
			end
			if setup["state"] == nil or setup["state"] == global_states.up or state == global_states.up then
				-- Update WiFi interface statey
				local timestamp = os.time()
				for _, wl in ipairs(setup["wifi-iface"]) do
					cursor:revert(config, wl, "state")
					cursor:set(config, wl, "state", (state == global_states.up and "1" or "0"))
					cursor_persist:set(config, wl, "hotspot_timestamp", timestamp)
					uci_state_changed = true
				end
			end
			setup["state"] = state
		end
	end
	if uci_state_changed then
		cursor:save(config)
		cursor_persist:commit(config)

		-- Reload hostapd and netifd
		do_ubus_operations.reload_wireless = true
		do_ubus_operations.reload_network = true
	end
	cursor_persist:unload(config)
	cursor:unload(config)

end

local function perform_ubus_operations(operations)
	if operations.reload_network then
		ubus_conn:call("network", "reload", { })
	end
	if operations.reload_wireless then
		ubus_conn:call("wireless", "reload", { })
	end

	local stop_interfaces = operations.stop_interfaces
	if stop_interfaces then
		for _, name in ipairs(stop_interfaces) do
			log:info("Stop interface " .. name)
			ubus_conn:call("network.interface", "down", { ["interface"] = name })
		end
	end

	local start_interfaces = operations.start_interfaces
	if start_interfaces then
		for _, name in ipairs(start_interfaces) do
			log:info("Start interface " .. name)
			ubus_conn:call("network.interface", "up", { ["interface"] = name })
		end
	end
end

local function tunnel_timer_handler()
	local ubus_operations = { }

	-- Update tunnel status
	update_tunnels_state(ubus_operations)
	perform_ubus_operations(ubus_operations)
end
tunnel_timer = uloop.timer(tunnel_timer_handler)

-- Discard current state and reload the UCI configuration
local function reload_configuration()
	local config
	local newhotspots = get_configuration()
	local ubus_operations = { }

	local newwifi = {}
	for name, setup in pairs(newhotspots) do
		for _, wl in ipairs(setup["wifi-iface"]) do
			newwifi[wl] = true
		end

		-- Preserve the hotspot states in an attempt to avoid useless wireless/network reloads
		if hotspots[name] then
			newhotspots[name].state = hotspots[name].state
		end
	end

	-- Clean volatile state of wireless interfaces that are no longer controlled by this daemon
	config = "wireless"
	cursor:load(config)
	for name, setup in pairs(hotspots) do
		for _, wl in ipairs(setup["wifi-iface"]) do
			if not newwifi[wl] then
				cursor:revert(config, wl, "state")
				ubus_operations.reload_wireless = true
				ubus_operations.reload_network = true
			end
		end
	end
	cursor:unload(config)

	-- Replace current state with the new one
	hotspots = newhotspots

	-- Set tunnels and hotspots state
	update_tunnels_state(ubus_operations)
	update_hotspots_state(false, ubus_operations)
	perform_ubus_operations(ubus_operations)
end

-- Remove hotspot
local function delete_hotspot(name)
	local config
	local setup = hotspots[name]
	local ubus_operations = { }

	if not setup then
		return
	end

	hotspots[name] = nil

	-- Remove it from the UCI configuration
	config = "gre_hotspotd"
	cursor_persist:load(config)
	cursor_persist:delete(config, name)
	cursor_persist:commit(config)
	cursor_persist:unload(config)

	-- Clean volatile state of wireless interfaces that are no longer controlled by this daemon
	config = "wireless"
	cursor:load(config)
	for _, wl in ipairs(setup["wifi-iface"]) do
		cursor:revert(config, wl, "state")
	end
	ubus_operations.reload_wireless = true
	ubus_operations.reload_network = true
	cursor:unload(config)

	-- Reload the bridge used by the removed hotspot
	update_hotspots_state(true, ubus_operations)
	perform_ubus_operations(ubus_operations)
end

-- Modify or add hotspot
local function set_hotspot(name, newsetup)
	local config, newhotspot
	local setup = hotspots[name]
	local newvlanid, errstring
	local ubus_operations = { }

	-- Validate some input parameters
	if newsetup["vlan-id"] then
		_, _, newvlanid = string.find(newsetup["vlan-id"], "^(%d+)$")
		if not newvlanid or tonumber(newvlanid) > 4095 then
			return { error = "Invalid VLAN ID" }
		end
	end
	if not setup or newsetup["wifi-iface"] then
		if type(newsetup["wifi-iface"]) == "string" then
			newsetup["wifi-iface"] = { newsetup["wifi-iface"] }
		end
		errstring = validate_wifi_ifaces(name, newsetup["wifi-iface"], hotspots)
		if errstring then
			return { error = errstring }
		end
	end

	-- Handle wifi-iface setup and hotspot creation
	if newsetup["wifi-iface"] then
		-- Get bridge interface
		local bridge
		config = "wireless"
		cursor:load(config)
		bridge, errmsg = get_hotspot_bridge(cursor, config, newsetup["wifi-iface"])
		if not bridge then
			return { error = errmsg }
		end
		cursor:unload(config)

		-- Get bridge GRE port, type, interface and VLAN ID
		if not get_interface_cached_attribute(bridge, "up") then
			return { error = "Bridge interface '" .. bridge .. "' is down" }
		end
		config = "network"
		cursor_persist:load(config)
		local greport, greiface, vlanid
		greport = get_gre_port(cursor_persist, config, bridge)
		if not greport then
			cursor_persist:unload(config)
			return { error = "Invalid bridge setup" }
		end
		_, greiface, vlanid = get_gre_setup(cursor_persist, config, greport)
		errstring = validate_gre_settings(name, greiface, vlanid, hotspots)
		if errstring then
			cursor_persist:unload(config)
			return { error = errstring }
		end
		cursor_persist:unload(config)

		if not setup then
			-- If this is a new hotspot, create the setup
			setup = {
				["wifi-iface"] = newsetup["wifi-iface"],
				["enable"] = get_bool_option(newsetup["enable"], true),
				["monitor-iface"] = (newsetup["monitor-iface"] or false),
				["check-private-wifi"] = get_bool_option(newsetup["check-private-wifi"], true),
				["check-private-wifi-encryption"] = get_bool_option(newsetup["check-private-wifi-encryption"], true),
				["allow-ethwan-mode"] = get_bool_option(newsetup["allow-ethwan-mode"], true),
				["xdsl-rate-hysteresis"] = tonumber(newsetup["xdsl-rate-hysteresis"]) and math.floor(newsetup["xdsl-rate-hysteresis"]),
				["min-xdsl-downstream-rate"] = tonumber(newsetup["min-xdsl-downstream-rate"]) and math.floor(newsetup["min-xdsl-downstream-rate"]),
				["min-xdsl-upstream-rate"] = tonumber(newsetup["min-xdsl-upstream-rate"]) and math.floor(newsetup["min-xdsl-upstream-rate"]),
				["upstream-rate"] = tonumber(newsetup["upstream-rate"]) and math.floor(newsetup["upstream-rate"]),
				["upstream-percentage"] = tonumber(newsetup["upstream-percentage"]) and math.floor(newsetup["upstream-percentage"]),
			}
			newhotspot = true
		else
			local wls = { }, new_wl
			for _, wl in ipairs(setup["wifi-iface"]) do
				wls[wl] = true;
			end
			for _, wl in ipairs(newsetup["wifi-iface"]) do
				if not wls[wl] then
					new_wl = true
					break
				end
				wls[wl] = nil
			end
			if new_wl or pairs(wls) then
				-- Clean volatile state of wireless interfaces that are no longer controlled by this daemon
				config = "wireless"
				cursor:load(config)
				for _, wl in ipairs(setup["wifi-iface"]) do
					cursor:revert(config, wl, "state")
				end
				ubus_operations.reload_wireless = true
				ubus_operations.reload_network = true
				cursor:unload(config)

				-- reset interface
				setup["wifi-iface"] = newsetup["wifi-iface"]

				-- force a state update
				setup["state"] = nil
			end
		end

		-- Update hotspot setup derived from wifi interface
		setup["bridge"] = bridge
		setup["gre-bridge-port"] = greport
		setup["gre-iface"] = greiface
		setup["vlan-id"] = vlanid
	elseif not get_interface_cached_attribute(setup["bridge"], "up") then
		return { error = "Bridge interface '" .. setup["bridge"] .. "' is down" }
	end

	-- Update GRE related parameters
	if newsetup["gre-iface"] or newvlanid then
		local gretype, greiface, vlanid, vlandevice
		local section

		config = "network"
		cursor_persist:load(config)
		gretype, greiface, vlanid, vlandevice = get_gre_setup(cursor_persist, config, newsetup["gre-iface"] or setup["gre-bridge-port"])
		if newvlanid then
			vlanid = newvlanid
		end
		errstring = validate_gre_settings(name, greiface, vlanid, hotspots)
		if errstring then
			return { error = errstring }
		end
		if greiface ~= setup["gre-iface"] or vlanid ~= setup["vlan-id"] then
			-- Save new GRE settings persistently
			local greprefix, greport
			greprefix = get_gre_proto_intf_prefix(gretype)
			if vlanid == "0" then
				greport = greprefix .. greiface
			elseif vlandevice then
				greport = newsetup["gre-iface"]
				cursor_persist:set(config, newsetup["gre-iface"], "vid", vlanid)
			else
				greport = greprefix .. greiface .. "." .. vlanid
			end
			set_gre_port(cursor_persist, config, setup["bridge"], greport)

			ubus_operations.reload_network = true
			cursor_persist:commit(config)

			-- Change running setup
			setup["gre-bridge-port"] = greport
			setup["gre-iface"] = greiface
			setup["vlan-id"] = vlanid
		end
		cursor_persist:unload(config);
	end

	-- Update parameters other than GRE
	if newhotspot then
		-- Add if not already added
		-- Note: other parameters were already updated when newsetup was created
		hotspots[name] = setup
	else
		if newsetup["enable"] ~= nil then
			setup["enable"] = get_bool_option(newsetup["enable"], true)
		end
		if newsetup["monitor-iface"] ~= nil then
			setup["monitor-iface"] = ((type(newsetup["monitor-iface"]) == "string" and #newsetup["monitor-iface"] > 0)
				and newsetup["monitor-iface"] or false)
		end
		if newsetup["check-private-wifi"] ~= nil then
			setup["check-private-wifi"] = get_bool_option(newsetup["check-private-wifi"], true)
		end
		if newsetup["check-private-wifi-encryption"] ~= nil then
			setup["check-private-wifi-encryption"] = get_bool_option(newsetup["check-private-wifi-encryption"], true)
		end
		if newsetup["allow-ethwan-mode"] ~= nil then
			setup["allow-ethwan-mode"] = get_bool_option(newsetup["allow-ethwan-mode"], true)
		end
		if tonumber(newsetup["xdsl-rate-hysteresis"]) ~= nil then
			setup["xdsl-rate-hysteresis"] = math.floor(newsetup["xdsl-rate-hysteresis"])
		end
		if tonumber(newsetup["min-xdsl-downstream-rate"]) ~= nil then
			setup["min-xdsl-downstream-rate"] = math.floor(newsetup["min-xdsl-downstream-rate"])
		end
		if tonumber(newsetup["min-xdsl-upstream-rate"]) ~= nil then
			setup["min-xdsl-upstream-rate"] = math.floor(newsetup["min-xdsl-upstream-rate"])
		end
		if tonumber(newsetup["upstream-rate"]) ~= nil then
			setup["upstream-rate"] = math.floor(newsetup["upstream-rate"])
		end
		if tonumber(newsetup["upstream-percentage"]) ~= nil then
			setup["upstream-percentage"] = math.floor(newsetup["upstream-percentage"])
		end
	end

	-- Update hotspot UCI config
	config = "gre_hotspotd"
	cursor_persist:load(config)
	if newhotspot then
		cursor_persist:set(config, name, "hotspot")
	end
	cursor_persist:set(config, name, "wifi_iface", setup["wifi-iface"])
	cursor_persist:set(config, name, "enable", setup["enable"] and "1" or "0")
	if setup["monitor-iface"] then
		cursor_persist:set(config, name, "monitor_iface", setup["monitor-iface"])
	else
		cursor_persist:delete(config, name, "monitor_iface")
	end
	cursor_persist:set(config, name, "check_private_wifi", setup["check-private-wifi"] and "1" or "0")
	cursor_persist:set(config, name, "check_private_wifi_encryption", setup["check-private-wifi-encryption"] and "1" or "0")
	cursor_persist:set(config, name, "allow_ethwan_mode", setup["allow-ethwan-mode"] and "1" or "0")
	if setup["xdsl-rate-hysteresis"] then
		cursor_persist:set(config, name, "xdsl_rate_hysteresis", setup["xdsl-rate-hysteresis"])
	else
		cursor_persist:delete(config, name, "xdsl_rate_hysteresis")
	end
	if setup["min-xdsl-downstream-rate"] then
		cursor_persist:set(config, name, "min_xdsl_downstream_rate", setup["min-xdsl-downstream-rate"])
	else
		cursor_persist:delete(config, name, "min_xdsl_downstream_rate")
	end
	if setup["min-xdsl-upstream-rate"] then
		cursor_persist:set(config, name, "min_xdsl_upstream_rate", setup["min-xdsl-upstream-rate"])
	else
		cursor_persist:delete(config, name, "min_xdsl_upstream_rate")
	end
	if setup["upstream-rate"] then
		cursor_persist:set(config, name, "upstream_rate", setup["upstream-rate"])
	else
		cursor_persist:delete(config, name, "upstream_rate")
	end
	if setup["upstream-percentage"] then
		cursor_persist:set(config, name, "upstream_percentage", setup["upstream-percentage"])
	else
		cursor_persist:delete(config, name, "upstream_percentage")
	end
	cursor_persist:commit(config)
	cursor_persist:unload(config)

	-- Update hotspot status
	update_hotspots_state(true, ubus_operations)
	perform_ubus_operations(ubus_operations)

	return { [name] = setup }
end

-- Remove tunnel management info
local function delete_tunnel(name)
	local config
	local tunnel = tunnels[name]
	local ubus_operations = { }

	if not tunnel then
		return
	end

	-- Remove only management data from tunnels cache, network data might be used by hotspots
	local k
	for k in pairs(tunnel) do
		if k ~= "proto" and k ~= "tunlink" and k ~= "peeraddr" and k ~= "peer6addr" and k ~= "state" then
			tunnel[k] = nil
		end
	end

	-- Remove tunnel management data from gre-hotspotd UCI configuration
	config = "gre_hotspotd"
	cursor_persist:load(config)
	cursor_persist:delete(config, name)
	cursor_persist:commit(config)
	cursor_persist:unload(config)

	-- Update tunnel status
	update_tunnels_state(ubus_operations)
	perform_ubus_operations(ubus_operations)
end

-- Modify or add tunnel management info
local function set_tunnel(name, newtunnel)
	local config, section
	local tunnel = tunnels[name]
	local ubus_operations = { }

	-- Validate some input parameters
	if type(newtunnel["peers"]) == "string" then
		newtunnel["peers"] = { newtunnel["peers"] }
	end

	if not tunnel then
		local grename

		-- Add tunnel if not already in tunnels table
		config = "network"
		cursor_persist:load(config)
		_, greiface = get_gre_setup(cursor_persist, config, name)
		cursor_persist:unload(config)
		tunnel = tunnels[name]
		if greiface ~= name or not tunnel then
			return { error = "No such gre(v6)tap interface" }
		end
	end

	-- Update tunnel parameters and store the new settings
	config = "gre_hotspotd"
	cursor_persist:load(config)
	cursor_persist:set(config, name, "tunnel")
	if newtunnel["enable"] ~= nil then
		tunnel["enable"] = get_bool_option(newtunnel["enable"], false)
		cursor_persist:set(config, name, "enable", tunnel["enable"] and "1" or "0")
	end
	if newtunnel["peers"] then
		tunnel["peers"] = newtunnel["peers"]
		cursor_persist:set(config, name, "peers", tunnel["peers"])
	end
	if newtunnel["ping-peer"] ~= nil then
		tunnel["ping-peer"] = get_bool_option(newtunnel["ping-peer"], false)
		cursor_persist:set(config, name, "ping_peer", tunnel["ping-peer"] and "1" or "0")
	end
	if tonumber(newtunnel["ping-count"]) ~= nil then
		tunnel["ping-count"] = math.floor(newtunnel["ping-count"])
		cursor_persist:set(config, name, "ping_count", tunnel["ping-count"])
	end
	if tonumber(newtunnel["ping-retry-interval"]) ~= nil then
		tunnel["ping-retry-interval"] = math.floor(newtunnel["ping-retry-interval"])
		cursor_persist:set(config, name, "ping_retry_interval", tunnel["ping-retry-interval"])
	end
	if tonumber(newtunnel["ping-silent-peer-interval"]) ~= nil then
		tunnel["ping-silent-peer-interval"] = math.floor(newtunnel["ping-silent-peer-interval"])
		cursor_persist:set(config, name, "ping_silent_peer_interval", tunnel["ping-silent-peer-interval"])
	end
	if tonumber(newtunnel["xdsl-rate-hysteresis"]) ~= nil then
		tunnel["xdsl-rate-hysteresis"] = math.floor(newtunnel["xdsl-rate-hysteresis"])
		cursor_persist:set(config, name, "xdsl_rate_hysteresis", tunnel["xdsl-rate-hysteresis"])
	end
	if tonumber(newtunnel["min-xdsl-downstream-rate"]) ~= nil then
		tunnel["min-xdsl-downstream-rate"] = math.floor(newtunnel["min-xdsl-downstream-rate"])
		cursor_persist:set(config, name, "min_xdsl_downstream_rate", tunnel["min-xdsl-downstream-rate"])
	end
	if tonumber(newtunnel["min-xdsl-upstream-rate"]) ~= nil then
		tunnel["min-xdsl-upstream-rate"] = math.floor(newtunnel["min-xdsl-upstream-rate"])
		cursor_persist:set(config, name, "min_xdsl_upstream_rate", tunnel["min-xdsl-upstream-rate"])
	end
	if tonumber(newtunnel["upstream-rate"]) ~= nil then
		tunnel["upstream-rate"] = math.floor(newtunnel["upstream-rate"])
		cursor_persist:set(config, name, "upstream_rate", tunnel["upstream-rate"])
	end
	if tonumber(newtunnel["upstream-percentage"]) ~= nil then
		tunnel["upstream-percentage"] = math.floor(newtunnel["upstream-percentage"])
		cursor_persist:set(config, name, "upstream_percentage", tunnel["upstream-percentage"])
	end
	cursor_persist:commit(config)
	cursor_persist:unload(config)

	if tunnel["enable"] == nil then
		-- Managed tunnels must have an enable flag
		tunnel["enable"] = true
	end

	-- Update tunnel status
	tunnel["refresh-state"] = true
	update_tunnels_state(ubus_operations)
	perform_ubus_operations(ubus_operations)

	return { [name] = tunnel }
end

-- Callback function when 'gre-hotspotd config' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_config(req, msg)
	local newenable = msg["enable"]
	local response = {}

	if type(newenable) == "boolean" then
		local config, section, param = "gre_hotspotd", "global", "enable"

		log:info("Updating global configuration")

		cursor_persist:load(config)
		cursor_persist:set(config, section, param, newenable and "1" or "0")
		cursor_persist:commit(config)
		cursor_persist:unload(config)

		reload_configuration()
	end

	response["enable"] = global_enable

	ubus_conn:reply(req, response)
end

-- Callback function when 'gre-hotspotd reload' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_reload(req, msg)
	log:info("Reloading configuration")
	reload_configuration()
	ubus_conn:reply(req,{})
end

-- Callback function when 'gre-hotspotd get' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_get(req, msg)
	local name=msg["name"]
	local response = {}

	-- Filter on name
	if type(name) == "string" then
		response[name]=hotspots[name];
	else
		response = hotspots;
	end

	ubus_conn:reply(req, response);
end

-- Callback function when 'gre-hotspotd set' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_set(req, msg)
	local name = msg["name"]
	local response = { }

	if type(name) == "string" then
		response = set_hotspot(name, msg)
	end

	ubus_conn:reply(req,response)
end

-- Callback function when 'gre-hotspotd delete' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_delete(req, msg)
	local name = msg["name"]

	if type(name) == "string" then
		delete_hotspot(name)
	end
	ubus_conn:reply(req,{})
end

-- Callback function when 'gre-hotspotd tunget' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_tunget(req, msg)
	local name=msg["name"]
	local response = {}

	-- Filter on name
	if type(name) == "string" then
		response[name]=tunnels[name];
	else
		response = tunnels;
	end

	ubus_conn:reply(req, response);
end

-- Callback function when 'gre-hotspotd tunset' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_tunset(req, msg)
	local name = msg["name"]
	local response = { }

	if type(name) == "string" then
		response = set_tunnel(name, msg)
	end

	ubus_conn:reply(req,response)
end

-- Callback function when 'gre-hotspotd tundelete' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_tundelete(req, msg)
	local name = msg["name"]

	if type(name) == "string" then
		delete_tunnel(name)
	end
	ubus_conn:reply(req,{})
end

-- Callback function when 'gre-hotspotd cachedstate' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_cachedstate(req, msg)
	local response= { }

	response.interfaces_cache = all_interfaces
	response.started_l3_devices_cache = all_started_l3_devices
	response.upstream_rate_cache = configured_upstream_rates

	ubus_conn:reply(req,response)
end

-- Initialize private SSID cached state
local function init_private_ssid_state()
	private_ssid_state = false
	private_ssid_encrypted = false

	-- Get private SSID and its operational state
	local ssid = ubus_conn:call("wireless.ssid", "get", { ["name"] = private_ssid_name })
	if ssid then
		ssid = ssid[private_ssid_name]
	end
	if not ssid or ssid["oper_state"] ~= 1 then
		return
	end

	-- SSID operational state is up
	private_ssid_state = true

	-- Get private SSID access point
	local aps = ubus_conn:call("wireless.accesspoint", "get", { })
	local ap, k, v
	for k, v in pairs(aps) do
		if v["ssid"] == private_ssid_name then
			ap = k
			break
		end
	end
	if not ap then
		return
	end

	-- Get private SSID access point security
	local security = ubus_conn:call("wireless.accesspoint.security", "get", {  ["name"] = ap })
	if security then
		security = security[ap]
	end
	if not security or not security["mode"] or security["mode"] == "none" then
		return
	end

	-- Security mode is different than none
	private_ssid_encrypted = true
end

-- Handle private wireless SSID events on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_private_ssid_event(msg)
	if type(msg) == "table" and msg["name"] == private_ssid_name and
		 (private_ssid_state ~= (msg["oper_state"] == 1) or
			private_ssid_encrypted ~= (msg["security"] and msg["security"] ~= "none")) then

		private_ssid_state = (msg["oper_state"] == 1)
		private_ssid_encrypted = (msg["security"] and msg["security"] ~= "none")

		local ubus_operations = { }
		update_hotspots_state(true, ubus_operations)
		perform_ubus_operations(ubus_operations)
	end
end

-- Get the lowest interface possible beneath a certain device
local function get_lowest_interface(device)
	while device do
		local status = ubus_conn:call("network.device", "status", { ["name"] = device })
		if type(status) ~= "table" then
			break
		end

		if status["parent"] then
			device = status["parent"]
		elseif tostring(status["type"]):lower() == "vlan" then
			local pos = string.find(device, "[.]")
			if pos then
				device = string.sub(device, 1, pos - 1)
			end
			break
		else
			break
		end
	end
	return device
end

-- Initialize all interfaces cached state
local function init_all_interfaces_state()
	local dump = ubus_conn:call("network.interface", "dump", { })
	local interfaces, elem

	if dump then
		local xtmconfig = "xtm"
		cursor_persist:load(xtmconfig)

		for _,interfaces in pairs(dump) do
			for _, elem in pairs(interfaces) do
				if elem["interface"] then
					local up = elem["up"] and true or nil
					local l3_device = elem["l3_device"]
					local lowest_device = get_lowest_interface(elem["device"] or l3_device)
					local is_over_xdsl, has_ipv4, has_ipv6

					if lowest_device then
						local xtmdevice = cursor_persist:get(xtmconfig, lowest_device)
						if xtmdevice == "atmdevice" or xtmdevice == "ptmdevice" then
							is_over_xdsl = true
						end
					end

					if type(elem["ipv4-address"]) == "table" and elem["ipv4-address"][1] then
						has_ipv4 = true
					end
					if type(elem["ipv6-prefix"]) == "table" and elem["ipv6-prefix"][1] then
						has_ipv6 = true
					elseif type(elem["ipv6-address"]) == "table" then
						local x
						for _, x in ipairs(elem["ipv6-address"]) do
							-- Exclude link-local addresses
							if x["address"] and string.sub(x["address"], 1, 5) ~= "fe80:" then
								has_ipv6 = true
								break
							end
						end
					end

					-- DHCPv6 lower layer device is pointing to l3_device
					-- copy is_over_xdsl from IPv4 interface entry instead
					if l3_device and up then
						if not all_started_l3_devices[l3_device] then
							all_started_l3_devices[l3_device] = { }
						end
						if has_ipv4 then
							all_started_l3_devices[l3_device]["ipv4"] = elem["interface"]
						elseif all_started_l3_devices[l3_device]["ipv4"] then
							lowest_device = all_interfaces[all_started_l3_devices[l3_device]["ipv4"]]["lowest_device"]
							if not is_over_xdsl then
								is_over_xdsl = all_interfaces[all_started_l3_devices[l3_device]["ipv4"]]["is_over_xdsl"]
							end
						end
						if has_ipv6 then
							all_started_l3_devices[l3_device]["ipv6"] = elem["interface"]
						elseif has_ipv4 and all_started_l3_devices[l3_device]["ipv6"] then
							all_interfaces[all_started_l3_devices[l3_device]["ipv6"]]["lowest_device"] = lowest_device
							if is_over_xdsl then
								all_interfaces[all_started_l3_devices[l3_device]["ipv6"]]["is_over_xdsl"] = is_over_xdsl
							end
						end
					end

					all_interfaces[elem["interface"]] = {
						up = up,
						l3_device = l3_device,
						lowest_device = lowest_device,
						is_over_xdsl = is_over_xdsl,
						has_ipv4 = has_ipv4,
						has_ipv6 = has_ipv6,
					}
				end
			end
		end

		cursor_persist:unload(xtmconfig)
	end
end

-- Handle network ifup/ifdown events on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_network_interface_event(msg)
	if type(msg) == "table" and msg["interface"] then
		if msg["action"] == "ifup" then
			local status = ubus_conn:call("network.interface." .. msg["interface"], "status", { })
			if status then
				local l3_device = status["l3_device"]
				local lowest_device = get_lowest_interface(status["device"] or l3_device)
				local is_over_xdsl, has_ipv4, has_ipv6

				if lowest_device then
					local xtmconfig = "xtm"
					cursor_persist:load(xtmconfig)
					local xtmdevice = cursor_persist:get(xtmconfig, lowest_device)
					if xtmdevice == "atmdevice" or xtmdevice == "ptmdevice" then
						is_over_xdsl = true
					end
					cursor_persist:unload(xtmconfig)
				end

				if type(status["ipv4-address"]) == "table" and status["ipv4-address"][1] then
					has_ipv4 = true
				end
				if type(status["ipv6-prefix"]) == "table" and status["ipv6-prefix"][1] then
					has_ipv6 = true
				elseif type(status["ipv6-address"]) == "table" then
					local x
					for _, x in ipairs(status["ipv6-address"]) do
						-- Exclude link-local addresses
						if x["address"] and string.sub(x["address"], 1, 5) ~= "fe80:" then
							has_ipv6 = true
							break
						end
					end
				end

				-- DHCPv6 lower layer device is pointing to l3_device
				-- copy is_over_xdsl from IPv4 interface entry instead
				if l3_device then
					if not all_started_l3_devices[l3_device] then
						all_started_l3_devices[l3_device] = { }
					end
					if has_ipv4 then
						all_started_l3_devices[l3_device]["ipv4"] = msg["interface"]
					elseif all_started_l3_devices[l3_device]["ipv4"] then
						lowest_device = all_interfaces[all_started_l3_devices[l3_device]["ipv4"]]["lowest_device"]
						if not is_over_xdsl then
							is_over_xdsl = all_interfaces[all_started_l3_devices[l3_device]["ipv4"]]["is_over_xdsl"]
						end
					end
					if has_ipv6 then
						all_started_l3_devices[l3_device]["ipv6"] = msg["interface"]
					elseif has_ipv4 and all_started_l3_devices[l3_device]["ipv6"] then
						all_interfaces[all_started_l3_devices[l3_device]["ipv6"]]["lowest_device"] = lowest_device
						if is_over_xdsl then
							all_interfaces[all_started_l3_devices[l3_device]["ipv6"]]["is_over_xdsl"] = is_over_xdsl
						end
					end

					-- Update status of managed peer tunnels that use this interface as tunlink
					refresh_tunnels_using_tunlink(l3_device)
				end

				all_interfaces[msg["interface"]] = {
					up = true,
					l3_device = l3_device,
					lowest_device = lowest_device,
					is_over_xdsl = is_over_xdsl,
					has_ipv4 = has_ipv4,
					has_ipv6 = has_ipv6,
				}

				-- Update hotspots that were not fully configured due to bridge interface being down
				for name, setup in pairs(hotspots) do
					if setup["bridge"] == msg["interface"] then
						local config = "network"
						cursor_persist:load(config)
						setup["gre-bridge-port"] = get_gre_port(cursor_persist, config, setup["bridge"])
						if not setup["gre-bridge-port"] then
							log:error("hotspot " .. name .. ": Invalid bridge setup")
							hotspots[name] = nil
							cursor_persist:unload(config)
							break
						end

						_, setup["gre-iface"], setup["vlan-id"] = get_gre_setup(cursor_persist, config, setup["gre-bridge-port"])
						local errstring = validate_gre_settings(name, setup["gre-iface"], setup["vlan-id"], hotspots)
						if errstring then
							log:error("hotspot " .. name .. ": " .. errstring)
							hotspots[name] = nil
						end
						cursor_persist:unload(config)
						break
					end
				end
			end
		elseif msg["action"] == "ifdown" then
			local interface = all_interfaces[msg["interface"]]
			if interface then
				interface["up"] = nil
				local l3_device = interface["l3_device"]

				if l3_device and all_started_l3_devices[l3_device] then
					-- Update status of managed peer tunnels that use this interface as tunlink
					refresh_tunnels_using_tunlink(l3_device)

					local ipv4_intf, ipv6_intf = get_started_interfaces
					if interface["has_ipv4"] and msg["interface"] == all_started_l3_devices[l3_device]["ipv4"] then
						all_started_l3_devices[l3_device]["ipv4"] = find_started_interface(l3_device, "has_ipv4")
					end
					if interface["has_ipv6"] and msg["interface"] == all_started_l3_devices[l3_device]["ipv6"] then
						all_started_l3_devices[l3_device]["ipv6"] = find_started_interface(l3_device, "has_ipv6")
					end
				end
			end
		elseif type(msg["ipv4-address"]) == "table" and get_interface_cached_attribute(msg["interface"], "up") then
			-- IPv4 addresses are added to interface after ifup event
			local interface = all_interfaces[msg["interface"]]
			local has_ipv4 = (#msg["ipv4-address"] > 0)
		        if interface["has_ipv4"] == has_ipv4 then
				return -- already marked as having IPv4
			end
			interface["has_ipv4"] = has_ipv4

			local l3_device = interface["l3_device"]
			if l3_device then
				if has_ipv4 and all_started_l3_devices[l3_device]["ipv4"] ~= msg["interface"] then
					all_started_l3_devices[l3_device]["ipv4"] = msg["interface"]
					local ipv6_intf = all_started_l3_devices[l3_device]["ipv6"]
					if ipv6_intf then
						all_interfaces[ipv6_intf]["lowest_device"] = interface["lowest_device"]
						if interface["is_over_xdsl"] then
							all_interfaces[ipv6_intf]["is_over_xdsl"] = true
						end
					end

					-- Update status of managed peer tunnels that use this interface as tunlink
					refresh_tunnels_using_tunlink(l3_device)
				elseif not has_ipv4 and all_started_l3_devices[l3_device]["ipv4"] == msg["interface"] then
					-- Update status of managed peer tunnels that use this interface as tunlink
					refresh_tunnels_using_tunlink(l3_device)

					all_started_l3_devices[l3_device]["ipv4"] = find_started_interface(l3_device, "has_ipv4")
				end
			end
		else
			return
		end

		local ubus_operations = { }
		update_tunnels_state(ubus_operations)
		update_hotspots_state(false, ubus_operations)
		perform_ubus_operations(ubus_operations)
	end
end

local function errhandler(err)
	log:critical(err)
	for line in string.gmatch(debug.traceback(), "([^\n]*)\n") do
		log:critical(line)
	end
end

-- Main code
uloop.init();
ubus_conn = ubus.connect()
if not ubus_conn then
	log:error("Failed to connect to ubus")
end


-- Register RPC callback
ubus_conn:add( { ['gre-hotspotd'] = {	config = { handle_rpc_config, { ["enable"] = ubus.BOOLEAN } },
					reload = { handle_rpc_reload, { } },
					get = { handle_rpc_get, { ["name"] = ubus.STRING } },
					set = { handle_rpc_set, { ["name"] = ubus.STRING, ["wifi-iface"] = ubus.ARRAY, ["gre-iface"] = ubus.STRING,
									["vlan-id"] = ubus.STRING, ["enable"] = ubus.BOOLEAN, ["monitor-iface"] = ubus.STRING,
									["check-private-wifi"] = ubus.BOOLEAN, ["check-private-wifi-encryption"] = ubus.BOOLEAN,
									["allow-ethwan-mode"] = ubus.BOOLEAN, ["xdsl-rate-hysteresis"] = ubus.STRING,
									["min-xdsl-downstream-rate"] = ubus.STRING, ["min-xdsl-upstream-rate"] = ubus.STRING,
									["upstream-rate"] = ubus.STRING, ["upstream-percentage"] = ubus.STRING, } },
					delete = { handle_rpc_delete, { ["name"] = ubus.STRING } },
					tunget = { handle_rpc_tunget, { ["name"] = ubus.STRING } },
					tunset = { handle_rpc_tunset, { ["name"] = ubus.STRING, ["peers"] = ubus.ARRAY, ["ping-peer"] = ubus.BOOLEAN,
									["ping-count"] = ubus.STRING, ["ping-retry-interval"] = ubus.STRING, ["enable"] = ubus.BOOLEAN,
									["ping-silent-peer-interval"] = ubus.STRING, ["xdsl-rate-hysteresis"] = ubus.STRING,
									["min-xdsl-downstream-rate"] = ubus.STRING, ["min-xdsl-upstream-rate"] = ubus.STRING,
									["upstream-rate"] = ubus.STRING, ["upstream-percentage"] = ubus.STRING, } },
					tundelete = { handle_rpc_tundelete, { ["name"] = ubus.STRING } },
					cachedstate = { handle_rpc_cachedstate, { } }, } } );

-- Register event listener
ubus_conn:listen({ ["wireless.ssid"] = handle_private_ssid_event} );
ubus_conn:listen({ ["network.interface"] = handle_network_interface_event} );

-- Initialize cached state
init_private_ssid_state()
init_all_interfaces_state()

hotspots = get_configuration()
do
	local ubus_operations = { }
	update_tunnels_state(ubus_operations)
	update_hotspots_state(false, ubus_operations)
	perform_ubus_operations(ubus_operations)
end

log:info("Daemon started")

-- Idle loop
xpcall(uloop.run,errhandler)
