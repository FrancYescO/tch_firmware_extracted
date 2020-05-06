#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2013 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************

package.path = '/usr/lib/mobiledongle/?.lua;' .. package.path
local lfs = require("lfs")
local uci = require("uci")
local ubus = require ("ubus")
local _print = print
local cursor = uci.cursor(nil, "/var/state")
local cursor_network = uci.cursor()
local logger = require 'transformer.logger'
logger.init(6, false)
local log = logger.new("mobiledongle", 5) -- 3 5=info 6=debug
local unix = require("tch.socket.unix")

local popen = io.popen
local open = io.open
local match = string.match
local lower = string.lower
local dir = lfs.dir

local tonumber = tonumber
local next = next
local pairs = pairs
local ipairs = ipairs
local type = type
local error = error
local pcall = pcall

local netw_wwan=nil
local update_pin_uci_info
local at_support_huawei_cmd = nil

local mbd_uci_cfg_begin   -- the mobiledongle uci config at begin (start)
local mbd_uci_cfg_end     -- the mobiledongle uci config at end (leave)
local uci_info = {}       -- the mobiledongle uci info section
local uci_mbd_network = {}
local at_ctrl



MBD="mobiledongle"
PARM="parm"
INFO="info"

local maxLogSize = 1048576 --1MB

function print (...)
  -- _print( ...)
  if mbd_uci == nil or
    mbd_uci.config.log == "0" then
    return nil
  end

  local filesize = 0
  local filename = "/root/mobiledongle/fg.log"
  local filename_old = "/root/mobiledongle/fg_old.log"
  local fd_log = io.open(filename, "a+")
  assert(fd_log)
  --fd_log:write("@@@ log ::" )
  for i=1, select ('#', ...) do
    local arg = select(i, ...)
    -- _print("@@myprint_var i=", i, " arg=",arg, " type=", type(arg))
    if type(arg) == "string" then
      fd_log:write(arg)
    elseif type(arg) == "nil" then
      fd_log:write(" nil ")
    elseif type(arg) == "table" then
      fd_log:write(tostring(arg))
    elseif type(arg) == "number" then
      fd_log:write(" " .. tostring(arg) .. " ")
    elseif type(arg) == "boolean" then
      if arg == true then
        fd_log:write(" true ")
      else
        fd_log:write(" false ")
      end
    else
      print("@@@@@@@@@@@@@@@@@@@@@ ", type(arg), ..., "@=@=@=@=@")
    end
  end
  fd_log:write("\n" )
  filesize = fd_log:seek("end", 0)
  fd_log:close()

  if (filesize > maxLogSize) then
    os.rename(filename, filename_old)
  end
end

local tprint = require("tch/tableprint")

local state_helper = require("mobiledongle/state_helper")
state_helper.init({cursor = cursor, uci_info=uci_info, log = log, tprint=tprint})

local at_helper = require("mobiledongle/at_helper")
at_helper.init({log = log, tprint=tprint})

local function rpc_ubus_ifdown(itf)
    if itf then
netw_wwan = assert(string.format("network.interface.%s", itf))
    end
    local conn = assert(ubus.connect())
    conn:call(netw_wwan, "down", { } )
    conn:close()
end

local function do_save_uci_info()
  assert(type(uci_info) == "table")
  state_helper.do_save_uci_section("info",uci_info,false,"public")
end

local function do_save_uci_parm(p)
  assert(type(p) == "table")
  state_helper.do_save_uci_section("parm",p,true,"public")
end

local function do_save_uci_cardinfo(p)
  assert(type(p) == "table")
  state_helper.do_save_uci_section("cardinfo",p,true,"public")
end


--local proto="Prot=12"
local function get_usedTTY(proto)
  -- Opens a file in read
  file = io.open("/proc/bus/usb/devices", "r")

  -- sets the default input file as test.lua
  io.input(file)

  local l
  local itfnbr

  while true do
    l=io.read("*l")
    if l == nil then break end

    -- I:* If#= 0 Alt= 0 #EPs= 2 Cls=ff(vend.) Sub=02 Prot=12 Driver=option
    itfnbr=string.match(l, "I:[*]+ If#= (%d) [%w ().#=]+ " .. proto .. " Driver=option")
    if itfnbr then  break end
  end
  -- closes the open file
  io.close(file)

  if itfnbr == nil then return end

  local result
  local f = popen ("ls -l /sys/bus/usb-serial/drivers/option1" )

  if f == nil then return result end

  local p=itfnbr .. "/ttyUSB[0-9]+$"
  while true do
    local l = f:read("*l")
    if (l == nil) then break end
    result=string.match(l, p)
    if result then
      result=string.match(result, "(ttyUSB[0-9]+)$")
      break
    end
  end

  f:close()
 return result

