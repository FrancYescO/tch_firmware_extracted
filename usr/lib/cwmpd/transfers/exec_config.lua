
local require = require
local print = print
local format = string.format
local open = io.open
local concat = table.concat
local remove = table.remove
local sort = table.sort
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local error = error
local xpcall = xpcall
local unpack = unpack
local type = type
local tostring = tostring

local stderr = io.stderr

local lfs = require 'lfs'
local xpcall = require 'tch.xpcall'
local moduci = require 'uci'

local uci
local function setup_uci(savedir)
	uci = moduci.cursor(CONF_DIR, savedir)
end

local function setup_uci_dir(config_dir)
	uci = moduci.cursor(config_dir)
end

local current_line = 0
local ispconfig = false

-----------------------------------------------------------------------------
-- Override error handling so that user errors are treated differently
-- from programming error.
-- A user error (=error executing faulty command) will not produce
-- any output.
-- A programming error will produce a traceback
--
-- In order to achieve this we override pcall
-- a user error is not raised as a string but as a string wrapped in a table.
-----------------------------------------------------------------------------
local function error_traceback(err)
    if type(err)=='table' then
        -- error resulting from errmsg
        -- this should not cause a traceback as the error was the intended
        -- behaviour
        return err
    else
        -- any other error.
        -- This error is unexpected and must result in a traceback as it
        -- likely represents a programming error.
        local traceback = debug.traceback(err, 2)
        io.stderr:write(traceback, '\n')
    end
end

local function pcall(fn, ...)
    return xpcall(fn, error_traceback, ...)
end

---------------------------------------------------------------------------
-- extra table functions
---------------------------------------------------------------------------

-- retrieve index of value in array
-- @param tbl [array] the array to search
-- @param value [any] the value to find
-- @returns the index of the value or nil if the value is not in the array
local function table_index(tbl, value)
    for i, v in ipairs(tbl) do
        if v==value then
            return i
        end
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- remember wich configs have been changed, so they can later be commited
-- or reverted
local changed_configs = {}
local function changed_config(config)
    changed_configs[config] = true
end

-- remember wich config have been added, so they can be deleted on revert
local added_configs = {}
local function added_config(config, filename)
    added_configs[filename] = config
end


local function printf(fmt, ...)
    print(format(fmt, ...))
end

-- send an error msg to stdout and return it as a user error
-- this allows chaining it with error:
--   error(errmsg(...))
local function errmsg(fmt, ...)
    local msg = format(fmt, ...)
    stderr:write('*error line ', tostring(current_line),': ', msg, '\n')
    return {msg}
end

----------------------------------------------------------------------------
-- command parsing
----------------------------------------------------------------------------

