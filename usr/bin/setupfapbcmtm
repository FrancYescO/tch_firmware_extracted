#!/usr/bin/env lua
local string = require('string')
local cursor = require('uci').cursor()
local os = require('os')
local io = require('io')

-- set to 'true' to enable extended logging
local logging_enable = false

-- number of switchports on internal switch
local nbrofswitchports = 8
local nbrofswitchprio = 8
-- two types of ethernet ports exist ("lan", "wan")

local wantype = "wan"
local lantype = "lan"
local devconfigtype = "qos_devconfig"
local intfconfigtype = "qos_intfconfig"
local tmenable = nil

-- fap mode configuration
local configuration_mode = nil
local modestring = {
   ["manual"] = " --manual ",
   ["auto"] = " --auto " }

-- fap policy conversion string
local policystring = {
   ["sp"] = " --sp ",
   ["sp_wrr"] = " --spwrr ",
   ["wrr"] = " --wrr",
   ["wfq"] = " --wfq" }

-- suppoted number of queues in function of realm
local nbrofqueues = {
   [wantype] = 8,
   [lantype] = 4 }

-- fap traffic manager towards queue mapping table
-- index in table refers towards the fap queue nbr
local tm2swqueue = {
   [wantype] = {0,0,1,1,2,2,3,3,4,4},
   [lantype] = {0,1,2,3,4} }

local cmdprefix = nil

--- Helper function to check if a table contains an entry
-- @param tbl The table to check
-- @param item The item to check
-- returns the index if the entry exists, otherwise false
function inTable(tbl, item)
    for key, value in pairs(tbl) do
	if value == item then return key end
    end
    return false
 end

--- Helper function to trace execute the passed commands
-- @param str The command which needs to be executed
local function log_execute(str)
  if logging_enable == true then
      print(str)
  end
  os.execute(str)
end

--- Helper function to check if the UCI boolean specifies true/false
-- @param value The option value which needs to be checked
-- @default defvalue The value which needs to be returned if the parameter is nil
-- @return true or false
local function bool_is_true(value, defvalue)
   if not value then
      return defvalue
   elseif value ~=nil and (value == "1" or value == "on" or value == "true" or value == "enabled") then
      return true
   else
      return false
   end
end

--- Helper function to check if a file exists
-- @param name The file name
-- @return true if the file exist or false otherwise
local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function platform_judge()
   if file_exists("/usr/bin/fapctl") then
      return "fap"
   elseif file_exists("/usr/bin/bcmtmctl") then
      return "bcmtm"
   else
      return "none"
   end
end

--- Helper function which enables the trafficmanager on the specified port for the requested mode
-- @param ethdevice The ethernet netdevice
-- @param mode The FAP mode (auto/manual)
local function tm_port_enable(ethdevice, mode)
   if mode ~= configuration_mode then
      configuration_mode = mode
      if mode == "manual" then
	 configuration_mode = "manual"
	 log_execute(cmdprefix .. "mode --if ".. ethdevice .. modestring["manual"])
	 log_execute(cmdprefix .. "enable --if ".. ethdevice .. modestring["manual"])
	 log_execute(cmdprefix .. "disable --if ".. ethdevice .. modestring["auto"])
      elseif mode == "auto" then
	 configuration_mode = "auto"
	 log_execute(cmdprefix .. "mode --if ".. ethdevice .. modestring["auto"])
	 log_execute(cmdprefix .. "disable --if ".. ethdevice .. modestring["manual"])
	 --not going to enable the interface (done by the ethernet driver in his linkchange notification callback)
      else
	 print("Internal error : requested mode " .. mode .. " is not supported")
      end
   end
end

--- Helper function which disables the traffic manager on the specified port
-- @param ethdevice The ethernet netdevice
local function tm_port_disable(ethdevice)
   configuration_mode = "manual"
   log_execute(cmdprefix .. "mode --if ".. ethdevice .. modestring["manual"])
   log_execute(cmdprefix .. "disable --if ".. ethdevice .. modestring["manual"])
   --not going to disable the auto mode (ethernet driver masters this action)

   -- apply the configuration
   log_execute(cmdprefix .. "apply --if ".. ethdevice)
end


