<%
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local pairs, table = pairs, table
local content, helpmsg

-- Return number representing the IP address / netmask (first byte is first part ...)
local ipmatch = "(%d+)%.(%d+)%.(%d+)%.(%d+)"
local function ipv42num(ipstr)
    local result = 0
    local ipblocks = { string.match(ipstr, ipmatch) }
    if #ipblocks < 4 then
        return nil
    end

    for _,v in ipairs(ipblocks) do
        result = bit.lshift(result, 8) + v
    end
    return result
end

local function num2ipv4(ip)
    local ret = bit.band(ip, 255)
    local ip = bit.rshift(ip,8)
    for i=1,3 do
        ret = bit.band(ip,255) .. "." .. ret
        ip = bit.rshift(ip,8)
    end
    return ret
end

-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "text",
    attr = { input = { class="span2" } },
    unique = true,
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    unique = true,
  },
  {
    header = "",
    name = "sleases_owner",
    param = "owner",
    type = "hidden",
    readonly = true,
    attr = { },
  },
}

local sleases_attributes = {
}

local sleases_valid = {
    sleases_name = post_helper.validateNonEmptyString,
    sleases_mac = post_helper.validateStringIsMAC,
    sleases_ip = post_helper.validateStringIsIP,
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.",
    createMsg = "Add new static lease",
}

local syshosts_data = proxy.get("sys.hosts.host.")

local sleases_filter = function(data)
    if data['owner'] == "portforward" then
        local path
        if syshosts_data then
            for _, v in pairs(syshosts_data) do
                if v.value == data['mac'] then
                    path = v.path
                    break
                end
            end
            for _, v in pairs(syshosts_data) do
                if v.path == path and v.param == "HostName" then
                    data['name'] = v.value
                    break
                end
            end
        end
        return { canEdit = false, canDelete = false }
    end
    return true
end

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, sleases_filter, nil, sleases_valid)

-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@lan.start",
    dhcpLimit = "uci.dhcp.dhcp.@lan.limit",
    dhcpState = "uci.dhcp.dhcp.@lan.ignore",
    leaseTime = "uci.dhcp.dhcp.@lan.leasetime",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
    localIPv6 = "uci.network.interface.@lan.ipv6",
    localIP6assign = "uci.network.interface.@lan.ip6assign",
}

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@lan.dhcp_option."
local dnsServer = ""
local dnsRemoved = false

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
        -- if the key does not exist, no harm done
        proxy.del(mapParams[key]:sub(1,-6))
        -- remove the value, there is nothing to set
        object[key] = nil
        dnsRemoved = true
        return true
    else
        local valid, helpmsg = post_helper.validateStringIsIP(value, object, key)
        if not valid and dnsIndex == (#dhcp.options + 1) then
            proxy.delete(mapParams[key]:sub(1,-6))
            dnsRemoved = true
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return valid, helpmsg
    end
end

local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid then
        if value == "0" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            local ipv6 = proxy.get(mapParams["localIPv6"]) -- get current value in datamodel to know if we're switching state
            if ipv6 and ipv6.value ~= "0" then -- default is enabled so anything non 0 is enabled
                proxy.set(mapParams["localIP6assign"], "0") -- the value will be set back to its current value by process_query
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        end
    end
    return valid, msg
end

local mapValid = {
    localdevIP = post_helper.validateStringIsIP,
    localdevmask = post_helper.validateStringIsIP,
    localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = post_helper.validateStringIsLeaseTime,
    dhcpStart = post_helper.validatePositiveNum,
    dhcpLimit = post_helper.validatePositiveNum,
}

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
content_helper.addListContent(dhcp, { options = baseDHCPOptions } )
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v:find("^6,") == 1 then
        dnsServer = v:sub(3)
        dnsIndex = i
    end
end

-- This is quite convoluted but I only found this way to get it to work.
-- getExactContent will return an error if we access an unknown instance
-- so we cannot load from uci an option if it does not exist
-- in the end we only add the parameter to the parameters list if:
--    - it exists (get or post)
--    - we're doing a post -> in this case, we add an entry and delete it if validation fails
if (dnsIndex < #dhcp.options +1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
    mapParams["dnsServer"] = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
end
if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
end

content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start

if content["dhcpState"] == "" then
    content["dhcpState"] = "0"
end
if content["localIPv6"] == "" then
    content["localIPv6"] = "1"
end

local baseip = ipv42num(content["localdevIP"])
local netmask = ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local network = bit.band(baseip, netmask)
local ipmin = network + 1
local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
local ipend = ipstart+numips-1
if ipend > ipmax then
    ipend = ipmax
end

%>

<% ngx.print(ui_helper.createHeader(T"Local Network", true, false)) %>

   <div class="modal-body update">
     <form class="form-horizontal" method="post" action="modals/ethernet-modal.lp">
        <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        %>
          <fieldset>
              <legend><%= T"Global Information" %></legend>
              <%
              local html = {}
              local advanced = {
                    group = {
                    class = "advanced hide",
                    }
                }
              local advanceddisabled = {
                    group = {
                    class = "advanced hide",
                    },
                    input = {
                    readonly = "readonly",
                    }
                }
              -- Labels that shows the Local Device IP address & network subnet
                html[#html + 1] = ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"])
                html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
                html[#html + 1] = ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
               ngx.print(html)
              %>
              <legend><%= T"DHCP Settings" %></legend>
              <%
                html = {}
              -- Labels that shows DHCP info
                local switchDHCP = {
                    values = {
                        on = "0",
                        off = "1"
                    }
                }

                html[#html + 1] = ui_helper.createSwitch(T"DHCP Server", "dhcpState", content["dhcpState"],switchDHCP)
                html[#html + 1] = ui_helper.createInputText(T"Network address", "dhcpNetwork", num2ipv4(network), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"DHCP Start address", "dhcpStart2", num2ipv4(ipstart), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"DHCP End address", "dhcpLimit2", num2ipv4(ipend), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced, helpmsg["dhcpStart"])
                html[#html + 1] = ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced, helpmsg["dhcpLimit"])
                html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                ngx.print(html)
              %>

          </fieldset>
          <fieldset>
              <legend><%= T"Static leases" %></legend>
              <%
                ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg))
              %>
          </fieldset>
        </form>
   </div>

<% ngx.print(ui_helper.createFooter()) %>
