--[[
Remote Assistance
=================

This modudle defines an Assistant type that keeps track of the state of
remote assistance for a session manager.
It attaches itself to the configured session manager.
When enabled it generate a random password for the configured user and then
updates the SRP salt and hash of this user in the session  manager.
Then the state is written to a file and then the datamodel is updated,
triggering a commit and apply rule to update the firewall.

Session manager code was modified to trigger activity timer resets.
--]]
-- just make sure tainting is set up properly
require 'web.web'

local require, ipairs, setmetatable, type = require, ipairs, setmetatable, type
local format = string.format
local untaint = string.untaint
local match = string.match
local random = math.random
local randomseed = math.randomseed
local exec = os.execute
local concat = table.concat

local ngx = ngx
local dm = require 'datamodel'
local srp = require 'srp'
local control = require 'web.sessioncontrol'
local posix = require("tch.posix")
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC

-- The state of the remote assistance must be written to a file as it is
-- needed by the commit/apply script that will update the firewall with the
-- correct rules.
-- We must be able to read the state back here as the commit/apply script
-- relies on the fact that the IP and port numbers are still present in the
-- file when the assistance gets disabled.
local stateFile = "/var/run/assistance/%s"
local function loadState(name)
    local state = {
        wanip="";
        wanport="";
        lanport="";
        enabled="0";
        password="";
        mode="0";
    }
    local f = io.open(stateFile:format(name), 'r')
    if f then
        for ln in f:lines() do
            local key, value = ln:match('^%s*([^=%s]*)%s*=%s*([^%s]*)')
            if key then
                state[key] = value
            end
        end
        f:close()
    end
    return state
end

local function writeState(name, state, stateOnly)
    local f = io.open(stateFile:format(name), 'w')
    if f then
        for key, value in pairs(state) do
            f:write(string.format("%s=%s\n", key, value))
        end
        f:close()
        if not stateOnly then
            local uci = string.format("uci.web.assistance.@%s.active", name)
            dm.set(uci, state.enabled or "trigger")
            dm.apply()
        end
    end
end

--- Get the IP address of the named interface
-- \param ifname (string) the interface (wan, lan, ...)
-- \returns the ip address string or nil if not found
local function getInterfaceIP(ifname)
    local info = dm.get(string.format('rpc.network.interface.@%s.ipaddr', ifname))
    if info and info[1] and (info[1].param=='ipaddr') then
        return info[1].value
    end
end

