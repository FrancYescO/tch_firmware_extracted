--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2018-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo, globals config

local runpath = '/var/run/cujo'
cujo.filesys.mkdir(runpath)

local version = assert(cujo.filesys.readfrom('/proc/version', 'l'))

local prefix_ro = os.getenv'CUJO_HOME'
local cujo_version = assert(cujo.filesys.readfrom(prefix_ro .. '/build_info', 'l'))
local company_name = assert(io.popen("/sbin/uci get env.var.company_name")):read("*l")
local prod_number = assert(io.popen("/sbin/uci get env.var.prod_number")):read("*l")
local wan_ifaces = assert(io.popen("/sbin/uci get rabid.config.wan_ifaces")):read("*l")
local lan_ifaces = assert(io.popen("/sbin/uci get rabid.config.lan_ifaces")):read("*l")
local ssdpbindport = assert(io.popen("/sbin/uci get rabid.config.ssdpbindport")):read("*l")

local function splitspaces(s)
       local words = {}
       for word in s:gmatch('%S+') do
               table.insert(words, word)
       end
       return words
end

config.conntrack = '/usr/sbin/conntrack'
config.ipset = os.getenv'CUJO_IPSET_PATH' or '/usr/sbin/ipset'
config.ip = '/sbin/ip'
config.tls = {
    protocol = 'tlsv1_2',
    verify = 'peer',
    cafile = prefix_ro .. '/etc/tls-cujo-cloud.pem',
}
config.hardware_revision = company_name .. "-" .. prod_number
config.build_version = cujo_version:match'build_version="(.+)"'
config.build_number = 0
config.build_time = 0
config.build_kernel = string.match(version, "%D+(%S+).+")
config.build_arch = assert(io.popen("uname -m")):read("*l")
config.wan_ifaces = splitspaces(wan_ifaces)
config.lan_ifaces = splitspaces(lan_ifaces)
config.rabidctl.sockpath = runpath .. '/rabidctl.sock'
config.wan_ipv6addr = cujo.snoopy.getdevaddripv6(config.lan_ifaces)
config.nets = {
    ip4 = {iptables = os.getenv'CUJO_IPTABLES_PATH' or '/usr/sbin/iptables'},
    ip6 = {iptables = os.getenv'CUJO_IP6TABLES_PATH' or '/usr/sbin/ip6tables'},
}
config.privileges = nil
config.ssdpbindport = tonumber(ssdpbindport) or 0

config.cloud_iface_required = false

local paac_key_path = prefix_ro .. '/etc/technicolor-fe-paac-emea.pem'

config.cloudurl = {
    authentication = 'secret',
    route = 'https://routing.cujo-emea.hosted.cujo.io/environment/redirect/',
    certificate = config.get_certificate(paac_key_path),
}
