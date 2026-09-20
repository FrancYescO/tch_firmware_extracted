--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

-- This module just sets up the netfilter rules for capturing fingerprinting
-- traffic, i.e.:
--
-- * Received DHCP traffic
-- * Received DHCPv6 traffic
-- * Received DNS traffic
-- * Received TCP SYN packets
-- * Received HTTP packets with the TCP PSH flag set
--
-- And provides publishers for other modules to integrate with.

local shims = require "cujo.shims"
local util = require "cujo.util"

local set

local module = {
    enable = util.createenabler('fingerprint', function (self, enable, callback)
        if enable then
            cujo.fingerprint.mdns_mcast_listen(self)
        else
            cujo.log:info('fingerprint cleanup')
            for lan_index in pairs(cujo.config.lan_ifaces) do
                if cujo.config.nets.ip4 ~= nil then
                    self.mdns_ipv4_socket[lan_index]:close()
                end
                if cujo.config.nets.ip6 ~= nil then
                    self.mdns_ipv6_socket[lan_index]:close()
                end
            end
        end

        if enable then
            cujo.nfrules.set('fingerprint', function()
                cujo.nfrules.check('fingerprint', callback)
            end)
        else
            cujo.nfrules.clear('fingerprint', function()
                cujo.nfrules.check_absent('fingerprint', callback)
            end)
        end
    end),
}

function module.setbypass(mac, add) set:set(add, mac) end
function module.flush() set:flush() end
function module.mdns_mcast_listen(self)
    self.mdns_ipv4_socket = {}
    self.mdns_ipv6_socket = {}

    for lan_index, lan_interface in ipairs(cujo.config.lan_ifaces) do
        if cujo.config.nets.ip4 ~= nil then
            self.mdns_ipv4_socket[lan_index] = shims.socket_create_udp("ip4")

            -- We need to listen socket to get packet into INPUT chain, port doesn't need to be 5353
            local res, err = shims.socket_setsockname(self.mdns_ipv4_socket[lan_index], '224.0.0.251', 0)
            if res == nil then
                cujo.log:error('MDNS ipv4 setsockname fails: ', err)
            else
                local interface = cujo.config.getdevaddr(lan_interface, 'ipv4')

                res, err = shims.socket_add_membership(
                    self.mdns_ipv4_socket[lan_index], '224.0.0.251', interface)
                if res == nil then
                    cujo.log:error('MDNS ipv4 setoption fails: ', err)
                else
                    cujo.log:debug('MDNS ipv4 listening on ', lan_interface)
                end
            end
        end

        if cujo.config.nets.ip6 ~= nil then
            self.mdns_ipv6_socket[lan_index] = shims.socket_create_udp("ip6")

            local netcfg = cujo.net.newcfg()
            local devindex = netcfg:getdevindex(lan_interface)
            cujo.log:info('MDNS ipv6 interface index: ', devindex)

            local res, err = shims.socket_add_membership6(
                self.mdns_ipv6_socket[lan_index], 'ff02::fb', devindex)
            if res == nil then
                cujo.log:error('MDNS ipv6 setoption fails: ', err)
            else
                cujo.log:debug('MDNS ipv6 listening on ', lan_interface)
            end
        end
    end
end

for _, pub in ipairs{'dhcp', 'dns', 'mdns', 'http', 'tcp'} do
    module[pub] = util.createpublisher()
end

function module.initialize()
    set = cujo.ipset.new{name = 'fingerprint', type = 'mac'}

    for _, pub in ipairs{'dhcp', 'dns', 'mdns', 'http', 'tcp'} do
        cujo.nf.subscribe(pub, module[pub])
    end
end

return module
