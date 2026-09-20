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
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
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

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, nil, nil, sleases_valid)

-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@lan.start",
    dhcpLimit = "uci.dhcp.dhcp.@lan.limit",
    dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
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

local function validateDHCPState(value, object, key)
    local valid, helpmsg = gVCS(value, object, key)
    if (valid ~= true) then
        return valid,  helpmsg
    end

    if (object[key] == "0") then
        object[key] = "1"
    else
        object[key] = "0"
    end
    return true
end

local mapValid = {
    localdevIP = post_helper.validateStringIsIP,
    localdevmask = post_helper.validateStringIsIP,
    localIPv6 = gVCS,
    dhcpIgnore = validateDHCPState,
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

if content["dhcpIgnore"] == "" then
    content["dhcpIgnore"] = "0"
end

local dhcpState
if (content["dhcpIgnore"] == "0") then
    dhcpState = 1
else
    dhcpState = 0
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


local function resetreboot(path)
  proxy.set(path, "1")
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
            return resetreboot("rpc.system.reboot")
        end
    end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<% =ui_helper.createHeader(T"Local Network", true, false, nil, help_link) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/ethernet-modal.lp">
    <div class="row">
      <div class="span11">
          <%
              ngx.print(ui_helper.createMessages(message_helper.popMessages()))
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
              local lanipattr = {
                    input = {
                        id = "lanip-addr",
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
            %>
            </div>
            <div class="span5">
            <legend><%= T"DHCP Settings" %></legend>
            <%
                html = {}
                html[#html + 1] = ui_helper.createCheckboxSwitch(T"DHCP Server", "dhcpIgnore", dhcpState)
                html[#html + 1] = ui_helper.createInputText(T"Network address", "dhcpNetwork", num2ipv4(network), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"DHCP Start address", "dhcpStart2", num2ipv4(ipstart), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"DHCP End address", "dhcpLimit2", num2ipv4(ipend), advanceddisabled)
                html[#html + 1] = ui_helper.createInputText(T"New start", "dhcpStart", content["dhcpStart"], advanced, helpmsg["dhcpStart"])
                html[#html + 1] = ui_helper.createInputText(T"New limit", "dhcpLimit", content["dhcpLimit"], advanced, helpmsg["dhcpLimit"])
                html[#html + 1] = ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"])
                html[#html + 1] = ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
                ngx.print(html)
            %>
            </div>
          </fieldset>
          <fieldset>
            <legend><%= T"Static leases" %></legend>
            <%
                ngx.print(ui_helper.createTable(sleases_columns, sleases_data, sleases_options, sleases_attributes, sleases_helpmsg))
            %>
          </fieldset>
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
            %>
          </fieldset>
      </div>
    </div>
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
