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
local bridged = require("bridgedmode_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local pairs, table = pairs, table
local content, helpmsg
local match, format  = string.match, string.format
local default_lan = 'lan'

local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = k:match("%[(.*)%]")
    hosts_mac[k] = mac
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
local getintf = getargs.intf or default_lan

local curintf = default_lan
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface_lan."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local lan_intfs, other_lan_ips = {}, {}
for _,v in ipairs(all_intfs) do
    -- remove VLANx as these will be handled in multi-bridge page
    if not match(v.paramindex, "^VLAN%d$") then
        lan_intfs[#lan_intfs + 1] = v.paramindex
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
    else
        other_lan_ips[v.ipaddr] = true
    end
end

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
    localIP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign",
}

local guestIpParam
if curintf ~= default_lan then
    guestIpParam = curintf .. "_ip"
    mapParams[guestIpParam] = "rpc.network.firewall." .. guestIpParam
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
            local valid, helpmsg = post_helper.validateStringIsIP(value, object, key)
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

local function validatedevIP(value, object, key)
    local valid, msg = post_helper.validateStringIsIP(value, object, key)
    if valid then
        if match(value, "192%.168%.253%.%d") then
            return nil, "IP ranges 192.168.253.1~192.168.253.254 is reserved for IPTV services"
        elseif match(value, "192%.168%.252%.%d") then
            return nil, "IP ranges 192.168.252.1~192.168.252.254 is reserved for other services (WOL)"
        elseif other_lan_ips[value] then
            return nil, 'IP address ' .. value .. ' has already been used by another LAN IP interface'
        end
        if guestIpParam then
            object[guestIpParam] = value
        end
    end
    return valid, msg
end

local mapValid = {
    localdevIP = validatedevIP,
    localdevmask = post_helper.validateIPv4Netmask,
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
%>

<% ngx.print(ui_helper.createHeader(T"Local Network", true, false)) %>

   <div class="modal-body update">
     <form class="form-horizontal" method="post" action="<%= uri %>">
     <%
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
     %>
     <div class="span2">
        <ul class="nav nav-list">
        <%
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
        %>
         </ul>
     </div>
     <div class="span6">
        <%
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
        %>
          <fieldset>
              <% if not bridged.isBridgedMode() then %>
              <div class="span5">
              <% end %>
              <legend><%= T"Global Information" %></legend>
              <%
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
              %>
              </div>
              <div class="span5">
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
                html[#html + 1] = ui_helper.createLabel(T"Network address", num2ipv4(network), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP Start address", num2ipv4(ipstart), advanced)
                html[#html + 1] = ui_helper.createLabel(T"DHCP End address", num2ipv4(ipend), advanced)
                html[#html + 1] = ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced, helpmsg["dhcpStart"])
                html[#html + 1] = ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced, helpmsg["dhcpLimit"])
                html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                ngx.print(html)
              %>
              </div>
              <%
              -- Do not display the static lease when the interface is not lan
              if curintf == default_lan then
              %>
                  <legend><%= T"Static leases" %></legend>
                  <%
                    ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg))
                  %>
              </fieldset>
              <%
               end
               %>

              <fieldset>
            <legend><%= T"Network mode" %></legend>
            <%
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
            %>
          </fieldset>

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

<% ngx.print(ui_helper.createFooter()) %>

<script src="/js/srp-min.js" ></script>
<script>
(function() {
  $('input[name="localdevIP"]').keydown(function(){
    var msg = $("#lanipchange-msg");
    var msg_dst = $(this);
    msg_dst.after(msg);
    msg.removeClass("hide");
  });

  var refreshTimeOut = 5000;
  var refreshDelay = 3000;
  var target = $(".modal form").attr("action");

  function wait_for_webserver_running() {
    $.ajax({ url: "/", timeout: refreshTimeOut })
    .done(function(data) {
      document.open("text/html");
      document.write(data);
      document.close();
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function wait_for_webserver_down() {
    $.ajax({ url: target, timeout: refreshTimeOut })
    .done(function() {
      window.setTimeout(wait_for_webserver_down, refreshDelay);
    })
    .fail(function() {
      window.setTimeout(wait_for_webserver_running, refreshDelay);
    });
  }

  function resetreboot(msg, msg_dst, action) {
    msg_dst.after(msg);
    msg.removeClass("hide");
    msg[0].scrollIntoView();
    $.post(
      target,
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      wait_for_webserver_down,
      "json"
    );
    return false;
  }

 $("#btn-bridged").click(function() {
    $("#confirming-msg").removeClass("hide");
    $("#bridged-changes").removeClass("hide");
  });


  $("#bridged-confirm").click(function() {
    $("#confirming-msg").addClass("hide");
    $("#bridged-changes").addClass("hide");
    $("#btn-bridged").addClass("hide");
    return resetreboot($("#rebooting-msg"), $("#btn-bridged"), "BRIDGED");
  });

  $("#bridged-cancel").click(function() {
    $("#confirming-msg").addClass("hide");
    $("#bridged-changes").addClass("hide");
    $("#rebooting-msg").addClass("hide");
  });

}());
</script>

