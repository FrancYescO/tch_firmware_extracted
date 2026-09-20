<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs = table, ipairs

local ddns_supported_services = {}

local function generate_ddns_supported_services()
    -- open the supported services file that come with the ddns package
    local f = io.open("/usr/lib/ddns/services", "r")
    if f then
        for line in f:lines() do
            --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
            local service = line:match('^%b""')
            if service then
                service = service:gsub('"','')
                local serviceline = { service , service:upper():match('[%a%w]*%.'):gsub('%.','') }
                ddns_supported_services[#ddns_supported_services + 1] = serviceline
            end
        end
        f:close()
    end
end

generate_ddns_supported_services()

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    DMZ_enabled = "rpc.network.dmz.enabled",
    ddns_enabled = "uci.ddns.service.@myddns.enabled",
    ddns_service_name = "uci.ddns.service.@myddns.service_name",
    ddns_domain = "uci.ddns.service.@myddns.domain",
    ddns_username = "uci.ddns.service.@myddns.username",
    ddns_password = "uci.ddns.service.@myddns.password",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)

local qry_valid = {
    DMZ_enabled = vB,
    ddns_enabled = vB,
    ddns_service_name = gVIPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVIPIL(vNES, "ddns_enabled", {"1"}),
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,

}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

-- In UCI
--config 'redirect'
--        option 'enabled'  '1'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- rpc.network.firewall.portforward.{i}.enabled
-- rpc.network.firewall.portforward.{i}.name
-- rpc.network.firewall.portforward.{i}.src
-- rpc.network.firewall.portforward.{i}.src_dport
-- rpc.network.firewall.portforward.{i}.dest_ip
-- rpc.network.firewall.portforward.{i}.dest_port
-- rpc.network.firewall.portforward.{i}.target
-- rpc.network.firewall.portforward.{i}.dest
-- rpc.network.firewall.portforward.{i}.proto.@1.value

-- Templates for pre-defined rules
local knownapps = require("pfwd_helper")

local portrange_pattern = "^(%d+)%-(%d+)$"
function compare_startport(a,b)
  return a.start < b.start
end

local function validPorts(ports)
    local curend = -1

    for _,v in ipairs(ports) do
        if v.start <= curend then
            return nil, { wanport = T"An existing mapping overlaps with the ports range" }
        else
            curend = v["end"]
        end
    end
    return true
end

local function globalValid(data)
    local tcp = {}
    local udp = {}
    local p1,p2
    local err, msg

    for i,v in ipairs(data) do
        local chunks = { v[4]:match(portrange_pattern) }
        if #chunks == 2 then
            p1 = tonumber(chunks[1])
            p2 = tonumber(chunks[2])
        else
            p1 = tonumber(v[4])
            p2 = p1
        end

        local proto = v[3]
        if proto == "tcp" or proto == "tcpudp" then
            tcp[#tcp+1] = { start = p1, ["end"] = p2, index = i }
        end
        if proto == "udp" or proto == "tcpudp" then
            udp[#udp+1] = { start = p1, ["end"] = p2, index = i }
        end
    end

    table.sort(tcp, compare_startport)
    table.sort(udp, compare_startport)

    err, msg = validPorts(tcp)
    if not err then
        return err, msg
    end
    err, msg = validPorts(udp)
    return err, msg
end

local pfw_destination_values = (function ()
    local values = {}

    for name, ip in pairs(hosts_ac) do
        values[#values + 1] = { ip, name }
    end
    return values
end)()

-- Firewall forwarding rules
local pfw_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    unique = true,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto.@1.value",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP/UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "select",
    values = pfw_destination_values,
    attr = { select = { class="span2" } },
  },
}

local pfw_attributes = {
}

local pfw_valid = {
    enabled = vB,
    name = vNES,
    lanport = vSIPR,
    wanport = vSIPR,
    destinationip = vSIDIP,
}

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
    src = "wan",
    dest = "lan",
    family = "ipv4",
    target = "DNAT",
}

local pfw_filter = nil

local pfw_options = {
    tableid = "portforwarding",
    basepath = "rpc.network.firewall.portforward.",
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)


