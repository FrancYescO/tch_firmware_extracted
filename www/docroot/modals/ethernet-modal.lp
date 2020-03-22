--pretranslated: do not change this file
 
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
local pairs, table = pairs, table
local content, helpmsg
local match, format, gsub = string.match, string.format, string.gsub
local ww = require("web.web")
local ipv6_pattern = "%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*"


function getAutocompleteHostsList(hosts)
    local ipv4hosts={}
    local ipv6hosts={}

    for i,v in ipairs(hosts) do
        if v.FirewallZone == "LAN" then
            local name = ww.html_escape(v.HostName)
            local iplist = ww.html_escape(v.IPAddress)
            local macaddr = ww.html_escape(v.MACAddress)
            local friendlyName

            --Get the IPv4 hosts
            local ip = iplist:match("%d+%.%d+%.%d+%.%d+") -- match first IPv4 in list (will have to do for now)
            if ip then
                if name == "" then
                        friendlyName = ip
                else
                        friendlyName = name .. " (" .. ip .. ")"
                end
                friendlyName = friendlyName .. " [" .. macaddr .. "]"
                ipv4hosts[friendlyName] = ip
            end

            --Get the IPv6 hosts
            for ipv6 in iplist:gmatch(ipv6_pattern) do
                if ipv6 then
                    if name == "" then
                        friendlyName = ipv6
                    else
                        friendlyName = name .. "(" .. ipv6 .. ")"
                    end
                    friendlyName = friendlyName .. " [" .. macaddr .. "]"
                    ipv6hosts[friendlyName] = ipv6
                end
            end
        end
    end
    return ipv4hosts, ipv6hosts
end

local hostlist = {}
local hosts_ac = {}
local hosts_mac_ac = {}
local syshosts_data = proxy.get("sys.hosts.host.")

if type(syshosts_data) == "table" then
    hostlist = content_helper.convertResultToObject("sys.hosts.host.", syshosts_data)
    if hostlist then
        hosts_ac = getAutocompleteHostsList(hostlist)
        for k, v in pairs(hosts_ac) do
            local mac = match(k, "%[(.+)%]")
            hosts_mac_ac[k] = mac
        end
     end
end

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

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf

local curintf = "lan"
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local lan_intfs = {}
for k,v in ipairs(all_intfs) do
    if v.type == "lan" then
        lan_intfs[#lan_intfs + 1] = v.paramindex
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
    end
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
    attr = { input = { class="span2" }, autocomplete=hosts_mac_ac },
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

local function sleases_name_validation(value)
  local r1, r2 = post_helper.validateNonEmptyString(value)
  if r1 then
    if string.match(value,"%s") then
      return nil, T"String may not contain space character"
    end
  end
  return r1, r2
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = post_helper.validateStringIsMAC(value)
  if r1 then
    -- dhcp static lease only supports colon format MAC, so replace - with :
    if match(value, "^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$") then
        value = gsub(value,"-",":")
    end
    object[key] = string.lower(value)
  end
  return r1, r2
end

local sleases_valid = {
    sleases_name = sleases_name_validation,
    sleases_mac = sleases_mac_validation,
    sleases_ip = post_helper.validateStringIsIP,
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.",
    createMsg = T"Add new static lease",
}


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

local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))
local lan_dhcp_intfs = {}

for k,v in ipairs(all_dhcp_intfs) do
    if v.interface == curintf then
        cur_dhcp_intf = v.paramindex
        break
    end
