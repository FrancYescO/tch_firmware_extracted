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
local u = require ("ubus")
local uloop = require('uloop')
local async = require('mobiledongle/bg_async')
local _print = print
local cursor = uci.cursor(nil, "/var/state")
local cursor_network = uci.cursor()
local logger = require 'transformer.logger'
logger.init(6, false)
local log = logger.new("mobiledongle", 5) -- 3
local unix = require("tch.socket.unix")
--local sk = unix.dgram(unix.SOCK_NONBLOCK)
local sk = unix.dgram(unix.SOCK_CLOEXEC)
assert(sk:bind("/var/run/mobiledongle_cmd"))


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

local mbd_uci
local parm
local at_ctrl
local uci_info= {}       -- the mobiledongle uci info section
local conn = ubus.connect()

local wwan={}
local mbd_netw_persist={}

MBD="mobiledongle"
INFO="info"

local maxLogSize = 1048576 --1MB

function print (...)
  -- _print( ...)
  if mbd_uci == nil or
    mbd_uci.config.log == "0" then
    return nil
  end

  local filesize = 0
  local filename = "/root/mobiledongle/bg.log"
  local filename_old = "/root/mobiledongle/bg_old.log"
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


function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

local function event_cb(event)
  log:info(string.format("=== event_cb"))
  print("=== event_cb")
  print("=== event_cb", event)
  tprint(event)

  if event == "network_device_wwan_up" then
    log:info(string.format("DATA_SESSION_ACTIVE"))
    uci_info.state = "DATA_SESSION_ACTIVE"
    state_helper.do_save_uci_info(uci_info)
    --cursor:set(MBD, INFO, "state", "DATA_SESSION_ACTIVE")
    --cursor:save(MBD)
  end

  if event == "network_device_wwan_up"     or event == "timeout" then
    print("=== stop timer and close the uloop ...")
    _print("=== stop timer and close the uloop ...")
    async.timerstop()
    uloop.close()
  end
  --[[
     nState = states[cState]:update(event)

     if l2states[nState] then
     -- continue on level 2
       states=l2states
     elseif l3states[nState] then
     -- continue on level 3
       states=l3states
     else
       return
     end

     -- entering a new state ?
     if nState ~= cState then
       cState = nState
       states[cState]:entry()
       washelper.initmode_save(x, cState)
     end
     ]]
end


local function rpc_ubus_get_status(itf)
    local conn = assert(ubus.connect())
    netw_wwan = assert(string.format("network.interface.%s", itf))
    print("===== wwan=", netw_wwan)
    local status = conn:call(netw_wwan, "status", { })
    conn:close()
    return status
end

local function rpc_ubus_ifdown(itf)
    --log:error(string.format("ifdown[%s]%s", parm.network,itf))
    netw_wwan = assert(string.format("network.interface.%s", itf))
    local conn = assert(ubus.connect())
    print("rpc_ubus_ifdown=", netw_wwan, " itf=", itf)
    conn:call(netw_wwan, "down", { } )
    conn:close()

    return rpc_ubus_get_status(itf)
end

local function rpc_ubus_ifup(itf)
    --log:error(string.format("ifup[%s]%s", parm.network, itf))
    local conn = assert(ubus.connect())
    netw_wwan = assert(string.format("network.interface.%s", itf))
    print("rpc_ubus_ifup=", netw_wwan, " itf=", itf)
    conn:call(netw_wwan, "up", { } )
    conn:close()

    return rpc_ubus_get_status(parm.network)
end


local function do_reload_network(tag)
        local result = {}

        local f = popen ("/etc/init.d/network reload 2>&1" )

assert(f)

        if f == nil then
                return result
        end

        -- parse line
        local cli_output = f:read("*a")
        if (cli_output == nil) then
                f:close()
                return {}
        end

	_print(tag, " ==== ", cli_output)

  result=cli_output

        f:close()
        return result
end

local function do_clean_network_wwan( )
  local cursor_network = uci.cursor()

  local netw_wwan, err = cursor_network:get_all("network.wwan")
  tprint("network.wwan === precond do_clean_network_wwan")
  tprint(netw_wwan)
  assert(netw_wwan)

  for k, v in pairs(netw_wwan) do
    -- handle only non hidden keys
    if string.find(k, "^[^\.]") then
      cursor_network:delete("network", "wwan", k)
    end
  end

  cursor_network:set("network", "wwan", "auto", "0")
  cursor_network:commit("network")
  cursor_network:close()

  local cursor_network = uci.cursor()
  local netw_wwan, err = cursor_network:get_all("network.wwan")
  tprint("network.wwan === postcond do_clean_network_wwan")
  tprint(netw_wwan)
  assert(netw_wwan)
  cursor_network:close()

  print("==clean============== reload network.wwan ===== ")
  os.execute("/etc/init.d/network reload > /tmp/jwil")

end

local function do_add_network_wwan( )
  local cursor_network = uci.cursor()
  local tmpl = {}

  tprint("network.wwan === precond parm.network=", parm.network)
  log:info(string.format("do_add_network_wwan netw=%s ppp=%s", parm.network, mbd_uci.network.ppp))

  if parm.network == "wwan_eth" or "wwan_eth_dhcp" then
    assert(mbd_uci.wwan_eth_dhcp)
    tmpl=mbd_uci.wwan_eth_dhcp
  end

  if parm.network == "wwan_ppp" then
    assert(mbd_uci.wwan_ppp)
    tmpl=mbd_uci.wwan_ppp
  end

  for k, v in pairs(tmpl) do
    -- handle only non hidden keys
    if string.find(k, "^[^\.]") then
      cursor_network:set("network", "wwan", k, v)
    end

  end

  if parm.network == "wwan_ppp" then
      local device_name = string.format("/dev/%s", mbd_uci.parm.at_data)
      cursor_network:set("network", "wwan", "apn", mbd_uci.network.apn)
      cursor_network:set("network", "wwan", "device", device_name)
      --[[ --Sierra 4G telstra dongle will not work
      cursor_network:set("network", "wwan", "pincode", mbd_uci.sim.pin)
      ]]

    if mbd_uci.network.ppp == '1' and mbd_uci.network.password and mbd_uci.network.username then
        log:info(string.format("Set PPP username/password"))
        cursor_network:set("network", "wwan", "username", mbd_uci.network.username)
        cursor_network:set("network", "wwan", "password", mbd_uci.network.password)
    end
  end

  cursor_network:commit("network")
  cursor_network:close()

  local cursor_network = uci.cursor()
  local netw_wwan, err = cursor_network:get_all("network.wwan")
  tprint("network.wwan === postcond do_add_network_wwan")
  tprint(netw_wwan)
  assert(netw_wwan)

  log:info(string.format("Reload network wwan config is changed"))
  print("==add============== reload network.wwan ===== ")
  _print("===add============= reload network.wwan ===== ")
  --os.execute("/etc/init.d/network reload")
  local i=0
