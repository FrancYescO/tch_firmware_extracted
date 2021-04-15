--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local api = require'cujo.shell.api'
local argparse = require'argparse'

cujo = {net = require'cujo.net'}
require'cujo.log'
cujo.log:level(0)
require'cujo.filesys'
require'cujo.snoopy'
require'cujo.config'

local function exit(msg, err, errno)
	io.stderr:write(msg, ' (', err, ')\n')
	os.exit(errno)
end

local function doexecute(conn, ...)
	local ok, res, err = conn:execute(...)
	if not ok then
		print(res .. ' error', err)
	elseif #res > 0 then
		print(table.unpack(res))
	end
end

function customprint(args)
	print(table.unpack(args))
end

local parser = argparse('rabidctl', 'cujo rabid controler')
parser:argument('file', 'Script file.'):args'*'
parser:option('-e', 'Script string.'):args'1':count'*'
local args = parser:parse()

local conn, err = api.connect(cujo.config.rabidctl.sockpath)
if not conn then
	exit('Unable to connect to Rabid', err, 2)
end

conn.print = customprint

for i, v in ipairs(args.e) do
	doexecute(conn, '(command line):' .. i, v)
end

if args.file[1] then
	local code, err = cujo.filesys.readfrom(args.file[1], 'a')
	if code then
		doexecute(conn, args.file[1], code, table.unpack(args.file, 2))
	else
		exit('Unable to read file', err, 3)
	end
end

conn:close()
