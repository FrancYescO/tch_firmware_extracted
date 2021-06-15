#!/usr/bin/lua

--[[
  (C) 2016 NETDUMA Software <iainf@netduma.com>
  Reset config key, useful during development
--]]

package.path = package.path .. ";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"
require "libos"
os.netgear_reset( arg[1] )
