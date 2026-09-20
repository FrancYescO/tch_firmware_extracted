local match = string.match

local M = {}

local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")
local cmd_capture = require("tch.configmigration.convert_helper").cmd_capture

function M.convert(g_user_ini)
   local section_string = g_user_ini["ppp.ini"]
   local system_string = g_user_ini["system.ini"]

   local mode = match(system_string, "config WANMode=(%a+)")
   local username, password

   if mode == "ADSL" then
      username, password = match(section_string, "ifconfig intf=PPPoEDSL user=(%S+) password=(%S+)")
      if not username or not password then
         username, password = match(section_string, "ifconfig intf=Internet user=(%S+) password=(%S+)")
      end
   else
      username, password = match(section_string, "ifconfig intf=PPPoEWAN user=(%S+) password=(%S+)")
   end

   if username and password then
      local ucicmd = {}
      ucicmd.uci_config = "network"
      ucicmd.uci_secname = "ppp"

      ucicmd.uci_option = "username"
      ucicmd.value = username
      ucicmd.action = "set"

      append_commit_list(ucicmd.uci_config)
      touci.touci(ucicmd)

      ucicmd.uci_option = "password"
      ucicmd.value = cmd_capture("passwd_decrypt "..password)
      ucicmd.action = "set"
      touci.touci(ucicmd)
   end
end

return M
