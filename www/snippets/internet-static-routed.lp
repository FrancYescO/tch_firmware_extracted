<%
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
local format, untaint = string.format, string.untaint
local interface_name = "wan"
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)

---
--- SETUP FOR PRINTING DATA
---
local format = string.format

---
--- SHORTCUTS FOR DATA PATHS
---
local wanIpAddrPath_uci   = uci_wan_path.."ipaddr"
local wanNetmaskPath_uci  = uci_wan_path.."netmask"
local wanGatewayPath_uci  = uci_wan_path.."gateway"

---
--- CONFIGURABLE DATA FROM MAP FILE (network.map)
---
local mapParams = {
    wanIpAddrParam    = wanIpAddrPath_uci,
    wanNetmaskParam   = wanNetmaskPath_uci,
    wanGatewayParam   = wanGatewayPath_uci,
}

---
--- FIELD VALUE INTEGRITY FUNCTIONS
---
local mapValid = {
    wanIpAddrParam    = post_helper.advancedIPValidation,
    wanNetmaskParam   = post_helper.validateIPv4Netmask,
    wanGatewayParam   = post_helper.advancedIPValidation,
}

--- GRAB CURRENT DATA AND HELP MESSAGES FROM POST HANDLER
--- FOR DNS CONFIGURATION, EITHER GET CURRENT VALUE OR LEAVE BLANK BASED ON FINDINGS
--- HELP MESSAGES APPEAR NEXT TO CONTROLS (EXAMPLE INVALID VALUE ERRORS FOR TEXT FIELDS)
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

---
--- DNS CONFIGURATION TABLE ITEMS
---
local ipv4pattern = "^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))$"
local dnsColumns = {
    {
       header = "DNS IP Address",
       name   = "wanDnsParam",                          -- MAP THIS PARAMETER AGAINST dnsValid TABLE
       param  = "value",                                -- APPENDED TO basepath OF dnsOptions TABLE
       type   = "text",
       attr   = { input = { class="span2", maxlength="15", pattern = ipv4pattern } },
    },
}

local dnsOptions = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid    = "dnsserver",
    basepath   = uci_wan_path.."dns.@.",
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
        html[#html+1] = ui_helper.createLabel(T"IP Address", content["wanIpAddrParam"])
        html[#html+1] = ui_helper.createLabel(T"Subnet Mask", content["wanNetmaskParam"])
        html[#html+1] = ui_helper.createLabel(T"Gateway", content["wanGatewayParam"])
    
        
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
    