end
local function get_usedTTYByAll()
  local f = popen ("ls -l /sys/bus/usb-serial/drivers/option1")
  local at_ctrl,at_data
  if f == nil then return at_ctrl,at_data end
  for l in f:lines() do  
    result = string.match(l, "(ttyUSB[0-9]+)$")
    if result then
      if at_data == nil then at_data = result end
      local rv = at_helper.exec_at_cmd(result, "ATI", "10")
      local model = string.match(rv, "MODEL: .*")
      if model then
        at_ctrl = result
        break
      end
    end
  end
  f:close()
  return at_ctrl, at_data
end

local update_pin_uci_info = function (state, left_verify, left_unblock)

  print("update_pin_uci_info  :pin_status=", state, " left_veriy=", left_verify, " left_unblock=", left_unblock)

  if state == "READY" then
     print("call state_helper.update_Sim_Status (READY)" )
     state_helper.update_Sim_Status("READY")
  end
  if left_unblock == "0" then
     state_helper.update_Sim_Status("LOCKED")
  end


  log:info(string.format("===update_pin_uci_info==:pin_status:%s, retry_verify=%s, retry_unblock=%s", state , left_verify, left_unblock))

  uci_info["pin_verify_entries_left"]= left_verify
  uci_info["pin_unblock_entries_left"]= left_unblock

end

local function validate_UciConfig_pin()
  --[[
  -- when sim locked no need to give a pin code.
  if not mbd_uci_cfg_begin.sim or not mbd_uci_cfg_begin.sim.pin then
    state_helper.do_early_exit("PIN_REQUIRED", "Missing sim card config (pin)")
  end
  ]]

  if mbd_uci_cfg_begin.sim.pin then
    print("--validate pin code =", mbd_uci_cfg_begin.sim.pin,"=")
    pin=string.match(mbd_uci_cfg_begin.sim.pin,"%d%d%d%d")
    if pin ~= mbd_uci_cfg_begin.sim.pin then
      state_helper.do_early_exit("PIN_REQUIRED", "Invalid pin code (shall be 4 digits)")
    end
  end
end

local function validate_UciConfig_puk()
  if mbd_uci_cfg_begin.sim.puk then
    print("--validate puk code =", mbd_uci_cfg_begin.sim.puk,"=")
    puk = string.match(mbd_uci_cfg_begin.sim.puk,"%d%d%d%d%d%d%d%d")
    if puk ~= mbd_uci_cfg_begin.sim.puk then
      state_helper.do_early_exit("PUK_REQUIRED", "Invalid puk code (shall be 8 digits)")
    end
  end

end

local function validate_UciConfig()

  if not mbd_uci_cfg_begin.config.network then
    state_helper.do_early_exit("NETWORK_SELECT_REQUIRED", "Invalid config: config.network not set")
  end

  local v = mbd_uci_cfg_begin.config.network
  local network=mbd_uci_cfg_begin[ v ]
  if not network or mbd_uci_cfg_begin[ v ][".type"] ~= "mobile_network" then
    _print("mbd_uci_cfg_begin.config.network4=", v)
    _print("mbd_uci_cfg_begin[ v ]=", mbd_uci_cfg_begin[ v ])
    _print("mbd_uci_cfg_begin[ v ][\".type\"]=", mbd_uci_cfg_begin[ v ][".type"])
    state_helper.do_early_exit("APN_REQUIRED", "Invalid config: mobile_network not found")
  end
  -- workaround do_save_uci_section don't support hidden fields
  local netw = {}
  netw.apn= network.apn
  netw.ppp= network.ppp
  if network.username then netw.username=network.username end
  if network.password then netw.password=network.password end
  if network.authpref then netw.authpref=string.lower(network.authpref) end
  state_helper.do_save_uci_section("network", netw, true, "mobile_network")

  if not network.apn then
    state_helper.do_early_exit("APN_REQUIRED", "Missing mobile network config (APN)")
  end

  if not network.ppp then
    state_helper.do_early_exit("PPP_SELECT_REQUIRED", "Invalid config: missing mandatory mobile_network field (ppp)")
  end

  if network.ppp == "1" and
    (not network.username or not network.password) and
    mbd_uci_cfg_begin.config.network ~= "other" then
    state_helper.do_early_exit("PPP_AUTH_REQUIRED", "Invalid config: ppp username/password missing")
  end

  print("==== jwil mbd_uci_cfg_begin")
  tprint(mbd_uci_cfg_begin)
