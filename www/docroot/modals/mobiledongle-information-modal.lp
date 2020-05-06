<%
-- Enable localization
gettext.textdomain('webui-mobiledongle')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local format, match = string.format, string.match
local setmetatable = setmetatable
local untaint_mt = require("web.taint").untaint_mt
local current_operator_map = setmetatable(require("operatorcode_helper"), untaint_mt)

local link_status_map = setmetatable({
  ["CONNECTED"]     = T"Connected",
  ["CONNECTING"]    = T"Connecting to network...",
  ["DISCONNECTING"] = T"Disconnecting from network...",
  ["SEARCHING"]     = T"Search for networks...",
  ["ERROR"]         = T"Error",
  ["NA"]            = T"Disconnected",
}, untaint_mt)

local device_status_map = setmetatable({
  ["CONNECTED"]          = T"Device configured",
  ["CONNECTING"]         = T"Configuring device...",
  ["DISCONNECTED"]       = T"Device configuration failed",
  ["WAITING_FOR_DEVICE"] = T"Searching device...",
  ["NA"]                 = T"",
}, untaint_mt)

local sim_status_map = setmetatable({
  ["READY"]    = T"Ready",
  ["SIM_PIN"]  = T"PIN code required",
  ["SIM_PUK"]  = T"PUK code required",
  ["DISABLED"] = T"PIN code not required",
  ["LOCKED"]   = T"SIM card locked",
  ["UNKNOWN"]  = T"Error",
  ["NA"]       = T"",
}, untaint_mt)

local registration_status_map = setmetatable({
  ["REGISTERED_HOME"]    = T"Registered (home network)",
  ["REGISTERED_ROAMING"] = T"Registered (roaming)",
  ["REGISTER"]           = T"Register...",
  ["TECH_ERROR"]         = T"Technology not supported",
  ["NO_NETWORK_FOUND"]   = T"No network found",
  ["INIT"]               = T"Initializing...",
  ["UNKNOWN"]            = T"Error",
  ["NA"]                 = T"",
}, untaint_mt)

local ppp_status_map = setmetatable({
  ["CONNECTED"]     = T"Connected",
  ["CONNECTING"]    = T"Connecting...",
  ["NETWORKING"]    = T"Networking...",
  ["DISCONNECTING"] = T"Disonnecting...",
  ["DISCONNECTED"]  = T"Disconnected",
  ["ERROR"]         = T"Error",
  ["NA"]            = T"",
}, untaint_mt)

-- Get the content
local UCI_content = {
  link_status         = "uci.mobiledongle.info.link_status",
  link_status_displ   = "uci.mobiledongle.info.link_status",
  device_name         = "uci.mobiledongle.info.device_name",
  device_status       = "uci.mobiledongle.info.device_status",
  registration_status = "uci.mobiledongle.info.registration_status",
  ppp_status          = "uci.mobiledongle.info.ppp_status",
  RSSI                = "uci.mobiledongle.info.RSSI",
  current_operator    = "uci.mobiledongle.info.current_operator",
  current_technology  = "uci.mobiledongle.info.current_technology",
  interface_enabled   = "uci.mobiledongle.config.enabled",
  sim_status          = "uci.mobiledongle.sim.status",
  emi_detected        = "uci.usb.ehci_emi_detectNumberOfEntries"
}

local RPC_content = {
  wwan_ipaddr         = "rpc.network.interface.@wwan.ipaddr",
  dnsservers          = "rpc.network.interface.@wwan.dnsservers",
  uptime              = "rpc.network.interface.@wwan.uptime",
  rx_bytes            = "rpc.network.interface.@wwan.rx_bytes",
  tx_bytes            = "rpc.network.interface.@wwan.tx_bytes",
}

--
-- start of helper functions
--
local function device_name(devicename)
  if devicename == "NA" then
    return T"DEVICE NAME NOT FOUND"
  end
  return devicename
end

--[[
    Convert number of bytes into human readable format
    @param integer bytes     Number of bytes to convert
    @param integer precision Number of digits after the decimal separator
        @return string
]]
local function bytesToSize(bytes)
        local kilobyte = 1024
        local megabyte = kilobyte * 1024
        local gigabyte = megabyte * 1024
        local terabyte = gigabyte * 1024
        local nbytes = tonumber(bytes)

        if bytes == "" or nbytes == nil then
                return "NA"
        end

        if ((nbytes >= 0) and (nbytes < kilobyte)) then
                return nbytes .. ' B'
        elseif ((nbytes >= kilobyte) and (nbytes < megabyte)) then
                return format("%.2f KB", (nbytes / kilobyte))
        elseif ((nbytes >= megabyte) and (nbytes < gigabyte)) then
                return format("%.2f MB", (nbytes / megabyte))
        elseif ((nbytes >= gigabyte) and (nbytes < terabyte)) then
                return format("%.2f GB", (nbytes / gigabyte))
        elseif (nbytes >= terabyte) then
                return format("%.2f TB", (nbytes / terabyte))
        else
                return nbytes .. ' B'
        end
