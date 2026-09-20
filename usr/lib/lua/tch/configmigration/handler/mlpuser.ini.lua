local match = string.match
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

function M.convert(g_user_ini)
    local section_string = g_user_ini["mlpuser.ini"] or ""

    local user_name, password = match(section_string, "add name=(%C+) password=(%C+) role=Administrator hash2=%C+")

    if not user_name and not password then
        log:critical("Cannot get admin username and password.")
        return
    end

    --to get the salt of password
    local salt = stringsub(password, 7, 14)
    local pass = stringsub(password, 15, 64)

    ch.set_each_section("web", "usr_admin", "name", user_name)
    ch.set_each_section("web", "usr_admin", "legacy_salt", salt)

    --add new srp user & get the srp_salt& srp_verifier
    local srp_salt, srp_verifier = srp.new_user(user_name, pass)
    if not srp_salt or not srp_verifier then
        log:critical("Cannot get srp_salt or srp_verifier")
        return
    else
         --write the srp_salt & verifier to uci config
        ch.set_each_section("web", "usr_admin", "srp_salt", srp_salt)
        ch.set_each_section("web", "usr_admin", "srp_verifier", srp_verifier)
    end

    --Transfer the salt to normal string from hex string
    local tmpsalt = gsub(salt, "%x%x", function (salt) return format("%c", tonumber(salt, 16)) end)
    
    --Set the default user: if the password is null means is default user in legacy
    local filename = "/tmp/tmplegacysalt"
    local tmplegacysalt_f, msg = io.open(filename, "w")
    if not tmplegacysalt_f then
        log:critical(msg)
        return
    end

    tmplegacysalt_f:write(tmpsalt)
    local ret_sha1_hex_hash = ch.cmd_capture("sha1sum "..filename)
    local sha1_hex_hash = match(ret_sha1_hex_hash, "(%x+)  ")
    tmplegacysalt_f:close()
    os.remove(filename)

    if pass == sha1_hex_hash then
       ch.set_each_section("web", "default", "default_user", "usr_admin")
    else
       ch.set_each_section("web", "default", "default_user", "")
    end
end
return M