--
-- @param name The name of the interface or device
-- @return the defined classgroup nil when nothing active was found
local function classgroup_for_device_or_interface(name)
   enabled=cursor:get("qos",name,"enable")
   if bool_is_true(enabled,1) then
      return cursor:get("qos",name,"classgroup")
   end
   return nil
end

--
-- create a mapping for each eth device of devtype how to configure its classgroup
-- @param devtype The type of ports which need to be parsed (lan or wan type)
-- @returns table containing the association between the requested ethernet port and its related qos classgroup
--          ethernet ports not having a classgroup will be not present
--          ethernet ports not having an enabled classgroup will not be present
--          ethernet ports not referenced in the qos.device section will inherit the
--                classgroup of its associated OpenWRT interface ("lan"/"wan")
local function parse_ethdev_config_type(devtype)
   local ethdevcgroup = {}
   local section_filter=function(s) return (bool_is_true(s['wan'],false)==false);  end
   if devtype == wantype  then
      section_filter=function(s) return bool_is_true(s['wan'],false);  end
   end

   cursor:foreach("ethernet", "port", function(s)
					 if section_filter(s) then
					    local name=s['.name']
					    ethdevcgroup[name] = classgroup_for_device_or_interface(name)
					    if (not ethdevcgroup[name]) then
					       -- fallback to interface qos configuration
					       ethdevcgroup[name] = classgroup_for_device_or_interface(devtype)
					    end
					 end
				   end)
   return ethdevcgroup
end




--- Function which configures the ethernet device in the FAP trafficmanager
-- @param ethdevice The ethernet netdevice
-- @param classgroup Contains the qos.classgroup object (specifies
--                   the number of queues and arbitration between those)
-- @param type Specifies the ethernet device realm (lan/wan)
local function configure_ethdevice(ethdevice, classgroup, type)
   local policy = nil
   local classes = nil
   local classesstring = cursor:get("qos",classgroup,"classes")
   local trafficdescriptor = nil
   local validpolicy = {"sp"}



   if not classesstring then return end

   configuration_mode = nil
   tm_port_enable(ethdevice, "auto")
   log_execute(cmdprefix .. "reset --if ".. ethdevice .." --manual")

   if platform_judge() == "fap" then
      log_execute(cmdprefix .. "type --if ".. ethdevice .." --" .. type)
   end

   --check if there is a port based shaping configured
   --this port based shaping is only relevant for manual mode
   --in auto mode this port based shaping is configured by the ethernet driver
   trafficdescriptor = cursor:get("ethernet", ethdevice, "td")
   if trafficdescriptor ~= nil and bool_is_true(cursor:get("ethernet", trafficdescriptor, "enable"), 1) then
      tm_port_enable(ethdevice, "manual")
      local mbr = cursor:get("ethernet", trafficdescriptor, "mbr")
      local mbs = cursor:get("ethernet", trafficdescriptor, "mbs")
      local ratio = cursor:get("ethernet", trafficdescriptor, "ratio")
      local rate = cursor:get("ethernet", trafficdescriptor, "rate")
      if mbr ~= nil and mbs ~= nil then
	 if rate ~= nil then
	    log_execute(cmdprefix .. "ifcfg --if ".. ethdevice .." --manual --kbps ".. mbr .." --mbs ".. mbs .." --rate")
	 elseif ratio ~= nil then
	    log_execute(cmdprefix .. "ifcfg --if ".. ethdevice .." --manual --kbps ".. mbr .." --mbs ".. mbs .." --ratio")
	 else
	    log_execute(cmdprefix .. "ifcfg --if ".. ethdevice .." --manual --kbps ".. mbr .." --mbs ".. mbs)
	 end
      else
	 print("Incorrect port configuration: mbs and mbr needs to be specified for ".. ethdevice)
      end
   end

   --let's parse the per queue shaping configuration
   classes=string.gmatch(classesstring,"(%S+)%s*")
   local numclasses=0
   for class in classes do
      local weight = cursor:get("qos", class, "weight")
      local mbr = cursor:get("qos", class, "mbr")
      local pbr = cursor:get("qos", class, "pbr")
      local mbs = cursor:get("qos", class, "mbs")

      if weight ~= nil then
	 validpolicy={"sp", "wrr", "wfq", "sp_wrr"}
	 log_execute(cmdprefix .. "queueweight --if ".. ethdevice .. modestring[configuration_mode] .. " --queue ".. numclasses .." --weight ".. weight)
      end
      if mbr ~= nil then
	 if mbs ~= nil then
	    tm_port_enable(ethdevice, "manual")
	    log_execute(cmdprefix .. "queuecfg --if ".. ethdevice .. modestring[configuration_mode] .. " --queue ".. numclasses .." --min --kbps ".. mbr .." --mbs ".. mbs)
	 else
	    print("Incorrect queue configuration: please specify mbs for ".. ethdevice .. " class " .. class)
	 end
      end
      if pbr ~= nil then
	 if mbs ~= nil then
	    tm_port_enable(ethdevice, "manual")
	    log_execute(cmdprefix .. "queuecfg --if ".. ethdevice .. modestring[configuration_mode] .. " --queue ".. numclasses .." --max --kbps ".. pbr .." --mbs ".. mbs)
	 else
	    print("Incorrect queue configuration: please specify mbs for ".. ethdevice .. " class " .. class)
	 end
      end
      numclasses = numclasses + 1
      if ( numclasses > nbrofqueues[type] ) then
	 print("Incorrect queue configuration: max " .. nbrofqueues[type] .. " classes supported")
	 break
      end
   end

   -- configure the queue scheduling
   policy=cursor:get("qos", classgroup, "policy")
   if policy ~= nil and inTable(validpolicy,policy) then
      if policy == "sp_wrr" then
	 local lowprioqueue= 0
	 --classes is iterator function so we need to reparse again
	 classes = string.gmatch(classesstring,"(%S+)%s*")
	 for class in classes do
	    if cursor:get("qos", class, "weight") ~= nil then
	       lowprioqueue = lowprioqueue + 1
	    else
	       break
	    end
	 end
	 if lowprioqueue >= nbrofqueues[type] then lowprioqueue = nbrofqueues[type] - 1 end
	 log_execute(cmdprefix .. "arbitercfg --if ".. ethdevice .. modestring[configuration_mode] .. policystring[policy] .." --lowprioq ".. lowprioqueue)
      else
	 log_execute(cmdprefix .. "arbitercfg --if ".. ethdevice .. modestring[configuration_mode] .. policystring[policy])
      end
   else
      print("Incorrect configuration for qos." .. classgroup )
      return
   end

   if platform_judge() == "fap" then
      --setup tm queue to switch queue mapping
      for i = 1, nbrofqueues[type] do
	 log_execute(cmdprefix .. "tmq2swq --if ".. ethdevice .." --queue ".. i-1 .." --swqueue ".. tm2swqueue[type][i])
      end
   end

   -- apply the configuration
   log_execute(cmdprefix .. "apply --if ".. ethdevice)
