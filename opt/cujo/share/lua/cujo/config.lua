--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo, globals cujo.config

local log = require 'cujo.log'
local net = require 'cujo.net'

local ippattern = {
    ipv4 = 'inet (%d+%.%d+%.%d+%.%d)/(%d+)',
    ipv6 = 'inet6 ([%x:]+)/(%d+) scope global',
}
local config = {
    -- Customizable hook for parameters.lua, called after loading all code
    -- but before connecting to the cloud.
    startup = function () end,

    -- Helper for getting the IP(v4/v6) address on a given interface,
    -- defaults to using the ip binary defined in config.ip.
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

    -- Cloud reconnect backoff for agent-service (not used e.g. for
    -- routing-service or urlchecker).
    backoff = {
        initial = 5,
        factor = 6,
        range = 0.5,
        max = 15 * 60,
    },

    -- TLS configuration, forwarded as-is as "client parameters" to luasec
    -- when creating TLS connections.
    tls = {
        protocol = nil,
        verify = nil,
        cafile = nil,
    },

    -- Number of messages that can be queued to be sent to the
    -- agent-service. If this limit is reached, further messages will be
    -- dropped.
    maxcloudmessages = 30,

    -- Number of coroutines handling urlchecker lookups. Effectively also
    -- the number of simultaneous connections kept open to the urlchecker.
    lookupjobs = 4,

    -- Timeout in seconds for urlchecker lookups.
    urlcheckertimeout = 3,

    rabidctl = {
        -- Timeout in seconds for Rabid receiving a command from
        -- rabidsh. Infinite if unset.
        timeout = nil,

        -- Path to the UNIX domain socket used for rabidsh
        -- communication.
        sockpath = nil,
    },

    job = {
        -- Maximum number of seconds any external processes are allowed
        -- to run for, and the frequency at which process status is
        -- checked. A zero pollingtime effectively makes it a busy loop
        -- (while allowing other coroutines to run).
        timeout = 5,
        pollingtime = 0.001,
    },

    warmcache = {
        -- Default TTL for the safebro warmcache, in seconds. Can be
        -- overridden by the cloud.
        ttl = 60 * 60 * 24,

        -- Fixed delay between warmcache download attempts in case of
        -- failure, in seconds.
        retryinterval = 60 * 5,
    },

    cloudurl = {
        -- The routing-service /environment/redirect endpoints to
        -- connect to.
        route = nil,

        -- A fallback routing-service endpoint. See also
        -- config.cloud.route_callback.
        default_route = nil,

        -- Defines the authentication mode used with the agent-service.
        -- See the "auth" mapping in cloud/auth.lua for the available
        -- alternatives.
        authentication = nil,

        -- String containing a certificate in UNKNOWN format (TBD from
        -- agent-service specification), used as a client certificate
        -- when the authentication mode is set to "secret".
        certificate = nil,
    },

    -- If true, error out if config.cloud_iface is unset.
    --
    -- config.cloud_iface is the name of the network interface used to
    -- communicate to all cloud endpoints.
    cloud_iface_required = true,

    -- The minimum receive and send buffer sizes (as seen from the userspace
    -- point of view) of the netlink socket used to communicate with the
    -- kernel agent.
    --
    -- We don't expect to need this much, but leave some extra space in case
    -- the CPU is being overwhelmed and either side has trouble keeping up.
    nf_recv_buf_size = 1024 * 1024,
    nf_send_buf_size = 1024 * 1024,

    -- config.nf as a whole is called just "config" on the kernel side.
    nf = {
        -- Netlink socket family (see netlink(7)) and port number. The
        -- family must match the value compiled into NFLua.
        netlink = {port = 1337, family = 24},

        -- Configuration for various LRUs (see nf/lru.lua). These LRUs
        -- all live in the kernel.
        -- * appblock: For both sets used in appblock.
        -- * conn: For the connections that are processed by safebro.
        --         Note that the TTL is not configurable and always nil.
        -- * http: For the safebro-blocked hosts that can be unblocked
        --         by the user.
        -- * threat.cache: For the per-domain urlchecker responses. Should be
        --                 big enough to hold at least the warmcache (typically
        --                 5000 entries, but may vary by cloud environment).
        --                 Note that the TTL is not configurable here, it is
        --                 specified by the cloud.
        -- * threat.pending: For the domains currently undergoing
        --                   urlchecker lookups.
        -- * threat.whitelist: For the safebro-blocked hosts that have
        --                     been unblocked by the user. Note that
        --                     domains are treated separately per user
        --                     (MAC address), but this one limit applies
        --                     globally.
        appblocker = {maxentries = 1024},
        conn = {maxentries = 512},
        http = {maxentries = 1024, ttl = 2 * 60},
        threat = {
            cache = {maxentries = 6000},
            pending = {maxentries = 128, ttl = 60},
            whitelist = {maxentries = 1024, ttl = 60 * 60},
        },

        tcptracker = {
            -- Maximum number of TCP connections whose SYN packets
            -- are tracked in detail in the kernel, as part of the
            -- synlistener module used in both the tcptracker and
            -- apptracker features.
            maxentries = 200,

            -- Interval between sends of SYN traffic information to
            -- userspace, in seconds.
            pollinterval = 5,
        },
        apptracker = {
            -- Maximum number of connections (TCP or UDP) that can
            -- be pending for application data in the kernel at any
            -- given time, as part of the apptracker feature.
            maxentries = 3000,

            -- The maximum number of messages about such connections
            -- that can be sent at any given time. We need to avoid
            -- overflowing the 64k buffer size on the netlink
            -- socket. Currently one message for an IPv6 connection
            -- containing Chromium's user agent tends to be around
            -- 200 bytes in size. We are conservative and assume we
            -- see an average message size of twice that, and leave
            -- some headroom on top.
            max_entries_send = 150,

            -- Interval between sends of application data to
            -- userspace, in seconds.
            timeout = 5,

            -- Callback function, called whenever a new mac is added
            -- or removed to the list of tracked macs. The callback
            -- is passed a table, indexed by mac address, contains
            -- the number of conntrack read loops that that mac
            -- has been active for.
            activemac_callback = nil,
        },
        trackerblock = {maxentries = 512},
    },

    -- Parameters related to apptracker. The logic is relatively
    -- complicated, see cujo/apptracker.lua for details.
    apptracker = {
        -- Interval between conntrack polling iterations.
        timeout = 5,

        -- LRU sizes for the "pending" and "tracked" flows, the MAC
        -- cache, and the DNS cache, respectively.
        maxpending = 2000,
        maxflows = 6000,
        maccachesize = 20,
        dnscachesize = 6000,

        -- The maximum number of appdata flows that can be sent in one
        -- message to agent-service.
        msgflows = 200,

        -- Controls rate limiting of the conntrack reading. After
        -- reading (approximately) "linespersecond * interval" conntrack
        -- entries, the reading coroutine is throttled to achieve an
        -- approximate rate of "linespersecond".
        linespersecond = 10000,
        interval = 1,

        -- The minimum receive buffer size of the netlink socket used to
        -- read conntrack data. If ENOBUFS ("no buffer space available")
        -- errors are reported by libmnl, this needs increasing.
        --
        -- conntrack tables can get large, so reserve a lot of space.
        -- 1.5 MiB should be enough for an approximately 4000-entry
        -- table plus 1000 destroy events.
        conntrack_recv_buf_size = 1536 * 1024,

        -- A function that returns packet and byte counters for
        -- augmenting tracked connections, required on devices that have
        -- a network accelerator that causes conntrack to not see all
        -- the data.
        get_fastpath_bytes = nil
    },

    -- iptables configuration: The packet matching table in which all chains
    -- are created, and the prefix used for all chain names.
    chain_table = 'filter',
    chain_prefix = 'CUJO_',

    -- The prefix used for all ipset names.
    set_prefix = 'cujo_',

    -- Lists of all LAN and WAN interface names. Must be set to non-empty
    -- list values or functionality will be limited to practically nothing.
    lan_ifaces = nil,
    wan_ifaces = nil,

    nets = {
        -- If one of these is set to non-nil, the value must have an
        -- "iptables" member that is used as an iptables command to
        -- create firewall rules for that network.
        ip4 = nil,
        ip6 = nil,
    },

    -- Additional flags to always use with iptables binaries
    extra_iptables_flags = "-w -W 50000",

    -- If set to true, ipsets and iptables rules are not created, and are
    -- instead expected to be put in place by an external process.
    external_nf_rules = os.getenv("CUJO_EXT_NF_RULES") and true or false,

    safebro = {
        -- If a urlchecker lookup takes longer than lookup_threshold
        -- milliseconds, lookup_timeout_callback is called.
        lookup_threshold = 350.0,
        lookup_timeout_callback = function(time_taken, url)
            cujo.log:warn("url checker slow ", time_taken, " ms for '", url:sub(0, 5), "...'")
        end,

        -- Called whenever a new safebro configuration is received from
        -- the cloud, after it has been fully taken into use.
        config_change_callback = function(enable, settings)
            cujo.log:safebro('safebro settings updated ', settings)
        end,
    },
    trackerblock = {
        -- The frequency at which tracker blocking statistics are sent
        -- to the cloud, in seconds.
        report_period = 300,

        report_max_entries = 200
    },
    cloud = {
        -- A default callback assigned to cujo.cloud.ongetroute. Can be
        -- set to nil if undesired.
        route_callback = function(got, custom, route)
            if not got then return end
            if custom then
                cujo.log:config('custom cloud endpoint used '.. route)
            else
                cujo.log:config('default cloud endpoint used '.. route)
            end
        end,
    },
    -- config.privileges defines whether Rabid runs as the root user and group or
    -- not, and how it is able to perform privileged operations when it is not root.
    --
    -- * "user" and "group" define the names of the user and group to run as.
    --
    -- * "capabilities" determines the capability mode, which can be either
    --   "process", "ambient" or "sudo".
    --
    --   * If set to "process", the Rabid process just sets its own process
    --     capabilities. This means that when a non-root Rabid process executes an
    --     external process like iptables, that process will run as non-root but
    --     without the capabilities which normally would mean that they fail. An
    --     external mechanism, such as setting the set-user-ID bit on the iptables
    --     executable, is required for such external processes to work.
    --
    --   * If set to "ambient", the Rabid process also sets its ambient
    --     capabilities, allowing subprocesses to inherit the capabilities and thus
    --     Rabid to execute privileged executables like iptables while not being
    --     root. Note that this is supported only since Linux 4.3.
    --
    --   * If set to "sudo", follows the same set of method as "process", however all
    --     exeternal commands are prefixed with "sudo". This method can be used as a
    --     way to run rabid as non root for kernels without ambient capabilities and where
    --     the set-user-ID bit is not possible to set.
	privileges = nil
}