--  repeat
     i=i+1
     do_reload_network(string.format("==== %d ===", i))
     local rv = rpc_ubus_get_status("wwan")
     if rv.proto == "none" or rv.available == "false" then
	log:warning(string.format("Failed : Reload network wwan config is changed"))
        sleep(2)
     end
_print(".... rv.proto=", rv.proto, " rv.available=", rv.available)
--  until (rv.proto ~= "none" and rv.available == "true") or i > 10


end

------------------------ START AT-SPECIFIC ------

local function at_get_info()

  local rv = at_helper.at_info_cmd(at_ctrl,"at+cgdcont=?")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cgdcont?")

end

decode_copstech_mode = {
  [ "0" ] = "2G",
  [ "2" ] = "3G",
  [ "7" ] = "4G"
}

decode_mode = {
  [ "0" ] = "AUTOMATIC",
  [ "1" ] = "MANUAL"
}

local function at_get_current_cops(s)
  local mode, oper_full, oper_short, oper_code, AcT
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops=3,0")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops?")
  if rv then
      mode, oper_full, AcT = string.match(rv, "+COPS: (%d+),0,\"([%P%C%Z]+)\",([0-7]+)")
  end

  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops=3,1")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops?")
  if rv then
      mode, oper_short, AcT = string.match(rv, "+COPS: (%d?),1,\"([%P%C%Z]+)\",([0-7]+)")
  end
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops=3,2")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops?")
  if rv then
      mode, oper_code, AcT = string.match(rv, "+COPS: (%d?),2,\"(%d+)\",([0-7]+)")
  end
  print("decode +cops=", mode, decode_mode[ mode ], oper_full, oper_short,oper_code,AcT, decode_copstech_mode [ AcT ])
  return decode_mode[ mode ], oper_full, oper_short, oper_code, decode_copstech_mode [ AcT ]
end


local function at_analyse_cops(s)
  local home_netw = ""
  local roaming_netw = ""
  local unknown_netw = ""
  local netw_home_code
  local current_netw_code
  local scops
  for l in s:gmatch("[^\n]*") do
      print(l.."|");
      scops=string.match(l, "+COPS: ([^\n]*)")
      if scops then
        break
      end
  end

  print("scops found =", scops)
  _print("scops found =", scops)
  if scops then
    for w in string.gmatch(scops, "\([0,1,2]+,[^,]+,[^,]+,[^,]+[,]?[0-7]?\)") do
        _print("w=", w)
        local mode, lstring, sstring, code, Act = string.match(w, "(%d+),\"([%P%C%Z]+)\",\"([%P%C%Z]+)\",\"(%d+)\"[,]?([0-7]?)")
        _print("mode=", mode, " lstring=", lstring, " sstring=", sstring, " code=", code, " AcT=", Act)
        print("mode=", mode, " lstring=", lstring, " sstring=", sstring, " code=", code, " AcT=", Act)
        if not home_code then
          home_code = code
        end

        if mode ~= nil and ( mode == "0" or mode == "1" or mode == "2") then
          if home_code == code then
            home_netw = string.format("%s;%s=%s", home_netw, code, decode_copstech_mode[Act])
          else
            roaming_netw = string.format("%s;%s=%s", roaming_netw, code, decode_copstech_mode[Act])
          end
        end


        if mode == nil then
          break
        elseif mode == "2"  then
          current_netw_code=code
        end
    end

    print("... home_netw=", home_netw)
    print("... roaming_netw=", roaming_netw)
    print("=== at_analyse_cops=", current_netw_code)
    local cursor_netw = uci.cursor()
    cursor_netw:set(MBD, "network", "home", tostring(home_netw))
    cursor_netw:set(MBD, "network", "roaming", tostring(roaming_netw))
    cursor_netw:commit(MBD)
    cursor_netw:close()

    mbd_netw_persist = state_helper.do_load_uci_persist(true, "reload after home/roaming network init")
    -- tprint(mbd_netw_persist)
    -- os.exit(1)
     if  mbd_netw_persist.network.home then
       print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.home)
     end
     if  mbd_netw_persist.network.roaming then
       print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.roaming)
     end
     --[[
     if  mbd_netw_persist.network.unknown then
       print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.unkown)
     end
     ]]

  end
  return current_netw_code

end

local function at_search_networks()
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cops=?")
  return at_analyse_cops(rv)
end

at_tech_mode = {
  [ "2G" ] = "0",
  [ "3G" ] = "2",
  [ "4G" ] = "7"
}

local function verify_valid_network()
    local valid
    local i=1
    while mbd_uci.config.operator_code_list[i] and not valid  do
      _print("#@#@#@#@ operator_code=", mbd_uci.config.operator_code_list[i], " uci_info.current_operator=", uci_info.current_operator)
      if uci_info.current_operator and uci_info.current_operator == mbd_uci.config.operator_code_list[i] then
        _print("#@#@#@#@ verify_valid_network=", uci_info.current_operator, mbd_uci.config.operator_code_list[i], i)
        valid = true
      end
      i=i+1
    end
    return valid
end

