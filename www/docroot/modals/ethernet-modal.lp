--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local tonumber = tonumber
local content, helpmsg
local match, format  = string.match, string.format
local find, untaint = string.find, string.untaint

-- Shortcuts to validation helpers to make lines shorter
local ipv42num = post_helper.ipv42num
local gAV = post_helper.getAndValidation
local aIPV = post_helper.advancedIPValidation
local vIP4N = post_helper.validateIPv4Netmask
local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = match(k, "%[(.*)%]")
    hosts_mac[k] = mac
end

local function num2ipv4(ip)
    local ret = bit.band(ip, 255)
    ip = bit.rshift(ip,8)
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
        if v.name and v.name ~= "" then
            lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex}
        else
            lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex}
        end
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
  if (value:find("^ReservedStatic") ~= nil) then
    return nil, T"Cannot use reserved names as static lease name"
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
    sleases_name = gAV(sleases_name_validation,post_helper.validateStringIsDomainName),
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
    dhcpv4State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv4",
    dhcpIgnore = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
}

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
content_helper.addListContent(dhcp, { options = baseDHCPOptions } )
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v:find("^6,") == 1 then
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
        local dns = {}
        for word in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = word
          local valid, helpmsg_validip = post_helper.advancedIPValidation(word, object, key)
          if not valid then
            return valid, helpmsg_validip
          end
        end
        if #dns > 3 then
            return nil, nil
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return true
    end
end

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"
local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid then
        proxy.set("uci.env.var.useripv6", "1")
        local ipv6 = proxy.get(mapParams["localIPv6"])[1].value -- get current value in datamodel to know if we're switching state
        if value == "0" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            if ipv6 and untaint(ipv6) ~= "0" then -- default is enabled so anything non 0 is enabled
                -- set ra to 'disabled' in dhcp config
                proxy.set("uci.dhcp.dhcp.@" .. curintf .. ".ra", "disabled")
                -- need to delete ip6assign entry
                proxy.set(IP6assign, "")
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        else
            if ipv6 and untaint(ipv6) == "0" then
                -- enable router advertisements and set ip6assign value back to default
                proxy.set("uci.dhcp.dhcp.@" .. curintf .. ".ra", "server")
                proxy.set(IP6assign, "64")
                proxy.apply()
            end
        end
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
local gPHS = post_helper.getPossibleHostsInSubnet
local function validateNewLimit(value, object)
    local validatorNumberInRange = post_helper.getValidateNumberInRange(1,gPHS(object["localdevmask"]))
    local limitvalue, limitmsg =  validatorNumberInRange(value)
    if not limitvalue then
        return nil, limitmsg
    end
    if string.match(value, "^[0-9]*$") then
        return true
    else
       return nil, T"Invalid Limit Value"
    end
end

local function validateAndCalculateNewStart(value, object)
    local validatorNumberInRange = post_helper.getValidateNumberInRange(1,gPHS(object["localdevmask"]))
    local val, msg = validatorNumberInRange(value)
    if not val then
        return nil,  msg
    end
    if object["dhcpStart"] then
        val, msg = validatorNumberInRange(object["dhcpStart"])
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
    local ipstart,_,network = calculateDHCPStartAddress(baseip,netmask,start,numips)
    baseip =  num2ipv4(baseip)
    if ipstart == baseip then
      return nil, T"Invalid Input.Ensure that DHCP Start Address should not be equal to Local Device IP address."
    elseif ipstart == network then
      return nil, T"Invalid Input.Ensure that DHCP Start Address should not be equal to Network address."
    else
      return true
    end

  else
    return nil, T"Invalid Input"
  end
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
local function validatelocalDevIp(value, object, key)
   local val, errmsg = aIPV(value, object, key)
   if not val then
      return nil, errmsg
   end
   local ip = ipv42num(value)

   if value and post_helper.isPublicIP(value) then
      return nil, T"Public IP Range should not be used"
   end

   for _, intf in ipairs(lan_intfs) do
      if intf.index ~= curintf then
         local ipaddr, mask, baseip, netmask, network, ipmax
         ipaddr = proxy.get("uci.network.interface.@" .. intf.index .. ".ipaddr")[1].value
         mask = proxy.get("uci.network.interface.@" .. intf.index .. ".netmask")[1].value
         baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
         netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)

         if baseip and netmask then
            network = bit.band(baseip, netmask)
            ipmax = bit.bor(network, bit.bnot(netmask))
         end

         if network and ipmax then
            if ip >= network and ip <= ipmax then
               if intf.name ~= "" then
                  return nil, T"Gateway IP should not be in " .. intf.name .. T" IP Range"
               else
                  return nil, T"Gateway IP should not be in " .. intf.index .. T" IP Range"
               end
            end
         end
      end
   end
   return true