end

------------------------ START AT-SPECIFIC ------
local function at_check_sim_locked()
  rv = at_helper.exec_at_cmd(at_ctrl, "at+clck=\\\"sc\\\",2")
  tprint(rv)
  lock = string.match(rv, "+CLCK: 0")
  if lock then
     state_helper.update_Sim_Status("DISABLED")
     log:info("Sim card = DISABLED")
  end
  return lock
end


local function at_get_pin_status()
  local pin1_status, pin1_err, pin1_err, pin1_retry_verify, pin_retry_unblock
  local rv

  print(".... jwil : at_support_huawei_cmd=", at_support_huawei_cmd)


  rv = at_helper.exec_at_cmd(at_ctrl, "at+cpin?")
  tprint(rv)
  log:debug(string.format("at+cpin? :: rv=%s", rv))

  rv = at_helper.exec_at_cmd(at_ctrl, "at+cpinc?")
  tprint(rv)
  log:debug(string.format("at+cpinc? :: rv=%s", rv))
  pin1_left, pin2_left, puk1_left, puk2_left = string.match(rv, "+CPINC: (%d+),(%d),(%d+),(%d+)")
  if puk1_left and puk1_left == "0" then
     state_helper.update_Sim_Status("LOCKED")
  end
  if pin1_left and puk1_left then
    pin1_retry_verify = pin1_left
    pin_retry_unblock = puk1_left
  else
    pin1_retry_verify = "NA"
    pin_retry_unblock = "NA"
  end

  if at_support_huawei_cmd == nil then
    rv = at_helper.exec_at_cmd(at_ctrl, "at+cpin?")
    tprint(rv)
    log:debug(string.format("at+cpin? :: rv=%s", rv))

    pin1_status = string.match(rv, "+CPIN: ([A-Z ]+)")
    if pin1_status ~= nil then
      print("== non-huawei-cmd-pin1_status=" .. pin1_status .. "=")
    end


  else
    rv = at_helper.exec_at_cmd(at_ctrl, "at\^cpin?")
    log:debug(string.format("at\^cpin? :: rv=%s", rv))
    pin1_status = string.match(rv, "\^CPIN: ([A-Z ]+)")
    print("== huawei-cmd-pin1_status=", pin1_status)
  end

  if  pin1_status == "READY" then
     state_helper.update_Sim_Status("READY")
  end


  -- Huawei
  pin1_err = string.match(rv, "+CME ERROR: ([A-Z a-z]+)")
  if pin1_err ~= nil and pin1_err == 'SIM failure' then
        state_helper.do_early_exit("SIM_ERROR", "no sim card present")
  end

  -- ZTE
  local v = string.match(rv, "ERROR")
  if v ~= nil then
        state_helper.do_early_exit("SIM_ERROR", "no sim card present")
  end

  update_pin_uci_info(pin1_status, pin1_retry_verify, pin_retry_unblock)
  return pin1_status, pin1_err, pin1_retry_verify, pin_retry_unblock
end

local function at_verify_pin(pin)
   if not pin then
      state_helper.do_early_exit("PIN_REQUIRED", "Missing sim card config (pin)")
   end
   local rv = at_helper.exec_at_cmd(at_ctrl, "at+cpin=" .. pin)
   log:debug(string.format("rv=%s", rv))
--   tprint(rv)

    -- sequence error :
    -- set pin => ok
    -- at+cpin? => READY
    -- at+cpin=<wrong-pin> =>  +CME ERROR: operation not allowed
    --
  local pin_err= string.match(rv, "+CME ERROR: ([A-Z a-z0-9]+)")

  return  pin_err

end

