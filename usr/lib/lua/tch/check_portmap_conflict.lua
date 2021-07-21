#!/usr/bin/env lua
local cursor = require("uci").cursor()

local function portMapConflictCheck( externalPort, protocol)
   local result = '0'
   externalPort = tonumber(externalPort)
   cursor:foreach( "firewall", "redirectsgroup", function(s)
      if s.enabled == '1' and ( s[".name"] == "userredirects" or s[".name"] == "acsredirects" or s[".name"] == "guiredirects" or s[".name"] == "cliredirects" ) then
         -- Check the conflict, if the redirectsgroup is enabled
         cursor:foreach("firewall", s.type, function(r)
            local external_port = {}
            for token in string.gmatch(r.src_dport  , "[^:]+") do
               table.insert( external_port, token)
            end
            for _, proto in pairs(r.proto) do
               if r.enabled == '1' and string.lower(proto) == string.lower(protocol) and ((external_port[2] == nil and tonumber(external_port[1]) == externalPort) or
                  ( external_port[2] ~= nil  and tonumber(external_port[2]) >= externalPort and tonumber(external_port[1]) <= externalPort)) then
                  result = '1'
		  return false
               end
            end
         end)
      end
   end)
   return result
end

print(portMapConflictCheck(arg[1], arg[2]))
