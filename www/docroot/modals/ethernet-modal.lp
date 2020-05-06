<%
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local pairs, table = pairs, table
local content, helpmsg
local match, format  = string.match, string.format
local find, untaint = string.find, string.untaint
local interface_name = proxy.get("uci.env.custovar.wan_if")[1].value
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)


local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = match(k, "%[(.*)%]")
    hosts_mac[k] = mac
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
local wireless_radio = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local radios = match(v.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
  if radios then
    wireless_radio[radios] = true
  end
end
local lan_intfs = {}
for k,v in ipairs(all_intfs) do
    if v.type == "lan" and (not find(v["ppp.ll_intf"], "wl") or wireless_radio[untaint(v["ppp.ll_intf"])])then
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
    attr = { input = { class="span2", maxlength="63" } },
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "text",
    attr = { input = { class="span2", maxlength="17" }, autocomplete=hosts_mac },
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

local function sleases_name_validation(value)
  if #value == 0 or #value > 63 then
    return nil, T"A hostname must be between 1 and 63 characters"
  end
  if match(value, "[^%w%-]") then
    return nil, T"A hostname must contain only alphanumeric characters and dash"
  end
  return true
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = post_helper.validateStringIsMAC(value)
  if r1 then
    if string.lower(value) == "ff:ff:ff:ff:ff:ff" then
        return nil, T"The requested MAC address can't be the broadcast MAC"
    else
        object[key] = string.lower(value)
    end
  end
  return r1, r2
end

local function sleases_ip_validation(value, object, key)
    local errCode, errMsg = post_helper.validateStringIsIP(value, object, key)
    if(errCode == nil) then
        return errCode, errMsg
    end

    local result = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    if(value == result) then
        return nil, T"The requested IP can't be the same as the gateway IP"
    end

    local networkAddress = session:retrieve("networkAddr")

    if value == networkAddress then
        return nil, T"The requested IP can't be the Network Address"
    end

    local baseip = post_helper.ipv42num(result)

    result = proxy.get("uci.network.interface.@" .. curintf .. ".netmask")[1].value
    local mask = post_helper.ipv42num(result)

    local ip = post_helper.ipv42num(value)

    if(bit.band(ip, 255) == 255) then
        return nil, T"The requested IP can't be the broadcast IP"
    end

    if(bit.band(ip, mask) == bit.band(baseip, mask)) then
        return true
    end
    return nil, T"The requested IP is not in the same subnet as the gateway"
end

local sleases_valid = {
    sleases_name = sleases_name_validation,
    sleases_mac = sleases_mac_validation,
    sleases_ip = sleases_ip_validation,
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.",
    createMsg = T"Add new static lease",
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
    localIP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign",
}


local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsServer = ""
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
content_helper.addListContent(dhcp, { options = baseDHCPOptions } )
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v:find("^6,") == 1 then
        dnsServer = v:sub(3)
        dnsIndex = #dhcp.options
    end
end

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
        local dnsservers = {}
        local Index = 0
        local lastIndex = 0
        local dns = {}
        for word in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = word
          local valid, helpmsg = post_helper.validateStringIsIP(word, object, key)
          if not valid then
            return valid, helpmsg
          end
        end
        if #dns > 3 then
            return nil, nil
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return true
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
        -- Modify IPv6 at WAN-side accordingly:
        -- this is especially necessary to make sure Neighbor Solicitation (for DAD etc.) messages are sent upon network reload
        proxy.set(uci_wan_path.."ipv6", value)
        proxy.apply()
    end
    return valid, msg
end

local function validateLeaseTime(value, postdata, key)
   local success, msg = post_helper.validateStringIsLeaseTime(value)
   if success then
     postdata["leaseTime"] = match(untaint(value), "^0*([1-9]%d*[smhdw]?)$")
     return true
   else
     return nil, msg
   end
end
--[[
Function calculateDHCPStartAddress, Calculating DHCPStartaddress using localdeviceip, netmask, newstart and newlimit value. function returns DHCPStartAddress, DHCPEndAddress  and NetworkAddress
]]
local function calculateDHCPStartAddress (baseip, netmask, start, numips)
    local network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local ipend = ipstart+numips-1
    ipstart = num2ipv4(ipstart)
    if ipend > ipmax then
      ipend = ipmax
    end
    ipend = num2ipv4(ipend)
    network = num2ipv4(network)
  return ipstart,ipend,network
end
--[[
  Function validateAndCalculateNewStart first check for Newstart value contain only number and check for DHCPstartaddress not equal to localDeviceIP, based on newstart and newlimit value.
]]
local function validateAndCalculateNewStart(value, object)
    local validatorNumberInRange = post_helper.getValidateNumberInRange(1,255)
    local val, msg = validatorNumberInRange(value)
    if not val then
        return nil,  msg
    end
    if object["dhcpStart"] then
        local val, msg = validatorNumberInRange(object["dhcpStart"])
        if not val then
            return nil, "[dhcpStart] " .. msg
        end
    end

  if string.match(value, "^[0-9]*$") then
    local baseip = post_helper.ipv42num(string.untaint(object["localdevIP"]))
    local netmask = post_helper.ipv42num(object["localdevmask"])
    local start = tonumber(object["dhcpStart"])
    local numips = tonumber(object["dhcpLimit"])
    if not netmask or not baseip or not numips then
        return nil, T"Invalid Input"
    end
    local ipstart,_,_ = calculateDHCPStartAddress(baseip,netmask,start,numips)
    baseip =  num2ipv4(baseip)
    if ipstart ~= baseip then
      return true
    else
      return nil, T"Invalid Input"
    end

  else
    return nil, T"Invalid Input"
  end
end

local mapValid = {
    localdevIP = post_helper.advancedIPValidation,
    localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = validateLeaseTime,
    dhcpStart = post_helper.getValidateNumberInRange(1,255),
    -- as dhcpStart and dhcpLimit validators are combined, we only assign to one of them, and move helpmsg later on to the correct field
    dhcpLimit = validateAndCalculateNewStart,
}

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
-- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
-- If so move it to localdevmask
if helpmsg["localdevIP"] then
  local msg = match(helpmsg["localdevIP"], '^%[netmask%] (.*)')
  if msg then
    helpmsg["localdevIP"] = nil
    helpmsg["localdevmask"] = msg
  end
end
if helpmsg["dhcpLimit"] then
    local msg = match(helpmsg["dhcpLimit"], '^%[dhcpStart%] (.*)')
    if msg then
        helpmsg["dhcpLimit"] = nil
        helpmsg["dhcpStart"] = msg
    end
end

-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] == nil then
    local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    content["dnsServer"] = localIP
