#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2013 Technicolor                                           **
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
local proxy = require("datamodel")
local match = string.match
local logger = require 'transformer.logger'
logger.init(6, false)
local log = logger.new("wan_iptv", 6)


local LAN_IF = "lan"
local WAN_IPTV_IF = "wan_iptv"
local WAN_IPTV_ETH_IF = "eth4_iptv"
local WAN_IPTV_ROUTE_TABLE = "iptv"

local lan_ip

-- IPTV host list
local active_iptv_host_list = {};

-- all IPTV vendor ID list
local iptv_vendor_id_list = {"Motorola_VIP", "CH_IPTV", "ComHem_VIP"};


local function get_if_addr(interface)
        local x
        x=ubus_conn:call("network.interface."..interface, "status", {})
        if x and x["ipv4-address"] and x["ipv4-address"][1]
          and x["ipv4-address"][1]["address"] and type(x["ipv4-address"][1]["address"])=="string"
          and match(x["ipv4-address"][1]["address"], "%d+\.%d+\.%d+\.%d+") then
                return x["ipv4-address"][1]["address"]
        else
                return nil
        end
end

local function get_wan_iptv_addr()
        return get_if_addr(WAN_IPTV_IF)
end



local function find_iptv_in_active_list(ip_addr)
        local index, tmp

        -- find this host in the active IPTV list
        for index, tmp in ipairs(active_iptv_host_list) do
                if ip_addr == tmp then
                        return index
                end
        end

        return nil
end


local function add_iptv_to_active_list(ip_addr)

        if find_iptv_in_active_list(ip_addr) then
                return
        end

        table.insert(active_iptv_host_list, ip_addr)
end



local function rm_iptv_from_active_list(ip_addr)
        local pos

        pos = find_iptv_in_active_list(ip_addr)

        if pos then
                table.remove(active_iptv_host_list, pos)
        end
end


local function add_stb_ip_rule(ip_addr)
	local cmd = "[ -z \"$(ip rule list | grep 'from "..ip_addr.." lookup "..WAN_IPTV_ROUTE_TABLE.."')\" ] && ip rule add from ".. ip_addr .." table ".. WAN_IPTV_ROUTE_TABLE

	os.execute(cmd)
	log:info("IP rule added for IPTV "..ip_addr)
end


local function rm_stb_ip_rule(ip_addr)
        local cmd = "[ -n \"$(ip rule list | grep 'from "..ip_addr.." lookup "..WAN_IPTV_ROUTE_TABLE.."')\" ] && ip rule del from ".. ip_addr .." table ".. WAN_IPTV_ROUTE_TABLE

        os.execute(cmd)
	log:info("IP rule removed for IPTV "..ip_addr)
end


local function handle_add_iptv_host(ip_addr)
        local iptv_wan_ip

        log:info("IPTV host ("..ip_addr..") is added")

        add_iptv_to_active_list(ip_addr)

	add_stb_ip_rule(ip_addr)

        iptv_wan_ip=get_wan_iptv_addr()
        if not iptv_wan_ip then
        -- try to trigger the wan_iptv interface
       		os.execute("ip rule add fwmark 0x10000000\/0xf0000000 table iptv")
                os.execute("ifup "..WAN_IPTV_IF.." &")
        end

        lan_ip = get_if_addr(LAN_IF)
        log:info("add local host "..lan_ip.." for iptv route table")
        os.execute("ip route add local "..lan_ip.." dev br-lan proto kernel scope host src "..lan_ip.." table iptv")
end


local function handle_del_iptv_host(ip_addr)
        local iptv_wan_ip

        log:info("IPTV host ("..ip_addr..") is deleted")

        rm_iptv_from_active_list(ip_addr)

	rm_stb_ip_rule(ip_addr)
	
        log:info("delete local host "..lan_ip.." from iptv route table")
        os.execute("ip route delete local "..lan_ip.." table iptv")
end


local function is_iptv_dev(vendor_id)
         -- find out if it's a IPTV device
        for _, tmp in ipairs(iptv_vendor_id_list) do
                if string.find(tostring(vendor_id), tmp) ~= nil then
                        return true
                end
        end

        return false
end




local function handle_add_host(vendor_id, ip_addr)

        if is_iptv_dev(vendor_id) then
                handle_add_iptv_host(ip_addr)
        end

end


local function handle_del_host(ip_addr)
        local pos

        pos = find_iptv_in_active_list(ip_addr)
        if pos then
        -- this deleted host is an IPTV
                handle_del_iptv_host(ip_addr)
        end
end


-- Handles an neighbour update event on UBUS
-- msg like this: { "network.neigh": {"mac-address":"9c:97:26:98:98:e4","hostname":"wan_iptv","ipv4-address":{"address":"192.168.0.240"},"interface":"br-lan","action":"add","dhcp":{"time-remaining":43200,"lease-expires":57868,"domain":"lan","vendor-class":"iptv","tags":"lan br-lan"}} }
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_host_update(msg)
        if (msg['action'] == nil or (msg['action']~="add" and msg['action']~="delete")) then
                return
        end

        if not (msg["interface"] and type(msg["interface"])=="string" and msg["interface"]=="br-lan") then
                return
        end


        if ( not (msg['ipv4-address'] and (type(msg['ipv4-address'])=="table") and msg['ipv4-address'].address
            and type(msg['ipv4-address'].address)=="string"
            and match(msg['ipv4-address'].address, "%d+\.%d+\.%d+\.%d+")))   then
                return
        end

        if (msg['action']=="add" and msg['dhcp'] and msg['dhcp']['vendor-class'] and type(msg['dhcp']['vendor-class']) == "string") then
                handle_add_host(msg['dhcp']['vendor-class'], msg['ipv4-address'].address)
        elseif (msg['action']== "delete") then
                handle_del_host(msg['ipv4-address'].address)
        end

end




local function wan_iptv_init()

end




-- Main code
uloop.init();
ubus_conn = ubus.connect()
if not ubus_conn then
        log:error("Failed to connect to ubus")
end

wan_iptv_init()


-- Register event listener
ubus_conn:listen({ ['network.neigh'] = handle_host_update} );


log:info("WAN_IPTV started")

-- Idle loop
xpcall(uloop.run,errhandler)