end

-- start of the main logic
-- check if it is a fap based board
if platform_judge() == "fap" then
   cmdprefix = "fapctl tm --"
elseif platform_judge() == "bcmtm" then
   cmdprefix = "bcmtmctl "
else
   return
end

--get the bcmtm enable/disable configuration
--on 63381 platform tm module is a SW task which will take too many CPU resource,
--in some case we must turn off it to save CPU usage
tmenable = cursor:get("ethernet", "globals", "trafficmanager")
--default value is enable if no configuration in uci
if tmenable == nil then
   tmenable = "1"
end
if tmenable == "0" then
--as indicated by broadcom(CSP972341), we must disable all eth interface before turn off TM
   cursor:foreach("ethernet", "port", function(s)
					 tm_port_disable(s[".name"])
				      end)

   log_execute(cmdprefix .. "off")
   return
else
   log_execute(cmdprefix .. "on")
end

-- we look only once for the classgroup of the interface
local interface_classgroup=classgroup_for_device_or_interface(arg[1])
-- iterate over a table that maps ethdevs to their qos configuration type
for ethdev, classgroup in pairs(parse_ethdev_config_type(arg[1])) do
   print("interface "..arg[1] .." device "..tostring(ethdev).." using classgroup '" .. tostring(classgroup))
   if classgroup then
      configure_ethdevice(ethdev, classgroup, arg[1])
   else
      tm_port_disable(ethdev)
   end
end
