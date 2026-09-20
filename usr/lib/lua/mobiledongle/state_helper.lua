#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- -- **                                                                          **
-- -- ** Copyright (c) 2013 Technicolor                                           **
-- -- ** All Rights Reserved                                                      **
-- -- **                                                                          **
-- -- ** This program contains proprietary information which is a trade           **
-- -- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- -- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- -- ** to retain this program in confidence and is not permitted to use or      **
-- -- ** make copies thereof other than as permitted in a written agreement       **
-- -- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- -- **                                                                          **
-- -- ******************************************************************************

local _print = print
local tprint = require("tch/tableprint")

local uci = require("uci")


local runtime = { }
local M = {}

local state_tbl = { }
local sim_tbl= { }
local registration_tbl= { }
local link_tbl= { }

local action_tbl = {
  ["DISABLED"] = {},
  ["ENABLED"] = {},
  ["DEVICE_DISCONNECTED"] =  {dev="WAITING_FOR_DEVICE", sim="NA", link="ERROR", reg="NA"},
  ["DETECTION_FAILED"] =  {dev="DETECTION_FAILED", sim="NA", link="ERROR", reg="NA"},
  ["APN_REQUIRED"] = {link="ERROR", reg="NA"},
  ["NETWORK_SELECT_REQUIRED"] = {link="ERROR", reg="NA"},
  ["PIN_REQUIRED"] = {dev="CONNECTED", sim="SIM_PIN", link="ERROR", reg="NA"},
  ["PPP_AUTH_REQUIRED"] = {link="ERROR", reg="NA"},
  ["PPP_SELECT_REQUIRED"] = {link="ERROR", reg="NA"},
  ["PUK_REQUIRED"] = {dev="CONNECTED", sim="SIM_PUK", link="ERROR", reg="NA"},
  ["SIM_ERROR"] = {dev="CONNECTED", sim="UNKNOWN", link="ERROR", reg="NA"},
}

--  Connection Information
-- link Status
local link_tbl = {
  ["CONNECTED"] = {},   --"[==[Connected]==]",
  ["CONNECTING"] = {},  --"[==[Connecting...]==]",
  ["DISCONNECTING"] = {},  --"[==[Disconnecting...]==]",
  ["SEARCHING"] = {},   --"[==[Attempting to connect]==]",
  ["ERROR"] = {},       -- "[==[Error conditon]==]",
  ["NA"] = {}           --"[==[init]==]"
}

--Mobile Information
--Device Name = uci.mobiledongle.info.deviceName //tbd
--Device Status = uci.mobiledongle.info.deviceStatus
local device_tbl = { 
  ["CONNECTED"] = {}, -- "[==[Device configured]==]",
  ["CONNECTING"] =  {}, --"[==[Configuring device]==]",
  ["DISCONNECTED"] =  {link="ERROR"}, --"[==[Device configuration failed]==]",
  ["WAITING_FOR_DEVICE"] =  {}, --"[==[Searching device]==]",
  ["DETECTION_FAILED"] =  {link="ERROR"}, --"[==[Unknown device type]==]",
  ["NA"] = {} --"[==[init]==]"
}

--SIM Status  = uci.mobiledongle.sim.status
local sim_tbl = {
  ["READY"] =  {}, --"[==[Ready]==]",
  ["SIM_PIN"] =  {link="ERROR"}, --"[==[PIN code required]==]",
  ["SIM_PUK"] =  {link="ERROR"}, --"[==[PUK code required]==]",
  ["DISABLED"] =  {}, --"[==[Disabled]==]",
  ["LOCKED"] =  {}, --"[==[SIM card locked]==]",
  ["UNKNOWN"] =  {link="ERROR"}, --"[==[Error]==]",
  ["NA"] = {} --"[==[init]==]"
}

--Registration State = uci.mobiledongle.info.registrationStatus
local regis_tbl = {
  ["REGISTERED_HOME"] =  {}, --"[==[Registered (home network)]==]",
  ["REGISTERED_ROAMING"] =  {}, --"[==[Registered (roaming)]==]",
  ["REGISTER"] = {}, --"[==[Register ...]==]",
  ["TECH_ERROR"] = {link="ERROR"}, --"[==[Technology not supported]==]",
  ["NO_NETWORK_FOUND"] = {link="ERROR"}, --"[==[No network found]==]",
  ["INIT"] = {}, --"[==[Initializing ...]==]",
  ["UNKNOWN"] = {link="ERROR"}, --"[==[Error]==]",
  ["NA"] = {}, --"[==[init]==]"
}

--PPP Status = uci.mobiledongle.info.ppp_status
local ppp_tbl = { 
  ["CONNECTED"] = {}, -- "[==[PPP configured]==]",
  ["CONNECTING"] =  {}, --"[==[Configuring PPP]==]",
  ["NETWORKING"] =  {}, --"[==[Configuring PPP]==]",
  ["DISCONNECTING"] =  {link="ERROR"}, --"[==[PPP configuration failed]==]",
  ["DISCONNECTED"] =  {link="ERROR"}, --"[==[PPP configuration failed]==]",
  ["ERROR"] =  {link="ERROR"}, --"[==[Searching device]==]",
  ["NA"] = {} --"[==[init]==]"
}