local function at_unblock_pin( puk, pin )
  if not puk then
    state_helper.do_early_exit("PUK_REQUIRED", "Missing sim card config (puk)")
  end

  -- avoid puk lock of sim-card.
  local cursor = uci.cursor()
  assert(cursor:delete(MBD, "sim", "puk"))
  assert(cursor:commit(MBD))
  cursor:close()

  local rv = at_helper.exec_at_cmd(at_ctrl, string.format("at+cpin=%s,%s", puk, pin))
  --tprint(rv)
  log:debug(string.format("rv=%s", rv))

  local pin_err= string.match(rv, "+CME ERROR: ([A-Z a-z0-9]+)")

  if pin_err ~= nil then
      if pin_err == 'INCORRECT PASSWORD' or pin_err == '16' then
        state_helper.do_early_exit("PUK_REQUIRED", "Wrong puk code")
      end
  end

  if not string.match(rv, "OK") then
    state_helper.do_early_exit("SIM_ERROR", rv)
    -- sequence error :
    -- set pin => ok
    -- at+cpin? => READY
    -- at+cpin=<wrong-pin> =>  +CME ERROR: operation not allowed
    --
  end


end

local function at_do_pin( simcard )
  local card=simcard.sim

  at_device_ctrl=parm.at_ctrl
  print("@@@@jwil : at_device_ctrl=", at_device_ctrl)
  print ("====== do_pin ===== pin=", card.pin)
  tprint(simcard)

  local pin1_status, pin1_err = at_get_pin_status()
  print("pin1_status = ", pin1_status, " pin1_err=", pin1_err)

  if pin1_status == 'SIM PIN' then
    local pin_err = at_verify_pin( card.pin )
    print("==== result of at_verify_pin=", pin_err)
    if pin_err ~= nil then
      if pin_err == 'INCORRECT PASSWORD' or pin_err == '12' then
        state_helper.do_early_exit("PIN_REQUIRED", "Wrong pin code")
      elseif pin_err == 'SIM FAILURE' then
        state_helper.do_early_exit("SIM_ERROR", "no sim card present")
      elseif (pin_err == 'PINBLOCKED') or pin_err == 'SIM PUK REQUIRED' or pin_err == '16' then
        at_unblock_pin( card.puk,  card.pin)
        at_get_pin_status()
      else
         state_helper.do_early_exit("SIM_ERROR", "unknown cause " .. pin_err)
      end
    end
    local pin1_status = at_get_pin_status()
    if pin1_status == 'READY' then
       log:debug("== sim succesfull unlocked")
    else
       state_helper.do_early_exit("SIM_ERROR", "unknown cause : " .. pin1_status)
    end
  elseif  pin1_status == 'READY' then
    log:debug("== nothing to do already verified ")
  elseif pin1_status == 'SIM PUK' then
      at_unblock_pin( card.puk,  card.pin)
      at_get_pin_status()
  elseif  pin1_err ~= nil then
    if pin1_err == "SIM PUK REQUIRED" then
      at_unblock_pin( card.puk,  card.pin)
      at_get_pin_status()
    end
    if pin1_err == 'INCORRECT PASSWORD' then
      state_helper.do_early_exit("PIN_REQUIRED", "Wrong pin code")
    end

  else
    state_helper.do_early_exit("SIM_ERROR", pin1_status)
  end

  print(".... pin-checking finished...")
end


------------------------ END AT-SPECIFIC ------
--
------------------------ START QMI-SPECIFIC ------

local function exec_qmi_cmd(qmi_device, qmi_cmd)
        local result = {}
        local f = popen (string.format("qmicli -d /dev/%s %s 2>&1", qmi_device, qmi_cmd) )

        if f == nil then
                return result
        end

        -- parse line
        local qmi_output = f:read("*a")
        if (qmi_output == nil) then
                f:close()
                return {}
        end

 -- print("== jwil-raw :" .. qmi_output .. ": end jwil-raw ===")
  result=qmi_output

        f:close()
        return result
end

function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

local function set_uci_state_info(uci_field, rawinfo, search_pattern)
  local result = nil
  --[[
  print("DEBUG == set_uci_state_info : ", uci_field, "=",  result, "::\'", search_pattern, "\'")
  tprint(rawinfo)
  ]]
  for v in rawinfo:gmatch(search_pattern) do
    result=v
 --   print("------------- MBD=", MBD, " INFO=", INFO, " uci_field=", uci_field, " result=", result, " type=", type(result))

    if uci_info[uci_field] ~= nil then print("WARNING OVERWRITE:uci_info:[", uci_field, "]=", uci_info[uci_field]) end
    uci_info[uci_field]=tostring(result)
    print("NEW VALUE:uci_info:[", uci_field, "]=", uci_info[uci_field])
    break
  end

  --[[
  print("DEBUG == set_uci_state_info : ", uci_field, "=",  result, "::\'", search_pattern, "\'")
  print("DEBUG rawinfo ", uci_field, " === BEGIN")
  print(rawinfo)
  print("DEBUG rawinfo ", uci_field, " === END")
  ]]
  return result