local function at_set_tech_mode(network_code)
  tprint("-- at_set_tech_mode")
  tprint(at_tech_mode)
  local at_cmd
  local tech_mode= at_tech_mode [ mbd_uci.config.requested_technology ]
  if mbd_uci.config.operator_mode == "AUTOMATIC"  then
    at_cmd="at+cops=0"
  elseif not at_tech_mode then
    state_helper.update_Registration_Status("TECH_ERROR")
    at_cmd="at+cops=2" -- deregister from network
  else
    if mbd_uci.config.operator_mode == "AUTOMATIC" and
       mbd_uci.config.requested_operator then
       print("--at_set_tech_mode:: requested_operator=", requested_operator, " network_code=", network_code)
       network_code = mbd_uci.config.requested_operator
     end

    print("===AT=========================== tech_mode=", mbd_uci.config.operator_mode, " tech_mode=",  tech_mode, " network_code=", network_code)
    _print("===AT=========================== tech_mode=", mbd_uci.config.operator_mode, " tech_mode=",  tech_mode, " network_code=", network_code)
    if tech_mode then
      at_cmd = string.format("at+cops=1,2,\\\"%s\\\",%s", network_code, tech_mode)
    else
      at_cmd = string.format("at+cops=1,2,\\\"%s\\\"", network_code)
    end
    _print("============================== tech_mode=", mbd_uci.config.operator_mode, " tech_mode=",  tech_mode, " at_cmd=", at_cmd)
    print("============================== tech_mode=", mbd_uci.config.operator_mode, " tech_mode=",  tech_mode, " at_cmd=", at_cmd)
  end

  local rv = at_helper.at_info_cmd(at_ctrl,at_cmd)
  local error = string.match(rv, "+CME ERROR: ([A-Z a-z]+)")
  local OK = string.match(rv, "OK")
  print("--at_set_tech_mode: return code ok=", OK, " error=", error)
  return ok, error
end

local function at_sierra_getActState ()
  local rv = at_helper.at_info_cmd(at_ctrl,"at!scact?1")
  local state=string.match(rv, "!SCACT: 1,(%d+)")
  if state == nil then
    _print("NIL : Sierra LinkState=", rv)
    state=0
  end
  _print("Sierra LinkState=", state)
  return state
end

local function at_sierra_disableLink ()
  local rv = at_helper.at_info_cmd(at_ctrl,"at!scact=0,1")
end

local function at_sierra_enableLink()
  at_get_current_cops(s)
  --[[
  _print("...... start searching networks")
  at_search_networks()
  _print("...... start searching networks ++++ DONE")
  at_set_tech_mode()
  ]]

  local rv = at_helper.at_info_cmd(at_ctrl,"AT!SELRAT=?")
  local rv = at_helper.at_info_cmd(at_ctrl,"AT!SELRAT?")
  local rv = at_helper.at_info_cmd(at_ctrl,"AT+cpin?")
--  at_sierra_set_tech_mode ()

  local cmd=string.format("at+cgdcont=1,\\\"IP\\\",\\\"%s\\\"", mbd_uci.network.apn )
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\\\$QCPDPP=?"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\\\$QCPDPP?"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd
  if mbd_uci.network.ppp == '1' and mbd_uci.network.password and mbd_uci.network.username then
    state_helper.update_PPP_Status("CONNECTING")
    state_helper.do_save_uci_info(uci_info)
    local auth_type = "2" -- default  CHAP
    if mbd_uci.network.authpref then
       local authpref = mbd_uci.network.authpref
       if authpref == "pap" then
	       auth_type="1"
       elseif authpref == "chap" then
	        auth_type="2"
       end
    end
    cmd=string.format("at\\\$QCPDPP=1,%s,\\\"%s\\\",\\\"%s\\\"", auth_type, mbd_uci.network.password, mbd_uci.network.username)
    log:info("Enable network authentication")
  else
    state_helper.update_PPP_Status("NA")
    cmd="at\\\$QCPDPP=1,0"
    log:info("Disable network authentication")
  end
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\\\$QCPDPP?"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="at!scdftprof=1"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  -- default disable profile
  local cmd="at!scprof=1,\\\" \\\",0,0,0,0"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local rv = at_helper.at_info_cmd(at_ctrl,"at+cfun?")
  local state_radio =string.match(rv, "+CFUN: (%d+)")
  print("--at_sierra_enableLink: state_radio=", state_radio, " rv=", rv)

  if  state_radio == "0" then
    print ("Enable radio")
    -- enable radio
    local cmd="at+cfun=1"
    local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
    tprint(rv)
    log:debug(string.format("%s :: rv=%s", cmd, rv))

    local rv = at_helper.at_info_cmd(at_ctrl,"at+cfun?")
    local state_radio =string.match(rv, "+CFUN: (%d+)")
    print("--at_sierra_enableLink: state_radio=", state_radio, " rv=", rv)
    local i=0
    repeat
      local rv = at_helper.at_info_cmd(at_ctrl,"at+cgatt?")
      local state_attach =string.match(rv, "+CGATT: (%d+)")
      print("i=",i, " state_attach=", state_attach)
      if state_attach == "1" then
        break
      end
      sleep("1")
      i=i+1
    until i > 60

  else
    print ("Radio is active")
  end

  local cmd="at!scact=1,1"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local error = string.match(rv, "+CME ERROR: ([A-Z a-z]+)")
  local OK = string.match(rv, "OK")
  print("--at_sierra_enableLink: return code ok=", OK, " error=", error)

  if mbd_uci.network.ppp == '1' then
    if OK then
      state_helper.update_PPP_Status("CONNECTED")
    else
      state_helper.update_PPP_Status("ERROR")
    end
  else
    state_helper.update_PPP_Status("NA")
  end

  if OK then
    log:info(string.format("--Sierra REGISTERED "))
  else
    state_helper.update_Registration_Status("UNKNOWN")
  end

  at_get_current_cops(s)
  local rv = at_helper.at_info_cmd(at_ctrl,"AT!SELRAT?")
end

local function at_huawei_getActState ()
  log:info(string.format("at_huawei_getActState"))
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "ATI")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at\^curc=0")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+cgreg?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+creg?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+cfun?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+cgact?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+cgatt?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at+cgdcont?")


  local cmd="AT\^SYSINFO"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\^SYSINFOEX"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local rv = at_helper.at_info_cmd(at_ctrl,"at\^ndisstatqry?")
--  local state=string.match(rv, "\\\^NDISSTATQRY: (%d+),")
--  search failed => why don't work special char ^
  local state=string.match(rv, "NDISSTATQRY: (%d+),")
  if state == nil then
    _print("NIL : Huawei LinkState=", rv)
    log:info(string.format("NIL : Huawei LinkState=%s",rv))
    state='0'
  end
  _print("Huawei LinkState=", state)
  return tostring(state)
end

local function at_huawei_disableLink ()
  log:info(string.format("at_huawei_disableLink"))
  local rv = at_helper.at_info_cmd(at_ctrl,"at\^ndisdup=1,0")