end

-- Construct an uptime string from the number of seconds
local function secondsToTime(uptime)
        local nuptime = tonumber(uptime)
        if uptime == "" or nuptime == nil then
                return "NA"
        end
        local days =  math.floor(nuptime / 86400)
        local hours =  math.floor(nuptime / 3600) % 24
        local minutes = math.floor(nuptime / 60) % 60
        local seconds = nuptime % 60
        if (days > 0) then
                return format(T"%d days %d hours %d min %d sec", days, hours, minutes, seconds)
        elseif (hours > 0) then
                return format(T"%d hours %d min %d sec", hours, minutes, seconds)
        elseif (minutes > 0) then
                return format(T"%d min %d sec", minutes, seconds)
        else
                return format(T"%d sec", seconds)
        end
end

--- convert DNSserver "<IPAddress1,IPAddress2>"" format to "Preferred DNS server IPAddress1<br> Alternative DNS server IPAddress2"
local function printableDNSServers(dnsservers)
  local ip1, ip2 = match(dnsservers, "([^,]+),([^,]+)")
  if not ip1 then
    return dnsservers
  end
  return format(T"Preferred DNS server %1$s<br>Alternative DNS server %2$s", ip1, ip2)
end

local function convertReceivedData(content)
  if UCI_content["link_status_displ"] then
    UCI_content["link_status_displ"] = link_status_map[UCI_content["link_status_displ"]]
  end
  if UCI_content["device_name"] then
    UCI_content["device_name"] = device_name(UCI_content["device_name"])
  end
  if UCI_content["device_status"] then
    UCI_content["device_status"] = device_status_map[UCI_content["device_status"]]
  end
  if UCI_content["registration_status"] then
    UCI_content["registration_status"] = registration_status_map[UCI_content["registration_status"]]
  end
  if UCI_content["ppp_status"] then
    UCI_content["ppp_status"] = ppp_status_map[UCI_content["ppp_status"]]
  end
  if UCI_content["current_operator"] then
    local operator = current_operator_map[UCI_content["current_operator"]]
    if operator then
      UCI_content["current_operator"] = operator
    else
      UCI_content["current_operator"] = current_operator_map["NA"]
    end
  end
  if UCI_content["sim_status"] then
    UCI_content["sim_status"] = sim_status_map[UCI_content["sim_status"]]
  end
  if RPC_content["dnsservers"] then
    RPC_content["dnsservers"] = printableDNSServers( RPC_content["dnsservers"])
  end
  if RPC_content["rx_bytes"] then
    RPC_content["rx_bytes"] = bytesToSize(RPC_content["rx_bytes"])
  end
  if RPC_content["tx_bytes"] then
    RPC_content["tx_bytes"] = bytesToSize(RPC_content["tx_bytes"])
  end
  if RPC_content["uptime"] then
    RPC_content["uptime"] = secondsToTime(RPC_content["uptime"])
  end
  if UCI_content["emi_detected"] then
    UCI_content["emi_detected"] = (UCI_content["emi_detected"] == "" or UCI_content["emi_detected"] == "0") and "0" or "1"
  end
end

--- based on the ui_helper.createFooter Template we add the Connect/Disconnect button when the state is Disabled.
local function createFooterConnect()
	--if  UCI_content["device_status"] == "CONNECTED" then
		return format([[
		<div class="modal-footer">
				<div class="monitor-link_status monitor-ERROR monitor-NA">
					<div id="modal-no-change">
						<div id=CONNECT class="btn btn-large custom-handler" data-value="connect" data-name="action">%s</div>
						<div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
					</div>
					<div id="modal-changes" class="hide">
						<div id=CONNECT class="btn btn-large custom-handler" data-value="connect" data-name="action">%s</div>
						<div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
						<div id="save-config" class="btn btn-primary btn-large">%s</div>
					</div>
				</div>
				<div class="monitor-link_status monitor-CONNECTED monitor-CONNECTING monitor-SEARCHING">
					<div id="modal-no-change">
						<div id=DISCONNECT class="btn btn-large custom-handler monitor-link_status monitor-CONNECTED" data-value="disconnect" data-name="action">%s</div>
						<div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
					</div>
					<div id="modal-changes" class="hide">
						<div id=DISCONNECT class="btn btn-large custom-handler monitor-link_status monitor-CONNECTED" data-value="disconnect" data-name="action">%s</div>
						<div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
						<div id="save-config" class="btn btn-primary btn-large">%s</div>
					</div>
				</div>
			</div>
		]], T"Connect", T"Close", T"Connect" , T"Cancel", T"Save", T"Disconnect", T"Close", T"Disconnect", T"Cancel", T"Save")
