gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
format = string.format
local sfp = proxy.get("uci.env.rip.sfp")[1].value
local wansensing = proxy.get("uci.wansensing.global.enable")[1].value
local session = ngx.ctx.session

local M = {}


function setLanRelay(dname)
  local sfpCheck = proxy.get("uci.env.rip.sfp")[1].value or ""
  if sfpcheck == "1" then
  proxy.del("uci.network.interface.@lan.pppoerelay.")
  proxy.add("uci.network.interface.@lan.pppoerelay.")
  proxy.set("uci.network.interface.@lan.pppoerelay.@1.value",dname)
  end
end

function M.broadBandDetails()
local tablecontent ={}
tablecontent[#tablecontent + 1] = {
     name = "adsl",
     default = false,
     description = "ADSL2+",
     view = "broadband-adsl-advanced.lp",
     card = "002_broadband_xdsl.lp",

     check = function()
       if wansensing == "1" then
         local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
         if L2 == "ADSL" then
           return true
         end
       else
         local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
         local iface = string.match(ifname, "atm")
         if iface then
           return true
         end
       end
     end
     ,
     operations = function()
       local difname =  proxy.get("uci.network.device.@wanatmwan.ifname")
       if sfp == "1" then
         if difname then
           local dname = proxy.get("uci.network.device.@wanatmwan.name")[1].value
           difname =  proxy.get("uci.network.device.@wanatmwan.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
           else
             proxy.set("uci.network.interface.@wan.ifname", "atmwan")
             setLanRelay("atmwan")
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "atmwan")
           setLanRelay("atmwan")
           proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
         end
       else
         if difname then
           local dname = proxy.get("uci.network.device.@wanatmwan.name")[1].value
           difname =  proxy.get("uci.network.device.@wanatmwan.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
           else
             proxy.set("uci.network.interface.@wan.ifname", "atmwan")
             setLanRelay("atmwan")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "atmwan")
           setLanRelay("atmwan")
         end
       end
       local ptmdev = proxy.get("uci.xtm.ptmdevice.")
       if next(ptmdev) then
         proxy.del("uci.xtm.ptmdevice.")
       end
     end
     ,
}
tablecontent[#tablecontent + 1] =    {
     name = "vdsl",
     default = true,
     description = "VDSL2",
     view = "broadband-vdsl-advanced.lp",
     card = "002_broadband_xdsl.lp",

     check = function()
       if wansensing == "1" then
         local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
         if L2 == "VDSL" then
           return true
         end
       else
         local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
         local iface = string.match(ifname, "ptm0")
         if iface then
           return true
         end
       end
     end
     ,
     operations = function()
       local difname =  proxy.get("uci.network.device.@wanptm0.ifname")
       if sfp == "1" then
         if difname then
           local dname = proxy.get("uci.network.device.@wanptm0.name")[1].value
           difname =  proxy.get("uci.network.device.@wanptm0.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
           else
             proxy.set("uci.network.interface.@wan.ifname", "ptm0")
             setLanRelay("ptm0")
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "ptm0")
           setLanRelay("ptm0")
           proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
         end
       else
         if difname then
           local dname = proxy.get("uci.network.device.@wanptm0.name")[1].value
           difname =  proxy.get("uci.network.device.@wanptm0.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
           else
             proxy.set("uci.network.interface.@wan.ifname", "ptm0")
             setLanRelay("ptm0")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "ptm0")
           setLanRelay("ptm0")
         end
       end
       local ptmdev = proxy.get("uci.xtm.ptmdevice.")
       if not next(ptmdev) then
         proxy.add("uci.xtm.ptmdevice.","ptm0")
         proxy.set("uci.xtm.ptmdevice.@ptm0.priority","low")
         proxy.set("uci.xtm.ptmdevice.@ptm0.path","fast")
       end
     end
     ,
    }
tablecontent[#tablecontent + 1] = {
     name = "ethernet",
     default = false,
     description = "Ethernet",
     view = "broadband-ethernet-advanced.lp",
     card = "002_broadband_ethernet.lp",

     check = function()
       if wansensing == "1" then
         local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
         if L2 == "ETH" then
           return true
         end
       else
         local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
         local iface = string.match(ifname, "eth4")
         if sfp == "1" then
           local lwmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value
           if iface and lwmode == "0" then
             return true
           end
         else
           if iface then
             return true
           end
         end
       end
     end
     ,
     operations = function()
       local difname =  proxy.get("uci.network.device.@waneth4.ifname")
       if sfp == "1" then
         if difname then
           local dname = proxy.get("uci.network.device.@waneth4.name")[1].value
           difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
           else
             proxy.set("uci.network.interface.@wan.ifname", "eth4")
             setLanRelay("eth4")
             proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "eth4")
           setLanRelay("eth4")
           proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
         end
       else
         if difname then
           local dname = proxy.get("uci.network.device.@waneth4.name")[1].value
           difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
           if difname ~= "" and difname ~= nil then
             proxy.set("uci.network.interface.@wan.ifname", dname)
             setLanRelay(dname)
           else
             proxy.set("uci.network.interface.@wan.ifname", "eth4")
             setLanRelay("eth4")
           end
         else
           proxy.set("uci.network.interface.@wan.ifname", "eth4")
           setLanRelay("eth4")
         end
       end
     end
     ,
    }
if sfp == "1" and session:getrole() ~= "ispuser" then
tablecontent[#tablecontent + 1] = {
     name = "gpon",
     default = false,
     description = "GPON",
     view = "broadband-gpon-advanced.lp",
     card = "002_broadband_gpon.lp",

     check = function()
       if wansensing == "1" then
         local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
         local gponState = proxy.get("rpc.optical.Interface.1.Status")[1].value or ""
         if L2 == "SFP" or gponState == "Dormant" then
           return true
         end
       else
         local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
         local iface = string.match(ifname, "eth4")
         if sfp == "1" then
           local lwmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value
           if iface and lwmode == "1" then
             return true
           end
	 else
           if iface then
             return true
           end
         end
       end
     end
     ,
     operations = function()
       local difname =  proxy.get("uci.network.device.@waneth4.ifname")
       if difname then
         local dname = proxy.get("uci.network.device.@waneth4.name")[1].value
         difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
         if difname ~= "" and difname ~= nil then
           proxy.set("uci.network.interface.@wan.ifname", dname)
           setLanRelay(dname)
           proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
         else
           proxy.set("uci.network.interface.@wan.ifname", "eth4")
           setLanRelay("eth4")
           proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
         end
       else
         proxy.set("uci.network.interface.@wan.ifname", "eth4")
         setLanRelay("eth4")
         proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
       end
     end
     ,
    }

end
return tablecontent
end
return M
