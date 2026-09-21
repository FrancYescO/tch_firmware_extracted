gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
format = string.format

return {
    {
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
		,
    },
    {
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
		,
    },
    {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet-advanced.lp",
        card = "002_broadband_ethernet.lp",
        check = function()
						ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

						iface = string.match(ifname, "eth4")
	
					if iface then
						return true
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
							else
								proxy.set("uci.network.interface.@wan.ifname", "eth4")
							end
						else
							proxy.set("uci.network.interface.@wan.ifname", "eth4")
						end
		end
		,
    },
}