function M.update_Link_Status(status)
  assert(link_tbl[status])
  runtime.log:info(string.format("Link status: %s", status))
  runtime.uci_info.link_status = status
end

function M.update_Device_Status(status)
  local action = assert(device_tbl[status])
  if action.link then
     M.update_Link_Status(action.link)
  end
  runtime.log:info(string.format("Device status: %s", status))
  runtime.uci_info.device_status = status
end

function M.update_Sim_Status(status)
  local action = assert(sim_tbl[status])
  if action.link then
     M.update_Link_Status(action.link)
  end
  local cursor = uci.cursor(nil, "/var/state")
  cursor:revert(MBD, "sim", "status")
  cursor:set(MBD, "sim", "status", status)
  cursor:save(MBD)
  cursor:close()
  runtime.log:info(string.format("Sim status: %s", status))
end
  
function M.update_Registration_Status(status)
  local action = assert(regis_tbl[status])
  if action.link then
     M.update_Link_Status(action.link)
  end
  runtime.uci_info.registration_status = status
  runtime.log:info(string.format("Registration status: %s", status))
end

function M.update_PPP_Status(status)
  local action = assert(ppp_tbl[status])
  if action.link then
     M.update_Link_Status(action.link)
  end
  runtime.uci_info.ppp_status = status
  runtime.log:info(string.format("PPP status: %s", status))
end


function M.dump(p, c, marker)
  if not p then  return end
  assert(type(p) == "table")
  assert(type(c) == "string")
  if marker then
    print(string.format("==BEGIN== %s ===", marker))
  end
  for k, v in pairs(p) do
      if type(v) == "table" then M.dump(v, "--") end
      print("dump ==", c, "==:", k, "=", v)
  end
  if marker then
    print(string.format("==END== %s ===", marker))
  end
end 

function M.do_save_uci_section(s, p, revert, t)
    assert(type(s) == "string")
    assert(type(p) == "table")
    assert(type(t) == "string")
    assert(type(revert) == "boolean")

    local cursor = uci.cursor(nil, "/var/state")

    -- manage the /var/state/mobiledongle state filesize
    --[[
    if revert then  
      cursor:revert(MBD, s)
    end
    ]]
    if t then cursor:set(string.format("mobiledongle.%s=%s",s,t)) end
    
    for k, v in pairs(p) do
      print("= do_save_uci_section=",s,"=== k=", k, " v=", v)
      cursor:set(MBD, s, k, v)
    end
    cursor:save(MBD)
    cursor:close()
end

function M.do_save_uci_info(uci_info)
  assert(type(uci_info) == "table")
  M.do_save_uci_section("info", uci_info, false, "public")
end

function M.do_load_uci_state_var(l, comment)
    local cursor = uci.cursor(nil, "/var/state")
     
    local v = assert(cursor:get_all(MBD))
    print("--do_load_uci_state_var:", comment)
    if l then
      print("--do_load_uci_state_var : ====== BEGIN=", comment)
      tprint(v)
      print("--do_load_uci_state_var : ====== END=", comment)
    end
    
    cursor:close()
    return v
end

function M.do_load_uci_persist(l, comment)
    local cursor = uci.cursor()
     
    local v = assert(cursor:get_all(MBD))
    print("--do_load_uci_persist:", comment)
    if l then
      print("--do_load_uci_persist: ====== BEGIN=", comment)
      tprint(v)
      print("--do_load_uci_persist: ====== END=", comment)
    end
    
    cursor:close()
    return v
end


function M.do_early_exit(info_state, comment_str)
    assert(info_state)
    local comment = comment_str or ""

    local action=action_tbl[info_state]
    print("--do_early_exit:", comment_str)
    tprint(action)

    if action.link then
       M.update_Link_Status(action.link)
    end
    if action.dev then
       M.update_Device_Status(action.dev)
    end
    if action.sim then
       M.update_Sim_Status(action.sim)
    end
    if action.reg then
       M.update_Registration_Status(action.reg)
    end

    -- uci sections are not valid.
    runtime.cursor:revert(MBD, "parm")
    runtime.cursor:revert(MBD, "cardinfo")
    
    runtime.uci_info.state = info_state
    M.do_save_uci_info(runtime.uci_info)

    local cursor = uci.cursor(nil, "/var/state")
    local info_state_read, err = cursor:get(MBD, INFO, "state")
    cursor:close()                                                                  


    if err then 
    runtime.log:critical("uci state update failed (" .. err .. ")")
    end 
    
    if info_state ~= info_state_read then 
    runtime.log:critical(string.format("uci state update failed [%s, %s] %s", info_state, info_state_read, comment_str))
    end 

   if info_state then
   runtime.log:error(string.format("[%s] %s", info_state, comment_str))
   end
   os.exit(1)
end


function M.init (rt)

   print("init runtime = ", rt)
   tprint(rt)

   runtime = rt
end

return M