end

local function at_huawei_enableLink()
  log:info(string.format("at_huawei_enableLink"))
  at_get_current_cops(s)
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at\^dialmode?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at\^syscfgex?")
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, "at\^syscfgex=?")

  local cmd=string.format("at+cgdcont=1,\\\"IP\\\",\\\"%s\\\"", mbd_uci.network.apn )
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local auth_cmd = string.format(",\\\"%s\\\"",mbd_uci.network.apn)
  local auth_type = ""

  if mbd_uci.network.ppp == '1' and mbd_uci.network.password and mbd_uci.network.username then
    auth_cmd = string.format(",\\\"%s\\\",\\\"%s\\\",\\\"%s\\\"",mbd_uci.network.apn,mbd_uci.network.username,mbd_uci.network.password)
    if mbd_uci.network.authpref then
       local authpref = mbd_uci.network.authpref
       if authpref == "pap" then
	  auth_type=",1"
       elseif authpref == "chap" then
	  auth_type=",2"
       end
    end
  end

  local cmd="at\^ndisdup=1,1" .. auth_cmd .. auth_type
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local error = string.match(rv, "+CME ERROR: ([A-Z a-z]+)")
  local OK = string.match(rv, "OK")
  print("--at_sierra_enableLink: return code ok=", OK, " error=", error)

  if mbd_uci.network.ppp == '1' then
    if OK then
      state_helper.update_PPP_Status("CONNECTED")
    else
      state_helper.update_PPP_Status("ERROR")
    end
  else
    state_helper.update_PPP_Status("NA")
  end

  if OK then
    log:info(string.format("--huawei REGISTERED "))
  else
    state_helper.update_Registration_Status("UNKNOWN")
  end

  local cmd="AT\^SYSINFO"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\^SYSINFOEX"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  local cmd="AT\^ndisstatqry?"
  local rv = at_helper.exec_at_cmd(parm.at_ctrl, cmd)
  tprint(rv)
  log:debug(string.format("%s :: rv=%s", cmd, rv))

  at_get_current_cops(s)
end

local function at_update_radio_quality()
  local rv = at_helper.at_info_cmd(at_ctrl,"at+csq")
  local rssi, ber =string.match(rv, "+CSQ: (%d+),(%d+)")
  if not rssi then
    rssi, ber =string.match(rv, "+csq: (%d+),(%d+)")
  end
   --_print("#@#@#@# Radio signal quality rssi=", rssi, " ber=", ber)
   local SignalQual
   if rssi then
     uci_info.rssi=rssi
     local rssi = tonumber(rssi)
     if rssi < 2 then
       uci_info.RadioSignalQualValue="1"
       uci_info.RadioSignalQualName="poor"
     elseif rssi <= 9 then
       uci_info.RadioSignalQualValue="2"
       uci_info.RadioSignalQualName="weak"
     elseif rssi <= 14 then
       uci_info.RadioSignalQualValue="3"
       uci_info.RadioSignalQualName="fair"
     elseif rssi <= 19 then
       uci_info.RadioSignalQualValue="4"
       uci_info.RadioSignalQualName="good"
     elseif rssi <= 31 then
       uci_info.RadioSignalQualValue="5"
       uci_info.RadioSignalQualName="excellent"
     elseif rssi == 99 then
       uci_info.RadioSignalQualValue="0"
       uci_info.RadioSignalQualName="unknown"
     else
       uci_info.RadioSignalQualValue="0"
       uci_info.RadioSignalQualName="unknown"
     end

     local rssi_dbm=(rssi*2)-113
     uci_info.RSSI=string.format("%s dBm", rssi_dbm)

    log:info(string.format("Radio signal quality Rssi=%s SignalQual=%s : %s rssi=%s",
      rssi, uci_info.RadioSignalQualValue, uci_info.RadioSignalQualName, uci_info.RSSI))
    --  _print("#@#@#@# Radio signal quality rssi=", rssi, " ber=", ber, "SignalQual=", uci_info.RadioSignalQualValue, uci_info.RadioSignalQualName)
   end
end

local function at_extern_3g_ppp_status()
   -- shall be replace with L2 actions
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cfun?")
  local state_radio =string.match(rv, "+CFUN: (%d+)")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cgatt?")
  local state_attach =string.match(rv, "+CGATT: (%d+)")
  if not state_attach then
     state_attach='0'
  end

   local state_itf
   local netw_status=rpc_ubus_get_status("wwan")
   print("precond:at_extern_3g_ppp_status")
   tprint(netw_status)

   if netw_status.proto ~= "3g" then
     state_itf='0'
   else
     state_itf='1'
   end

   if state_itf == '1' and state_radio == '1' and state_attach == '1' then
     state= '1'
   else
     state= '0'
   end

  print("PPP 3g LinkState=", state, " state_radio=", state_radio, " state_attach=", state_attach, " state_itf=", state_itf)
  _print("PPP 3g LinkState=", state, " state_radio=", state_radio, " state_attach=", state_attach, " state_itf=", state_itf)
  return state
end
local function at_extern_3g_ppp_disableLink ()
  -- disable radio
  --local rv = at_helper.at_info_cmd(at_ctrl,"at+cfun=0")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cgatt=0")
end
local function at_extern_3g_ppp_enableLink ()
  -- enable radio
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cfun=1")
  local rv = at_helper.at_info_cmd(at_ctrl,"at+cgatt=1")
end


------------------------ END AT-SPECIFIC ------

-- -----------------------------
-- Start qmi specific code -----
-- -----------------------------
--

------------------------ START QMI-SPECIFIC ------
--
local qmi_data = {}

local function qmi_getActState ()
  local state
  if  uci_info.conn_status == "connected" then
    state="1"
  else
    state="0"
  end
  return state
end


local function exec_qmi_cmd(qmi_device, qmi_cmd)
        local result = {}
  print ("--exec_qmi_cmd cmd=", qmi_cmd)

        assert(qmi_device == "cdc-wdm0")
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

  print("--exec_qmi_cmd result=" .. qmi_output .. ":== end ===")
  result=qmi_output

        f:close()
        return result
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

local function qmi_update_conn_status()
  local conn_status = exec_qmi_cmd(parm.qmi_ctrl, "--wds-get-packet-service-status")
  print(conn_status)

  local v=set_uci_state_info("conn_status", conn_status, "'(%a+)\'")
  return v
