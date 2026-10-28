#!/usr/bin/env lua

-- global functions used
local xpcall, string, io = xpcall, string, io
local table, require, next = table, require, next
local match, find = string.match, string.find

-- library helpers
local ubus = require("ubus")
local uci = require("uci")
local datamodel = require ("datamodel")
local logger = require 'transformer.logger'
local popen = io.popen

logger.init(6, false)
local log = logger.new("sfp_telnet_adapt", 6)
local Original_state
local ubus_conn -- Talk to ubus via this connection
local x = uci.cursor()

local username , password , security_mode , uci_model

local function model_name_adapt(adapt_name)
      if adapt_name == "LTE3415-SC1     " then
         return "LTE3468L_SC1"
      end
      return "nil"
end

local function sfp_telnet_auto_adapt()

      local ctl = popen("/usr/sbin/sfpi2cctl -get -format vendpn")
      if ctl then
         local output = ctl:read("*a")
         local i2c_model = match(output, "^.+:%[(.+)%]")
         ctl:close()
         local model = model_name_adapt(i2c_model)
         uci_model= x:get("sfp", "device_defaults", "model")

         if uci_model ~= model and model ~= "nil" then
              x:set("sfp", "device_defaults", "model", model)
              x:commit("sfp")
         end
         local telnet_test_result = os.execute("sfp_get.sh --telnet_test 0")
         if telnet_test_result == 0 then
             x:set("sfp", "device_defaults", "telnet_security_mode", "none")
             x:commit("sfp")
         elseif telnet_test_result == 256 then
             username= x:get("sfp", model, "username")
	     password= x:get("sfp", model, "password")
             local table_id = 1
             local end_flag = 0
             while (table_id <= #password and end_flag == 0)
             do
                telnet_test_result = os.execute("sfp_get.sh --telnet_test 1 "..username.." "..password[table_id].."")
                if telnet_test_result == 0 then
                    log:debug("------sfp pwd set------")
                    x:set("sfp", "device_defaults", "telnet_security_mode", "pwd")
                    x:set("sfp", "device_defaults", "username", username)
                    x:set("sfp", "device_defaults", "password", password[table_id])
                    x:commit("sfp")
                    end_flag = 1
                end
                table_id = table_id + 1
             end
         elseif telnet_test_result == 512 then
             log:debug("------sfp fiber might not plug-------")
         end

     end
end

local function handle_sfp_status(statusList)
    if (statusList) then
        for _, status in pairs(statusList) do
            log:debug("------get sfp state == %s------", status["status"])
            if status["status"] == "linkup" and  Original_state == "plugin" then
               sfp_telnet_auto_adapt()
            end
               Original_state = status["status"]
        end
    end
end

local function get_sfp_msg(msg)
      handle_sfp_status( {msg} )
end

local function main()

    local uloop = require("uloop")

    uloop.init();
    ubus_conn = ubus.connect()
    if not ubus_conn then
        log:error("Failed to connect to ubus")
        return
    end

    log:debug("------ First do the sfp auto adapt -------")
    sfp_telnet_auto_adapt()

    -- Register sfp event listener
    ubus_conn:listen({ ['sfp'] = get_sfp_msg} );
    -- Idle loop
    uloop.run()
end

-- Invoke main loop
main()