else
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
    end
end

if content["dhcpState"] == "" then
    content["dhcpState"] = "0"
end
if content["localIPv6"] == "" then
    content["localIPv6"] = "1"
end

local baseip = post_helper.ipv42num(content["localdevIP"])
local netmask = post_helper.ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local ipstart,ipend,network
if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] then
  ipstart,ipend,network = calculateDHCPStartAddress(baseip,netmask,start,numips)
  session:store("dhcpStartAddr",ipstart)
  session:store("dhcpEndAddr",ipend)
  session:store("networkAddr",network)
 else
   ipstart = session:retrieve("dhcpStartAddr")
   ipend = session:retrieve("dhcpEndAddr")
   network =session:retrieve("networkAddr")
 end


%>

<% ngx.print(ui_helper.createHeader(T"Local Network", true, false)) %>

   <div class="modal-body update">
     <form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
     <%
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
     %>
     <div class="span2">
        <ul class="nav nav-list">
        <%
        local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
        for k,v in ipairs(lan_intfs) do
            local active = ""
            if v == curintf then
                active = "active"
            end
            local url = "modals/ethernet-modal.lp?intf=" .. v
            html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, v, url, v)
        end
        ngx.print(html)
        %>
        </ul>
     </div>
     <div class="span6">
        <%
        end
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        %>
          <fieldset>
              <legend><%= T"Global Information" %></legend>
              <%
              local advanced = {
                group = {
                  class = "advanced hide"
                }
              }
         local advanced_pattern = {
           group = {
             class = "advanced hide",
           },
           input = {
             pattern = "[1-9]{1,3}",
             maxlength = "3",
           }
         }
              -- Labels that shows the Local Device IP address & network subnet
              ngx.print(
                ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"]),
                ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"]),
                ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
              )
              %>
              <legend><%= T"DHCP Settings" %></legend>
              <%
                -- Labels that shows DHCP info
                local switchDHCP = {
                  values = {
                    on = "0",
                    off = "1"
                  }
                }
              ngx.print(
                  ui_helper.createSwitch(T"DHCP Server", "dhcpState", content["dhcpState"],switchDHCP),
                  ui_helper.createLabel(T"Network address", network, advanced),
                  ui_helper.createLabel(T"DHCP Start address", ipstart, advanced),
                  ui_helper.createLabel(T"DHCP End address", ipend, advanced),
                  ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced_pattern, helpmsg["dhcpStart"]),
                  ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced_pattern, helpmsg["dhcpLimit"]),
                  ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"]),
                  ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                )
               %>
              <%
              -- Do not display the static lease when the interface is not lan
              if curintf == "lan" then
              %>
                  <legend><%= T"Static leases" %></legend>
                  <%
                    ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, nil, sleases_helpmsg))
                  %>
              </fieldset>
              <%
              end
              %>
          <%
          -- Do not display the navlist on the list if only 1 lan interface
          if #lan_intfs > 1 then
          %>
          </div>
          <%
          end
          %>
        </form>
   </div>

<script type='text/javascript'>
$(function() {
    var currentlanip = "<%= content["localdevIP"] %>";
    $("[name='localdevIP']").change(function(){
      if (currentlanip == $("[name='dnsServer']").val()){
          $("[name='dnsServer']").val($(this).val());
          currentlanip = $(this).val();
      }
    });
  });
</script>

<% ngx.print(ui_helper.createFooter()) %>