local function genpsw(size, pswchars)
    local psw = {}
    for i=1,size do
        local idx = random(#pswchars)
        psw[#psw+1] = pswchars:sub(idx, idx)
    end
    return concat(psw, '')
end


local Assistant = {}
Assistant.__index = Assistant

--- Check if assistent is enabled
-- \returns true if enabled, false otherwise
function Assistant:enabled()
    return self._psw~=nil
end

--- Get the username for the assistant to use
-- only relevant if the assistant is enabled
function Assistant:username()
    return self._user
end

--- Get the port number
function Assistant:port()
    return self._port or ''
end

--- Get the password for the assistant to use
-- This is only relevant if the assistent is enabled
-- There is no need to show password when random password is not enabled
function Assistant:password()
    return self._pswcfg==nil and self._psw or ''
end

--- Get the mode for the assistant to use
--- true: permanent mode
--- false: temporary mode
function Assistant:isPermanentMode()
    return self._permanent
end

--- check if the random password is used for the assistant
--- return true if random password is enabled otherwise false
function Assistant:isRandomPassword()
    return self._pswcfg==nil
end

-- check if there is any change for _mode and _pswcfg
function Assistant:_checkupdate(bPermanent, password)
    if type(self._pswcfg) == "table" and type(password)=="table"
       and (self._pswcfg["salt"]~=password["salt"] or self._pswcfg["verifier"]~=password["verifier"]) then
         return true
    elseif (type(password)=="string" or type(password)=="table" or password== nil)
           and self._pswcfg~=password then
         return true
    else
         return self._permanent~=(bPermanent or false)
    end
end

--- update assistant cfg
-- \param bPermanent (bool) if true permanent mode else temporary mode
-- \param password:
--    if nil, random password is enabled
--    if string, clear text password is given by user
--    if table, srp salt/verifier is given by user
--    otherwise, previous password cfg will be used
function Assistant:_updatecfg(bPermanent, password)
    self._permanent=(bPermanent or false)
    if type(password)=="table" then
         self._pswcfg = {}
         self._pswcfg["salt"] = password["salt"]
         self._pswcfg["verifier"] = password["verifier"]
    elseif  password==nil or type(password)=="string" then
         self._pswcfg =password
    end

    -- update state file so that IGD can get the correct info
    local config = loadState(self._name)
    config.mode=self._permanent and "1" or "0"
    if self._pswcfg~=nil then
        config.password=''
    elseif self._pswcfg==nil and config.password=='' then
        --set dummy password here to indicate random password is enabled when remote assistance is not enabled
        config.password='_DUMMY_PASSWORD_'
    end
    writeState(self._name, config, true)
    return true
end

--- enable or disable the assistant
-- \param bActive (bool) if true enable else disable
-- \param bPermanent (bool) if true permanent mode else temporary mode
-- \param password:
--    if nil, random password is enabled
--    if string, clear text password is given by user
--    if table, srp salt/verifier is given by user
--    otherwise, previous password cfg will be used
-- \returns true if no error or nil, errmsg is case of error
function Assistant:enable(bActive, bPermanent, password)
   -- disable assistance if its cfg needs update
    if self:_checkupdate(bPermanent, password) and self:enabled() then
        local ok, msg = self:_do_disable()
        if not ok then
            return err,msg
        end
    end

    -- update cfg
    if not self:enabled() then
        self:_updatecfg(bPermanent,password)
    end

    if bActive then
        -- enable assistance
        if not self:enabled() then
            return self:_do_enable()
        else
            -- already active, action is no-op
            return true
        end
    else
        -- disable assistance
        if self:enabled() then
            return self:_do_disable()
        else
            -- already disabled, no-op
            return true
        end
    end
end

-- timeout timer callback
local function disable_assistant(premature, assistant)
    assistant._timerRunning = false
    if premature then
        return
    end
    if not assistant:checkTimeout() then
        assistant:_startTimer()
    end
end

-- generate a random port number in the configured range
local function genport(fromPort, toPort)
    local range=toPort-fromPort
    local r = 0
    if range>0 then
        r = random(range)-1
    end
    return fromPort+r
end

-- enable the assistant
function Assistant:_do_enable()
    local port = genport(self._fromPort, self._toPort)
    local user = self._mgr.users[self._user]
    if user then
        local psw, pwd
        if self._pswcfg == nil then
             psw = genpsw(10, self._pswchars)
             pwd = psw
        elseif type(self._pswcfg) == "string" then
             psw = self._pswcfg
        end
        if psw then
            local salt, verifier = srp.new_user(self._user, psw)
            user.srp_salt = salt
            user.srp_verifier = verifier
            self._psw = psw
        else
            user.srp_salt = self._pswcfg["salt"]
            user.srp_verifier = self._pswcfg["verifier"]
            --set dummy password here as self._psw is used to check if the assistant is enabled or not
            self._psw = "_DUMMY_PASSWORD_"
        end
        self._port = port
        self._wanip = getInterfaceIP(self._interface) or ''
        self:activity()
        writeState(self._name, {
            wanip=self._wanip;
            wanport=tostring(port);
            lanport=self._lanport;
            enabled="1";
            password=pwd or '';
            mode = self._permanent and "1" or "0";
        })
        return true
    end
    return nil, "internal error: user disappeared"
end

--- get the external ip and port
-- only meaningfull if the assistant is enabled
function Assistant:getExternalAddress()
    return self._wanip, self._port
end

-- disable the assistant
function Assistant:_do_disable()
    local user = self._mgr.users[ self._user ]
    if user then
        -- this will disable login
        user.srp_verifier = ''
    end
    -- log out all active sessions on my session manager
    for _, session in ipairs(self._mgr.sessions) do
        session:logout()
    end
    self._psw = nil
    self._port = nil
    self.timestamp = nil
    ngx.log(ngx.INFO, "disabled assistant ")
    local config = loadState(self._name)
    config.enabled="0"
    writeState(self._name, config)
    return true
end

function Assistant:_startTimer()
    if not self._timerRunning then
        local ok, err = ngx.timer.at(60, disable_assistant, self)
        if not ok then
            ngx.log(ngx.ERR, "failed to create assistant timer ", err)
        else
            self._timerrunning = true
        end
    end
end

function Assistant:activity()
    -- in case the timer is not running we now have the opportunity to check
    -- the timer
    self:checkTimeout()

    -- if still active reset activity timer
    if self._psw then
        self.timestamp = clock_gettime(CLOCK_MONOTONIC)
        self:_startTimer()
    end
end

-- check the timeout
-- \returns true if expired, false if not
-- if expired the assistant is disabled
function Assistant:checkTimeout()
    local expired = not self._permanent and self.timestamp and (self.timestamp + self._timeout) < clock_gettime(CLOCK_MONOTONIC) or false
    if expired then
        self:enable(false)
    end
    return expired
end

local function newAssistant(config, sessionmgr)
    local timeout = tonumber(config.timeout)
    if not timeout then
        ngx.log(ngx.ERR, format("invalid timeout value (%s) for assistant %s", tostring(config.timeout), config._name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    local fromPort, toPort = config.port:match('^%s*(%d+)%s*-%s*(%d+)%s*$')
    if fromPort then
        fromPort = tonumber(fromPort)
        toPort = tonumber(toPort)
    else
        fromPort = tonumber(config.port)
        toPort = fromPort
    end
    if not( fromPort and toPort) then
        ngx.log(ngx.ERR, format("invalid port spec for assistant %s", config._name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if toPort<fromPort then
        fromPort, toPort = toPort, fromPort
    end


    local assistant = {
        _name = config._name;
        _mgr = sessionmgr;
        _user = config.user;
        _timeout = timeout*60; --convert minutes to seconds
        _interface = config.interface;
        _lanport = control.mgrport(config.sessionmgr);
        _fromPort = fromPort;
        _toPort = toPort;
        _port = nil; --only set if enabled
        _psw = nil; --only set if enabled
        _pswchars = config.passwordchars;
        _permanent = false;
        _pswcfg = nil;
    }
    return setmetatable(assistant, Assistant)
end

-- load the config data for the named assistant
-- \param name (string) the name of the assistant
-- \param defaults (table or nil) the default values
-- \returns a table with configured values (possibly with default) or nil
-- if there is no config for the assistant named
local function loadAssistanceConfig(name, defaults)
    local config
    local path=format("uci.web.assistance.@%s.", name)
    local cfg=dm.get(path)
    if cfg then
        config = defaults or {}
        for _, entry in ipairs(cfg) do
            if (entry.path==path) then
                local v = untaint(entry.value)
                if v~='' then
                    config[untaint(entry.param)] = v
                end
            end
        end
        config._name = name
    end
    return config
end

local function loadAssistant(name)
    local config = loadAssistanceConfig(name, {
        interface="wan",
        timeout=30,
        port="55000-56000",
-- valid password chars
-- leave out characters that can be confusing like:
-- 0 1 o O l I
        passwordchars="23456789abcdefghijkmnpqrstuvwxyz!@#$%*.ABCDEFGHJKLMNPQRSTUVWXYZ"
    })

    if not config then
        ngx.log(ngx.INFO, format("%s assistance not enabled", name))
        ngx.log(ngx.ERR, err)
        return
    end

    local mgrname = config.sessionmgr
    if not mgrname then
        ngx.log(ngx.ERR, format("assistant %s has no sessionmgr assigned", name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if not config.user then
        ngx.log(ngx.ERR, format("assistant %s has no user assigned", name))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local mgr = control.loadmgr(mgrname)
    local user = mgr.users[untaint(config.user or '')]
    if not user then
        ngx.log(ngx.ERR, format("session manager %s has no user %s", mgrname, config.user))
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local assistant = mgr.assistant
    if not assistant then
        assistant = newAssistant(config, mgr)
        mgr.assistant = assistant
    end
    return assistant
end

local M = {}

local assistants_info = {}

--- get the assistant
-- \param name (string) the name of the assistant to retrieve
-- \returns the assistant or nil if no assistant of that name is configured
-- This function will call ngx.exit on any configuration error.
function M.getAssistant(name)
    local info = assistants_info[name]
    if not info then
        -- no attempt to load the named assistant has been attempted yet.
        local assistant = loadAssistant(name)

        -- store the returned assistant in a table (even if it is nil)
        -- this allows us to remember we tried to load it
        info = {assistant=assistant}

        -- store in cache
        assistants_info[name] = info
    end
    return info.assistant
end

-- enable remote assistance by loading all assistants
-- This has effect only once and must be called from the ngx access phase
local enabled = false
function M.enable()
    if not enabled then
        if ngx.get_phase() ~= "access" then
          ngx.log(ngx.ERR, "web.assistance.enable() called outside access phase")
          ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        --list all configured assistant names
        local assistants = {}
        local cfg=dm.get("uci.web.assistance.")
        if cfg then
            for _, entry in ipairs(cfg) do
                -- extract the name
                local name = match(untaint(entry.path),'%.@([^.]*)%.')
                if name then
                    assistants[name] = true
                end
            end
        end
        -- load all assistants
        for name, _ in pairs(assistants) do
            M.getAssistant(name)
        end
        enabled = true
    end
end

-- do environment setup
-- This must be called when the process is still running as root
local setup_done = false
function M.setup()
    if not setup_done then
        -- setup the state directory and make sure it is accessible when running
        -- as user nobody
        local state_dir = '/var/run/assistance'
        local cmd = format('if [ ! -d %s ]; then mkdir %s && chown nobody %s; fi;rm -f %s/*', state_dir, state_dir, state_dir, state_dir)
        exec(cmd)

        setup_done = true
    end
end

return M
