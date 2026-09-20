<%
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-mobiledongle')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local format, find, sub = string.format, string.find, string.sub
local tprint = require("tch.tableprint")
local posix =  require("tch.posix")

local mobiledongle_state_map = {
    ["DEVICE_DISCONNECTED"]     = T"Disconnected",
    ["DEVICE_OFFLINE"]          = T"Disconnected",
    ["NO_NETWORK_CONNECTED"]    = T"Disconnected",
    ["NETWORK_CONNECTED"]       = T"Registered",
    ["DATA_SESSION_ACTIVE"]     = T"Active",
    ["PIN_REQUIRED"]            = T"Enter PIN",
    ["PUK_REQUIRED"]            = T"Enter PUK",
    ["APN_REQUIRED"]            = T"Enter APN",
    ["PPP_AUTH_REQUIRED"]       = T"Enter PPP username/password",
    ["NO_SIM"]                  = T"Insert SIM",
    ["SIM_ERROR"]               = T"SIM error",
    ["DISABLED"]                = T"Disabled",
    ["RELOADING"]               = T"Reloading",
    ["UNKNOWN"]                 = T"Disconnected",
    ["NA"]                      = T"Disconnected",
}

local link_status_map           = {
    ["CONNECTED"]               = T"Connected",
    ["CONNECTING"]              = T"Connecting to network...",
    ["DISCONNECTING"]           = T"Disconnecting from network...",
    ["SEARCHING"]               = T"Search for networks...",
    ["ERROR"]                   = T"Error",
    ["NA"]                      = T"Disconnected",
}

local device_status_map         = {
    ["CONNECTED"]               = T"Device configured",
    ["CONNECTING"]              = T"Configuring device...",
    ["DISCONNECTED"]            = T"Device configuration failed",
    ["WAITING_FOR_DEVICE"]      = T"Searching device...",
    ["NA"]                      = T"",
}

local sim_status_map            = {
    ["READY"]                   = T"Ready",
    ["SIM_PIN"]                 = T"PIN code required",
    ["SIM_PUK"]                 = T"PUK code required",
    ["DISABLED"]                = T"PIN code not required",
    ["LOCKED"]                  = T"SIM card locked",
    ["UNKNOWN"]                 = T"Error",
    ["NA"]                      = T"",
}

local registration_status_map   = {
    ["REGISTERED_HOME"]         = T"Registered (home network)",
    ["REGISTERED_ROAMING"]      = T"Registered (roaming)",
    ["REGISTER"]                = T"Register...",
    ["TECH_ERROR"]              = T"Technology not supported",
    ["NO_NETWORK_FOUND"]        = T"No network found",
    ["INIT"]                    = T"Initializing...",
    ["UNKNOWN"]                 = T"Error",
    ["NA"]                      = T"",
}

local ppp_status_map            = {
    ["CONNECTED"]               = T"Connected",
    ["CONNECTING"]              = T"Connecting...",
    ["NETWORKING"]              = T"Networking...",
    ["DISCONNECTING"]           = T"Disonnecting...",
    ["DISCONNECTED"]            = T"Disconnected",
    ["ERROR"]                   = T"Error",
    ["NA"]                      = T"",
}

local current_operator_map = {
    ["50501"]                   = T"Telstra (50501)",
    ["50506"]                   = T"Telstra (50506)",
    ["46001"]                   = T"China Union (46001)",
    ["20610"]                   = T"Mobistar (20610)",
    ["20601"]                   = T"Proximus (20601)",
    ["20620"]                   = T"Base (20620)",
    ["42402"]                   = T"Etisalat (42402)",
    ["NA"]                      = T"",
}


-- Get the content
local content = {
    link_status                 = "uci.mobiledongle.info.link_status",
    link_status_displ           = "uci.mobiledongle.info.link_status",
    device_name                 = "uci.mobiledongle.info.device_name",
    device_status               = "uci.mobiledongle.info.device_status",
    registration_status         = "uci.mobiledongle.info.registration_status",
    ppp_status                  = "uci.mobiledongle.info.ppp_status",
    state                       = "uci.mobiledongle.info.state",
    RSSI                        = "uci.mobiledongle.info.RSSI",
    current_operator            = "uci.mobiledongle.info.current_operator",
    current_technology          = "uci.mobiledongle.info.current_technology",
    network                     = "uci.mobiledongle.config.network",
    interface_enabled           = "uci.mobiledongle.config.enabled",
    sim_status                  = "uci.mobiledongle.sim.status",
    wwan_ipaddr                 = "rpc.network.interface.@wwan.ipaddr",
    dnsservers                  = "rpc.network.interface.@wwan.dnsservers",
    uptime                      = "rpc.network.interface.@wwan.uptime",
    rx_bytes                    = "rpc.network.interface.@wwan.rx_bytes",
    tx_bytes                    = "rpc.network.interface.@wwan.tx_bytes",
}

