#!/usr/bin/env lua

local uci = require("uci")
local cursor = uci.cursor()

local function update_gwIP()
  local gatewayIP =  cursor:get("network", "lan", "ipaddr")
  local whiteListEnabled =  cursor:get("parental", "general", "exclude")
  local parentalEnabled =  cursor:get("parental", "general", "enable")
  local getGatewaySection
  if whiteListEnabled == "0" and parentalEnabled == "1" then
    cursor:foreach("parental", "URLfilter", function(s)
      if string.match(s[".name"] ,"URLfilterGWIP") then
         getGatewaySection = s[".name"]
      end
    end)
    if getGatewaySection then
      cursor:set("parental", getGatewaySection, "site", gatewayIP)
      cursor:commit("parental")
    end
  end
end

update_gwIP()