end

local function qmi_get_pin_status()

  local rv = exec_qmi_cmd(parm.qmi_ctrl, "--dms-uim-get-pin-status")
  log:debug(string.format("--dms-uim-get-pin-status :: rv=%s", rv))

  local pin1_status, pin1_retry_verify, pin_retry_unblock =
    string.match(rv, "PIN1:\n%s+Status:%s+([a-zA-Z\-]+)\n%s+Verify:%s+(%d+)\n%s+Unblock:%s+(%d+)\n")
  log:info(string.format("pin_status:%s, retry_verify=%s, retry_unblock=%s", pin1_status, pin1_retry_verify, pin_retry_unblock))

  update_pin_uci_info(pin1_status, pin1_retry_verify, pin_retry_unblock)
  return pin1_status, pin1_retry_verify, pin_retry_unblock
end

local function qmi_verify_pin(pin)
    if not pin then
      state_helper.do_early_exit("PIN_REQUIRED", "Missing sim card config (pin)")
    end

   local rv = exec_qmi_cmd(parm.qmi_ctrl, "--dms-uim-verify-pin=PIN," .. pin)
   log:debug(string.format("rv=%s", rv))
   --tprint(rv)
   --
  local pin_err= string.match(rv, "\'(%w+)\'")
  local pin1_left_verify, pin_retry_left_unblock = string.match(rv, "Retries left:\n%s+Verify:%s+(%d+)\n%s+Unblock:%s+(%d+)")

  if pin_err ~= nil then
    log:info(string.format("pin_status:%s, retry_verify=%s, retry_unblock=%s", pin_err , pin1_left_verify, pin_retry_left_unblock))
    update_pin_uci_info(pin_err, pin1_left_verify, pin_retry_left_unblock)
  end
  return  pin_err

end

local function qmi_unblock_pin( puk, pin )
  if not puk then
    state_helper.do_early_exit("PUK_REQUIRED", "sim card.puk code ?")
  end

  -- avoid puk lock of sim-card.
  local cursor = uci.cursor()
  assert(cursor:delete(MBD, "sim", "puk"))
  assert(cursor:commit(MBD))
  cursor:close()

  local rv = exec_qmi_cmd(parm.qmi_ctrl, string.format("--dms-uim-unblock-pin=PIN,%s,%s", puk, pin))
  if not string.match(rv, "PIN unblocked successfully") then
    state_helper.do_early_exit("SIM_ERROR", rv)
  end

  --tprint(rv)
  log:debug(string.format("rv=%s", rv))

end

local function qmi_do_pin( simcard )
  local card=simcard.sim

  print ("====== do_pin ===== pin=", card.pin)
  tprint(simcard)

  local pin1_status = qmi_get_pin_status()

  print("pin1_status = " .. pin1_status)

  if pin1_status == 'enabled-not-verified' then
    local pin_err = qmi_verify_pin( card.pin )
    if pin_err ~= nil then
      if pin_err == 'IncorrectPin' then
        state_helper.do_early_exit("PIN_REQUIRED", "Wrong pin code")
      elseif pin_err == 'UimUninitialized' then
        state_helper.do_early_exit("SIM_ERROR", "no sim card present")
      elseif pin_err == 'PinBlocked' then
        qmi_unblock_pin( card.puk,  card.pin)
        qmi_get_pin_status()
      else
         state_helper.do_early_exit("SIM_ERROR", "unknown cause " .. pin_err)
      end
    end
  elseif  pin1_status == 'disabled' then
    log:debug("== pin code check disabled")
  elseif  pin1_status == 'enabled-verified' then
    log:debug("== nothing to do already verified ")
  elseif  pin1_status == 'blocked' then
    qmi_unblock_pin( card.puk,  card.pin)
    qmi_get_pin_status()
  else
    state_helper.do_early_exit("SIM_ERROR", pin1_status)
  end
end


