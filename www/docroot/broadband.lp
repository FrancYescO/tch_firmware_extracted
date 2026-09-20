<%
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
%>

<%
-- Localization
gettext.textdomain('webui-telstra')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string = string
local format = string.format
local floor = math.floor
local tonumber = tonumber

local content_wan = {
  proto =  "uci.network.interface.@wan.proto",
}
content_helper.getExactContent(content_wan)

local wan_intf ="wan"
local wan6_intf ="wan6"

local ppp_intf = ""
local wan_mode =""
local l3sense = false
if content_wan.proto == ""  then
  -- wansensing is in L3Sense state
  ppp_intf = "ppp"
  wan_mode = "PPPoE"
  l3sense = true
else
  ppp_intf = "wan"
  
  local content_wwan = {
    ipaddr = "rpc.network.interface.@wwan.ipaddr",
  }
  content_helper.getExactContent(content_wwan)

  if content_wwan.ipaddr:len() ~= 0 then
    wan_intf = "wwan"
    wan_mode = "Mobile"
  elseif content_wan.proto == "pppoe" then
    wan_mode = "PPPoE"
  else
    ppp_intf = "ppp"
    wan_mode = "IPoE"
  end
end

-- Process POST query
local post_helper = require("web.post_helper")

local mapParams = {
    uci_wan_username = "uci.network.interface.@" .. ppp_intf .. ".username",
    uci_wan_password = "uci.network.interface.@" .. ppp_intf .. ".password",
    uci_ppp_username = "uci.network.interface.@ppp.username",
    uci_ppp_password = "uci.network.interface.@ppp.password",
}

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

