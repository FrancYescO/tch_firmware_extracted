gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
format = string.format
local sfp = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value

local tablecontent ={}
tablecontent[#tablecontent + 1] = {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-adsl-advanced.lp",
        card = "002_broadband_xdsl.lp",
        check = function()
						ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

						iface = string.match(ifname, "atm")
	
					if iface then
						return true
					end
				end
		,
        operations = function()
						difname =  proxy.get("uci.network.device.@wanatmwan.ifname")
						if sfp == "1" then
						if difname then
						dname = proxy.get("uci.network.device.@wanatmwan.name")[1].value
						difname =  proxy.get("uci.network.device.@wanatmwan.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							else
								proxy.set("uci.network.interface.@wan.ifname", "atmwan")
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "atmwan")
							proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
						end
						else
						if difname then
						dname = proxy.get("uci.network.device.@wanatmwan.name")[1].value
						difname =  proxy.get("uci.network.device.@wanatmwan.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
							else
								proxy.set("uci.network.interface.@wan.ifname", "atmwan")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "atmwan")
						end
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
						ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

						iface = string.match(ifname, "ptm0")
	
					if iface then
						return true
					end
				end
		,
        operations = function()
						difname =  proxy.get("uci.network.device.@wanptm0.ifname")
						if sfp == "1" then
						if difname then
						dname = proxy.get("uci.network.device.@wanptm0.name")[1].value
						difname =  proxy.get("uci.network.device.@wanptm0.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							else
								proxy.set("uci.network.interface.@wan.ifname", "ptm0")
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "ptm0")
							proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
						end
						else
						if difname then
						dname = proxy.get("uci.network.device.@wanptm0.name")[1].value
						difname =  proxy.get("uci.network.device.@wanptm0.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
							else
								proxy.set("uci.network.interface.@wan.ifname", "ptm0")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "ptm0")
						end
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
						ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
						
						iface = string.match(ifname, "eth4")
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
		,
        operations = function()
						difname =  proxy.get("uci.network.device.@waneth4.ifname")
						if sfp == "1" then
						if difname then
						dname = proxy.get("uci.network.device.@waneth4.name")[1].value
						difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
							else
								proxy.set("uci.network.interface.@wan.ifname", "eth4")
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "eth4")
							proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
						end
						else
						if difname then
						dname = proxy.get("uci.network.device.@waneth4.name")[1].value
						difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
							else
								proxy.set("uci.network.interface.@wan.ifname", "eth4")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "eth4")
						end
						end
		end
		,
    }

	if sfp == "1" then
	
	tablecontent[#tablecontent + 1] = {
        name = "gpon",
        default = false,
        description = "GPON",
        view = "broadband-gpon-advanced.lp",
        card = "002_broadband_gpon.lp",
        check = function()
						ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
						
						iface = string.match(ifname, "eth4")
						
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
		,
        operations = function()
						difname =  proxy.get("uci.network.device.@waneth4.ifname")
						if difname then
						dname = proxy.get("uci.network.device.@waneth4.name")[1].value
						difname =  proxy.get("uci.network.device.@waneth4.ifname")[1].value
							if difname ~= "" and difname ~= nil then
								proxy.set("uci.network.interface.@wan.ifname", dname)
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							else
								proxy.set("uci.network.interface.@wan.ifname", "eth4")
								proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "eth4")
							proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
						end
		end
		,
    }
	
	end
return tablecontent