end

local dhcpv4StateSelect = {
    {"server"},
    {"disabled"},
}

local mapValid = {
    localdevIP = validatelocalDevIp,
    localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = validateLeaseTime,
    localdevmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
    dhcpStart = validateAndCalculateNewStart,
    -- as dhcpStart and dhcpLimit validators are combined, we only assign to one of them, and move helpmsg later on to the correct field
    dhcpLimit = validateNewLimit,
    dhcpv4State = post_helper.getValidateInEnumSelect(dhcpv4StateSelect),
    dhcpIgnore =  validatedhcpIgnore,
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

if content["dhcpv4State"] == "" then
    content["dhcpv4State"] = "server"
end
if content["localIPv6"] == "" then
    content["localIPv6"] = "1"
end
if not match(content["leaseTime"],"^0*([1-9]%d*[smhdw])$") then
  content["leaseTime"] = content["leaseTime"] .. "s"
end
local baseip = post_helper.ipv42num(content["localdevIP"])
local netmask = post_helper.ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local ipstart,ipend,network
if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"]  then
  ipstart,ipend,network = calculateDHCPStartAddress(baseip,netmask,start,numips)
  session:store("dhcpStartAddr",ipstart)
  session:store("dhcpEndAddr",ipend)
  session:store("networkAddr",network)
 else
   ipstart = session:retrieve("dhcpStartAddr")
   ipend = session:retrieve("dhcpEndAddr")
   network =session:retrieve("networkAddr")
 end
if helpmsg["leaseTime"] then
  content["leaseTime"] = ngx.req.get_post_args().leaseTime
end
if ngx.var.request_method == "POST" then
  local gwIP = session:retrieve("old_ip")
  session:store("old_ip",(content["localdevIP"]))
  if content["localdevIP"]~= gwIP and not next(helpmsg) then  ngx.print('\
    <script type="text/javascript">\
      window.location="http://');  ngx.print(content["localdevIP"]); ngx.print('";\
    </script>\
    ');  session:logout()
  end
else
  session:store("old_ip",(content["localdevIP"]))
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", true, false))   ngx.print('\
\
   <div class="modal-body update">\
     <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
     ');  
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
       ngx.print('\
     <div class="span2">\
        <ul class="nav nav-list">\
        ');  
        local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
        for k,v in ipairs(lan_intfs) do
            local active = ""
            if v.index == curintf then
                active = "active"
            end
            local url = "modals/ethernet-modal.lp?intf=" .. v.index
            html[#html+1] = format('<li class="%s"><a id="%s" href="#" data-remote="%s">%s</a></li>', active, v.index, url, v.name)
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
             pattern = "[1-9]{1}[0-9]*",
           }
         }
              -- Labels that shows the Local Device IP address & network subnet
              ngx.print(
                ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"]),
                ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"]),
                ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
              )
                ngx.print('\
              <legend>');  ngx.print( T"DHCP Settings" ); ngx.print('</legend>\
              ');  
                -- Labels that shows DHCP info
                local switchDHCP = {
                  values = {
                    on = "server",
                    off = "disabled"
                  }
                }
              ngx.print(
                  ui_helper.createSwitch(T"DHCP Server", "dhcpv4State", content["dhcpv4State"],switchDHCP),
                  ui_helper.createLabel(T"Network address", network, advanced),
                  ui_helper.createLabel(T"DHCP Start address", ipstart, advanced),
                  ui_helper.createLabel(T"DHCP End address", ipend, advanced),
                  ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced_pattern, helpmsg["dhcpStart"]),
                  ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced_pattern, helpmsg["dhcpLimit"]),
                  ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"]),
                  ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                )
                 ngx.print('\
              ');  
              -- Do not display the static lease when the interface is not lan
              if curintf == "lan" then
                ngx.print('\
                  <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
                  ');  
                    ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, nil, sleases_helpmsg))
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
        </form>\
   </div>\
\
<script type=\'text/javascript\'>\
$(function() {\
    var currentlanip = "');  ngx.print( content["localdevIP"] ); ngx.print('";\
    $("[name=\'localdevIP\']").change(function(){\
      if (currentlanip == $("[name=\'dnsServer\']").val()){\
          $("[name=\'dnsServer\']").val($(this).val());\
          currentlanip = $(this).val();\
      }\
    });\
  });\
</script>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 