-- find the given quote in the line start from start
-- @param line [string] the current line
-- @param start [int] the current start index
-- @param quote [char] the quote to look for
-- @returns the index of the first unescaped quote found
--          or nil if there is no such quote.
local function quoted_string(line, start, quote)
    local term
    while (not term) and (start<=#line) do
        local n = line:find(quote, start, true)
        if n and (line:sub(n-1, n-1)~='\\') then
            term = n
        elseif n then
            start = n+1
        else
            break
        end
    end

    return term
end

-- parse line into a list of arguments
-- @param line [string] the current input line
-- @param args [array] array to append found args to
-- @returns args plus a bool indicating if the line is continued (ends in \)
-- found arguments are added to the given args array. This enables the parsing
-- of commands spread across several line.
local function parse_args(line, args)
    local cont = false -- set to true if line ends in \
    local start = 1
    local len = #line
    if ispconfig and current_line==1 then
        if line ~= "ispconfig" then
            error(errmsg("file is not an ispconfig sts"))
        end
        return args, false
    end
    while start<=len do
        local s, f
        s, f = line:find('^%s+', start)
        if s then
            -- string starts with whitespace, skip it
            start = f+1
        else
            local arg
            local first=line:sub(start, start)
            if (first=='#') or (first==';') then
                -- ignore everything after # or ;
                break
            elseif first=='\\' then
                if start==len then
                    -- line ends with a \, so the command is continued on the
                    -- next line
                    cont = true
                    break
                else
                    error(errmsg("invalid backslash"))
                end
            else
                -- parse a single arg, which can contain embedded quoted strings
                local arg_start, arg_last = start, start
                while (arg_last<=len) do
                    s, f = line:find('^[^%s"\']+', start)
                    if s then
                        -- an unquoted portion of the argument
                        arg_last=f
                        start = f+1
                    end
                    first = line:sub(start, start)
                    if (first=='') or first:match('%s') then
                        -- end of string or whitespace, this arg is over
                        break
                    end
                    if (first=='"') or (first=="'") then
                        -- a quoted part of arg, find the end of it
                        f = quoted_string(line, start+1, first)
                        if not f then
                            error(errmsg("unterminated string"))
                        end
                        arg_last = f
                        start = f+1
                    end
                end
                arg = line:sub(arg_start, arg_last)
            end
            if arg then
                args[#args+1] = arg
            end
        end
    end


    return args, cont
end

----------------------------------------------------------------------------
-- UCI helper function
----------------------------------------------------------------------------

-- return a list of section names of a given type
-- @param config [string] the config name
-- @param sectype [string] the section type
-- @returns an array of section names.
local function section_list(config, sectype)
    local sections = {}

    -- get all wanted sections
    uci:foreach(config, sectype, function(s)
        sections[#sections+1] = s
    end)

    -- sort then by .index
    sort(sections, function(s1, s2) return s1['.index']<s2['.index'] end)

    local result = {}
    for _, section in ipairs(sections) do
        result[#result+1] = section['.name']
    end
    return result
end

-- convert the given section to the real .name property of the section
-- @param config [string] the config name
-- @param section [string] the section, either name or @type[d] syntax
-- @returns the .name property or nil if not found
local function get_real_section(config, section)
    local sectype, index = section:match('^@([^[]*)%[([+-]?%d+)%]$')
    if not sectype then
        return section
    else
        index = tonumber(index)
        local list = section_list(config, sectype)
        if index>=0 then
            return list[index+1]
        else
            return list[#list+1+index]
        end
    end
end

-- get section name of given section
-- @param config [string] the config name
-- @param secmap [table] the complete section table
-- @returns the display name of the section.
-- This is the name if not anonymous or @type[d] if anonymous
local function section_name(config, secmap)
    if secmap['.anonymous'] then
        local names = section_list(config, secmap['.type'])
        local index = table_index(names, secmap['.name'])
        if not index then
            error(errmsg("invalid section found"))
        end
        return format('@%s[%d]', secmap['.type'], index-1)
    else
        return secmap['.name']
    end
end

-- print a section
-- @param config [string] the config name
-- param secmap [table] the section table
local function print_section(config, secmap)
    local section = section_name(config, secmap)
    printf("%s.%s=%s [%d]", config, section, secmap['.type'], secmap['.index'] or -1)
    for k, v in pairs(secmap) do
        if k:sub(1,1)~='.' then
            -- a real option
            if type(v)=='table' then
                v=concat(v, ', ')
            end
            printf("%s.%s.%s=%s", config, section, k, tostring(v))
        end
    end
end

-- check the value
-- @param option [string] one of 'required' , 'denied', 'allowed'
-- @param value [any] value to check
-- @param name [string] name to use in error messages
-- @returns nothing but is value does not match option a user error is raised
--
-- option 'required' -> value can not be nil
-- option 'denied' -> value must be nil
-- option 'allowed' -> value can be any value but this is not checked
local function check_value_option(option, value, name)
    if option=='required' then
        if not value then
            error(errmsg("%s is required", name))
        end
    elseif option=='denied' then
        if value then
            error(errmsg("%s is not allowed", name))
        end
    end
end

-- parse command arguments
-- @param arg [string] the argument to parse
-- @param options [table] options for arg parts
-- @returns {config=config. section=section, option=option, value=value}
-- if some part does match the options an error is raised.
--
-- arg must be of the form config[.section[.option][=value]
-- options may contain section, option, value entries with the values
-- 'allowed', 'denied', 'required' wich is the default
-- config is always required
local function parse_cmdarg(arg, options)
    local r={}
    options=options or {}
    local s,f = arg:find('[^%.=]+')
    if s then
        r.config = arg:sub(s, f)
        if arg:sub(f+1, f+1)=='.' then
            s, f = arg:find('[^%.=]+', f+2)
            if not s then
                error(errmsg("section expected"))
            end
            r.section = arg:sub(s, f)
            if arg:sub(f+1, f+1)=='.' then
                s, f = arg:find('[^%.=]+', f+2)
                if not s then
                    error(errmsg("option expected"))
                end
                r.option = arg:sub(s, f)
            end
        end
        if arg:sub(f+1, f+1)=='=' then
            local value = arg:sub(f+2) or ''
            local first = value:sub(1,1)
            local last = value:sub(-1, -1)
            if (first==last) and first:match('^[\'"]') then
                value = value:sub(2, -2) --strip of quotes
            end
            r.value = value
        end
    end
    if r.config and r.section then
        r.section = get_real_section(r.config, r.section)
        if not r.section then
            error(errmsg("invalid section"))
        end
        printf("*real section: %s", r.section)
    end
    check_value_option('required', r.config, 'config')
    check_value_option(options.section or 'required', r.section, 'section')
    check_value_option(options.option or 'required', r.option, 'option')
    check_value_option(options.value or 'required', r.value, 'value')
    return r
end

-- get full config, section or single option
-- get config[.section[.option]]
local function do_get(args)
    local arg = parse_cmdarg(concat(args, ''), {section='allowed', option='allowed', value='denied'})
    if arg.option then
        local secmap, err = uci:get_all(arg.config, arg.section)
        if not secmap then
            error(errmsg("%s", err or '???'))
        end
        local section = section_name(arg.config, secmap)
        local value = secmap[arg.option]
        if value then
            if type(value)=='table' then
                value=concat(value, ', ')
            end
            printf("%s.%s.%s=%s", arg.config, section, arg.option, value)
        end
    elseif arg.section then
        local secmap, err = uci:get_all(arg.config, arg.section)
        if not secmap then
            error(errmsg("%s", err or '???'))
        end
        print_section(arg.config, secmap)
    else
        local cfg, err = uci:get_all(arg.config)
        if not cfg then
            error(errmsg("%s", err or '???'))
        end
        -- list and sort sections on .index to be consistent with uci command
        sections = {}
        for _, secmap in pairs(cfg) do
            sections[#sections+1] = secmap
        end
        sort(sections, function(s1, s2) return s1['.index']<s2['.index'] end)
        for _, secmap in pairs(sections) do
            print_section(arg.config, secmap)
        end
    end
end

-- set a single option value
-- set config.section.option=value
-- Allow to set empty value, which is the equivalent of deleting the option
local function do_set(args)
    local arg = parse_cmdarg(concat(args, ''))
    uci:set(arg.config, arg.section, arg.option, arg.value)
    local newval, err = uci:get(arg.config, arg.section, arg.option)
    if not newval then
        if arg.value == '' then
            newval=''
        else
            error(errmsg("%s", err or '<no val>'))
        end
    end
    if arg.value~=newval then
        error(errmsg("failed to set value"))
    end
    changed_config(arg.config)
end

local function find_section_named(config, sectype, secname)
    local section
    uci:foreach(config, sectype, function(s)
        if s['.name']==secname then
            section = s
            return false --break out of foreach
        end
    end)
    return section
end

-- rename a section or option
-- rename config.section[.option]=value
local function do_rename(args)
    local arg = parse_cmdarg(concat(args, ''), {option='allowed'})
    local section = uci:get_all(arg.config, arg.section)
    if not section then
        error(errmsg("no such section %s.%s", arg.config, arg.section))
    end
    if arg.option then
        if not section[arg.value] then
            -- target option does not exists
            if section[arg.option] then
                uci:rename(arg.config, arg.section, arg.option, arg.value)
                printf("*option %s renamed to %s", arg.option, arg.value)
            else
                printf("*no option %s, rename is no-op", arg.option)
            end
        else
            error(errmsg("duplicate option name %s", arg.value))
        end
    else
        if not find_section_named(arg.config, section['.type'], arg.value) then
            uci:rename(arg.config, arg.section, arg.value)
            printf("*section renamed to %s", arg.value)
        else
            error(errmsg("duplicate section name %s", arg.value))
        end
    end
    changed_config(arg.config)
end

-- add config or section
-- add config [section [name]]
-- --> No dot between config and section!!
local function do_add(args)
    local config = args[1]
    local section = args[2]
    local name = args[3]
    if section then
        local v=uci:add(config, section)
        if v then
            printf("*added section %s %s", config, v)
            changed_config(config)
            if name then
                if not find_section_named(config, section, name) then
                    uci:rename(config, v, name)
                    printf("*newly created section renamed to %s", name)
                else
                    uci:delete(config, v)
                    error(errmsg("duplicate section name %s", name))
                end
            end
        else
            error(errmsg("failed to add section %s %s", config, section))
        end
    elseif config then
        -- create new config file
        if not uci:create_config_file(config) then
            error(errmsg("failed to create config %s", config))
        end
    else
        error(errmsg("missing parameters"))
    end
end

-- add an item to a list option
-- add_list config.section.option=value
-- does allow to create duplicates
local function do_add_list(args)
    local arg = parse_cmdarg(concat(args, ''))
    local v, err = uci:get(arg.config, arg.section, arg.option)
    if type(v)~='table' then
        printf("*transforming %s.%s.%s to a list", arg.config, arg.section, arg.option)
        v = {v}
    end
    if (arg.value~='') then
        v[#v+1] = arg.value
        uci:set(arg.config, arg.section, arg.option, v)
        changed_config(arg.config)
    else
        print("*warning: not adding empty value to list")
    end
end

-- delete an item (also all duplicates) from a list option
-- del_list config.section.option=value
-- no error to remove an option that is not in the list
local function do_del_list(args)
    local arg = parse_cmdarg(concat(args, ''))
    local v, err = uci:get(arg.config, arg.section, arg.option)
    if type(v)~='table' then
        printf("*transofrming %s.%s.%s to a list", arg.config, arg.section, arg.option)
        v = {v}
    end
    local v_index = (arg.value~='') and table_index(v, arg.value) or nil
    if v_index then
        repeat
           table.remove(v, v_index)
           v_index=table_index(v, arg.value)
        until not v_index
        uci:delete(arg.config, arg.section, arg.option)
        uci:set(arg.config, arg.section, arg.option, v)
        changed_config(arg.config)
    else
        print("*warning: value not found")
    end
end

-- delete section or option
-- delete config.section[.option]
local function do_delete(args)
    local arg = parse_cmdarg(concat(args), {option='allowed', value='denied'})
    if arg.option then
        uci:delete(arg.config, arg.section, arg.option)
    else
        uci:delete(arg.config, arg.section)
    end
    changed_config(arg.config)
end

-- set the exit code on error
-- this is mainly to aid in testing
local exit_code
local function do_errorcode(args)
    local code = tonumber(args[1])
    if (not code) or (math.floor(code)~=code) then
        error(errmsg("invalid error code (must be integer)"))
    end
    if (0<code) and (code<256) then
        exit_code = code
    else
        error(errmsg("error code must be from 1 to 255."))
    end
end

local reboot = true
local reboot_set = false

local function set_reboot(on)
    if not reboot_set then
        reboot = on;
        printf("turned reboot %s", on and "on" or "off")
        reboot_set = true
    else
        error(errmsg("can have only one 'reboot off' or 'reboot on' in the script"))
    end
end

local function do_reboot(args)
    local arg = args[1] or 'on'
    if arg=='on' then
        set_reboot(true)
    elseif arg=='off' then
        set_reboot(false)
    elseif arg=='show' then
        printf("reboot is %s", reboot and 'on' or 'off')
    else
        error(errmsg("invalid argument (%s) to reboot, must be on, off or show", arg))
    end
end

local function do_ispconfig()
    if not ispconfig then
        error(errmsg("ispconfig command not valid in this context"))
    end
    -- otherwise this command is a no-op
end

local function do_set_config_dir(args)
    if #args~=1 then
        error(errmsg("'config_dir' requires (exactly) one argument"))
    end
    if lfs.attributes(args[1], "mode") ~= "directory" then
        error(errmsg("'config_dir' %s does not exist",args[1]))
    end
    setup_uci_dir(args[1])
end

-- for /etc/init.d/service calls we only allow at most one parameter which, if
-- given, must be in the following table.
local allowed_service_action = {
    stop = true,
    start = true,
    restart = true,
    reload = true,
    disable = true,
    enable = true,
}

-- all service calls must be executed after the uci commit so we collect them
local service_calls = {}

local function do_service(args, ignore_error)
    if #args>2 then
        error(errmsg("only one argument allowed (%d)", #args-1))
    end
    if ispconfig then
        error(errmsg("not allowed to call /etc/init.d script in ispconfig"))
    end
    if reboot then
        error(errmsg("not allowed to call /etc/init.d script when reboot is on"))
    end
    local cmd
    local action = args[2]
    if action and not allowed_service_action[action] then
        error(errmsg("action %s is not allowed", action))
    end
    if action then
        cmd = format("/etc/init.d/%s %s", args[1], action)
    else
        cmd = format("/etc/init.d/%s", args[1])
    end
    printf("*queued: %s", cmd)
    service_calls[#service_calls+1] = {
        cmd = cmd,
        ignore_error = ignore_error
    }
end

local function exec_service_calls()
    local success = true
    for _, svc in ipairs(service_calls) do
        local cmd = svc.cmd
        local ignore_error = svc.ignore_error
        printf("*execute: %s", cmd)
        if os.execute(cmd)~=0 then
            printf("failed to execute: %s", cmd)
            if not ignore_error then
                success = false
            end
        end
    end
    return success
end

-- commit all changes made
local function commit()
    for config, _ in pairs(changed_configs) do
        printf("*committing %s", config)
        uci:commit(config)
    end
    changed_configs = {}
end

-- rollback all changes made
local function revert()
    for config, _ in pairs(changed_configs) do
        printf("*reverting %s", config)
        uci:revert(config)
    end
    changed_configs = {}

    for conffile, config in pairs(added_configs) do
        printf("*removing %s", config)
        os.remove(conffile)
    end
    added_configs = {}
end

local cmdmap = {
    get = do_get;
    set = do_set;
    add = do_add;
    add_list = do_add_list;
    del_list = do_del_list;
    rename = do_rename;
    delete = do_delete;
    del = do_delete;
    errorcode = do_errorcode;
    reboot = do_reboot,
    ispconfig = do_ispconfig,
    config_dir = do_set_config_dir,

    -- we do not use a string key as we do not want to introduce an extra
    -- command
    [do_service] = do_service
}

local function do_exec(args)
    local ignore_error = false
    local cmd = args[1]
    if cmd:match('^%-') then
        cmd = cmd:sub(2)
        ignore_error = true
    end
    local service = cmd:match('^/etc/init.d/([^/*]*)$')
    if service then
        if service~="" then
            args[1] = service
            cmd = do_service
        else
            print("no service specified")
            return false
        end
    else
        remove(args, 1)
    end
    local handler = cmdmap[cmd]
    if not handler then
        local msg = errmsg("unknown command %s", cmd)
        return ignore_error
    else
        local ok, err = pcall(handler, args, ignore_error)
        if not ok then
            return (type(err)=='table') and ignore_error
        end
    end
    return true
end

local function do_print(args)
    if #args>0 then
        io.write('{[', concat(args, '], ['), ']}\n')
    else
        io.write('{}\n')
    end
    return 0
end

local exec = function(args)
    --do_print(args)
    return do_exec(args)
end

local function output_state(state, stateFile)
    local f
    if stateFile and (stateFile~='-') then
        local err
        f, err = open(stateFile, 'w')
        if not f then
            errmsg("failed to open statefile %s: %s", stateFile, err or '???')
            f = io.stdout
        end
    else
        f = io.stdout
    end

    for k, v in pairs(state) do
        f:write( k, "=", v, "\n" )
    end
    f:close()
end

local function handle_arguments(...)
    local result = {}
    for _, arg in ipairs{...} do
        local option, value = arg:match("^%-%-([^=]*)=?(.*)")
        if option then
            result[option] = value
        else
            result[#result+1] = arg
        end
    end
    return result
end

local function main(cmd_args)
    local result = 0
    local config = cmd_args[1]
    local stateFile = cmd_args[2]
    ispconfig = cmd_args.ispconfig
    setup_uci(cmd_args.dryrun)
    exit_code = 1
    printf("*Excecuting config file %s", config or '<stdin>')

    local f, err
    if config and (config~='-') then
        f, err = open(config)
    else
        f = io.stdin
    end
    if not f then
        errmsg("%s", err or '???')
        return 1
    end


    local args
    for line in f:lines() do
        current_line = current_line + 1
        printf("@%d: %s", current_line, line)
        local ok, cont
        ok, args, cont = pcall(parse_args, line, args or {})
        if not ok then
            print(args)
            result = 1
            break
        end
        if not cont then
            if #args>0 then
                local ok, success = pcall(exec, args)
                if not ok then
                    print(success)
                    result = exit_code
                    break
                elseif not success then
                    result = exit_code
                    break
                end
            end
            args = nil
        end
    end
    f:close()

    if args and not result then
        errmsg("unterminated statement")
        result = exit_code
    end

    if result~=0 then
        print("*Bailing out after error")
        revert()
    elseif not cmd_args.dryrun then
        commit()
        if not exec_service_calls() then
            result = 1
        end
    end

    printf("*Done [%d]", result)
    local state = {
        REBOOT = reboot and '1' or '0',
    }
    output_state(state, stateFile)
    return result
end


os.exit(main(handle_arguments(...)) or 0)