-- config.connkill is a function used to kill connections that are active at the
-- time when appblocking / iotblocking is triggered for a certain device.
local ipver = {ip4 = 'ipv4', ip6 = 'ipv6'}
function config.connkill(ipv, sip, dip, proto, port)
    local t = {'-D'}
    if ipv then cujo.util.append(t, '-f', ipver[ipv]) end
    if sip then cujo.util.append(t, '-s', sip) end
    if dip then cujo.util.append(t, '-d', dip) end
    if proto then
        cujo.util.append(t, '--proto', proto)
        if port then cujo.util.append(t, '--dport', port) end
    end
    cujo.jobs.exec(cujo.config.conntrack, t)
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

-- get content of certificate file into form suitable for use with cloud API
function config.get_certificate(cert_file_path)

    if not cert_file_path then
        return nil
    end

    local certificate = ''
    for l in io.lines(cert_file_path) do
        if string.find(l, 'CERTIFICATE-----') == nil then
        certificate = certificate .. l
        end
    end

    return certificate
end

-- config.runtime_settings is used for custom platform-specific settings
-- selectable by an environment variable.
local runtime_settings_str = os.getenv('CUJO_RUNTIME_SETTINGS')
runtime_settings_str = runtime_settings_str and runtime_settings_str or ""
config.runtime_settings = parse_runtime_settings_str(runtime_settings_str)