local function do_clean_network_wwan( )
  local cursor_network = uci.cursor()
  local netw_wwan, err = cursor_network:get_all("network.wwan")
  assert(netw_wwan)
  if netw_wwan["ifname"] then
    for k, v in pairs(netw_wwan) do
        -- handle only non hidden keys
        if string.find(k, "^[^\.]") then
            cursor_network:delete("network", "wwan", k)
        end
    end

    cursor_network:set("network", "wwan", "auto", "0")
    cursor_network:commit("network")
    os.execute("/etc/init.d/network reload")
  end
  cursor_network:close()
end

-- Main code
--
print("jwil command line args : " )
tprint(arg)

MBD="mobiledongle"
INFO="info"

print("----- Init intial status .....")
mbd_uci_cfg_begin = assert(cursor:get_all(MBD))
tprint(mbd_uci_cfg_begin)  --> 1


state_helper.dump(mbd_uci_cfg_begin, "=111=", "=fg-init=")

if arg[1] == 'start' or arg[1] == 'stop' then

  print("----- Init intial status values.....", arg[1])
  log:info(string.format("init WAITING_FOR_DEVICE : %s", arg[1]))
  uci_info.device_name = "NA"
  state_helper.update_Link_Status("NA")
  state_helper.update_Device_Status("WAITING_FOR_DEVICE")
  state_helper.update_Sim_Status("NA")
  state_helper.update_Registration_Status("NA")
  state_helper.update_PPP_Status("NA")
  uci_info.state = "NA"
  uci_info.RSSI = "NA"
  uci_info.current_operator = "NA"
  uci_info.current_technology = "NA"
  uci_info.network = "NA"

  do_save_uci_info()
end

if mbd_uci_cfg_begin.config.enabled == '1' then
  log:info(string.format("Enabled"))
  state_helper.update_Link_Status("CONNECTING")
  do_save_uci_info()
end

--    state_helper.do_early_exit("PIN_REQUIRED", "Missing sim card config (pin)")
--    state_helper.do_early_exit("DEVICE_DISCONNECTED", "WAITING_FOR_DEVICE", "No Mobile Dongle detected")
--    state_helper.do_early_exit("NETWORK_SELECT_REQUIRED", "Invalid config")
--    state_helper.do_early_exit("APN_REQUIRED", "Invalid config")
--    state_helper.do_early_exit("APN_REQUIRED", "Missing mobile network config (APN)")
--    state_helper.do_early_exit("PPP_SELECT_REQUIRED", "Invalid config")
--    state_helper.do_early_exit("PPP_AUTH_REQUIRED", "Invalid config")
--    state_helper.do_early_exit("SIM_ERROR", "no sim card present")
--    state_helper.do_early_exit("PIN_REQUIRED", "Missing sim card config (pin)")
--    state_helper.do_early_exit("PUK_REQUIRED", "sim card.puk code ?")
--    state_helper.do_early_exit("SIM_ERROR", "no sim card present")
--    state_helper.do_early_exit("PUK_REQUIRED", "sim card.puk code ?")
--    state_helper.do_early_exit("DEVICE_DISCONNECTED",  "No Mobile Dongle detected")
-- state_helper.do_early_exit("DETECTION_FAILED", "Unknown dongle type")
                                                                                                                                                                 --

    ---------------------------------------------------

if arg[1] == 'stop' or  mbd_uci_cfg_begin.config.enabled == '0' then
  if mbd_uci_cfg_begin.info and mbd_uci_cfg_begin.info.link_status == "CONNECTED" then
    log:info(string.format("Disable => Link status=DISCONNECTING"))
    state_helper.update_Link_Status("DISCONNECTING")
    --print("--set wwan interface down")
    --rpc_ubus_ifdown("wwan")
  else
    log:info(string.format("Disable => Link status=NA"))
    state_helper.update_Link_Status("NA")
  end
  state_helper.update_Registration_Status("NA")
  state_helper.update_PPP_Status("NA")
  do_save_uci_info()
end

if (mbd_uci_cfg_begin.qmi_wwan == nil) and (mbd_uci_cfg_begin.option_ppp == nil) and
    (mbd_uci_cfg_begin.sierra_ppp == nil) and (mbd_uci_cfg_begin.huawei_ether == nil) then
    do_clean_network_wwan( )
    state_helper.do_early_exit("DEVICE_DISCONNECTED",  "No Mobile Dongle detected")
end

