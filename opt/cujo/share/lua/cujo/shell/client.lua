--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local argparse = require'argparse'
local json = require'json'

local shims = require 'cujo.shims'

-- luacheck: globals cujo
cujo = {
    filesys = require 'cujo.filesys',
    net = require 'cujo.net',
    log = require 'cujo.log',
    snoopy = require 'cujo.snoopy',
}
cujo.log:level(0)
cujo.config = require'cujo.config'

local function exit(msg, err, errno)
    io.stderr:write(msg, ' (', err, ')\n')
    os.exit(errno)
end

local parser = argparse('rabidctl', 'cujo rabid controler')
parser:argument('file', 'Script file.'):args'*'
parser:option('-e', 'Script string.'):args'1':count'*'
parser:flag("-a --async")
    :description(
        "Provide 'async_cb' to the script and wait until it is called. " ..
        "It must be called when the operation is done, or this command will hang.")
    :default(false)
local args = parser:parse()

local messages = {}
local function add_msg(name, code, ...)
    messages[#messages + 1] = json.encode({name = name, code = code, args = {...}})
end

for i, v in ipairs(args.e) do
    add_msg('(command line):' .. i, v)
end

if args.file[1] then
    local code, err = cujo.filesys.readfrom(args.file[1], 'a')
    if not code then
        exit('Unable to read file', err, 3)
    end
    add_msg(args.file[1], code, table.unpack(args.file, 2))
end

shims.run_shell_client(
    cujo.config.rabidctl.sockpath,
    args.async,
    messages,
    function(err)
        exit('Unable to connect to Rabid', err, 2)
    end,
    print,
    function(data)
        local msg = json.decode(data)
        if msg.type == 'ret' then
            if #msg.args > 0 then
                print(table.unpack(msg.args))
            end
            return false
        elseif msg.type == 'print' then
            print(table.unpack(msg.args))
            return true
        else
            local res, err = table.unpack(msg.args)
            print(res .. ' error', err)
            return false
        end
    end)
