<%
-- NG-49023 GUI-Nat Settings not changeable
---
--- ENABLE LOCALIZATION
---
gettext.textdomain('webui-core')

---
--- REQUIRED LIBRARIES
---
--- content_helper: extracts information from the data model / uci layer
--- ui_helper:      controls creation of web ui widgets (switches, text entry, radio buttons, etc)
--- post_helper:    controls behavior of POST messages sent from web ui to Transformer
--- proxy:          used for access to the data model / uci layer (get and set methods)
--- message_helper: produces human readable content in the web ui (e.g. errors, success prompts)
---
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local message_helper = require("web.uimessage_helper")
local firewall_zone = "uci.firewall.zone."
local firewall_zone_path = content_helper.getMatchedContent(firewall_zone)
local zonenum = ""
for i, v in ipairs(firewall_zone_path) do
   local path = string.match(firewall_zone_path[i].path, "uci%.firewall%.zone%.([^%.]+)")
   if (v["name"] == "wan") then
	   zonenum = path
   end
end
local firewall_forwarding = "uci.firewall.forwarding."
local firewall_forwarding_path = content_helper.getMatchedContent(firewall_forwarding)
local forwdnum = ""
for i, v in ipairs(firewall_forwarding_path) do
   local path = string.match(firewall_forwarding_path[i].path, "uci%.firewall%.forwarding%.([^%.]+)")
   if (v["src"] == "wan" and v["dest"] == "lan") then
	   forwdnum = path
   end
end
local function validateNat(value, object, key)
    local valid = post_helper.validateBoolean(value, object, key)
		if valid and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
		proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
			if value == "1" then
				if forwdnum == "" then
					forwdnum = proxy.add("uci.firewall.forwarding.")
						proxy.set("uci.firewall.forwarding."..forwdnum..".src", "wan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".dest", "lan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".name", "for_w2l")
						proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
				else
					proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
				end
			else
				if forwdnum == "" then
					forwdnum = proxy.add("uci.firewall.forwarding.")
						proxy.set("uci.firewall.forwarding."..forwdnum..".src", "wan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".dest", "lan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".name", "for_w2l")
						proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
				else
					proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
				end
			end
			proxy.apply()
		end
    return valid, msg
end
---
--- SETUP FOR PRINTING DATA
---
local format = string.format

---
--- SHORTCUTS FOR DATA PATHS
---
local wanIpAddrPath_uci   = "uci.network.interface.@wan.ipaddr"
local wanNetmaskPath_uci  = "uci.network.interface.@wan.netmask"
local wanGatewayPath_uci  = "uci.network.interface.@wan.gateway"

---
--- CONFIGURABLE DATA FROM MAP FILE (network.map)
---
local mapParams = {
    wanIpAddrParam    = wanIpAddrPath_uci,
    wanNetmaskParam   = wanNetmaskPath_uci,
    wanGatewayParam   = wanGatewayPath_uci,
	uci_wan_masq 	= "uci.firewall.zone."..zonenum..".masq",	
}

---
--- FIELD VALUE INTEGRITY FUNCTIONS
---
local mapValid = {
    wanIpAddrParam    = post_helper.advancedIPValidation,
    wanNetmaskParam   = post_helper.validateIPv4Netmask,
    wanGatewayParam   = post_helper.advancedIPValidation,
	uci_wan_masq 	= validateNat,
}

--- GRAB CURRENT DATA AND HELP MESSAGES FROM POST HANDLER
--- FOR DNS CONFIGURATION, EITHER GET CURRENT VALUE OR LEAVE BLANK BASED ON FINDINGS
--- HELP MESSAGES APPEAR NEXT TO CONTROLS (EXAMPLE INVALID VALUE ERRORS FOR TEXT FIELDS)
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

---
--- DNS CONFIGURATION TABLE ITEMS
---

local dns_loopback = proxy.get("rpc.network.interface.@loopback.dnsservers")[1].value

local ipv4pattern = "^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))$"
local dnsColumns = {
    {
       header = T"DNS IP Address",
       name   = "wanDnsParam",                          -- MAP THIS PARAMETER AGAINST dnsValid TABLE
       param  = "value",                                -- APPENDED TO basepath OF dnsOptions TABLE
       type   = "text",
       attr   = { input = { class="span2", maxlength="15", pattern = ipv4pattern } },
    },
}

local dnsOptions = {
    tableid    = "dnsserver",
    basepath   = "uci.network.interface.@wan.dns.@.",
    createMsg  = T"Add New DNS",
    minEntries = 1,
    maxEntries = 4,                                     -- ADJUST LIMIT AS SEEN FIT
    sorted = function(a, b)
        return tonumber(a.paramindex) < tonumber(b.paramindex)
    end
}

