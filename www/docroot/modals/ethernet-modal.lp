--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local inet = require("tch.inet")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local bridged = require("bridgedmode_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local pairs, table = pairs, table
local content, helpmsg
local match, format, untaint, gsub = string.match, string.format, string.untaint, string.gsub
local default_lan = 'lan'
local ipv42num = post_helper.ipv42num
local gVSIIN = post_helper.getValidateStringIsIPv4InNetwork
local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = k:match("%[(.*)%]")
    hosts_mac[k] = mac
end

local function num2ipv4(ip)
    if not ip then
        return ""
    end
    local ret = bit.band(ip, 255)
    local ip = bit.rshift(ip,8)
    for i=1,3 do
        ret = bit.band(ip,255) .. "." .. ret
        ip = bit.rshift(ip,8)
    end
    return ret
end

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf or default_lan

local curintf = default_lan
-- Get all the LAN interfaces
local net_intfs_path = "uci.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local lan_intfs, other_lan_ips, other_lan_nms, bridges = {}, {}, {}, {}
for _,v in ipairs(all_intfs) do
    local network_type = proxy.get('rpc.network.interface.@' .. v.paramindex .. '.type')
    network_type = network_type and network_type[1].value
    if network_type == 'lan' then
        -- remove VLANx as these will be handled in multi-bridge page
        if not match(v.paramindex, "^VLAN%d$") then
            lan_intfs[#lan_intfs + 1] = v.paramindex
        else
            bridges[#bridges +1] = v.paramindex
        end
        if v.paramindex == getintf then
            curintf = v.paramindex
        else
            if v.ipaddr ~= "" then
                other_lan_ips[v.paramindex] = untaint(v.ipaddr)
                other_lan_nms[v.paramindex] = untaint(v.netmask)
            end
        end
    end
end
bridges[#bridges +1] = default_lan

table.sort(lan_intfs, function(a,b)
    if a == default_lan then
        return true
    elseif b == default_lan then
        return false
    elseif a < b then
        return true
    end
    return false
end)

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

local sleases_attributes = {
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
      value = value:match("^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$") and value:gsub("-",":") or value
      object[key] = string.lower(value)
  end
  return r1, r2
end

local function sleases_ip_validation(value, object)
    local contentdata = {
      localdevIP = "rpc.network.interface_lan.@" .. curintf .. ".ipaddr",
      localdevmask = "rpc.network.interface_lan.@" .. curintf .. ".netmask",
    }
    content_helper.getExactContent(contentdata)
    return post_helper.staticLeaseIPValidation(value, contentdata)
end

local sleases_valid = {
    sleases_name = sleases_name_validation,
    sleases_mac = sleases_mac_validation,
    sleases_ip = sleases_ip_validation,
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.@.",
    createMsg = T"Add new static lease",
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true,
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

local cur_dhcp_intf = default_lan
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
    localdevIP = "rpc.network.interface_lan.@" .. curintf .. ".ipaddr",
    localdevmask = "rpc.network.interface_lan.@" .. curintf .. ".netmask",
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
}

local firewall_rule_names
if curintf ~= default_lan then
    mapParams["guestruleaddress"] = "rpc.network.firewall.guestruleaddress"
    firewall_rule_names = {}
    for _, bridge in ipairs(bridges) do
        firewall_rule_names[#firewall_rule_names + 1] = format("drop-%s_2_%s_GW", bridge, curintf)
    end
    firewall_rule_names[#firewall_rule_names + 1] = format("Allow-%s_ICMP", curintf)
end

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
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
        local content_uci = {
            localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
        }
        content_helper.getExactContent(content_uci)
        if object.localdevIP ~= content_uci.localdevIP and value == content_uci.localdevIP then
            object[key] = "6," .. object.localdevIP
        else
            local valid, helpmsg_validip = post_helper.validateStringIsIP(value, object, key)
            if valid then
                local isNetmask = post_helper.validateIPv4Netmask(value)
                if isNetmask then
                    return nil, T"Cannot use netmask as DNS server IP"
                end
                local dnsIP, errmsg = post_helper.DNSIPValidation(value, object)
                if errmsg then
                    return nil, errmsg
                end
            end
            if not valid and dnsIndex == (#dhcp.options + 1) then
                proxy.delete(mapParams[key]:sub(1,-6))
                dnsRemoved = true
            end
            object[key] = "6," .. value -- DHCP option for DNS server is option 6
            return valid, helpmsg
        end
    end
    return true
end

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"
local tch_IP6assign = "uci.network.interface.@" .. curintf .. ".tch_ip6assign"  -- cache variable
local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    local ip6assign = proxy.get(IP6assign)[1].value -- get current value and store in cache if we are switching state
    local tch_ip6assign = proxy.get(tch_IP6assign)[1].value  -- fetching from cache
    if not tch_ip6assign or tch_ip6assign == "" then
        tch_ip6assign = ip6assign
    end
    if valid then
        local ipv6 = proxy.get(mapParams["localIPv6"])[1].value -- get current value in datamodel to know if we're switching state
        if value == "0" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            if ipv6 and untaint(ipv6) ~= "0" then -- default is enabled so anything non 0 is enabled
                -- set ra to 'disabled' in dhcp config
                proxy.set("uci.dhcp.dhcp.@" .. curintf .. ".ra", "disabled")
                -- need to delete ip6assign entry
                proxy.set(tch_IP6assign, ip6assign)  -- save current value to cache
                proxy.set(IP6assign, "")
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        else
            if ipv6 and untaint(ipv6) == "0" then
                -- enable router advertisements and restore ip6assign value from cache
                proxy.set("uci.dhcp.dhcp.@" .. curintf .. ".ra", "server")
                proxy.set(IP6assign, tch_ip6assign)  -- restore value from cache
                proxy.set(tch_IP6assign, "")         -- reset cache
                proxy.apply()
            end
        end
    end
    return valid, msg
end

local function validatedevIP(value, object, key)
    local valid, msg = post_helper.advancedIPValidation(value, object, key)
    if valid then
        local netmask = untaint(object.localdevmask)
        local result, nm1 = inet.validateIPv4Netmask(netmask)
        if result then
            for k,v in pairs(other_lan_ips) do
                local _, nm2 = inet.validateIPv4Netmask(other_lan_nms[k])
                local validate
                if nm1 > nm2 then
                     validate = gVSIIN(untaint(value), netmask)
                     result = validate(v)
                else
                     validate = gVSIIN(v, other_lan_nms[k])
                     result = validate(value)
                end
                if result then
                    return nil, 'IP address ' .. value .. '/' .. (32-nm1) .. ' should not be overlapped with LAN IP interface ' .. k ..'(' .. v .. '/' .. (32-nm2) ..')'
                end
            end
        end

        if firewall_rule_names then
            object["guestruleaddress"] = format("%s|%s", value, table.concat(firewall_rule_names, ","))
        end
    end
    return valid, msg
end

local function getDHCPData(object)
  -- Check the entered IP is valid IP and convert it to number
  local baseip = post_helper.validateStringIsIP(object["localdevIP"]) and ipv42num(object["localdevIP"])
  local netmask = post_helper.validateStringIsIP(object["localdevmask"]) and ipv42num(object["localdevmask"])
  local start = tonumber(object["dhcpStart"])
  local numips = tonumber(object["dhcpLimit"])
  return baseip, netmask, start, numips
end

local function validateDHCPStart(value, object)
       if match(value, "^[0-9]*$") then
          local baseip, netmask, start, numips = getDHCPData(object)
          if baseip and netmask and start and numips then
             local network = bit.band(baseip, netmask)
             local ipmax = bit.bor(network, bit.bnot(netmask))
             local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
             local limit = ipmax - network - 1
             if ipstart == network then
                return nil, T"DHCP Start value should not be a Network Address"
             elseif ipstart == ipmax then
                return nil, T"DHCP Start value should not be a broadcast address"
             elseif ipstart == baseip then
                return nil, T"DHCP Start value should not be gateway ip"
             end
             local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)
             local val = validatorNumberInRange(start)
             if not val then
                return nil, T"DHCP Start Address is not valid in Subnet Range"
             end
             object["dhcpStart"] = tostring(start)
             return true
          end
       else
       return nil, T"DHCP Start value is Invalid"
       end
end

local function validateDHCPLimit(value, object)
       if match(value, "^[0-9]*$") then
          local baseip, netmask, start, numips = getDHCPData(object)
          local temp, err = post_helper.getValidateWholeNumber(tostring(start))
          if not temp then
             return nil
          end
          if baseip and netmask and start and numips then
             local network = bit.band(baseip, netmask)
             local ipmax = bit.bor(network, bit.bnot(netmask))
             local limit = ipmax - network - start
             local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)
             local val = validatorNumberInRange(numips)
             if not val then
                return nil, T"DHCP Limit value not within subnet range"
             end
             object["dhcpLimit"] = tostring(numips)
          return true
       end
       else
       return nil, T"DHCP Limit value is invalid"
       end
end

local mapValid = {
    localdevIP = validatedevIP,
    localdevmask = post_helper.validateIPv4Netmask,
    localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = post_helper.validateStringIsLeaseTime,
    dhcpStart = validateDHCPStart,
    dhcpLimit = validateDHCPLimit,
    dhcpState = post_helper.validateBoolean,
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
local ipstart, ipend, network
if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"] then
    network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    ipend = ipstart+numips-1
    if ipend > ipmax then
        ipend = ipmax
    end
end

local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "BRIDGED" then
        if not bridged.isBridgedMode() then
            bridged.configBridgedMode()
            return resetreboot("rpc.system.reboot", "GUI")
        end
    end
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", true, false))   ngx.print('\
\
   <div class="modal-body update">\
     <form class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
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
        if not bridged.isBridgedMode() then
        html[#html+1] = format('<li class="nav-header">%s</li>', T"VLAN Interfaces")
        html[#html+1] = format('<li><a href="#" data-remote="modals/bridge-modal.lp">%s</a></li>', T"VLAN")
        end
        ngx.print(html)
          ngx.print('\
         </ul>\
     </div>\
     <div class="span6">\
        ');  
        end
        html = {}
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        local intf_descr = {
            lan = T"'lan' is the local network that is used for the Ethernet LAN and the wifi associated with (SSID of main wifi).",
            Guest1 = T"'Guest1' is the local network that is used for the wifi associated with (SSID of Guest wifi).",
            Guest1_5GHz = T"'Guest1_5GHz' is the local network that is used for the wifi associated with (SSID of Guest 5GHz wifi).",
        }
        local intf_descr_attr = {
            alert = {
                class = "alert-info",
            },
        }
        html[#html+1] = ui_helper.createAlertBlock(intf_descr[curintf], intf_descr_attr)
        ngx.print(html)
          ngx.print('\
          <fieldset>\
            ');  if not bridged.isBridgedMode() then   ngx.print('\
              <div class="span5">\
            ');  end   ngx.print('\
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
              if not bridged.isBridgedMode() then
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
                html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                ngx.print(html)
              -- Do not display the static lease when the interface is not lan
              if curintf == default_lan then
                ngx.print('\
                  <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
                  ');  
                    ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg))
                    ngx.print('\
              ');  end   ngx.print('\
            <legend>');  ngx.print( T"Network mode" ); ngx.print('</legend>\
            ');  
                local html = {}
                local rebooting = {
                  alert = {
                    class = "alert hide",
                    id = "rebooting-msg"
                  }
                }
                local confirming = {
                  alert = {
                    class = "alert hide",
                    id = "confirming-msg"
                  }
                }
                local bridged_button = {
                    button = {
                        id = "btn-bridged"
                    }
                }
                html[#html + 1] = ui_helper.createButton("Bridged Mode", "Bridged Mode", "icon-cog", bridged_button)
                html[#html + 1] = string.format('<div class="control-group controls">')
                html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Bridged Mode</strong> and restarting, please wait...", rebooting)
                html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure to switch the modem to <strong>Bridged Mode</strong>? <br /> Note: if you want the gateway to run in Routed Mode again, factory reset is needed.", confirming)
                html[#html + 1] = string.format([[
                  <div id="bridged-changes" class="hide">
                  <div id="bridged-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
                    <div id="bridged-cancel" class="btn">%s</div>
                  </div>
                </div>
                ]], T"Confirm", T"Cancel")
                html[#html + 1] = '</div>'
                ngx.print(html)
            else
                local html = {}
                local infomessage = {
                  alert = {
                    class = "alert",
                  }
                }
                html[#html + 1] = ui_helper.createAlertBlock(T[[Note: your gateway is in Bridged Mode. If you want the gateway to run in Routed Mode again, please do factory reset <a href="javascript:tch.loadModal('/modals/gateway-modal.lp')">here</a>]], infomessage)
                ngx.print(html)
            end
              ngx.print('\
          </fieldset>\
\
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
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script src="/js/srp-min.js" ></script>\
<script>\
(function() {\
  $(\'input[name="localdevIP"]\').keydown(function(){\
    var msg = $("#lanipchange-msg");\
    var msg_dst = $(this);\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
  });\
\
  var refreshTimeOut = 5000;\
  var refreshDelay = 3000;\
  var target = $(".modal form").attr("action");\
\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
 $("#btn-bridged").click(function() {\
    $("#confirming-msg").removeClass("hide");\
    $("#bridged-changes").removeClass("hide");\
  });\
\
\
  $("#bridged-confirm").click(function() {\
    $("#confirming-msg").addClass("hide");\
    $("#bridged-changes").addClass("hide");\
    $("#btn-bridged").addClass("hide");\
    return resetreboot($("#rebooting-msg"), $("#btn-bridged"), "BRIDGED");\
  });\
\
  $("#bridged-cancel").click(function() {\
    $("#confirming-msg").addClass("hide");\
    $("#bridged-changes").addClass("hide");\
    $("#rebooting-msg").addClass("hide");\
  });\
\
}());\
</script>\
\
'); 