-- We ensure that the PPP connection always contain the correct username/password by setting it whatever happens
-- So if the current wan interface is not ppp, we set the user/pass in both wan and ppp. If ppp is the current wan
-- interface, then we'll set it twice (but it is not a big deal)
local mapValid = {
    uci_wan_username = vNES,
    uci_wan_password = gVP(vNES),
    uci_ppp_username = function(val, object)
        object.uci_ppp_username = object.uci_wan_username
        return true
    end,
    uci_ppp_password = function(val, object)
        object.uci_ppp_password = object.uci_wan_password
        return true
    end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local content_uci_ppp = {
    username = "uci.network.interface.@" .. ppp_intf .. ".username",
    password = "uci.network.interface.@" .. ppp_intf .. ".password",
}
content_helper.getExactContent(content_uci_ppp)

local content_rpc = {
    wan_ppp_ll_intf = "rpc.network.interface.@" .. wan_intf .. ".ppp.ll_intf",
    wan_ppp_state = "rpc.network.interface.@" .. wan_intf .. ".ppp.state",
    wan_ppp_error = "rpc.network.interface.@" .. wan_intf .. ".ppp.error",
    ipaddr = "rpc.network.interface.@" .. wan_intf .. ".ipaddr",
    dns = "rpc.network.interface.@" .. wan_intf .. ".dnsservers",
    uptime = "rpc.network.interface.@" .. wan_intf .. ".uptime",
    tx_bytes = "rpc.network.interface.@" .. wan_intf .. ".tx_bytes",
    rx_bytes = "rpc.network.interface.@" .. wan_intf .. ".rx_bytes",
}
content_helper.getExactContent(content_rpc)

local primary_dns ="0.0.0.0"
local secondary_dns ="0.0.0.0"
local i,j
if string.match(content_rpc.dns, ",") then
  i,j,primary_dns, secondary_dns = string.find(content_rpc.dns, "(.*),(.*)")
elseif content_rpc.dns~="" then
  primary_dns=content_rpc.dns
end

local ipv4status = "IPv4 disconnected"
local ipv6status = "IPv6 disconnected"

local wanip6addr = "::"
local primary_ip6dns ="::"
local secondary_ip6dns ="::"

if wan_mode ~= "Mobile" and not l3sense then
  local content_wan6 = {
    ip6addr = "rpc.network.interface.@" .. wan6_intf .. ".ip6addr",
    ip6dns  = "rpc.network.interface.@" .. wan6_intf .. ".dnsservers",
  }

  content_helper.getExactContent(content_wan6)
  if content_wan6.ip6addr ~= "" then
    if wan_mode == "PPPoE" and content_rpc.wan_ppp_state == "connected" then
      ipv6status = "IPv6 connected"
      wanip6addr = content_wan6.ip6addr
    elseif wan_mode == "IPoE" then
      ipv6status = "IPv6 connected"
      wanip6addr = content_wan6.ip6addr
    end
  end

  if string.match(content_wan6.ip6dns, ",") then
    i,j,primary_ip6dns, secondary_ip6dns = string.find(content_wan6.ip6dns, "(.*),(.*)")
  elseif content_wan6.ip6dns ~= "" then
    primary_ip6dns=content_wan6.ip6dns
  end
end

if content_rpc.ipaddr=="" then
   content_rpc.ipaddr ="0.0.0.0"
elseif wan_mode == "PPPoE" and content_rpc.wan_ppp_state == "connected" and content_rpc.dns ~="" then
   ipv4status = "IPv4 connected"
elseif wan_mode == "IPoE" then
   ipv4status = "IPv4 connected"
end

local function bytes2string(s_bytes)
  if s_bytes=="" then
    return "0 B"
  else
    local bytes = tonumber(s_bytes)
    local kb = bytes/1024
    local mb = kb/1024
    local gb = mb/1024
    if gb >= 1 then
      return format("%.2f", gb) .. " GB"
    elseif mb >= 1 then
      return format("%.2f", mb) .. " MB"
    elseif kb >= 1 then
      return format("%.2f", kb) .. " KB"
    else
      return s_bytes .. " B"
    end
  end
end

local function secondsToTime(s_uptime)
  if s_uptime == "" then
    return "0"
  else
    local uptime = tonumber(s_uptime)
    local days =  floor(uptime / 86400)
    local hours =  floor(uptime / 3600) % 24
    local minutes = floor(uptime / 60) % 60
    local seconds = uptime % 60
    if (days > 1) then
      return format(T"%d day(s), %02d:%02d:%02d", days, hours, minutes, seconds)
    else
      return format("%02d:%02d:%02d", hours, minutes, seconds)
    end
  end
end

local wan_ppp_over_atm = string.find(content_rpc.wan_ppp_ll_intf, "atm_") == 1
local content_uci_xtm
if wan_ppp_over_atm then
  -- need to untaint the string otherwise getExactContent will get lost
  local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", content_rpc.wan_ppp_ll_intf)
  content_uci_xtm = {
    wan_atm_vpi = wan_atm_uci_path.."vpi",
    wan_atm_vci = wan_atm_uci_path.."vci",
  }
  content_helper.getExactContent(content_uci_xtm)
end

local attributes = {
  span = { class = "span3 text-left" } ,
}
%>

<div class="container toplevel">
<div class="row">
<div class="span11">
<form class="form-horizontal" method="post" action="broadband.lp">
<%
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<div class="span5">
<fieldset>
<legend><%= T"Connection Information" %></legend>
<%
  local html = {}
  html[#html + 1] = ui_helper.createLabel(T"Status",ipv4status)
  html[#html + 1] = ui_helper.createLabel("",ipv6status)
  html[#html + 1] = ui_helper.createLabel(T"Uptime", secondsToTime(content_rpc.uptime))
  html[#html + 1] = ui_helper.createLabel(T"Data Transfered", bytes2string(content_rpc.tx_bytes) .. "(Sent)", attributes)
  html[#html + 1] = ui_helper.createLabel("", bytes2string(content_rpc.rx_bytes) .. "(Received)", attributes)
  html[#html + 1] = ui_helper.createLabel(T"IPv4 Address", content_rpc.ipaddr)
  html[#html + 1] = ui_helper.createLabel(T"Primary DNS", primary_dns)
  html[#html + 1] = ui_helper.createLabel(T"Secondary DNS", secondary_dns)
  html[#html + 1] = ui_helper.createLabel(T"IPv6 Address", wanip6addr)
  html[#html + 1] = ui_helper.createLabel(T"IPv6 DNS server", primary_ip6dns)
  if secondary_ip6dns ~= "::" then
    html[#html + 1] = ui_helper.createLabel("", secondary_ip6dns)
  end
  ngx.print(html)
%>
</fieldset>
</div>
<div class="span5">
<fieldset>
<legend><%= T"Connection Settings" %></legend>
<%
html = {}
if wan_ppp_over_atm then
  html[#html + 1] = ui_helper.createLabel(T"PVC Info (VPI.VCI)", content_uci_xtm.wan_atm_vpi .. "." .. content_uci_xtm.wan_atm_vci)
  html[#html + 1] = ui_helper.createLabel(T"Type", wan_mode)
else
  html[#html + 1] = ui_helper.createLabel(T"Type", wan_mode)
  html[#html + 1] = ui_helper.createLabel("","")
end

ngx.print(html)
%>
</fieldset>
<%
  -- PPP username
  local class_username = {
      input = {
        maxlength= "127",
      }
  }
  html = {}
  html[#html + 1] = "<fieldset>"
  html[#html + 1] = "<legend>" .. T"PPPoE Settings" .. "</legend>"
  html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
  html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content_uci_ppp.username, class_username, helpmsg["uci_wan_username"])
  html[#html + 1] = "</div></div>"

  -- PPP password
  local class_password = {
      input = {
        maxlength= "80",
      }
  }
  html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content_uci_ppp.password, class_password, helpmsg["uci_wan_password"])
  html[#html + 1] = ui_helper.createInputPassword(T"Confirm Password", "uci_wan_password2", content_uci_ppp.password, class_password, helpmsg["uci_wan_password"])
  html[#html + 1] = ui_helper.createLabel(T"Mode","Always On")
  html[#html + 1] = "</fieldset>"
  html[#html + 1] = '<div id="form-changes" class="hide">'
  html[#html + 1] = '<div id="cancel-config" class="btn btn-large">Cancel</div>'
  html[#html + 1] = '<div id="save-pppoe-config" class="btn btn-primary btn-large">Save</div>'
  html[#html + 1] = "</div>"
  ngx.print(html)
%>
</div>
</form>
</div>
</div>
</div>

<script src="/js/srp-min.js" ></script>
<script type="text/javascript" >

    function clear_error_password()
    {
        var upass = $('input[name="uci_wan_password"],input[name="uci_wan_password2"]');
        upass.closest(".control-group").removeClass("error");
        upass.first().next().remove();
    }

    function display_error_password(msg)
    {
        var upass = $('input[name="uci_wan_password"],input[name="uci_wan_password2"]');
        upass.addClass("error");
        upass.closest(".control-group").addClass("error");
        upass.first().after('<span class="help-inline">' + msg + '</span>');
    }

    function clear_error_user()
    {
        var uinput = $('input[name="uci_wan_username"]');
        uinput.closest(".control-group").removeClass("error");
        uinput.next().remove();
    }

    function display_error_user()
    {
        var uinput = $('input[name="uci_wan_username"]');
        uinput.addClass("error");
        uinput.closest(".control-group").addClass("error");
        uinput.after('<span class="help-inline">Username can not be empty</span>');
    }

    function display_alert()
    {
        $('.alert').detach();
        $('.form-horizontal').before('<div class="alert alert-error">Some parameters failed validation</div>');
    }

    $(document).on("click", "#save-pppoe-config", function() {
            var user = $('input[name="uci_wan_username"]').val();
            var password = $('input[name="uci_wan_password"]').val();
            var password2 = $('input[name="uci_wan_password2"]').val();
            var vInput = true;

            clear_error_password();
            clear_error_user();

            if(user == "") {
               display_error_user();
               vInput = false;
            }

            if (password == "") {
              display_error_password("Password can not be empty");
              vInput = false;
            }
            else if (password !=password2) {
              display_error_password("Passwords do not match");
              vInput = false;
            }

            if (vInput) {
              var form = $("form");
              var params = form.serializeArray();
              params.push({
                  name : "action",
                  value : "SAVE"
              }, tch.elementCSRFtoken());
              var target = form.attr("action");
              tch.postParams(target,params);
            }
            else {
              display_alert();
            }
        });

</script>
<%
lp.include("networkmap.lp")
lp.include("footer.lp")
%>