end

local function qmi_reset_uci_conn_parms()
   uci_info.CID = nil
   uci_info.PDH = nil
end


local function qmi_clear_conn_context(cid)
    print("clear connect CID=", cid)
    if cid then
      local v = exec_qmi_cmd(parm.qmi_ctrl, "--wds-noop --client-cid=" .. cid)
      tprint(v)
      qmi_reset_uci_conn_parms()
    end
end

qmi_tech_mode = {
  [ "AUTOMATIC" ] = "ANY",
  [ "2G" ] = "GSM",
  [ "3G" ] = "UMTSGSM",
  [ "4G" ] = "LTE"
}

local function qmi_do_connect()
  local vj = nil
  local cid = nil
  local phd = nil
  local APN = mbd_uci.network.apn

  local v=qmi_update_conn_status()
  _print("======== jwil ==== conn_status=", v)

  if v == "disconnected" then

    -- check if there are no internal errors if so then reset
    if uci_info ~= nil then qmi_clear_conn_context(uci_info.CID) end

    local apn_auth=""
    if mbd_uci.network.ppp == '1' and mbd_uci.network.password and mbd_uci.network.username then
        state_helper.update_PPP_Status("CONNECTING")
        state_helper.do_save_uci_info(uci_info)
        local auth_type = "BOTH" -- default
        if mbd_uci.network.authpref then
           local authpref = mbd_uci.network.authpref
           if authpref == "pap" then
             auth_type="PAP"
           elseif authpref == "chap" then
              auth_type="CHAP"
           end
        end
        apn_auth=string.format(",%s,%s,%s", auth_type, mbd_uci.network.username, mbd_uci.network.password)
        log:info("Config network authentication (%s)", auth_type)
    else
        state_helper.update_PPP_Status("NA")
        state_helper.do_save_uci_info(uci_info)
    end

    for i = 1, 2 do

      print("==1===== connection start iter=", i)
      vj = exec_qmi_cmd(parm.qmi_ctrl, "--wds-start-network=" .. APN .. apn_auth .. " --client-no-release-cid")
      print("==2===== connection start iter=", i)
      tprint(vj)
      err=set_uci_state_info("connection_error", vj, "error:%s(.*)\n")
      pdh=set_uci_state_info("PDH", vj, "Packet data handle:%s(%d+)")
      cid=set_uci_state_info("CID", vj, "CID:%s\'(%d+)\'")

      if pdh == nil and cid ~=nil then
        print("connection setup is failed!!!!! pdh=" , pdh, " cid=", cid, " err=", err)
        -- internal communication error clear context before retrial
        -- check if there are no internal errors if so then reset
        qmi_clear_conn_context(cid)
      elseif pdh==nil and cid == nil then
        print("connection setup is failed!!!!! pdh=" , pdh, " cid=", cid, " err=", err)
      else
        break
      end
      print("==3===== connection start iter=", i)


    end

    local v=qmi_update_conn_status()
    _print("======== jwil ==== conn_status=", v)

    if mbd_uci.network.ppp == '1' then
      if pdh ~= nil then
        state_helper.update_PPP_Status("CONNECTED")
      else
        state_helper.update_PPP_Status("ERROR")
      end
    else
      state_helper.update_PPP_Status("NA")
    end

    --[[
    local v = exec_qmi_cmd(parm.qmi_ctrl, "--wds-noop --client-cid=1")
    tprint(v)

    local v = exec_qmi_cmd(parm.qmi_ctrl, "--wds-start-network=" .. uci_network.apn .. " --client-no-release-cid")
    tprint(v)

    local v = exec_qmi_cmd(parm.qmi_ctrl, "--wds-get-packet-service-status")
    tprint(v)
    ]]
  end
end

local function qmi_do_stop()
    local v=qmi_update_conn_status()

    print("===== STOP STOP ===")
    tprint(uci_info)

    if v == "connected" then
      local v = exec_qmi_cmd(parm.qmi_ctrl, "--wds-stop-network=" .. uci_info.PDH)
      tprint(v)


      local v=qmi_update_conn_status()

      if v == "connected" then
        -- internal error => clear context
        if uci_info.CID then qmi_clear_conn_context(uci_info.CID) end
      end

      local v=qmi_update_conn_status()
    end

end

local function do_QMI_ParmUpdate()
  local v = exec_qmi_cmd(parm.qmi_ctrl, "--nas-get-signal-info")
  tprint(v)
  set_uci_state_info("RSSI", v, "RSSI:%s\'(.-)\'")

  local v = exec_qmi_cmd(parm.qmi_ctrl, "--nas-get-serving-system")
  tprint(v)


  local v = exec_qmi_cmd(parm.qmi_ctrl, "--nas-get-system-info")
  tprint(v)

  local v = exec_qmi_cmd(parm.qmi_ctrl, "--nas-get-technology-preference")
  tprint(v)
  set_uci_state_info("tech_pref_mode_active", v, "Active:%s\'(.-)\'")
  set_uci_state_info("tech_pref_mode_duration", v, "duration:%s\'(.-)\'")

  local v = exec_qmi_cmd(parm.qmi_ctrl, "--nas-get-system-selection-preference")
  tprint(v)
  set_uci_state_info("tech_mode_pref", v, "Mode preference:%s\'(.-)\'")
  set_uci_state_info("band_pref", v, "Band preference:%s\'(.-)\'")
  set_uci_state_info("LTE_band_pref", v, "LTE band preference:%s\'(.-)\'")
  set_uci_state_info("Network_sel_pref", v, "Network selection preference:%s\'(.-)\'")
end


----------------------------

-- -----------------------------
-- END qmi specific code -----
-- -----------------------------
--
--
--
local function load_uci_config ()
  v=cursor:get_all("mobiledongle")
  tprint(v)
  return v
