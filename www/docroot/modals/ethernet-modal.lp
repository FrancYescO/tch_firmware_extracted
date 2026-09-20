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
local bridged = require("bridgedmode_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local pairs, table = pairs, table
local content, helpmsg
local format, match = string.format, string.match
local gsub, upper = string.gsub, string.upper
local match, sub = string.match, string.sub

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
}

local sleases_attributes = {
}

local function sleases_name_validation(value)
  if #value == 0 or #value > 63 then
    return nil, T"A hostname must be between 1 and 63 characters"
  end
  if string.match(value, "[^%w%-]") then
    return nil, T"A hostname must contain only alphanumeric characters and dash"
  end
  return true
end

--only support colon format in dhcp static lease, so delete hyphen format
local mac_pattern1 = "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local function validateStringIsMAC(value)
    local mac
    if not value then
        return nil, T"Invalid input"
    end
    if value:match(mac_pattern1) then
        mac = gsub(value,":","")
    else
        return nil, T"Invalid MAC address, it must be of the form 00:11:22:33:44:55"
    end

    mac = upper(mac)
    if mac == "000000000000" or mac == "FFFFFFFFFFFF" then
        return nil, T"Invalid MAC address"
    end

    --reference link: https://tools.ietf.org/html/rfc7042
    --validate Reserved MAC filtering functionality. It is validating that:
    --Multicast identifiers from 01:00:5E:00:00:00 to 01:00:5E:FF:FF:FF
    --Unicast identifiers from 00:00:5E:00:00:00 to 00:00:5E:FF:FF:FF
    --IPv6 multicast identifiers from 33:33:00:00:00:00 to 33:33:FF:FF:FF:FF
    --PPP identified from CF:00:00:00:00:00 to CF:FF:FF:FF:FF:FF
    if (match(mac, "^0[01]005E")) or (sub(mac, 1, 4) == "3333") or (sub(mac, 1, 2) == "CF") then
        return nil, T"Reserved MAC address"
    end
    return true
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = validateStringIsMAC(value)
  if r1 then
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
    createMsg = "Add new static lease",
}

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, nil, nil, sleases_valid)

