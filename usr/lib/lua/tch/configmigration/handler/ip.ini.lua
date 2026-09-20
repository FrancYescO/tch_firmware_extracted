local match = string.match

local M = {}

local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")
local logger = require("transformer.logger")
local log = logger.new("configmigration:ip.ini", config.log_level)
local format = string.format
local num2ipv4 = require("tch.configmigration.convert_helper").num2ipv4
local bit = require("bit")

function M.convert(g_user_ini)
   local section_string = g_user_ini["ip.ini"]
   if not section_string then return end

   --fill in attributes of each service
   --local  address = {}
   --for addr in sgmatch(section_string, "ipadd intf=LocalNetwork addr=(.-) ") do
      --table.insert(address, addr)
   --end
   local address, netmask
   address, netmask = match(section_string, "ipadd intf=LocalNetwork addr=([%d%.]+)/(%d+)")
   if address and netmask and tonumber(netmask) >= 0 and tonumber(netmask) <= 32 then
      log:debug(address)

      local ucicmd = {}
      ucicmd.uci_config = "network"
      ucicmd.uci_secname = "lan"

      ucicmd.uci_option = "ipaddr"
      ucicmd.action = "delete"

      touci.touci(ucicmd)
      touci.commit("network") --network.lan is not a valid config name


      --ucicmd.action = "add_list"
      ucicmd.action = "set"
      ucicmd.value = address
      touci.touci(ucicmd)

      -- convert netmask
      ucicmd.uci_option = "netmask"
      -- CIDR string to number
      netmask = netmask ~= "0" and bit.lshift(bit.bnot(0), 32-netmask) or 0
      ucicmd.value = num2ipv4(netmask)
      touci.touci(ucicmd)

      append_commit_list(ucicmd.uci_config)
   end
end

return M