end

  callTbl =
  {
    [ "qmi_wwan" ] =
    {
      [ "do_updateNetworkConfig" ] = do_update_network_wwan_ppp,
      [ "do_getLinkState" ] = qmi_getActState,
      [ "do_disableLink" ] = qmi_do_stop,
      [ "do_enableLink" ] = qmi_do_connect,
      [ "do_getInfo" ] = do_QMI_ParmUpdate
    },
    [ "sierra_wwan" ] =
    {
      [ "do_updateNetworkConfig" ] = do_update_network_wwan_ppp,
      [ "do_getLinkState" ] = at_sierra_getActState,
      [ "do_disableLink" ] = at_sierra_disableLink,
      [ "do_enableLink" ] = at_sierra_enableLink,
      [ "do_getInfo" ] = at_get_info
    },
    [ "huawei_ether" ] =
    {
      [ "do_updateNetworkConfig" ] = do_update_network_wwan_ppp,
      [ "do_getLinkState" ] = at_huawei_getActState,
      [ "do_disableLink" ] = at_huawei_disableLink,
      [ "do_enableLink" ] = at_huawei_enableLink,
      [ "do_getInfo" ] = at_get_info
    },
    [ "option_ppp"] =
    {
      [ "do_updateNetworkConfig" ] = do_update_network_wwan_ppp,
      [ "do_getLinkState" ] = at_extern_3g_ppp_status,
      [ "do_disableLink" ] = at_extern_3g_ppp_disableLink,
      [ "do_enableLink" ] = at_extern_3g_ppp_enableLink,
      [ "do_getInfo" ] = at_get_info
    },
    ["sierra_ppp"] =
    {
      [ "do_updateNetworkConfig" ] = do_update_network_wwan_ppp,
      [ "do_getLinkState" ] = at_extern_3g_ppp_status,
      [ "do_disableLink" ] = at_extern_3g_ppp_disableLink,
      [ "do_enableLink" ] = at_extern_3g_ppp_enableLink,
      [ "do_getInfo" ] = at_get_info
    }
  }

actionTbl = {}