end
-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".start",
    dhcpLimit = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".limit",
    dhcpState = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
}

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsServer = ""
local dnsRemoved = false
local dnsServerStr1, dnsServerStr2 = "", ""

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
      if object["dnsServer1"] == "" and object["dnsServer2"] == "" then
          -- if the key does not exist, no harm done
          proxy.del(mapParams["dnsServer"]:sub(1,-6))
          -- remove the value, there is nothing to set
          object["dnsServer"] = nil
          dnsRemoved = true
      end
      return true
    else
      local valid, helpmsg = post_helper.validateStringIsIP(value, object, key)
      if not valid and dnsIndex == (#dhcp.options + 1) then
          proxy.del(mapParams["dnsServer"]:sub(1,-6))
          --dnsRemoved = true
      end

      -- DHCP option for DNS server is option 6
      if key == "dnsServer1" then
        dnsServerStr1 = value
      else
        dnsServerStr2 = value
      end
      object["dnsServer"] = string.gsub(("6," .. dnsServerStr1 .. "," .. dnsServerStr2), ",,", ",")
      return valid, helpmsg
    end
end

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"
local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid then
        if value == "0" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            local ipv6 = proxy.get(mapParams["localIPv6"]) -- get current value in datamodel to know if we're switching state
            if ipv6 and ipv6.value ~= "0" then -- default is enabled so anything non 0 is enabled
                proxy.set(IP6assign, "0") -- the value will be set back to its current value by process_query
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        end
    end
    return valid, msg
end

local mapValid = {
    localdevIP = post_helper.validateStringIsIP,
    localdevmask = post_helper.validateIPv4Netmask,
    localIPv6 = validateIPv6,
    dnsServer1 = validateDNS,
    dnsServer2 = validateDNS,
    leaseTime = post_helper.validateStringIsLeaseTime,
    dhcpStart = post_helper.getValidateNumberInRange(0,255),
    dhcpLimit = post_helper.getValidateNumberInRange(0,255),
    dhcpState = post_helper.validateBoolean,
}

local function addListContent(content, incompletes)
    for k,v in pairs(incompletes) do
        local result = proxy.get(v)
        if(result) then
            table.sort(result, function(a,b)
               return a.path < b.path
             end)

            local temp = {}
            for _,w in ipairs(result) do
                temp[#temp+1] = w.value
            end
            content[k] = temp
        end
    end
end

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
addListContent(dhcp, { options = baseDHCPOptions } )
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

local dnsServer = content["dnsServer"]
local dnsServer1, dnsServer2 = "", ""
if content["dnsServer1"]~= nil and content["dnsServer2"] ~= nil then
  dnsServer1 = string.format("%s", content.dnsServer1)
  dnsServer2 = string.format("%s", content.dnsServer2)
else
  for dnsServ in string.gmatch(dnsServer, "([^,]+)") do
    if dnsServer1 == "" then
      dnsServer1 = dnsServ
    else
      dnsServer2 = dnsServ
    end
  end
end
  ngx.print('\
\
');  
ngx.print(ui_helper.createHeader(T"Local Network", true, false))
if #sleases_data > 0 then
  ngx.print("<div class = 'alert alert-error'>"..T"In order to assign the fixed IP address to the device, it is necessary to disconnect it from the modem and connect it again"..".</div>")
end
  ngx.print('\
\
   <div class="modal-body update">\
     <form class="form-horizontal" method="post" action="modals/ethernet-modal.lp">\
     ');  
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
       ngx.print('\
     <div class="span2">\
        <ul class="nav nav-list">\
        ');  
        html = {}
        html[#html+1] = format('<li class="nav-header">%s</li>', T"LAN Interfaces")
        for k,v in ipairs(lan_intfs) do
            local active = ""
            if v == curintf then
                active = "active"
            end
            local url = "modals/ethernet-modal.lp?intf=" .. v
            html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, v)
        end
        ngx.print(html)
          ngx.print('\
         </ul>\
     </div>\
     <div class="span6">\
        ');  
        end
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
          ngx.print('\
          <fieldset>\
              <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
              ');  
              local html = {}
              local advanced = {
                    group = {
                    class = "advanced hide",
                    }
                }
              -- Labels that shows the Local Device IP address & network subnet
                html[#html + 1] = ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"])
                html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
                html[#html + 1] = ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
               ngx.print(html)
                ngx.print('\
              <legend>');  ngx.print( T"DHCP Settings" ); ngx.print('</legend>\
              ');  
                html = {}
              -- Labels that shows DHCP info
                local switchDHCP = {
                    values = {
                        on = "0",
                        off = "1"
                    }
                }

                html[#html + 1] = ui_helper.createSwitch(T"DHCP Server", "dhcpState", content["dhcpState"],switchDHCP)
                html[#html + 1] = ui_helper.createLabel(T"Network address", num2ipv4(network), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP Start address", num2ipv4(ipstart), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP End address", num2ipv4(ipend), advanced)
                html[#html + 1] = ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced, helpmsg["dhcpStart"])
                html[#html + 1] = ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced, helpmsg["dhcpLimit"])
                html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server primary", "dnsServer1", dnsServer1, advanced, helpmsg["dnsServer1"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server secondary", "dnsServer2", dnsServer2, advanced, helpmsg["dnsServer2"])
                ngx.print(html)
                ngx.print('\
              ');  
              -- Do not display the static lease when the interface is not lan
              if curintf == "lan" then
                ngx.print('\
                  <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
                  ');  
                    html = {}
                    local apply_alert = {
                        alert = {
                          class = "alert hide",
                          id = "apply_alert"
                        }
                     }
                    html[#html + 1] = ui_helper.createAlertBlock(T"To apply the changes, disconnect and reconnect your device", apply_alert)
                    html[#html + 1] = ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg)
                    ngx.print(html)
                    ngx.print('\
              </fieldset>\
              ');  
              end
                ngx.print('\
          ');  
          -- Do not display the navlist on the list if only 1 lan interface
          if #lan_intfs > 1 then
            ngx.print('\
          </div>\
          ');  
          end
            ngx.print('\
\
        </form>\
   </div>\
\
<script type=\'text/javascript\'>\
$(function() {\
    var currentlanip = "');  ngx.print( content["localdevIP"] ); ngx.print('";\
    $("[name=\'localdevIP\']").change(function(){\
      // Make dnsServer1 follow GW IP address, if user provides no explicit override\
      // This is a protective measure to have at least one valid DNS server, so leave dnsServer2 untouched\
      if (currentlanip == $("[name=\'dnsServer1\']").val()){\
          $("[name=\'dnsServer1\']").val($(this).val());\
          currentlanip = $(this).val();\
      }\
    });\
  });\
</script>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
  $(function(){\
    var tag = $("div").hasClass("btn-table-add");\
    if (tag == true) {\
        $(\'#apply_alert\').show();\
    }\
  });\
</script>\
'); 