if mbd_uci_cfg_begin.config.enabled == '0' then
  print("--interface is DISABLED")
  log:info(string.format("set state=DISABLED"))
  state_helper.update_Link_Status("NA")
  state_helper.update_Registration_Status("NA")
  state_helper.update_PPP_Status("NA")
  uci_info.state = "NA"
  uci_info.RSSI = "NA"
  uci_info.current_operator = "NA"
  uci_info.current_technology = "NA"
  uci_info.state = "DISABLED"
  do_save_uci_info()
end

print("reload ...")
mbd_uci_cfg_begin = assert(cursor:get_all(MBD))
tprint(mbd_uci_cfg_begin)  --> 1

if mbd_uci_cfg_begin.config.enabled == '1' and
   (not mbd_uci_cfg_begin.info or mbd_uci_cfg_begin.info.state == 'DISABLED') then
    state_helper.update_Link_Status("NA")
    state_helper.update_Registration_Status("NA")
    uci_info.state = "NA"
    uci_info.RSSI = "NA"
    uci_info.current_operator = "NA"
    uci_info.current_technology = "NA"
    do_save_uci_info()
end

print("--Check if uci parm exist =", mbd_uci_cfg_begin.parm)
-- set derived Parms
if not mbd_uci_cfg_begin.parm then
  local M={}
  if mbd_uci_cfg_begin.qmi_wwan then
    state_helper.update_Device_Status("CONNECTING")
    do_save_uci_info()
    M.dongle_type='qmi_wwan'
    --M.network='wwan_ppp'
    M.network='wwan_eth'

    -- Huawei MODEL: E392
    M.at_data=get_usedTTY("Prot=01")
    M.at_ctrl=get_usedTTY("Prot=02")
    if M.at_ctrl == nil  then
      -- vendor propriery protocol used "Prot=ff"
      M.at_ctrl='ttyUSB2'
      M.at_data='ttyUSB3'
    end

    M.qmi_ctrl='cdc-wdm0'
    M.eth_data='wwan0'
    do_pin = qmi_do_pin -- update indirect function call
    do_updateNetworkConfig = nil -- network config should be right.
  elseif mbd_uci_cfg_begin.huawei_ether then
    state_helper.update_Device_Status("CONNECTING")
    do_save_uci_info()
    M.dongle_type='huawei_ether'
    M.network='wwan_eth'
    M.at_data=nil
    M.qmi_ctrl=nil
    M.qmi_data=nil
    M.at_ctrl=get_usedTTY("Prot=12")
    if M.at_ctrl == nil then
      -- Fall back
      -- Huawei MODEL: E3131
      M.at_data=get_usedTTY("Prot=01")
      M.at_ctrl=get_usedTTY("Prot=02")
      if M.at_ctrl == nil  then
        -- vendor propriery protocol used "Prot=ff"
        M.at_ctrl='ttyUSB2'
        M.at_data='ttyUSB3'
      else
       -- overrule dongle  ytype
        M.dongle_type='option_ppp'
        M.network='wwan_ppp'
      end
    end
                                                          --
    do_pin = at_do_pin -- update indirect function call
  elseif mbd_uci_cfg_begin.option_ppp then
    state_helper.update_Device_Status("CONNECTING")
    do_save_uci_info()
      _print("ZTE 3G ALWAYS PPP startup")
    M.dongle_type='option_ppp'
    M.network='wwan_ppp'
    --M.at_ctrl='ttyUSB1'
    --M.at_data='ttyUSB0'
    --M.at_ctrl='ttyUSB1'
    --M.at_data='ttyUSB2'
    M.qmi_ctrl=nil
    M.at_ctrl, M.at_data = get_usedTTYByAll();
    if M.at_ctrl == nil then return end
    do_pin = at_do_pin -- update indirect function call
  elseif mbd_uci_cfg_begin.sierra_ppp then
    state_helper.update_Device_Status("CONNECTING")
    do_save_uci_info()
    print("Sierra Wireless wwan startup")
    M.dongle_type='sierra_wwan'
    M.network='wwan_eth'
    M.at_ctrl='ttyUSB2'
    M.at_data='ttyUSB3'
    M.qmi_ctrl=nil
    M.qmi_data=nil
    do_pin = at_do_pin -- update indirect function call
  else
      state_helper.do_early_exit("DETECTION_FAILED", "Unknown dongle type")
  end

  print("@@@@ dongle config")
  tprint(M)

  do_save_uci_parm(M)

  --[[
  assert(cursor:get_all(MBD))
  print("--print reload after parm update parm=", mbd_uci_cfg_begin.parm)
  tprint(mbd_uci_cfg_begin)  --> 1
  ]]
  mbd_uci_cfg_begin = state_helper.do_load_uci_state_var(true, "reload after parm init")
  print("--create parm=", mbd_uci_cfg_begin.parm)
  parm=assert(mbd_uci_cfg_begin.parm)
