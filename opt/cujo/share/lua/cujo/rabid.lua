--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: globals cujo
cujo = {
    log = require 'cujo.log',
    filesys = require 'cujo.filesys',
    net = require 'cujo.net',
    snoopy = require 'cujo.snoopy',
}

cujo.config = require 'cujo.config'

-- set the privileges
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
            or cujo.config.privileges.capabilities == "ambient"
            or cujo.config.privileges.capabilities == "sudo", "illegal capability mode")
        local requiredcaps = { "net_admin", "net_raw", "net_bind_service" }
        assert(permission.setupcaps(table.unpack(requiredcaps)))
        if cujo.config.privileges.capabilities == "ambient" then
            for _, capname in ipairs(requiredcaps) do
                assert(permission.setambientcap(capname))
            end
        end
    end
end



for name, mod in pairs({
    appblocker = require 'cujo.appblocker',
    apptracker = require 'cujo.apptracker',
    cloud = require 'cujo.cloud.conn',
    filesys = require 'cujo.filesys',
    fingerprint = require 'cujo.fingerprint',
    hibernate = require 'cujo.hibernate',
    https = require 'cujo.https',
    iotblocker = require 'cujo.iotblocker',
    ipset = require 'cujo.ipset',
    jobs = require 'cujo.jobs',
    nf = require 'cujo.nf',
    nfrules = require 'cujo.nfrules',
    safebro = require 'cujo.safebro',
    shellserver = require 'cujo.shell.server',
    snoopy = require 'cujo.snoopy',
    snoopyjobs = require 'cujo.snoopyjobs',
    ssdp = require 'cujo.ssdp',
    tcptracker = require 'cujo.tcptracker',
    util = require 'cujo.util',
}) do
    cujo[name] = mod
end

cujo.safebro.trackerblock = require 'cujo.trackerblock'

return function()
    cujo.nf.initialize(function()
        cujo.ssdp.initialize()
        cujo.iotblocker.initialize()
        cujo.appblocker.initialize()
        cujo.safebro.initialize()
        cujo.apptracker.initialize()
        cujo.fingerprint.initialize()
        cujo.cloud.initialize()
        cujo.safebro.trackerblock.initialize()
        cujo.shellserver.initialize()
        cujo.snoopyjobs.initialize()

        cujo.config.startup()
        cujo.cloud.connect()
    end)
end