--
-- start of helper functions
--
function device_name(devicename)
    if devicename == "NA" then
        return T"DEVICE NAME NOT FOUND"
    else
        return devicename
    end
end

--[[
    Convert number of bytes into human readable format
    @param integer bytes     Number of bytes to convert
    @param integer precision Number of digits after the decimal separator
    @return string
]]
function bytesToSize(bytes)
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
function printableDNSServers(dnsservers)
    local cv = format("%s", dnsservers)
    local pref_string = T"Preferred DNS server"
    local alt_string = T"Alternative DNS server"
    local sepLoc = string.find(cv, ",")
    if sepLoc == nil then
        return cv
    elseif sepLoc < 1 then
        return cv
    end
    local ip1 = string.sub(cv, 1, sepLoc -1 )
    local ip2 = string.sub(cv, sepLoc + 1 )
    if ip1 and ip2 then
        return pref_string .. " " .. ip1 .. "<br>" .. alt_string .. " " .. ip2
    end
end

function convertReceivedData()
    if content["link_status"] then
        content["link_status"] = format("%s",content["link_status"])
    end
    if content["link_status_displ"] then
        content["link_status_displ"] = format("%s",content["link_status_displ"])
        content["link_status_displ"] = link_status_map[content["link_status_displ"]]
    end
    if content["network"] then
        content["network"] = format("%s",content["network"])
    end
    if content["device_name"] then
        content["device_name"] = format("%s",content["device_name"])
        content["device_name"] = device_name(content["device_name"])
    end
    if content["device_status"] then
        content["device_status"] = format("%s",content["device_status"])
        content["device_status"] = device_status_map[content["device_status"]]
    end
    if content["registration_status"] then
        content["registration_status"] = format("%s",content["registration_status"])
        content["registration_status"] = registration_status_map[content["registration_status"]]
    end
    if content["ppp_status"] then
        content["ppp_status"] = format("%s",content["ppp_status"])
        content["ppp_status"] = ppp_status_map[content["ppp_status"]]
    end
    if content["state"] then
        content["state"] = format("%s",content["state"])
    end
    if content["current_operator"] then
        content["current_operator"] = format("%s",content["current_operator"])
        if current_operator_map[content["current_operator"]] ~= nil then
            content["current_operator"] = current_operator_map[content["current_operator"]]
        else
            content["current_operator"] = current_operator_map["NA"]
        end
    end
    if content["current_technology"] then
        content["current_technology"] = format("%s",content["current_technology"])
    end
    if content["sim_status"] then
        content["sim_status"] = format("%s",content["sim_status"])
        content["sim_status"] = sim_status_map[content["sim_status"]]
    end
    if content["dnsservers"] then
        content["dnsservers"] = printableDNSServers( content["dnsservers"])
    end
    if content["rx_bytes"] then
        content["rx_bytes"] = bytesToSize(content["rx_bytes"])
    end
    if content["tx_bytes"] then
        content["tx_bytes"] = bytesToSize(content["tx_bytes"])
    end
    if content["uptime"] then
        content["uptime"] = secondsToTime(content["uptime"])
    end
end

--- based on the ui_helper.createFooter Template we add the Connect/Disconnect button when the state is Disabled.
function createFooterConnect(disconnected)
    if disconnected then
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
    else
        return ui_helper.createFooter()
    end
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
        ngx.print('{ "success":"true" }')
        ngx.exit(ngx.HTTP_OK)
    elseif action == "DISCONNECT"  then
        proxy.set("uci.mobiledongle.config.enabled","0")
        proxy.apply()
        ngx.print('{ "success":"true" }')
        ngx.exit(ngx.HTTP_OK)
    end
end