local function process_main_loop(action, i)
    log:info(string.format("process cmd=%s, i=%d", action, i ))
    if action == "reload" or action == "start" or action == "stop" then
        cursor:close()
        cursor = uci.cursor(nil, "/var/state")
        mbd_netw_persist = state_helper.do_load_uci_persist(true, "reload persist home/roaming network")
        if mbd_netw_persist.network.home then
            print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.home)
        end
        if mbd_netw_persist.network.roaming then
            print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.roaming)
        end
        if mbd_netw_persist.network.unknown then
            print("=== mbd_netw_persist.network.home=", mbd_netw_persist.network.unkown)
        end
        state_helper.dump(mbd_netw_persist, action, "reload")

        mbd_uci = load_uci_config()
        state_helper.dump(mbd_uci, action, "reload")
        print("@@@jwil_BG === START mbd_uci=")
        tprint(mbd_uci)
        print("@@@jwil_BG= === END mbd_uci")
        _print("#@#@#@##@#@#@# after table print action=", action, " enabled=", mbd_uci["config"]["enabled"])
        print("#@#@#@##@#@#@# after table print action=", action, " enabled=", mbd_uci["config"]["enabled"])
        print("uci_info.state=", uci_info.state, " mbd_uci.info.state=", mbd_uci.info.state)
        uci_info.state = mbd_uci.info.state
        parm=mbd_uci.parm
        at_ctrl=parm.at_ctrl

        actionTbl = callTbl[parm.dongle_type]
        print("@@@jwil: actionTbl=")
        tprint(actionTbl)
        assert(actionTbl)
        if parm.network == "wwan_eth" then
            local model = mbd_uci.cardinfo.Model
            local modem = cursor_network:get("mobiledongle","host_less", "device")
            if type(modem) == "table" then
                for _,v in ipairs(modem) do
                    if model == v then
                        parm.network = "wwan_eth_dhcp"
                        break
                    end
                end
            elseif type(modem) == "string" and modem == mbd_uci.cardinfo.Model then
                parm.network = "wwan_eth_dhcp"
            end
        end
    end

    print("@@@ dongle_type=", parm.dongle_type)
    local linkState = actionTbl.do_getLinkState ()

    print("action=", action, " enabled=", mbd_uci.config.enabled, " linkState=", linkState)
    log:info (string.format ("action=%s, enabled=%s linkState=%s", action, mbd_uci.config.enabled, linkState))

    if action == 'stop'  or (action == 'reload' and mbd_uci.config.enabled == '0') then
        print("@== ### DISABLE transaction ###")
        rpc_ubus_ifdown("wwan")
        if linkState == '1' and parm.nentwork ~= "wwan_eth_dhcp" then
            actionTbl.do_disableLink()
        end
        do_clean_network_wwan( )
        state_helper.update_PPP_Status("NA")
        state_helper.update_Link_Status("NA")
        state_helper.update_Registration_Status("NA")
        uci_info.state =  "DISABLED"
    elseif action == 'start' or action == 'reload' then
        if mbd_uci.config.enabled == '0' then
            print("@== ### DISABLE transaction 2 ###")
            print("#@#@#@# start or reload and enabled=false uci_info.state=", uci_info.state)
            if not  uci_info.state then
                state_helper.update_PPP_Status("NA")
                state_helper.update_Link_Status("NA")
                state_helper.update_Registration_Status("NA")
                uci_info.state =  "DISABLED"
            end
            log:error(string.format("State=%s", uci_info.state))
        elseif linkState == '0' then
            print("@== ### ENABLE linkState=0 ###")
            rpc_ubus_ifdown("wwan")
            --uci_info.state =  "NO_NETWORK_CONNECTED"
            state_helper.update_Link_Status("CONNECTING")
            state_helper.update_Registration_Status("REGISTER")
            state_helper.do_save_uci_info(uci_info)
            -- cursor:set(MBD, INFO, "state", "NO_NETWORK_CONNECTED")
            -- cursor:save(MBD)
            if parm.network ~= "wwan_eth_dhcp" then
                print("#@#@#@# start or reload and enabled=true and link L2 is down")

                print("==== start tech mode ")
                tprint(mbd_uci)
                tprint(uci_info)

                if  not mbd_uci.info.last_tech_mode or
                  mbd_uci.info.last_tech_mode ~= uci_info.last_tech_mode then
                    print("get current cops too if mode must be adapted")
                    uci_info.current_operator_mode,
                    uci_info.current_network_long,
                    uci_info.current_network_short,
                    uci_info.current_operator,
                    uci_info.current_technology = at_get_current_cops()

                    if uci_info.current_operator and not verify_valid_network() then
                        state_helper.update_Registration_Status("NO_NETWORK_FOUND")
                        state_helper.do_save_uci_info(uci_info)
                        at_cmd="at+cops=2" -- deregister from network
                        local rv = at_helper.at_info_cmd(at_ctrl,at_cmd)
                        actionTbl.do_disableLink()
                        return
                    end

                    print("--Check search networks: home=", mbd_netw_persist.network.home,
                        " req_oper=", mbd_uci.config.requested_operator,
                        " cur_oper=", mbd_uci.info.current_operator)
                    if (mbd_uci.config.requested_operator ~= mbd_uci.info.current_operator) then
                        local home_rep_operator,  roaming_rep_operator, unknown_rep_operator
                        if mbd_netw_persist.network.home then
                            home_rep_operator = string.match(mbd_netw_persist.network.home, mbd_uci.config.requested_operator)
                        end
                        if mbd_netw_persist.network.roaming then
                            roaming_rep_operator = string.match(mbd_netw_persist.network.roaming, mbd_uci.config.requested_operator)
                        end
                        if mbd_netw_persist.network.unknown then
                            unknown_rep_operator = string.match(mbd_netw_persist.network.unknown, mbd_uci.config.requested_operator)
                        end

                        print("--Requested operator found in detected networks=", home_rep_operator, roaming_rep_operator, unknown_rep_operator)

                        print("=== Check before search mbd_netw_persist.network.home=", mbd_netw_persist.network.home)
                        state_helper.dump(mbd_netw_persist.network, "config check" , "=need netw search??=")
                        if not mbd_netw_persist.network.home or
                          (mbd_uci.config.operator_mode == "MANUAL" and
                          (not home_rep_operator and not roaming_rep_operator and not unknown_rep_operator)) then
                            --not verify_valid_network() then
                            print("Search networks .... will take a time ... ")
                            _print("Search networks .... will take a time ... ")
	                        state_helper.update_Link_Status("SEARCHING")
                            state_helper.update_PPP_Status("NA")
                            state_helper.update_Registration_Status("NA")
                            state_helper.do_save_uci_info(uci_info)
                            uci_info.current_operator=at_search_networks()
                        end
                    end

                    if mbd_uci.config.operator_mode == "MANUAL" then
                        if mbd_netw_persist.network.home then
                            home_rep_operator = string.match(mbd_netw_persist.network.home, mbd_uci.config.requested_operator)
                        end
                        if mbd_netw_persist.network.roaming then
                            roaming_rep_operator = string.match(mbd_netw_persist.network.roaming, mbd_uci.config.requested_operator)
                        end
                        if mbd_netw_persist.network.unknown then
                            unknown_rep_operator = string.match(mbd_netw_persist.network.unknown, mbd_uci.config.requested_operator)
                        end
                        print("--Reload: Requested operator found in detected networks=", home_rep_operator, roaming_rep_operator, unknown_rep_operator)
                        if not home_rep_operator and not roaming_rep_operator and not unknown_rep_operator then
                            state_helper.update_Registration_Status("NO_NETWORK_FOUND")
                            state_helper.do_save_uci_info(uci_info)
                            return
                        end
                    end

                    state_helper.dump(mbd_netw_persist.network, "config check" , "=netw done=")
                    state_helper.dump(mbd_netw_persist.config, "config check" , "=set tech mode=")
                    state_helper.dump(mbd_uci.config, "state check" , "=set tech mode=")
                    state_helper.dump(mbd_uci.info, "state check" , "=set tech mode=")
                    state_helper.dump(uci_info, "current state" , "=set tech mode=")

                    if uci_info.current_operator_mode ~= mbd_uci.config.operator_mode  or
                      (mbd_uci.config.operator_mode == "MANUAL" and
                      (uci_info.current_operator ~= mbd_uci.config.requested_operator or
                      uci_info.current_technology ~= mbd_uci.config.requested_technology)) then
                        print("Set new tech_mode : ")
                        local ok, error = at_set_tech_mode(mbd_uci.config.requested_operator)
                        if error then
                            if not string.match(mbd_netw_persist.network.home, mbd_uci.config.requested_operator .. "=" .. mbd_uci.config.requested_technology) and
                              not string.match(mbd_netw_persist.network.roaming, mbd_uci.config.requested_operator .. "=" .. mbd_uci.config.requested_technology) then
                                state_helper.update_Registration_Status("TECH_ERROR")
                            else
                                state_helper.update_Registration_Status("NO_NETWORK_FOUND")
                            end

                            state_helper.do_save_uci_info(uci_info)
                            return
	                    end
                    end
                end
                state_helper.update_Link_Status("CONNECTING")
                state_helper.update_Registration_Status("REGISTER")
                state_helper.update_PPP_Status("NA")
                state_helper.do_save_uci_info(uci_info)
                actionTbl.do_enableLink()
            end
            local linkState_init = actionTbl.do_getLinkState ()
            sleep("5")
            local linkState_5s = actionTbl.do_getLinkState ()
            log:info(string.format("link state=%s, %s", linkState_init, linkState_5s ))
            if linkState_5s == "1" or parm.network == "wwan_ppp" or parm.network == "wwan_eth_dhcp" then
                uci_info.current_operator_mode,
                uci_info.current_network_long,
                uci_info.current_network_short,
                uci_info.current_operator,
                uci_info.current_technology = at_get_current_cops()
                if uci_info.current_operator and not verify_valid_network() then
                    state_helper.update_Registration_Status("NO_NETWORK_FOUND")
                    state_helper.do_save_uci_info(uci_info)
                    if parm.network ~= "wwan_eth_dhcp" then
                        at_cmd="at+cops=2" -- deregister from network
                        local rv = at_helper.at_info_cmd(at_ctrl,at_cmd)
                        actionTbl.do_disableLink()
                    end
                    return
                end

                local home_rep_operator,  roaming_rep_operator, unknown_rep_operator
                if mbd_netw_persist.network.home then
                    home_rep_operator = string.find(mbd_netw_persist.network.home, uci_info.current_operator)
                    print("##### home : ", home_rep_operator, " home=", mbd_netw_persist.network.home, " current=",uci_info.current_operator)
                end
                if mbd_netw_persist.network.roaming then
                    roaming_rep_operator = string.find(mbd_netw_persist.network.roaming, uci_info.current_operator)
                end
                if mbd_netw_persist.network.unknown then
                    unknown_rep_operator = string.find(mbd_netw_persist.network.unknown, uci_info.current_operator)
                end

                print("Requested operator found in detected networks=", home_rep_operator, roaming_rep_operator, unknown_rep_operator)

                if home_rep_operator then
                    state_helper.update_Registration_Status("REGISTERED_HOME")
                end

                if roaming_rep_operator then
                    state_helper.update_Registration_Status("REGISTERED_ROAMING")
                end

                if not home_rep_operator and not roaming_rep_operator then
                    print("--Switch sim card invalid stored home/roaming info")
                    local cursor_netw = uci.cursor()
                    cursor_netw:delete(MBD, "network", "home")
                    cursor_netw:delete(MBD, "network", "roaming")
                    cursor_netw:delete(MBD, "network", "unknown")
                    cursor_netw:commit(MBD)
                    cursor_netw:close()
                    state_helper.update_Registration_Status("REGISTERED_HOME")
                end
                state_helper.do_save_uci_info(uci_info)
                --end
                uci_info.state =  "NETWORK_CONNECTED"
                state_helper.do_save_uci_info(uci_info)

                print("#@#@#@# linkState=", linkState_init, linkState_5s)
                do_add_network_wwan( )
                rpc_ubus_ifup("wwan")

                local poll_time=2
                local retry_cnt=0
                local disconnect_cnt=0
                while true do
                    local netw_status2=rpc_ubus_get_status("wwan")
                    print("double check network status wwan", netw_status2, netw_status2.up)
                    tprint(netw_status2)
                    local t=retry_cnt*poll_time
                    state_helper.dump(netw_status2, "L3 netw state " .. t .. " sec" , "=itf wwan up " .. t .. " sec =")

                    if netw_status2.data then
                        if netw_status2.data.pppinfo and netw_status2.data.pppinfo.pppstate then
                            local pppstate=string.upper(netw_status2.data.pppinfo.pppstate)
                            if pppstate == "DISCONNECTED" then
                                disconnect_cnt = disconnect_cnt+1
                            end
                            state_helper.update_PPP_Status(pppstate)
                        end
                    end

                    if netw_status2.up == true then
                        state_helper.update_Link_Status("CONNECTED")

                        log:info(string.format("DATA_SESSION_ACTIVE"))
                        uci_info.state = "DATA_SESSION_ACTIVE"
                        state_helper.do_save_uci_info(uci_info)
                        break
                    end
                    if netw_status2.available == false then
                        log:info(string.format("network reload failed => retry"))
                        os.execute("/etc/init.d/network reload")
                    end
                    local t = retry_cnt * poll_time
                    log:info(string.format("retry ... cnt=%s t=%s poll_time=%s", tostring(retry_cnt), tostring(t), tostring(poll_time)))
                    retry_cnt = retry_cnt+1
                    if retry_cnt*poll_time > tonumber(mbd_uci.config.retry_timout) or
                      disconnect_cnt > tonumber(mbd_uci.config.retry_failures) then
                        local t = retry_cnt * poll_time
                        print("--L3 Link activation failed t=", t, " retry_timeout=", mbd_uci.config.retry_timout,
                          " disconnect_cnt=", disconnect_cnt, " retry_failures=", mbd_uci.config.retry_failures)
                        if netw_status2.data.pppinfo then
                            state_helper.update_PPP_Status("ERROR")
                        else
                            state_helper.update_Link_Status("ERROR")
                        end
                        state_helper.do_save_uci_info(uci_info)
                        -- status values are still on error condition to give the user a view what is going wrong.!!!!!
                        rpc_ubus_ifdown("wwan")
                        if parm.network ~= "wwan_eth_dhcp" then
                            actionTbl.do_disableLink()
                        end
                        do_clean_network_wwan( )
                        break
                    end
                    sleep(tostring(poll_time))
                end
            else
                print("--Link activation failed")
                state_helper.update_Registration_Status("UNKNOWN")
                state_helper.do_save_uci_info(uci_info)
            end

            uci_info.current_operator_mode,
            uci_info.current_network_long,
            uci_info.current_network_short,
            uci_info.current_operator,
            uci_info.current_technology = at_get_current_cops()

            print("#@#@#@# GetInfo")
            actionTbl.do_getInfo()
        else
            print("#@#@#@# start or reload and enabled=true and link L2 is up uci_info.state=", uci_info.state)
            print("#@#@#@# GetInfo")
            actionTbl.do_getInfo()
        end
    else
        assert(nil)
    end
    at_update_radio_quality()
    print("#@#@#@# do save uci_info state=", uci_info.state)
    state_helper.do_save_uci_info(uci_info)