-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@lan.start",
    dhcpLimit = "uci.dhcp.dhcp.@lan.limit",
    dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
    leaseTime = "uci.dhcp.dhcp.@lan.leasetime",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
    localIPv6 = "uci.network.interface.@lan.ipv6",
}

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@lan.dhcp_option."
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
        local valid, helpmsg = post_helper.validateStringIsIP(value, object, key)
        if not valid and dnsIndex == (#dhcp.options + 1) then
            proxy.delete(mapParams[key]:sub(1,-6))
            dnsRemoved = true
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return valid, helpmsg
    end
end

local gVCS = post_helper.getValidateCheckboxSwitch()

local function validatedhcpv4State(value, object, key)
  local valid, helpmsg = gVCS(value, object, key)
  if not valid then
      return nil, helpmsg
  end
  if object[key] == "1" then
      object[key] = "server"
  else
      object[key] = "disabled"
  end
  return true
end

local function validbitsIPv4Netmask(value)
    local netmask = ipv42num(value)
    if not netmask then
        return 0
    end
    local ones = 0
    local expecting = 0
    for i = 0, 31 do
        local bitmask = bit.lshift(1, i)
        local result = bit.band(netmask, bitmask)
        if result == 0 then
            if expecting ~= 0 then
                return 0
            end
        else
            if expecting == 0 then
                expecting = 1
            end
            ones = ones + 1
        end
    end
    if (ones < 8) or (ones > 30) then
        return 0
    end
    return ones
end

local function validateStringIsNotReservedIP(infaces)
    return function(value, object, key)
        local localinfacepath = "uci.network.interface."
        local maskpath = "uci.network.interface.@" .. infaces .. ".netmask"

        local valid, helpmsg = post_helper.validateStringIsIP(value, object, key)
        if (valid ~= true) then
            return valid, helpmsg
        end
        local netmask = proxy.get(maskpath)[1].value
        if netmask == "" then
           return true
        end
        local ip = ipv42num(value)
        local chunks = { value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
        if #chunks == 4 then
            local len = 32- validbitsIPv4Netmask(netmask)
            for i,v in ipairs(proxy.getPN(localinfacepath, true)) do
                local inface = string.match(v.path, "uci%.network%.interface%.@([^%.]+)%.")
                if inface ~= infaces then
                    local infaceIP = proxy.get(localinfacepath .. "@"..inface..".ipaddr")[1].value
                    if infaceIP ~= "" then
                        local infaceIPvalue = ipv42num(infaceIP)
                        if bit.rshift(infaceIPvalue, len) == bit.rshift(ip, len) then
                             return nil, T"Invalid IP address, conflict with other network ip! See help for more information."
                        end
                    end
                end
            end
        end
        return true
    end
end



local mapValid = {
    localdevIP = validateStringIsNotReservedIP("lan"),
    localdevmask = post_helper.validateIPv4Netmask,
    localIPv6 = gVCS,
    dhcpv4State = validatedhcpv4State,
    dnsServer = validateDNS,
    leaseTime = post_helper.validateStringIsLeaseTime,
    dhcpStart = post_helper.validatePositiveNum,
    dhcpLimit = post_helper.validatePositiveNum,
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
-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] == nil then
    local localIP = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
    content["dnsServer"] = localIP
else
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
    end
end

if content["dhcpv4State"] == "" then
    content["dhcpv4State"] = "server"
end

local dhcpv4State
if (content["dhcpv4State"] == "server") then
    dhcpv4State = "1"
else
    dhcpv4State = "0"
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
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", true, false, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/ethernet-modal.lp">\
    <div class="row">\
      <div class="span11">\
          ');  
              ngx.print(ui_helper.createMessages(message_helper.popMessages()))
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
              local lanipattr = {
                    input = {
                        id = "lanip-addr",
                    }
                }
              local lanipchange_alert = {
                alert = {
                    class = "alert hide",
                    id = "lanipchange-msg"
                }
              }
              -- Labels that shows the Local Device IP address & network subnet
	        -- Alert box to notify user what action need to take in next step
                html[#html + 1] = ui_helper.createAlertBlock(T"After Save, please renew your computer’s IP address to reconnect to the gateway", lanipchange_alert)
                html[#html + 1] = ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"], lanipattr, helpmsg["localdevIP"])
                html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
                html[#html + 1] = ui_helper.createCheckboxSwitch(T"Local Network IPv6 state", "localIPv6", content["localIPv6"])
                ngx.print(html)
            if not bridged.isBridgedMode() then
              ngx.print('\
            </div>\
            <div class="span5">\
            <legend>');  ngx.print( T"DHCP Settings" ); ngx.print('</legend>\
            ');  
                html = {}
                html[#html + 1] = ui_helper.createCheckboxSwitch(T"DHCP Server", "dhcpv4State", dhcpv4State)
                html[#html + 1] = ui_helper.createLabel(T"Network address", num2ipv4(network), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP Start address", num2ipv4(ipstart), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP End address", num2ipv4(ipend), advanced)
                html[#html + 1] = ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced, helpmsg["dhcpStart"])
                html[#html + 1] = ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced, helpmsg["dhcpLimit"])
                html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                ngx.print(html)
              ngx.print('\
            </div>\
          </fieldset>\
          <fieldset>\
            <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
            ');  
                ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg))
              ngx.print('\
          </fieldset>\
          <fieldset>\
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
                html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure to switch the modem to <strong>Bridged Mode</strong>?", confirming)
                html[#html + 1] = string.format([[
                  <div id="bridged-changes" class="hide">
                    <div id="bridged-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
                    <div id="bridged-cancel" class="btn">%s</div>
                  </div>
                </div>
                ]], T"Confirm", T"Cancel")
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
      </div>\
    </div>\
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
  function wait_for_webserver_running() {\
    $.ajax({ url: "/", timeout: refreshTimeOut })\
    .done(function(data) {\
      document.open("text/html");\
      document.write(data);\
      document.close();\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
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
'); 