ajax_helper.handleAjaxQuery({
    link_status                 = "uci.mobiledongle.info.link_status",
    link_status_displ           = "uci.mobiledongle.info.link_status",
    device_name                 = "uci.mobiledongle.info.device_name",
    device_status               = "uci.mobiledongle.info.device_status",
    registration_status         = "uci.mobiledongle.info.registration_status",
    ppp_status                  = "uci.mobiledongle.info.ppp_status",
    RSSI                        = "uci.mobiledongle.info.RSSI",
    current_operator            = "uci.mobiledongle.info.current_operator",
    current_technology          = "uci.mobiledongle.info.current_technology",
    network                     = "uci.mobiledongle.config.network",
    sim_status                  = "uci.mobiledongle.sim.status",
    wwan_ipaddr                 = "rpc.network.interface.@wwan.ipaddr",
    dnsservers                  = "rpc.network.interface.@wwan.dnsservers",
    uptime                      = "rpc.network.interface.@wwan.uptime",
    rx_bytes                    = "rpc.network.interface.@wwan.rx_bytes",
    tx_bytes                    = "rpc.network.interface.@wwan.tx_bytes",
    }, function(content)
--      tprint(content)
        if content["link_status"] then
            content["link_status"] = format("%s",content["link_status"])
        end
        if content["link_status_displ"] then
            content["link_status_displ"] = format("%s",content["link_status_displ"])
            content["link_status_displ"] = link_status_map[content["link_status_displ"]]
        end
        if content["device_name"] then
            content["device_name"] = format("%s",content["device_name"])
            content["device_name"] = device_name(content["device_name"])
        end
        if content["device_status"] then
            content["device_status"] = format("%s",content["device_status"])
            content["device_status"] = device_status_map[content["device_status"]]
        end
        if content["registration_status"] then
            content["registration_status"] = format("%s",content["registration_status"])
            content["registration_status"] = registration_status_map[content["registration_status"]]
        end
        if content["ppp_status"] then
            content["ppp_status"] = format("%s",content["ppp_status"])
            content["ppp_status"] = ppp_status_map[content["ppp_status"]]
        end
        if content["dnsservers"] then
            content["dnsservers"] = printableDNSServers( content["dnsservers"])
        end
        if content["rx_bytes"] then
            content["rx_bytes"] = bytesToSize(content["rx_bytes"])
        end
        if content["tx_bytes"] then
            content["tx_bytes"] = bytesToSize(content["tx_bytes"])
        end
        if content["uptime"] then
            content["uptime"] = secondsToTime(content["uptime"])
        end
        if content["sim_status"] then
            content["sim_status"] = format("%s",content["sim_status"])
            content["sim_status"] = sim_status_map[content["sim_status"]]
        end
        if content["current_operator"] then
            content["current_operator"] = format("%s",content["current_operator"])
            if current_operator_map[content["current_operator"]] ~= nil then
                content["current_operator"] = current_operator_map[content["current_operator"]]
            else
                content["current_operator"] = current_operator_map["NA"]
            end
        end
        if content["current_technology"] then
            content["current_technology"] = format("%s",content["current_technology"])
        end

        --tprint(content)
    end)

content_helper.getExactContent(content)
convertReceivedData()

local content_wan = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
}
content_helper.getExactContent(content_wan)

-- in case wan6 is not configured in uci, protection is needed
local content_wan6 = {
    ipaddr = "rpc.network.interface.@wan6.ipaddr",
}
content_helper.getExactContent(content_wan6)

local disconnected = content_wan.ipaddr:len() == 0 and content_wan6.ipaddr:len() == 0

--
-- end data collecting part
--

--
-- start page representation
--