end


print("--create parm=", mbd_uci_cfg_begin.parm)
parm=assert(mbd_uci_cfg_begin.parm)
print("--create at_ctrl=", parm.at_ctrl)
at_ctrl=assert(parm.at_ctrl)


print("@@@ jwil : reread the mbd_uci_cfg_begin=")
tprint(mbd_uci_cfg_begin)

  callTbl =
  {
    [ "qmi_wwan" ] =
    {
      [ "do_pin" ] = at_do_pin  -- qmi_do_pin
    },
    [ "sierra_wwan" ] =
    {
      [ "do_pin" ] = at_do_pin
    },
    [ "huawei_ether" ] =
    {
      [ "do_pin" ] = at_do_pin
    },
    [ "option_ppp"] =
    {
      [ "do_pin" ] = at_do_pin
    },
    ["sierra_ppp"] =
    {
      [ "do_pin" ] = at_do_pin
    }
  }

--print("@@@jwil: callTbl=")
--tprint(callTbl)

print("--Check if uci cardinfo exist =", mbd_uci_cfg_begin.cardinfo)
if not mbd_uci_cfg_begin.cardinfo and at_ctrl  then
  local M={}

  -- enable echo => "ATE"
  --dummy cmd to sync the port E392
  local v=at_helper.exec_at_cmd(parm.at_ctrl, "AT")
  local v=at_helper.exec_at_cmd(parm.at_ctrl, "ATI")
  _print("cardinfo=", v)
  M.Manufacturer=string.match(v, "MANUFACTURER: ([^\n]+)\n")
  M.Model=string.match(v, "MODEL: ([^\n]+)\n")
  M.Revision=string.match(v, "REVISION: ([^\n]+)\n")
  M.IMEI=string.match(v, "IMEI: ([^\n]+)\n")
  M.IMEI_SV=string.match(v, "IMEI SV: ([^\n]+)\n")
  M.FSN=string.match(v, "FSN: ([^\n]+)\n")
  M.GCAP=string.match(v, "+GCAP: ([^\n]+)\n")

  -- Start interop device_name

  -- M9200B
  if M.Model == '0' and M.Manufacturer == "QUALCOMM INCORPORATED" and M.Revision then
    local m = string.match(M.Revision, "^([%d%u]+)\-")
    if m then M.Model=m end
  end

  -- ZTE MODEL: +CGMM: "MF821"
  if M.Model then
    local m = string.match(M.Model, "+CGMM: \"(%u+%d+)")
    if m then M.Model=m end
  end

  -- END interop device_name

  if M.Model then
    uci_info.device_name = M.Model
  end

  print("cardinfo === parsed info @@@@@@@@@@@@@@@@@@@@@@")
  tprint(M)

  do_save_uci_cardinfo(M)

  uci_info.device_status = "CONNECTED"
  do_save_uci_info()
end


if mbd_uci_cfg_begin.sim then
  print("--validate pin and puk code")
-- validate config and do early exit!
  validate_UciConfig_pin()
  validate_UciConfig_puk()
end

if at_ctrl and (
   not mbd_uci_cfg_begin.sim  or
   (mbd_uci_cfg_begin.sim.status ~= "DISABLED" and
    mbd_uci_cfg_begin.sim.status ~= "READY")) then

  if not at_check_sim_locked() then
    do_pin = callTbl[ parm.dongle_type ].do_pin
    assert(do_pin)
    if do_pin then
      log:info("verify pin")
      local state, err = do_pin { sim=mbd_uci_cfg_begin.sim }  -- check and sed pincde
      if state then
        state_helper.do_early_exit(state, err)
      end
      log:info("verify pin done")
    end
  end
end

do_save_uci_info()

print("--start validate UciConfig")
-- validate config and do early exit!
validate_UciConfig()
print("--end validate UciConfig")


local function send_bg_msg(action)
  local sk = unix.dgram(unix.SOCK_CLOEXEC)
  assert(sk:connect("/var/run/mobiledongle_cmd"))
  sk:send(action)
  -- msg=assert(sk:recv())
end

send_bg_msg(arg[1])

--end