end

local function get_mbd_cmd()
     local data, from = sk:recvfrom()
     if data then
       --sk:sendto("received", from)
       -- log:info(string.format("rcv bg msg=%s", data))
       print(string.format("rcv bg msg=%s", data))
     end
     return data
end

-- Main code
--
--
cb = {
  [ "start" ]= process_main_loop,
  [ "stop"] = process_main_loop,
  [ "reload" ] = process_main_loop
}


print("@@@ jwil : reread the mbd_uci=")
tprint(mbd_uci)

local poll_time="5"

_print("Mobiledongle_background task started")
print("Mobiledongle_background task started")
i=0
old_state={}
while true do

  i=1 + tonumber(i)

 old_state.state= uci_info.state
 old_state.conn_status= uci_info.conn_status

 action=get_mbd_cmd()
 --log:info(string.format("while(true)=%s, i=%d", action, i ))
 if cb[action] then
   -- process only supported actions.
   --_print("@@@jwil_BG: awake...", action)
   process_main_loop(action, i)
 else
   action="poll"
   --print("@@@jwil_BG: goToSleep")
   sleep(poll_time)
   --print("@@@jwil_BG: awake...")
   --
   if parm then
     process_main_loop("poll", i)
   end

 end

  if action ~= "poll" or old_state.state ~= uci_info.state or
       old_state.conn_status ~= uci_info.conn_status then
   _print("i=", i, "action=", action, "state=", old_state.state, uci_info.state,
     " conn_status=", old_state.conn_status, uci_info.conn_status)
   print("action=", action, "state=", old_state.state, uci_info.state,
     " conn_status=", old_state.conn_status, uci_info.conn_status)
   end

end

sk:close()
fd_log:close()