-- UPnP forwarding rules
local upnp_columns = {
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP+UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Description",
    name = "description",
    param = "description",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
}

local upnp_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "upnpportforwarding",
    basepath = "sys.upnp.redirect.",
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content then
        local action = content["action"]
        local DMZ_flag = content["DMZ_flag"]
        if action == "SAVE" and DMZ_flag == "1"  then
            ngx.header.content_type = "application/json"
            ngx.print('{ "success":"true" }')
            ngx.timer.at(0, function()
                proxy.apply()
            end)
            ngx.exit(ngx.HTTP_OK)
        end
    end
end

%>

<% ngx.print(ui_helper.createHeader(T"DMZ", true, false)) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/dmz-modal.lp">
    <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset>
      <legend><%= T"DMZ on ETH port 4" %></legend>

	<text style="margin-left: 110px;">
          <%= T"A DMZ bridge is an external interface to the internet, providing a public IP address to a File Server or other customer equipment" %><br>
	</text>
	<text style="margin-left: 110px;">
	  <%= T"Since this equipment is exposed to the internet, there are security risks taken when this function is enabled." %><br><br>
	</text>

      <%
        local dmz = {
          switch = {
            id = "switch-dmz"
          },
          switcher = {
            id = "switcher-dmz"
          },
          input = {
            id = "input-dmz"
          }
        }
        local rebooting = {
          alert = {
            class = "alert hide",
            id = "rebooting-msg"
          }
        }
        local flagattr = {
          input = {
            class = "hide",
            id = "dmz-flag"
          }
        }
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enabled", qry_data["DMZ_enabled"], dmz, qry_helpmsg["DMZ_enabled"]),
        ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting),
        ui_helper.createSimpleInputText("DMZ_flag", "0", flagattr),
        '<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>')
      %>
	  
	  	<text style="margin-left: 110px;">
	  <%= T"When the DMZ bridge is initiated the MediaAccess Gateway will re-start" %><br>
	</text>

	
    </fieldset>
  </form>
</div>
<%=string.format([[
<div class="modal-footer">
  <div id="modal-no-change">
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
  </div>
  <div id="modal-changes" class="hide">
    <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
    <div id="save-wanservices-config" class="btn btn-primary btn-large">%s</div>
  </div>
</div>
]], T"Close", T"Cancel", T"Save")%>

<script src="/js/srp-min.js" ></script>
<script>
(function() {
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

  $("#input-dmz").change(function() {
    $("#dmz-flag").val("1");
  });

  function waiting_action(self) {
    var msg_dst = $(self);
    var busy_msg = $(".loading-wrapper");

    msg_dst.after(busy_msg);
    busy_msg.removeClass("hide");
    busy_msg[0].scrollIntoView();
    $(".modal-body").scrollLeft(0);
  };

  // Handle save config call
  $(document).on("click", "#save-wanservices-config", function () {
      $("#rebooting-msg").removeClass("hide");
      waiting_action(this);
      var form = $(".modal form");
      var params = form.serializeArray();
      params.push({
          name : "action",
          value : "SAVE"
      }, {
          name : "fromModal",
          value : "YES"
      }, tch.elementCSRFtoken());
      var target = form.attr("action");
      if ($("#dmz-flag").val() === "1") {
        $.post(
          target,
          params,
          wait_for_webserver_down,
          "json"
        );
        return false;
      } else {
        tch.loadModal(target, params, function () {
          var error = $('.error');
          if (error.length > 0) {
              // We're in an error case
              // Show the save/close buttons since nothing has been saved
              $('#modal-no-change').hide();
              $('#modal-changes').show();
          }

          // If some advanced elements are in error and we're not showing adv elements, then
          // display them
          var advanced = $(".modal-action-advanced:first").is(":visible");
          var errorInAdvanced = error.closest('.advanced');
          if (errorInAdvanced.length > 0 && !advanced) {
              switchAdvanced();
          }
          $('.error input:not([type="hidden"])').first().focus();
      });
    }
  });
}());
</script>
