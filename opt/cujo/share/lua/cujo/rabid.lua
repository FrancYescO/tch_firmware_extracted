--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

for k, v in pairs{
	vararg = 'vararg',
	event  = 'coutil.event',
	time   = 'coutil.time',
	socket = 'coutil.socket',
	oo     = 'loop.base',
	tabop  = 'loop.table',
	json   = 'json',
	base64 = 'base64',
	lru    = 'nf.lru',
} do
	_G[k] = require(v)
end

cujo = {net = require'cujo.net'}
for _, v in ipairs{
	'log', 'filesys', 'snoopy', 'config', 'util', 'jobs',
	'ipset', 'iptables', 'nf', 'https', 'ssdp',
	'iotblock', 'appblock', 'safebro', 'traffic', 'fingerprint',
	'cloud.conn', 'hibernate', 'trackerblock', 'shell.server',
	'snoopyjobs',
} do
	local path = assert(package.searchpath('cujo.' .. v, package.path))
	assert(loadfile(path))()
end

cujo.config.startup()
cujo.cloud.connect()
