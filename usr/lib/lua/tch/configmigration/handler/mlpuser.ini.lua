local gmatch = string.gmatch
local stringsub = string.sub
local gsub = string.gsub
local format = string.format
local M = {}

--local tprint = require("tch.tableprint")
local log_level = require("tch.configmigration.config").log_level
local logger = require("transformer.logger")
local log = logger.new("configmigration:mlpuser.ini", log_level)
local ch = require("tch.configmigration.convert_helper")
local srp = require("srp")
local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")

local mlpusers = require('tch.configmigration.mlpusers')
local roleMappingList = mlpusers.roleMappingList

local function add_section(section_name)
   local ucicmd = {}
   ucicmd.uci_config = "web"
   ucicmd.uci_sectype = "user"
   ucicmd.uci_secname = section_name
   ucicmd.action = "set"

   append_commit_list(ucicmd.uci_config)
   touci.touci(ucicmd)
end

local function add_to_default(section_name)
    local ucicmd = {}
    local user_list = touci.get("web.default.users")
    local isNewUser = true

    for _,user in ipairs(user_list) do
      if user == section_name then
        isNewUser = false 
        break
      end 
    end
    
    if isNewUser then
      ucicmd.uci_config = "web"
      ucicmd.uci_secname = "default"
      ucicmd.uci_option = "users"
      ucicmd.action = "add_list"
      
      user_list[#user_list + 1] = section_name
      ucicmd.value = user_list
      append_commit_list(ucicmd.uci_config)
      touci.touci(ucicmd)
    end
end

local function set_user_options(section_name, user_name, role, legacySalt, srp_salt, srp_verifier)
    local users = touci.get_config_type("web", "user")
    local foundSectionName = false
    for _,user in pairs(users) do
      if user[".name"] == section_name then
        foundSectionName = true
        break
      end
    end
    if not foundSectionName then
      add_section(section_name)
    end  
    ch.set_each_section("web", section_name, "name", user_name)
    ch.set_each_section("web", section_name, "role", role)
    ch.set_each_section("web", section_name, "legacy_salt", legacySalt)
    ch.set_each_section("web", section_name, "srp_salt", srp_salt)
    ch.set_each_section("web", section_name, "srp_verifier", srp_verifier)
end

function M.convert(g_user_ini)
    local section_string = g_user_ini["mlpuser.ini"] or ""
    local newUserList = {}
    
    for legacyRole, newRole in pairs(roleMappingList) do
      for user_name, password in gmatch(section_string, "add name=(%C+) password=(%C+) role=" .. legacyRole) do
      
        if not newUserList[user_name] then
          newUserList[user_name] = 0
        end
        if user_name and password then
          local section_name
          newUserList[user_name] = tonumber(newUserList[user_name]) + 1
          --to get the salt of password
          local salt = stringsub(password, 7, 14)
          local pass = stringsub(password, 15, 54)
          
          if newUserList[user_name] == 1 then
            section_name = "usr_" .. user_name
          else
            section_name = "usr_" .. user_name .. newUserList[user_name]
          end
          
          --add new srp user and get the srp_salt & srp_verifier
          local srp_salt, srp_verifier = srp.new_user(user_name, pass)
          if srp_salt and srp_verifier then
            --write the user name, role, legacy salt, srp_salt and srp_verifier to uci
            set_user_options(section_name, user_name, newRole, salt, srp_salt, srp_verifier)
            --add the new user to sessionmgr 'default'
            add_to_default(section_name)
          else
              log:critical("Cannot get srp_salt or srp_verifier")
          end
        end
      end
    end
end
return M