--local refresh = 5
local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<%= ui_helper.createHeader(T"Mobile 3G/4G", false, true, nil, help_link)%>
<div class="modal-body update">
    <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        local html = {}
        local tabs = {
            {
                desc = T"Information",
                active = "active",
                target = "modals/mobiledongle-information-modal.lp",
            },
        }
        if disconnected then
            tabs[#tabs + 1] = {
                desc = T"Configuration",
                target = "modals/mobiledongle-configuration-modal.lp",
            }
        end

        table.insert (html, ui_helper.createModalTabs(tabs))
        ngx.print (html)
    %>

    <form class="form-horizontal" method="post" action="modals/mobiledongle-information-modal.lp">
    <fieldset id="mobiledongle-information-tab">

    <%
        local html = {}
        tinsert(html, "<legend>" .. T"Line Information" .. "</legend>")
        local link_status_attributes = {
            input = {
                class = "monitor-changes",
                id = "link_status",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createSimpleInputHidden("link_status", content["link_status"], link_status_attributes))
        local link_status_label_attributes = {
            span = {
                class = "span4 monitor-changes",
                id = "link_status_displ",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"Link Status: ", content["link_status_displ"], link_status_label_attributes))

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
        tinsert(html, ui_helper.createLabel(T"IPv4: ", content["wwan_ipaddr"], connectedattributes_wwan_ipaddr))
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
        tinsert(html, ui_helper.createLabel(T"DNS Servers: ", content["dnsservers"], connectedattributes_dnsservers))

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
        tinsert(html, ui_helper.createLabel(T"Up Time: ", content["uptime"], connectedattributes_uptime))

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
        tinsert(html, ui_helper.createLabel(T"Tx Bytes: ", content["tx_bytes"], connectedattributes_rxbytes))
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
        tinsert(html, ui_helper.createLabel(T"Rx Bytes: ", content["rx_bytes"], connectedattributes_txbytes))
        tinsert(html, "<legend>" .. T"Mobile Information" .. "</legend>")
        local connectedattributes_device_name = {
            span = {
                class = "span4 monitor-changes",
                id = "device_name",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"Device Name: ", content["device_name"] , connectedattributes_device_name))
        local connectedattributes_device_status = {
            span = {
                class = "span4 monitor-changes",
                id = "device_status",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"Device Status: ", content["device_status"], connectedattributes_device_status))
        local connectedattributes_simstatus = {
            span = {
                class = "span4 monitor-changes",
                id = "sim_status",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"SIM Status: ", content["sim_status"], connectedattributes_simstatus))
        local connectedattributes_registration_status = {
            span = {
                class = "span4 monitor-changes",
                id = "registration_status",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"Registration Status: ", content["registration_status"], connectedattributes_registration_status))
        local connectedattributes_ppp_status = {
            span = {
                class = "span4 monitor-changes",
                id = "ppp_status",
                ["data-ajaxrefresh"] = "5",
            },
        }
        tinsert(html, ui_helper.createLabel(T"Network Status: ", content["ppp_status"], connectedattributes_ppp_status))

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
        tinsert(html, ui_helper.createLabel(T"Current Technology: ",  content["current_technology"], connectedattributes_ctech))
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
        tinsert(html, ui_helper.createLabel(T"Current Operator: ", content["current_operator"], connectedattributes_coper))

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
        tinsert(html, ui_helper.createLabel(T"Radio Signal Quality", content["RSSI"], connectedattributes_rssi))
        tinsert(html, "</fieldset>")
        ngx.print(html)
    %>
    </form>
</div>
<div id="spinner" class="spinner hide" align="center">
    <img id="img-spinner" src="../img/spinner.gif" alt="changing connection state" style="margin-left: 50px; margin-right: 50px; margin-top: 50px; margin-bottom: 50px; width:128px; height=128px"/>
</div>

<% ngx.print(createFooterConnect(disconnected)) %>

<script>
(function() {

    var modalbody = $(".modal-body");
    var busy_msg = $("#spinner");
    var target = $(".modal form").attr("action");
    var scrolltop = $(".modal-body").scrollTop();
    var initialDelay = 5000;
    var delay = initialDelay;

    function wait_for_connect_reply() {
        if ( delay === initialDelay) {
            delay = 0;
            window.setTimeout(function() {
                tch.loadModal(target, function () {
                    $(".modal-body").scrollTop(scrolltop);
                });
            }
            , initialDelay);
        }
    };

    $("#CONNECT").click(function() {
        busy_msg.removeClass("hide");
        modalbody.removeClass("update");
        modalbody.addClass("hide");
        $(this).addClass("hide");
        $(".modal-action-refresh").addClass("hide");
        busy_msg[0].scrollIntoView();

        $.post(
            target,
            {
                action:"CONNECT",
                CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
            },
            wait_for_connect_reply,
            "json"
        );
    return false;
    });

    $("#DISCONNECT").click(function() {
        busy_msg.removeClass("hide");
        modalbody.removeClass("update");
        modalbody.addClass("hide");
        $(this).addClass("hide");
        $(".modal-action-refresh").addClass("hide");
        busy_msg[0].scrollIntoView();

        $.post(
            target,
            {
                action:"DISCONNECT",
                CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
            },
            wait_for_connect_reply,
            "json"
        );
    return false;
    });


}());

</script>