local dnsValid = {
    wanDnsParam =  post_helper.advancedIPValidation,
}

local dnsData, dnsHelpMsg = post_helper.handleTableQuery(dnsColumns, dnsOptions, nil, nil, dnsValid)

---
--- TRIGGERED DURING POST OPERATION ON IP ADDRESS
---    1) GRABS POST ACTION AND ARGUMENTS FROM POST
---    2) CLEARS OUT MESSAGES FROM THE MESSAGE_HELPER QUEUE (THROUGH 'popMessages' CALL)
---    3) AFTER CHECKING WHICH PARAMETER IS GETTING UPDATED, VERIFIES FIELD VALUE
---    4) IF FIELD VALIDATION PASSES, TELL TRANSFORMER (THROUGH PROXY) TO PHYSICALLY UPDATE VALUE
---    5) UNDERLYING HARDWARE SHOULD GET CONFIGURED AUTOMATICALLY
if ngx.req.get_method() == "POST" then
    local postContent = ngx.req.get_post_args()
    local actionVal   = postContent["action"]
    
    local ipVal       = postContent["wanIpAddrParam"]
    local netmaskVal  = postContent["wanNetmaskParam"]
    local gatewayVal  = postContent["wanGatewayParam"]    
	
    if actionVal == "wanIpAddrParam" then
        content["wanIpAddrParam"] = ipVal
        proxy.set(wanIpAddrPath_uci,ipVal)
        proxy.apply()
    end
    if actionVal == "wanNetmaskParam" then
        content["wanNetmaskParam"] = netmaskVal
        proxy.set(wanNetmaskPath_uci,netmaskVal)
        proxy.apply()
    end
    if actionVal == "wanGatewayParam" then
        content["wanGatewayParam"] = gatewayVal
        proxy.set(wanGatewayPath_uci,gatewayVal)
        proxy.apply()
    end
end
    
%>
<%
--- THIS SECTION SETS UP COSMETICS FOR THE SUB-MENU (MODAL)
--- EACH CONTROL HAS THE OPTION OF SETTING ATTRIBUTES (WRAPPED INTO A "CLASS" CONTAINER) 
--- IN THIS CASE, INPUT TEXT FIELDS ARE RESPONSIBLE FOR GATHERING INFORMATION ABOUT THE WAN INTERFACE
%>
<%
-- CLEAR ALL MESSAGES FROM THE QUEUE
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
    <legend><%= T"Static Connection" %></legend>
    <%
        local html = {}

        local wanIPClass = {}
        wanIPClass["input"] = {
            ["data-for"] = "wanIpAddrParam",
            ["pattern"] = ipv4pattern
        }

        local wanNetmaskClass = {}
        wanNetmaskClass["input"] = {
            ["data-for"] = "wanNetmaskParam",
            ["pattern"] = ipv4pattern
        }

        local wanGatewayClass = {}
        wanGatewayClass["input"] = {
            ["data-for"] = "wanGatewayParam",
            ["pattern"] = ipv4pattern
        }

        -- UI CONTROLS LIST
        -- ARGUMENT 2 MUST MUST MATCH PARAMETER NAME FROM mapParams OR ERRORS WILL OCCUR DURING INTERFACE UPDATES
        html[#html + 1] = ui_helper.createSwitch(T"Nat", "uci_wan_masq", content.uci_wan_masq)
		html[#html+1] = ui_helper.createInputText(T"IP Address", "wanIpAddrParam", content["wanIpAddrParam"], wanIPClass, helpmsg["wanIpAddrParam"])
        html[#html+1] = ui_helper.createInputText(T"Subnet Mask", "wanNetmaskParam", content["wanNetmaskParam"], wanNetmaskClass, helpmsg["wanNetmaskParam"])
        html[#html+1] = ui_helper.createInputText(T"Gateway", "wanGatewayParam", content["wanGatewayParam"], wanGatewayClass, helpmsg["wanGatewayParam"])
        if dns_loopback ~= "" then
            html[#html+1] = ui_helper.createLabel(T"DNS Servers", dns_loopback)
        end

        ngx.print(html)
    %>
</fieldset>
<%
--- IN THIS SECTION, TABLE OF DNS SERVERS IS CREATED.  
--- HARD LIMITS ARE SET THROUGH "minEntries" AND "maxEntries" FIELDS OF THE "dnsOptions" TABLE
%>
<fieldset>
    <legend><%= T"Domain Name Server Configuration"  %></legend>
    <%
        local html2 = {}
        
        -- UI CONTROLS LIST
        html2[#html2+1] = ui_helper.createTable(dnsColumns, dnsData, dnsOptions, nil, dnsHelpMsg)        
        
        ngx.print(html2)
    %>
</fieldset>    
    