-- load parameters.lua

do
    local mod = 'cujo.config.parameters'
    local path = assert(package.searchpath(mod, package.path))
    -- parameters.lua and code it calls may expect cujo.config to exist
    -- already at this point.
    cujo.config = config
    local env = setmetatable({config = config}, {__index = _G})
    assert(loadfile(path, 'bt', env))()
    cujo.config = nil
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
        log:warn('invalid ', env, '="', ifaces_str,
             '", expected whitespace-separated values')
        return nil
    end
    return ifaces
end
local wan_ifaces = load_ifaces('CUJO_WAN_IFACES')
local lan_ifaces = load_ifaces('CUJO_LAN_IFACES')
local cloud_ifaces = load_ifaces('CUJO_CLOUD_IFACE')
if wan_ifaces ~= nil then config.wan_ifaces = wan_ifaces end
if lan_ifaces ~= nil then config.lan_ifaces = lan_ifaces end
if cloud_ifaces ~= nil then
    if #cloud_ifaces > 1 then
        log:error('too many values in CUJO_CLOUD_IFACE, using only the first one')
    end
    config.cloud_iface = cloud_ifaces[1]
end

local netcfg = net.newcfg()

-- config.gateway_ip and config.gateway_mac are the LAN-side IP and MAC
-- addresses of the device. They default to being determined from the first
-- element in lan_ifaces.
if config.gateway_ip == nil then
    local iface = assert(config.lan_ifaces[1])
    config.gateway_ip = assert(netcfg:getdevaddr(iface))
    config.gateway_mac = assert(netcfg:getdevhwaddr(iface))
end

-- config.serial is the string used to identify this device to the cloud (the
-- "serial number"). It defaults to being based on config.gateway_mac.
if config.serial == nil then
    config.serial = string.gsub(config.gateway_mac, ':', ''):lower()
end

log:config('identity serial number is ', assert(config.serial))
log:config('default gateway is ', config.gateway_ip, ' (MAC=', config.gateway_mac, ')')

-- Source address used when communicating with all cloud endpoints. Note that
-- the agent-service connection uses only config.cloud_iface, but not this.
function config.cloudsrcaddr()
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
        error("Network is unreachable over " .. cujo.config.cloud_iface)
    end
    return ifaceaddr
end


return config
