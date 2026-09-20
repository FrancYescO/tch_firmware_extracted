#!/usr/bin/lua
local uci = require('uci')
local wf = require('wansensingfw')

function loadconfig()
   local l2tbl = {}
   local l3tbl = {}
   local wtbl = {}
   local cursor = uci.cursor()

   cursor:foreach("wansensing", "wansensing", function(s) global = s end)
   cursor:foreach("wansensing", "L2State", function(s) l2tbl[s.name] = s end)
   cursor:foreach("wansensing", "L3State", function(s) l3tbl[s.name] = s end)
   cursor:foreach("wansensing", "worker", function(s) wtbl[s.name] = s end)
   return global, l2tbl, l3tbl, wtbl
end

local global, l2states,l3states, workers = loadconfig()

wf.start(global, l2states, l3states, workers)

