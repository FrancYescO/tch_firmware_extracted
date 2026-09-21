-- GHG-1541 Broadband card/modal
local content_helper = require("web.content_helper")
local format = string.format
local content = {
name =  "uci.network.interface.@wan.ifname"
}
content_helper.getExactContent(content)
local proxy = require("datamodel")
return {
    {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = function()
			ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
			
			if string.match(ifname, "atm") then
				return true
			end
		end
	    ,
        operations = {
            { "uci.network.interface.@wan.ifname", content.name},
        },
    },
    {
        name = "vdsl",
        default = true,
        description = "VDSL2",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = function()
			ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
			
			if string.match(ifname, "ptm0") then
				return true
			end
		end
		,
        operations = {
            { "uci.network.interface.@wan.ifname", "ptm0"},
        },
    },
    {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet.lp",
        card = "002_broadband_ethernet.lp",
        check = function()
			ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
			
			if string.match(ifname, "eth4") then
				return true
			end
		end
		,
        operations = {
            { "uci.network.interface.@wan.ifname", "eth4"},
        },
    },
}
