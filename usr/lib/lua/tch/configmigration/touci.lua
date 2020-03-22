local uci = require("uci")
local match, format, concat = string.match, string.format, table.concat
local tonumber, type, tostring =
      tonumber, type, tostring
local cursor = uci.cursor()

local log_level = require("tch.configmigration.config").log_level
local logger = require("transformer.logger")
local log = logger.new("configmigration:touci", log_level)

local M = {}

function M.get_config_type(config, sectype)
  local ifce = {}
  cursor:foreach(config, sectype, function(s) ifce[s[".index"]]=s end)
  return ifce
end

local function get_actual_uci_secname(cmd)
  if not cmd or not cmd.uci_secname then return nil end
  local uci_secname = cmd.uci_secname
  -- In case UCI instance is multiple, convert section name (in fact, is
  -- section type) to actual section name
  local st, idx = match(uci_secname, "@([^%[]+)%[(%-?%d+)]")
  if st and idx and tonumber(idx) then
     local t = M.get_config_type(cmd.uci_config, st)[tonumber(idx)]
     if t then
        uci_secname = t[".name"]
     end
  end
  return uci_secname
end

local function set_cb(cmd)
  cmd.uci_secname = get_actual_uci_secname(cmd)
  if cmd.uci_secname then
     cmd.uci_config  = tostring(cmd.uci_config)
     cmd.uci_secname = tostring(cmd.uci_secname)
     cmd.uci_option  = tostring(cmd.uci_option)
     cmd.value       = tostring(cmd.value)
     local rc, errmsg
     local setstr
     if cmd.uci_sectype then
        cmd.uci_sectype = tostring(cmd.uci_sectype)
        setstr = format("%s.%s=%s", cmd.uci_config, cmd.uci_secname, cmd.uci_sectype)
        rc, errmsg = cursor:set(cmd.uci_config, cmd.uci_secname, cmd.uci_sectype)
     else
        setstr = format("%s.%s.%s=%s", cmd.uci_config, cmd.uci_secname, cmd.uci_option, cmd.value)
        if cmd.value == "" then
           --when value is empty, following cursor:set(config, section, option, value) will failure.
           rc, errmsg = cursor:set(setstr)
        else
           --when value very long, cursor:set(assignment) will truncate the long string
           rc, errmsg = cursor:set(cmd.uci_config, cmd.uci_secname, cmd.uci_option, cmd.value)
        end
     end
     log:info("uci set %s => %s %s", setstr, tostring(rc), rc and "" or errmsg)
  end
end

local function add_list_cb(cmd)
  cmd.uci_secname = get_actual_uci_secname(cmd)
  if not cmd.uci_secname then return end
  -- convert string to list
  if type(cmd.value) == "string" then
     local tmp = cmd.value
     cmd.value = { tmp }
  end
  -- UCI binding do not accept empty list
  if #cmd.value > 0 then
     cmd.uci_config  = tostring(cmd.uci_config)
     cmd.uci_secname = tostring(cmd.uci_secname)
     cmd.uci_option  = tostring(cmd.uci_option)
     local rc,errmsg = cursor:set(cmd.uci_config, cmd.uci_secname, cmd.uci_option, cmd.value)
     log:info("uci add_list %s.%s.%s { %s } => %s %s", cmd.uci_config,
        cmd.uci_secname, cmd.uci_option, concat(cmd.value, ","), tostring(rc), rc and "" or errmsg)
  end
end

local function add_cb(cmd)
  cmd.uci_config  = tostring(cmd.uci_config)
  cmd.uci_sectype = tostring(cmd.uci_sectype)
  local rc,errmsg = cursor:add(cmd.uci_config, cmd.uci_sectype)
  log:info("uci add %s\t%s => %s", cmd.uci_config, cmd.uci_sectype, tostring(rc))
  return rc
end

local function delete_cb(cmd)
   cmd.uci_secname = get_actual_uci_secname(cmd)

   cmd.uci_config  = tostring(cmd.uci_config)
   cmd.uci_secname = tostring(cmd.uci_secname)
   if cmd.uci_option then
      cmd.uci_option  = tostring(cmd.uci_option)
      local rc,errmsg = cursor:delete(cmd.uci_config, cmd.uci_secname, cmd.uci_option)
      log:info("uci delete %s.%s.%s => %s %s", cmd.uci_config, cmd.uci_secname,
        cmd.uci_option, tostring(rc), rc and "" or tostring(errmsg))
   else
      local rc,errmsg = cursor:delete(cmd.uci_config, cmd.uci_secname)
      log:info("uci delete %s.%s => %s %s", cmd.uci_config, cmd.uci_secname,
        tostring(rc), rc and "" or tostring(errmsg))
   end
end

local action_map = {
  ["set"] = set_cb,
  ["add_list"] = add_list_cb,
  ["add"] = add_cb,
  ["delete"] = delete_cb,
}

local function callcb(ucicmd)
  local actcb = action_map[ucicmd.action]
  if type(actcb) == "function" then
     return actcb(ucicmd)
  end
end

function M.touci(ucicmd)
  if type(ucicmd) == "table" then
     if #ucicmd > 0 then
        --ucicmd is a group of commands

        for _,v in ipairs(ucicmd) do
            callcb(v)
        end
     else
        --ucicmd is a single command
        return callcb(ucicmd)
     end
  end
end

function M.commit(config)
  config = tostring(config)
  local rc,errmsg = cursor:commit(config)
  log:info("uci commit %s => %s %s", config,
    tostring(rc), rc and "" or tostring(errmsg))
end

function M.get_config_by_option_value(config, sectype, option, value)
  if not config or not sectype or not option or not value then return nil end
  local ins = {}
  cursor:foreach(config, sectype,
    function(s)
      if s[option] == value then
         ins[#ins+1] = s
      end
    end)
  return (#ins > 0) and ins or nil
end

function M.get(...)
  return cursor:get(...)
end

function M.get_all(...)
  return cursor:get_all(...)
end

return M