end

--
-- end of helper functions
--

--
-- start data collecting part
--
-- only refresh the page when we have a POST Message with action SAVE and no input validation errors occurs.
if ngx.req.get_method() == "POST" then
	local args = ngx.req.get_post_args()
	local action = args["action"]

	if action == "CONNECT"  then
		proxy.set("uci.mobiledongle.config.enabled","1")
		proxy.apply()
	elseif action == "DISCONNECT"  then
		proxy.set("uci.mobiledongle.config.enabled","0")
		proxy.apply()
	end
end

ajax_helper.handleAjaxQuery({
  wwan_ipaddr         = "rpc.network.interface.@wwan.ipaddr",
  dnsservers          = "rpc.network.interface.@wwan.dnsservers",
  uptime              = "rpc.network.interface.@wwan.uptime",
  rx_bytes            = "rpc.network.interface.@wwan.rx_bytes",
  tx_bytes            = "rpc.network.interface.@wwan.tx_bytes",
  }, convertReceivedData)

content_helper.getExactContent(UCI_content)
content_helper.getExactContent(RPC_content)
convertReceivedData(content)

--
-- end data collecting part
--

--
-- start page representation
--
%>

<%= ui_helper.createHeader(T"Mobile 3G/4G", false, true)%>
<div class="modal-body update">
		<%
		local usb_error_attribs = {
		  alert = {
		    class = "alert-danger monitor-emi_detected monitor-1"
		  }
		}
		if UCI_content["emi_detected"] == "0" then
		  usb_error_attribs.alert.class = usb_error_attribs.alert.class .. " hide"
		end
		ngx.print(ui_helper.createAlertBlock(T"USB Error detected, please restart manually your device", usb_error_attribs))

		if ((ngx.req.get_method() == "POST") and (ngx.req.get_post_args().action == "CONNECT")) then %>
		<div class="alert alert-warning" id="warning_msg"><%=T"Please do not remove the wan interface cable when connecting to the mobile network"%></div>
		<% else %>
		<div class="alert alert-warning hide" id="warning_msg"><%=T"Please do not remove the wan interface cable when connecting to the mobile network"%></div>
		<% end
		ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        local html = {}
        local tabs = {
            {
		    desc = T"Information",
		    active = "active",
                target = "modals/mobiledongle-information-modal.lp",
                },
            {
                desc = T"Configuration",
                    target = "modals/mobiledongle-configuration-modal.lp",
            },
            }
        table.insert (html, ui_helper.createModalTabs(tabs))
        ngx.print (html)
	%>

	<form class="form-horizontal" method="post" action="modals/mobiledongle-information-modal.lp">
    <fieldset id="mobiledongle-information-tab">

	<%
		local html = {}
		tinsert(html, "<legend>" .. T"Line Information" .. "</legend>")
                local emi_detected_attributes = {
                        input = {
                                class = "monitor-changes",
                                id = "emi_detected",
                                ["data-ajaxrefresh"] = "5",
                        },
                }
                html[#html+1] = ui_helper.createSimpleInputHidden("emi_detected", UCI_content["emi_detected"] or "", emi_detected_attributes)
		local link_status_attributes = {
			input = {
				class = "monitor-changes",
				id = "link_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createSimpleInputHidden("link_status", UCI_content["link_status"] or "", link_status_attributes))
		local link_status_label_attributes = {
			span = {
				class = "span4 monitor-changes",
				id = "link_status_displ",
				["data-ajaxrefresh"] = "5",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Link Status: ", UCI_content["link_status_displ"] or "", link_status_label_attributes))

		local connectedattributes_wwan_ipaddr = {
		span = {
		    class = "span4 monitor-changes",
				id = "wwan_ipaddr",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"IPv4: ", RPC_content["wwan_ipaddr"] or "", connectedattributes_wwan_ipaddr))
		local connectedattributes_dnsservers = {
		span = {
		    class = "span4 monitor-changes",
				id = "dnsservers",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"DNS Servers: ", RPC_content["dnsservers"] or "", connectedattributes_dnsservers))

		local connectedattributes_uptime = {
		span = {
		    class = "span4 monitor-changes",
				id = "uptime",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Up Time: ", RPC_content["uptime"] or "", connectedattributes_uptime))

		local connectedattributes_rxbytes = {
		span = {
		    class = "span4 monitor-changes",
				id = "rx_bytes",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Tx Bytes: ", RPC_content["tx_bytes"] or "", connectedattributes_rxbytes))
		local connectedattributes_txbytes = {
		span = {
		    class = "span4 monitor-changes",
				id = "tx_bytes",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Rx Bytes: ", RPC_content["rx_bytes"] or "", connectedattributes_txbytes))
		tinsert(html, "<legend>" .. T"Mobile Information" .. "</legend>")
		local connectedattributes_device_name = {
		span = {
		    class = "span4 monitor-changes",
				id = "device_name",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createLabel(T"Device Name: ", UCI_content["device_name"] , connectedattributes_device_name))
		local connectedattributes_device_status = {
		span = {
		    class = "span4 monitor-changes",
				id = "device_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createLabel(T"Device Status: ", UCI_content["device_status"] or "", connectedattributes_device_status))
		local connectedattributes_simstatus = {
		span = {
		    class = "span4 monitor-changes",
				id = "sim_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createLabel(T"SIM Status: ", UCI_content["sim_status"] or "", connectedattributes_simstatus))
		local connectedattributes_registration_status = {
		span = {
		    class = "span4 monitor-changes",
				id = "registration_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createLabel(T"Registration Status: ", UCI_content["registration_status"] or "", connectedattributes_registration_status))
		local connectedattributes_ppp_status = {
		span = {
		    class = "span4 monitor-changes",
				id = "ppp_status",
				["data-ajaxrefresh"] = "5",
			},
		}
		tinsert(html, ui_helper.createLabel(T"Network Status: ", UCI_content["ppp_status"] or "", connectedattributes_ppp_status))

		local connectedattributes_ctech = {
		span = {
		    class = "span4 monitor-changes",
				id = "current_technology",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Current Technology: ",  RPC_content["current_technology"] or "", connectedattributes_ctech))
		local connectedattributes_coper = {
		span = {
		    class = "span4 monitor-changes",
				id = "current_operator",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Current Operator: ", UCI_content["current_operator"] or "", connectedattributes_coper))

		local connectedattributes_rssi = {
		span = {
		    class = "span4 monitor-changes",
				id = "RSSI",
				["data-ajaxrefresh"] = "5",
			},
		group = {
		    class = "monitor-link_status monitor-CONNECTED",
		},
		}
		tinsert(html, ui_helper.createLabel(T"Radio Signal Quality", UCI_content["RSSI"] or "", connectedattributes_rssi))
		tinsert(html, "</fieldset>")
		ngx.print(html)
	%>
	</form>
    <div id="spinner" class="loading-wrapper hide" align="center" style="background:none;">
      <img id="img-spinner" src="../img/spinner.gif" alt="changing connection state"/>
    </div>
</div>
<% ngx.print(createFooterConnect()) %>

<script>
(function() {
  var modalbody = $(".modal-body");
  var busy_msg = $("#spinner");
  var target = $(".modal form").attr("action");
  var scrolltop = $(".modal-body").scrollTop();
  var initialDelay = 5000;
  var delay = initialDelay;

  function wait_for_disconnect_reply() {
    if ( delay === initialDelay) {
      delay = 0;
      window.setTimeout(function() {
      tch.loadModal(target, function () {
        $(".modal-body").scrollTop(scrolltop);
        });
      }, initialDelay);
    }
  };

  $("#CONNECT").click(function() {
    $(".alert-success").addClass("hide");
    $("#warning_msg").removeClass("hide");
    busy_msg.removeClass("hide");
    $(".modal-action-refresh").addClass("hide");
    busy_msg[0].scrollIntoView();
    $(this).addClass("hide");
    $.post(
      target,
      {
        action:"CONNECT",
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
      },
      function(data){
        window.setTimeout(function() {
          $("#mobiledongle-information-modal").html(data);
          busy_msg.addClass("hide");
          tch.modalLoaded();
        }, 5000);
      }
    );
    return false;
  });

  $("#DISCONNECT").click(function() {
    busy_msg.removeClass("hide");
    $("#warning_msg").addClass("hide");
    $(".modal-action-refresh").addClass("hide");
    $(this).addClass("hide");
    busy_msg[0].scrollIntoView();
    $.post(
      target,
      {
        action:"DISCONNECT",
        CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
      },
      wait_for_disconnect_reply
    );
    return false;
  });
}());
</script>
