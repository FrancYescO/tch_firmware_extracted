--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 0
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local string = string
local format, gmatch,find,sub = string.format, string.gmatch, string.find, string.sub
local validateStringIsIPv6 = post_helper.validateStringIsIPv6
local setmetatable = setmetatable
local untaint_mt = require("web.taint").untaint_mt

local cui = {
  s_defaultuser = "uci.web.sessionmgr.@default.default_user",
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  adusrname = "uci.web.user.@usr_admin.name",
  legacysalt = "uci.web.user.@usr_admin.legacy_salt",
  factory_id = "uci.env.rip.factory_id",
  serial_number = "uci.env.rip.serial",
  firmware_version = "uci.version.version.@version[0].version",
  product_name = "uci.env.var.prod_friendly_name",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override",
}
content_helper.getExactContent(cui)
if cui["firmware_version"] then
  local version = cui["firmware_version"]
  cui["firmware_version"] = cui.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. cui.fwversion_suffix
  if cui.fwversion_override then
    if cui.fwversion_override == "override1" then
      cui["firmware_version"] = cui.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. cui.fwversion_suffix
    end
  end
end

local currentuser = ngx.ctx.session:getusername()
local getargs = ngx.req.get_uri_args()

local content_wan = {
  wan_proto =  "uci.network.interface.@wan.proto",
  wwan_ipaddr = "rpc.network.interface.@wwan.ipaddr",
  wwan_ip6addr = "rpc.network.interface.@wwan.ip6addr",
  wans_l2type = "uci.wansensing.global.l2type",
  wans_ppp_username = "uci.network.interface.@wan.username",
}
content_helper.getExactContent(content_wan)

local content_cui = {
  fon_status = "uci.hotspotd.state.status",
  wirelss_hosts_num = "sys.hosts.ActiveWirelessNumberOfEntries",
  fxs_state = "uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.relay_state",
  sip_uri = "uci.mmpbxrvsipnet.profile.@sip_profile_0.uri",
}
content_helper.getExactContent(content_cui)


local wan_intf ="wan"
local wan6_intf ="wan6"

local ppp_intf = "ppp"
local wan_mode ="IPoE"
local l3sense = false
if content_wan.wan_proto == ""  then
  -- wansensing is in L3Sense state
  wan_mode = "PPPoE"
  l3sense = true
  if content_wan.wwan_ipaddr:len() ~= 0 or content_wan.wwan_ip6addr:len() ~= 0 then
    wan_intf = "wwan"
    wan_mode = "Mobile"
  end
else
  if content_wan.wwan_ipaddr:len() ~= 0 or content_wan.wwan_ip6addr:len() ~= 0 then
    wan_intf = "wwan"
    wan_mode = "Mobile"
  elseif content_wan.wan_proto == "pppoe" then
    wan_mode = "PPPoE"
  else
    wan_mode = "IPoE"
  end

  if content_wan.wan_proto == "pppoe" then
    ppp_intf = "wan"
  end
end

local content_rpc = {
    wan_ppp_state = "rpc.network.interface.@" .. wan_intf .. ".ppp.state",
    ipaddr = "rpc.network.interface.@" .. wan_intf .. ".ipaddr",
    dns = "rpc.network.interface.@" .. wan_intf .. ".dnsservers",
}
content_helper.getExactContent(content_rpc)

local led_objects = content_helper.convertResultToObject("rpc.Leds.Led.", proxy.get("rpc.Leds.Led."))
local content_led = {}

for _,v in pairs(led_objects) do
  if v.Status == "Blinking" and v.Color == "None" then
     v.Color = "Green"
  end
  content_led[string.untaint(v.Name)] = v
end

local color_map = setmetatable({
  Green = "green",
  Orange = "orange",
  None = "off"
}, untaint_mt)

function createLed(led_status,led_color)
  local statusIcon
  blink_on, blink_off = "",""
  if led_status == "Blinking" then
    blink_on, blink_off = "blink_fast_on", "blink_fast_off"
  end
  if led_status == "On" or led_status == "Netdev" or led_status == "Blinking" then
    statusIcon = format("<div class='light light-large %s %s' ></div><div class='light light-large off %s hide' ></div>", color_map[led_color] or "bright-red", blink_on, blink_off)
  else
    statusIcon = "<div class='light light-large bright-red hide'></div><div class='light light-large off'></div>"
  end
  return statusIcon
end

local primary_dns ="0.0.0.0"
local secondary_dns ="0.0.0.0"
local primary_ip6dns ="::"
local secondary_ip6dns ="::"

for ipaddr_value in gmatch(content_rpc.dns, "([^,]+)") do
  if not validateStringIsIPv6(ipaddr_value) then
    if primary_dns == "0.0.0.0" then
      primary_dns = ipaddr_value
    else
      secondary_dns = ipaddr_value
    end
  else
    if primary_ip6dns == "::" then
      primary_ip6dns = ipaddr_value
    else
      secondary_ip6dns = ipaddr_value
    end
  end
end

local ipv4status = "IPv4 disconnected"
local ipv6status = "IPv6 disconnected"
local phone_mode = "PSTN"
local phone_num = ""

local wanip6addr = "::"
local Username = ""

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
  local i, j
  if string.match(content_wan6.ip6dns, ",") then
    i,j,primary_ip6dns, secondary_ip6dns = string.find(content_wan6.ip6dns, "(.*),(.*)")
  elseif content_wan6.ip6dns ~= "" then
    primary_ip6dns=content_wan6.ip6dns
  end
elseif wan_mode == "Mobile" and content_wan.wwan_ip6addr:len() ~= 0 then
  wanip6addr = content_wan.wwan_ip6addr
  ipv6status = "IPv6 connected"
end

if content_rpc.ipaddr=="" then
   content_rpc.ipaddr ="0.0.0.0"
elseif (wan_mode == "PPPoE" and content_rpc.wan_ppp_state == "connected" and content_rpc.dns ~="")
  or (wan_mode == "IPoE") or (wan_mode == "Mobile" and content_wan.wwan_ipaddr:len() ~= 0) then
   ipv4status = "IPv4 connected"
end

if wan_mode == "PPPoE" then
  Username = content_wan["wans_ppp_username"]
end

if content_cui["fxs_state"] == "0" then
  phone_mode = "PSTN"
else
  phone_mode = "SIP"
end

if phone_mode == "SIP" or phone_mode == "VOLTE" then
  if content_cui["sip_uri"] ~= "profile1" then
    phone_num = content_cui["sip_uri"]
  end
end

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  local ret = false

  --if the post is to reset password, it means the legacy_salt should be reset
  if post_args.resetpass then
    ret = ngx.ctx.session:changePassword(post_args.salt, post_args.verifier)
    if ret then
      proxy.set("uci.web.user.@usr_admin.legacy_salt", "")
      proxy.apply()
    end
  end

  if post_args.do_signout then
    --NG-9496:In Advanced UI，the signout doesn't works.
    --The param from=adv comes from action.js
    if getargs.from == "adv" then  --User click signout in Advanced UI (cards)
      --Clear the current session
      ngx.ctx.session:logout()
      if cui.s_defaultuser ~= "" then
        --default user exists, access the advanced WEBUI with default user.
        ngx.redirect("/gateway.lp")
      else
        --store the "/gateway.lp" and then redirect to "/login.lp",
        --and redirect ot "/gateway.lp" after authentication
        ngx.ctx.session:store("lasturi", "/gateway.lp")
        --Show the uri without variable.
        ngx.redirect("/login.lp")
      end
    else  --User clicks the signout in RefreshUI.
      --if we changed the default user to non default user,the s_defaultuser will be null
      if cui.s_defaultuser ~= "" then
        --Non default usr restored to the default user, and later click logout.
        --The session temporary data need to be cleared.
        if currentuser ~= cui.s_defaultuser then
          ngx.ctx.session:logout()
        end
        --default user needn't to login, so we redirect to home page.
        ngx.redirect("/")
      else
        --the default user is NOT admin, the logout will redirect to login page (handled in action.js),
        --the session temporary data will be cleared here.
        ngx.ctx.session:logout()
      end
    end
  end
end

--NG-8926:After Signing in on the advaned user page you should be redirected to the Advance GUI
--The user clicked the SIGNIN in advanced UI,
--Store the "/gateway.lp" temporary,
--And redirect to "gateway.lp" after authentication.
if ngx.req.get_method() == "GET" then
  if getargs.from == "adv" then
    --store the "/gateway.lp" and then redirect to "/login.lp"
    ngx.ctx.session:store("lasturi", "/gateway.lp")
    ngx.redirect("/login.lp")
  end
end
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s" style="height:100%%">', gettext.language()) ); ngx.print('\
<head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw-telstra.css?version=');  ngx.print(cui.firmware_version); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-telstra-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>\
<body class="landingpage">\
<!-- START DESKTOP-->\
<div class="container visible-desktop login-part desktop" id="login_part">\
  <div class="row" style="width:100%;height:100%;-webkit-border-radius: 0;moz-border-radius: 0;border-radius: 0; background-color:transparent;box-shadow:none;padding: 0;border: 0;margin-bottom: 0;">\
    <div class="pull-left" style="width:10%;position:relative;">\
    </div>\
    <div class="span3" style="width:30%;position:relative;">\
    </div>\
    <div class="span3" style="width:30%;position:relative;">\
      <fieldset>\
        <h2 class="text-center" style="color:#808080">');  ngx.print( T"TELSTRA" ); ngx.print('</h2>\
        <h2 class="text-center" style="color:#808080">');  ngx.print( T"SMART MODEM" ); ngx.print('<sup style="font-size:13px;top:-1.2em">');  ngx.print( T"TM" ); ngx.print('</sup>');  ngx.print( T" GEN 2" ); ngx.print('</h2>\
      </fieldset>\
    </div>\
    <div class="login span3" style="width:30%;position:relative;float:right;margin-top:15px;">\
      <fieldset>\
        <div class="erroruserpass alert alert-error hide">\
           <strong>');  ngx.print( T"Invalid Username or Password" ); ngx.print('</strong>\
        </div>\
        <div class="control-group pull-right">\
          <form class="form-horizontal" style="margin-bottom:0;">\
            <input class="span2 text-center srp-username" style="-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;" type="text" placeholder="');  ngx.print( T"Your username" ); ngx.print('" id="srp_username" value="');  ngx.print( cui.defaultuser ); ngx.print('" autofocus>\
            <input class="span2 text-center srp-password" style="-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;" type="password" placeholder="');  ngx.print( T"Your password" ); ngx.print('" id="srp_password">\
          </form>\
        </div>\
        <div id="defaultpassword" class="defaultpassword alert alert-info hide">\
            ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your modem (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
        </div>\
        <div class="control-group pull-right">\
            <p class="text-right" style="margin-bottom:0;">');  ngx.print( T"Enter the Username and Password provided"); ngx.print('</p>\
            <p class="text-right" style="margin-bottom:0;">');  ngx.print( T"with your Telstra Smart Modem"); ngx.print('<sup style="font-size:8px;">');  ngx.print(T"TM"); ngx.print('</sup>');  ngx.print(T" Gen 2"); ngx.print('</p>\
            <p class="text-right"style="margin-bottom:0;">');  ngx.print( T"to access full features"); ngx.print('</p>\
        </div>\
        <div class="pull-right" style="clear:right;"><div id="sign-me-in" class="sign-me-in btn btn-primary btn-small buttonborder linear-desktop">');  ngx.print( T"Sign In" ); ngx.print('</div></div>\
      </fieldset>\
    </div>\
  </div>\
</div>\
<div class="container visible-desktop" style="width:100%;height:35%;">\
    <form class="form-horizontal" style="width:100%;height:100%;">\
      ');  
	local lable_bold_attr = {
		label = { class = "label-bold" },
	}
	local lable_black_attr = {
		label = { class = "label-color-black" },
	}
        ngx.print('\
      <div class="span1 pull-left" style="height:100%;width:5%;position:relative;">\
        <div style="position:absolute;bottom:0;right:0;">\
          <img src="/img/TELSTRA_LOGO.png">\
        </div>\
      </div>\
      <div class="span3" style="height:100%;width:24%;margin-left:0;">\
        <h3 class="text-center">');  ngx.print( T"Modem Information" ); ngx.print('</h3>\
        ');  
        local html = {}
        html[#html + 1] = ui_helper.createLabel(T"Serial No", cui["factory_id"] .. cui["serial_number"], lable_bold_attr)
        html[#html + 1] = ui_helper.createLabel(T"Firmware Number", cui["firmware_version"], lable_bold_attr)
        html[#html + 1] = ui_helper.createLabel(T"Modem Make Model", cui["product_name"], lable_bold_attr)
        ngx.print(html)
          ngx.print('\
      </div>\
      <div class="span4 gateway-pic-desktop">\
      </div>\
      <div class="span3" style="width:260px;height:200px;-webkit-border-radius:10px;-moz-border-radius:10px;border-radius:10px;border:2px solid #A0A0A0;padding:0.625em;">\
      ');  
      local img_wifi
      local img_pair
      if content_led.wireless.Color == "Green" then
        img_wifi ="/img/Wi-Fi.png"
        img_wifi_hide ="/img/Wi-Fi_Off.png"
      else
        img_wifi ="/img/Wi-Fi_Off.png"
        img_wifi_hide ="/img/Wi-Fi.png"
      end
      local wireless_led_blink_on =content_led.wireless.Status == "Blinking" and "blink_fast_on" or ""
      local wireless_led_blink_off =content_led.wireless.Status == "Blinking" and "blink_fast_off" or ""
      if content_led.dect.Color == "Green" then
        img_pair = "/img/Pair_green.png"
        img_pair_hide = "/img/Pair_Off.png"
      elseif content_led.dect.Color == "Red" then
        img_pair = "/img/Pair_red.png"
        img_pair_hide = "/img/Pair_Off.png"
      else
        img_pair ="/img/Pair_Off.png"
        img_pair_hide = "/img/Pair_green.png"
      end
      local dect_led_blink_on =content_led.dect.Status == "Blinking" and "blink_fast_on" or ""
      local dect_led_blink_off =content_led.dect.Status == "Blinking" and "blink_fast_off" or ""
        ngx.print('\
        <div class="span1" style="margin-left: 0px;margin-top: 15px;">\
          <div style="width:50px;height:50px;-webkit-border-radius:50%;-moz-border-radius:50%;border-radius:50%;border:2px solid #DADADA;padding:0.625em;margin-bottom:30px;position: relative;">\
            <center>\
              ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s">', img_wifi, wireless_led_blink_on)); ngx.print('\
              ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s hide">', img_wifi_hide, wireless_led_blink_off)); ngx.print('\
            </center>\
          </div>\
        <div style="width:50px;height:50px;-webkit-border-radius:50%;-moz-border-radius:50%;border-radius:50%;border:2px solid #DADADA;padding:0.625em;position: relative;">\
          <center>\
            ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s">', img_pair, dect_led_blink_on)); ngx.print('\
            ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s hide">', img_pair_hide, dect_led_blink_off)); ngx.print('\
          </center>\
        </div>\
      </div>\
      <div class="span2" style="margin-left: -40px;margin-top: 15px;">\
      ');  
      local img_link = '<img src="/img/link.png">'
      local img_onlink = '<img src="/img/online.png">'
      local img_mobile = '<img src="/img/mobile.png">'
      local img_signal = '<img src="/img/signal.png">'
      local img_phone = '<img src="/img/phone.png">'
      local led_online = createLed(content_led.internet.Status,content_led.internet.Color)
      local led_ethernet = createLed(content_led.ethernet.Status,content_led.ethernet.Color)
      local led_mobile = createLed(content_led.mobile.Status,content_led.mobile.Color)
      local led_signal = createLed(content_led.lte.Status,content_led.lte.Color)
      local led_phone = createLed(content_led.voip.Status,content_led.voip.Color)
        ngx.print('\
      ');  ngx.print( ui_helper.createLabel(T"ONLINE",format("%s%s",led_online, img_onlink), lable_black_attr) ); ngx.print('\
      ');  ngx.print( ui_helper.createLabel(T"WAN/DSL",format("%s%s", led_ethernet, img_link), lable_black_attr) ); ngx.print('\
      ');  ngx.print( ui_helper.createLabel(T"MOBILE MODE",format("%s%s", led_mobile, img_mobile), lable_black_attr) ); ngx.print('\
      ');  ngx.print( ui_helper.createLabel(T"MOBILE SIGNAL",format("%s%s", led_signal, img_signal), lable_black_attr) ); ngx.print('\
      ');  ngx.print( ui_helper.createLabel(T"PHONE",format("%s%s", led_phone, img_phone), lable_black_attr) ); ngx.print('\
      </div>\
    </div>\
    <div class="span1" style="height:100%;width:9%;">\
    <p class="text-left" style="color:#808080">');  ngx.print( T"These are the LEDs on the back of your Modem" ); ngx.print('</p>\
    </div>\
  </form>\
</div>\
<div class="container visible-desktop" style="background:url(/img/screen.png); background-size:cover; background-position:top center;width:100%;height:35%;position:relative;top:0;">\
  <form class="form-horizontal" style="padding-top:6%">\
    <div>\
      <div class="span3 status-icon">\
        <center>\
        <img src="/img/Icon_Broadband.png">\
        <h4 style="color:#ffffff">');  ngx.print( T"Broadband" ); ngx.print('</h4>\
        ');  
        local content_icon = {}
        content_icon.online = {}
        content_icon.online.icon = led_online
        content_icon.online.display = "Disconnected"
        if ipv4status == "IPv4 connected" or ipv6status == "IPv6 connected" then
            content_icon.online.display = "Connected"
        end
          ngx.print('\
        <div style="width:150px;height:28px;background:#ffffff;-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;text-align:center"><div style="float:none; display:inline-block">');  ngx.print(content_icon.online.icon ); ngx.print('</div><div style="display:inline-block">');  ngx.print( content_icon.online.display ); ngx.print('</div></div>\
        </center>\
      </div>\
      <div class="span3 status-icon">\
      <center>\
        <img src="/img/Icon_Phone.png">\
        <h4 style="color:#ffffff">');  ngx.print( T"Phone" ); ngx.print('</h4>\
        ');  
        content_icon.phone = {}
        content_icon.phone.icon = led_phone
        content_icon.phone.display = "Disabled"
        if content_led.voip.Status == "On" or content_led.voip.Status == "Netdev" then
          if content_led.voip.Color == "Green" then
            content_icon.phone.display = "Enabled"
          elseif content_led.voip.Color == "Orange" then
            content_icon.phone.display = "SOS"
          else
            content_icon.phone.display = "Error"
          end
        elseif content_led.voip.Status == "Blinking" then
          if content_led.voip.Color == "Green" then
            content_icon.phone.display = "Calling"
          end
        end
          ngx.print('\
        <div style="width:150px;height:28px;background:#ffffff;-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;text-align:center"><div style="float:none; display:inline-block">');  ngx.print( content_icon.phone.icon ); ngx.print('</div><div style="display:inline-block">');  ngx.print( content_icon.phone.display ); ngx.print('</div></div>\
        </center>\
      </div>\
      <div class="span3 status-icon">\
      <center>\
        <img src="/img/Icon_Wi-Fi.png">\
        <h4 style="color:#ffffff">');  ngx.print( T"Wi-Fi" ); ngx.print('</h4>\
        ');  
        content_icon.wifi = {}
        content_icon.wifi.icon = createLed(content_led.wireless.Status,content_led.wireless.Color)
        content_icon.wifi.display = "Off"
        if content_led.wireless.Status == "On" or content_led.wireless.Status == "Netdev" then
          if content_led.wireless.Color == "Green" then
            content_icon.wifi.display = "On"
          end
        end
          ngx.print('\
        <div style="width:150px;height:28px;background:#ffffff;-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;text-align:center"><div style="float:none; display:inline-block">');  ngx.print( content_icon.wifi.icon ); ngx.print('</div><div style="display:inline-block">');  ngx.print( content_icon.wifi.display ); ngx.print('</div></div>\
        </center>\
      </div>\
      <div class="span3 status-icon">\
      <center>\
        <img src="/img/Icon_Telstra-Air.png">\
        <h4 style="color:#ffffff">');  ngx.print( T"Telstra Air" ); ngx.print('</h4>\
        ');  
        content_icon.fon = {}
        content_icon.fon.display = "Off"
        if content_cui["fon_status"] == "up" then
          content_icon.fon.icon = "<div class=\"light light-large green\"></div>"
          content_icon.fon.display = "Active"
        else
          content_icon.fon.icon = "<div class=\"light light-large off\"></div>"
          content_icon.fon.display = "Not Active"
        end
          ngx.print('\
        <div style="width:150px;height:28px;background:#ffffff;-webkit-border-radius:20px;-moz-border-radius:20px;border-radius:20px;text-align:center"><div style="float:none; display:inline-block">');  ngx.print( content_icon.fon.icon ); ngx.print('</div><div style="display:inline-block">');  ngx.print( content_icon.fon.display ); ngx.print('</div></div>\
        </center>\
      </div>\
    </div>\
  </form>\
  <form class="form-horizontal" style="position:absolute;left:0;right:0;bottom:0; margin:auto">\
    <div class="row">\
      <center>\
        <span id="more_info" class="more_info" style="display: inline-block;vertical-align: middle;padding-top: 2%;color:#ffffff;">\
          <img src="/img/Icon_Down.png" style="width: 30px; height: 30px">\
          MORE INFO\
        <span>\
      </center>\
    </div>\
  </form>\
</div>\
<div class="container hide" style="width:100%;height:28%;" id="detailed_info">\
  <form class="form-horizontal" style="position:relative;height:100%">\
    <div class="row">\
      <div class="span3" style="width: 25%; margin-left: 0px;">\
      ');  
      local detailed_info_attr = {
        label = { class = "detailed-info" },
        controls = { class = "detailed-info" },
      }
      html = {}
      html[#html + 1] = ui_helper.createLabel(T"Access Type", content_wan["wans_l2type"], detailed_info_attr)
      html[#html + 1] = ui_helper.createLabel(T"Connection Type", wan_mode, detailed_info_attr)
      html[#html + 1] = ui_helper.createLabel(T"IPv4 Address", content_rpc.ipaddr, detailed_info_attr)
      html[#html + 1] = ui_helper.createLabel(T"IPv6 Address", wanip6addr, detailed_info_attr)
      html[#html + 1] = ui_helper.createLabel(T"Username", Username, detailed_info_attr)
      ngx.print(html)
        ngx.print('\
      </div>\
      <div class="span3" style="width: 25%; margin-left: 0px;">\
      ');  
      html = {}
      html[#html + 1] = ui_helper.createLabel(T"Mode",phone_mode,detailed_info_attr)
      html[#html + 1] = ui_helper.createLabel(T"Phone Number",phone_num,detailed_info_attr)
      ngx.print(html)
        ngx.print('\
      </div>\
      <div class="span3" style="width: 25%; margin-left: 0px;">\
      ');  
      ngx.print(ui_helper.createLabel(T"Connected Devices",content_cui["wirelss_hosts_num"],detailed_info_attr))
        ngx.print('\
      </div>\
      <div class="span3" style="width: 25%; margin-left: 0px;">\
        <p class="text-center" style="color:#808080">');  ngx.print( T"Telstra Air customers can connect to Australia's largest Wi-Fi network to access unlimited data using your smart phone,mobile device or laptop" .. "<br/>" .. "<br/>" .. T"When you're out and about,Telstra Air automatically connects you to the nearest hotspot in range via the Telstra Air App" ); ngx.print('</p>\
      </div>\
    </div>\
    <div class="row">\
      <center>\
        <span id="less_info" style="display: inline-block;vertical-align: middle;position: absolute; left: 0px; right: 0px; bottom: 0px; margin: auto;">\
          <img src="/img/Icon_Up.png" style="width: 30px; height: 30px">\
          LESS INFO\
        <span>\
    </div>\
  </form>\
</div>\
<div class="container linear-desktop hide" id="footer_picture" style="width:100%;height:2%;">\
</div>\
<!-- END DESKTOP-->\
<!-- START MOBILE-->\
<div class="container hidden-desktop login-part" style="height:60%;min-height:400px;margin-bottom:20px;" id="login_part_mobile">\
  <div class="" style="margin-top:15px;">\
    <center>\
      <img src="/img/TELSTRA_LOGO.png" style="width:57px;height:65px;">\
    </center>\
  </div>\
  <div class="">\
    <h2 class="text-center" style="font-size:30px">');  ngx.print( T"TELSTRA" ); ngx.print('</h2>\
    <h2 class="text-center" style="font-size:30px">');  ngx.print( T"SMART MODEM"); ngx.print('<sup style="font-size:10px;top:-1.3em;">');  ngx.print( T"TM" ); ngx.print('</sup>');  ngx.print( T" GEN 2" ); ngx.print('</h2>\
    <p class="text-center" style="margin-bottom:0">');  ngx.print( T"Enter the Username and Password provided"); ngx.print('</p>\
    <p class="text-center" style="margin-bottom:0">');  ngx.print( T"with your Telstra Smart Modem"); ngx.print('<sup sytle="font-size:6px;top:-0.8em;">');  ngx.print( T"TM"); ngx.print('</sup>');  ngx.print( T" Gen 2 to"); ngx.print('</p>\
    <p class="text-center" style="margin-bottom:0">');  ngx.print( T"access full features"); ngx.print('</p>\
  </div>\
  <div class="">\
    <div class="erroruserpass alert alert-error hide">\
      <strong>');  ngx.print( T"Invalid Username or Password" ); ngx.print('</strong>\
    </div>\
    <div class="control-group">\
      <center>\
      <form>\
      <input class="srp-username buttonborder text-center" type="text" placeholder="');  ngx.print( T"Your username" ); ngx.print('" id="srp_username" value="');  ngx.print( cui.defaultuser ); ngx.print('" autofocus style="-webkit-border-radius: 20px;-moz-border-radius: 20px;border-radius: 20px;width:50%;">\
      <input class="srp-password buttonborder text-center" type="password" placeholder="');  ngx.print( T"Your password" ); ngx.print('" id="srp_password" style="-webkit-border-radius: 20px;-moz-border-radius: 20px;border-radius: 20px;width:50%;">\
      </form>\
      <div id="defaultpassword" class="defaultpassword alert alert-info hide">\
        ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your modem (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
      </div>\
      <div id="sign-me-in-mobile" class="sign-me-in btn btn-primary buttonborder linear-mobile" style="width:50%; height:20px;padding:4px 6px;text-align:center;margin-top:-25px;">');  ngx.print( T"Sign In" ); ngx.print('\
      </div>\
      </center>\
    </div>\
  </div>\
</div>\
<div class="container down-icon hidden-desktop" id="icon_down">\
  <center>\
    <div class="mobile-menu down-icon">\
      <h4 class="text-center mobile-menu-text">');  ngx.print( T"DEVICE INFO" ); ngx.print('</h4>\
      <span id="more_info" class="more_info" style="display: inline-block;vertical-align: middle;padding-top: 5px;margin-bottom:10%;">\
        <img src="/img/Icon_Down.png" style="width: 40px; height: 40px">\
      <span>\
    </div>\
  </center>\
</div>\
<div class="container gateway-pic-mobile hide" id="device_pic">\
</div>\
<div class="container hide" id="detailed_list" style="background:url(/img/screen.png); background-size:cover; background-position:top center;width:100%;height:50%;position:absolute;bottom:0px;">\
  <center>\
    <div class="text-center mobile-menu detailed-list">\
      <h4 class="text-center mobile-menu-text" style="padding-bottom:10px;line-height:100%">');  ngx.print( T"MODEM INFORMATION" ); ngx.print('</h4>\
      <h4 class="text-center mobile-menu-text" style="padding-bottom:10px;line-height:100%">');  ngx.print( T"DEVICE STATUS" ); ngx.print('</h4>\
      <h4 class="text-center mobile-menu-text" style="line-height:100%">');  ngx.print( T"DETAILED INFORMATION" ); ngx.print('</h4>\
    </div>\
  </center>\
</div>\
<div class="container hide" id="detailed_info_mobile" style="width:100%;overflow:auto;">\
  <div>\
    <center>\
      <img src="/img/gateway_half.png" alt="picture of gateway_half" style="position:relative;padding-top:0;">\
    </center>\
  </div>\
  <div class="mobile-menu-text" style="background:url(/img/screen_info.png); background-size:cover; background-position:top center;width:100%;height:120px;line-height:120px; position:relative;margin-top:-30px;text-align:center;"><table style="width:100%;height:100%;line-height:100%"><tr><td>');  ngx.print( T"MODEM INFORMATION" ); ngx.print('</td></tr></table>\
  </div>\
  <div style="height:100%;">\
    <br/>\
    <table style="width:100%; height:100px; text-align:center">\
    <tr>\
    <td style="text-align:right;font-weight: 900;color:#808080">Serial No</td>\
    <td style="text-align:left;color:#808080">');  ngx.print( cui["factory_id"] .. cui["serial_number"] ); ngx.print('</td>\
    </tr>\
    <tr>\
    <td style="text-align:right;font-weight: 900;color:#808080;">Firmware Number</td>\
    <td style="text-align:left;color:#808080;">');  ngx.print( cui["firmware_version"] ); ngx.print('</td>\
    </tr>\
    <tr>\
    <td style="text-align:right;font-weight: 900;color:#808080;">Modem Make Model</td>\
    <td style="text-align:left;color:#808080;">');  ngx.print( cui["product_name"] ); ngx.print('</td>\
    </tr>\
    </table>\
    <br/>\
  </div>\
  <div class="mobile-menu-text" style="background:url(/img/screen_detailed.png);background-size:cover; background-position:top center;width:100%;height:120px;line-height:120px; position:relative;text-align:center;">');  ngx.print( T"DEVICE STATUS" ); ngx.print('\
  </div>\
  <div>\
    <br/><br/>\
    <form class="form-horizontal" style="width:100%;height:100%;">\
    <center>\
    <div style="width:220px;height:240px;-webkit-border-radius:10px;-moz-border-radius:10px;border-radius:10px;border:2px solid #A0A0A0;padding:0.625em;text-align:center">\
    <div style="margin-right: 10px;margin-top: 0px;display:inline-block;">\
      <div style="width:50px;height:50px;-webkit-border-radius:50%;-moz-border-radius:50%;border-radius:50%;border:2px solid #A0A0A0;padding:0.625em;position: relative;margin-top:30px;margin-bottom:40px">\
        <center>\
          ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s">', img_wifi, wireless_led_blink_on)); ngx.print('\
          ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s hide">', img_wifi_hide, wireless_led_blink_off)); ngx.print('\
        </center>\
      </div>\
      <div style="width:50px;height:50px;-webkit-border-radius:50%;-moz-border-radius:50%;border-radius:50%;border:2px solid #A0A0A0;padding:0.625em;position: relative;;margin-bottom:30px">\
      <center>\
        ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s">', img_pair, dect_led_blink_on)); ngx.print('\
        ');  ngx.print(format('<img style="margin: auto;position: absolute;left: 0;right: 0;top: 0;bottom: 0;" src="%s" class="%s hide">', img_pair_hide, dect_led_blink_off)); ngx.print('\
      </center>\
      </div>\
    </div>\
    <table style="width:60%;height:100%;line-height:45px;display:inline-block;padding-top:0px">\
    <tr>\
      <td class="table-td-described-info">ONLINE</td>\
      <td class="text-center">');  ngx.print( led_online ); ngx.print('</td>\
      <td class="text-center">');  ngx.print( img_onlink ); ngx.print('</td>\
    </tr>\
    <tr>\
      <td class="table-td-described-info">WAN/DSL</td>\
      <td class="text-center">');  ngx.print( led_ethernet ); ngx.print('</td>\
      <td class="text-center">');  ngx.print( img_link ); ngx.print('</td>\
    </tr>\
    <tr>\
      <td class="table-td-described-info" style="line-height:15px;">MOBILE MODE</td>\
      <td class="text-center">');  ngx.print( led_mobile ); ngx.print('</td>\
      <td class="text-center">');  ngx.print( img_mobile ); ngx.print('</td>\
    </tr>\
    <tr>\
      <td class="table-td-described-info" style="line-height:15px;">MOBILE SIGNAL</td>\
      <td class="text-center">');  ngx.print( led_signal ); ngx.print('</td>\
      <td class="text-center">');  ngx.print( img_signal ); ngx.print('</td>\
    </tr>\
    <tr>\
      <td class="table-td-described-info">PHONE</td>\
      <td class="text-center">');  ngx.print( led_phone ); ngx.print('</td>\
      <td class="text-center">');  ngx.print( img_phone ); ngx.print('</td>\
    </tr>\
    </table>\
    </div>\
    <p class="text-center" style="color:#808080">');  ngx.print( T"These are the LEDs on the back" .. "<br/>" .. T"of your Modem" ); ngx.print('</p>\
    </center>\
  </form>\
  </div>\
  <div class="mobile-menu-text" style="background:url(/img/screen_detailed.png);background-size:cover; background-position:top center;width:100%;height:120px;line-height:120px; position:relative;text-align:center;"><table style="width:100%;height:100%;line-height:100%"><tr><td>');  ngx.print( T"DETAILED INFORMATION" ); ngx.print('</td></tr></table>\
  </div>\
  <div>\
    <form class="form-horizontal text-center" style="width:100%;height:100%;">\
    <br>\
    <br>\
    <div style="text-align:left;position:relative;left:50%;width:285px;margin-left:-140px">\
      <img src="/img/Icon_Broadband_mobile.png" style="width: 75px; height: 75px; display:inline-block;margin-top:-40px">\
      <div style="display:inline-block;width:55%">\
      <p style="font-size:25px">');  ngx.print( T"Broadband" ); ngx.print('</p>\
      <div>');  ngx.print( content_icon.online.icon ); ngx.print('</div><div style="text-align:left;font-size:19px">');  ngx.print( content_icon.online.display ); ngx.print('</div>\
      </div>\
      </div>\
      <br>\
      <div style="text-align: left; position: relative; left: 50%; width:240px;margin-left: -100px;">\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Access Type" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( content_wan["wans_l2type"] ); ngx.print('</p>\
      <br>\
      </div>\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Connection Type" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( wan_mode ); ngx.print('</p>\
      <br>\
      </div>\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"IPv4 Address" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( content_rpc.ipaddr ); ngx.print('</p>\
      <br>\
      </div>\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"IPv6 Address" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( wanip6addr ); ngx.print('</p>\
      <br>\
      </div>\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Username" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( Username ); ngx.print('</p>\
      <br>\
      </div>\
      </div>\
      <hr />\
      <br>\
      <br>\
      <div style="text-align:left;position:relative;left:50%;width:285px;margin-left:-140px">\
      <img src="/img/Icon_Phone_mobile.png" style="width: 75px; height: 75px; display:inline-block;margin-top:-40px">\
      <div style="display:inline-block;width:55%">\
      <p style="font-size:25px">');  ngx.print( T"Phone" ); ngx.print('</p>\
      <div>');  ngx.print( content_icon.phone.icon ); ngx.print('</div><div style="text-align:left;font-size:19px">');  ngx.print( content_icon.phone.display ); ngx.print('</div>\
      </div>\
      </div>\
      <br>\
      <div style="text-align: left; position: relative; left: 50%; width:240px;margin-left: -100px;">\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Mode" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( phone_mode ); ngx.print('</p>\
      <br>\
      </div>\
      <div>\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Phone Number" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( phone_num ); ngx.print('</p>\
      <br>\
      </div>\
      </div>\
      <hr />\
      <br>\
      <br>\
      <div style="text-align:left;position:relative;left:50%;width:285px;margin-left:-140px">\
      <img src="/img/Icon_Wi-Fi_mobile.png" style="width: 75px; height: 75px; display:inline-block;margin-top:-40px">\
      <div style="display:inline-block;width:55%">\
      <p style="font-size:25px">');  ngx.print( T"Wi-Fi" ); ngx.print('</p>\
      <div>');  ngx.print( content_icon.wifi.icon); ngx.print('</div><div style="text-align:left;font-size:19px">');  ngx.print( content_icon.wifi.display ); ngx.print('</div>\
      </div>\
      </div>\
      <br>\
      <div style="text-align: left; position: relative; left: 50%;width:240px; margin-left: -100px;">\
      <p style="text-aligh:left;font-weight: 900">');  ngx.print( T"Number of Connected Clients" ); ngx.print('</p>\
      <p style="text-aligh:left">');  ngx.print( content_cui["wirelss_hosts_num"] ); ngx.print('</p>\
      <br>\
      </div>\
      <hr />\
      <br>\
      <br>\
      <div style="text-align:left;position:relative;left:50%;width:285px;margin-left:-140px">\
      <img src="/img/Icon_Telstra-Air_mobile.png" style="width: 75px; height: 75px; display:inline-block;margin-top:-40px">\
      <div style="display:inline-block;width:55%">\
      <p style="font-size:25px">');  ngx.print( T"Telstra Air" ); ngx.print('</p>\
      <div>');  ngx.print( content_icon.fon.icon ); ngx.print('</div><div style="text-align:left;font-size:19px">');  ngx.print( content_icon.fon.display ); ngx.print('</div>\
      </div>\
      </div>\
      <br>\
      <p class="text-left" style="color:#808080;position:relative;left:50%;width:240px;margin-left:-100px">');  ngx.print( T"Telstra Air customers can connect to Australia's largest Wi-Fi network to access unlimited data using your smart phone,mobile device or laptop." .. "<br/>" .. "<br/>" .. T"When you're out and about,Telstra Air automatically connects you to the nearest hotspot in range via the Telstra Air App." ); ngx.print('</p>\
      <hr />\
      </form>\
      <br/><br/>\
    </div>\
  <div>\
    <center>\
      <span id="top_page" style="display: inline-block;vertical-align: middle;padding-top: 5px;">\
        <img src="/img/Icon_Up.png" style="width: 40px; height: 40px">\
        <h2 class="text-center" style="color:#ff6600">');  ngx.print( T"TOP" ); ngx.print('</h2>\
      <span>\
    </div>\
    <div class="container linear-mobile hidden-desktop" id="footer_picture_mobile" style="width:100%;height:10px;">\
  </div>\
</div>\
<!-- END MOBILE-->\
<script>\
$(document).ready(\
  function() {\
    function create_blinking(blink_on, blink_off, timeout)\
    {\
      function blink() {\
        var led_on = $(blink_on)\
        var led_off = $(blink_off)\
        if (led_on.is(":visible")) {\
          led_on.hide();\
          led_off.show();\
        }\
        else {\
          led_off.hide();\
          led_on.show();\
        }\
        setTimeout(blink, timeout);\
      }\
      return blink\
    }\
\
    create_blinking(".blink_fast_on", ".blink_fast_off", 250)()\
\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
    var password = "";\
    var tmppassword = "";\
\
    // Set the focus on the first input field\
    $(\'form:first *:input[type!=hidden]:first\').focus();\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $(".sign-me-in").filter(":visible").click();\
        }\
    });\
\
    $(".sign-me-in").on("click", function () {\
      $(this).text(\'');  ngx.print( T"Verifying" ); ngx.print('\');\
      var login_container = $(this).closest(".container")\
      password = login_container.find(".srp-password").val();\
      username = login_container.find(".srp-username").val();\
      tmppassword = password;\
\
      //to get the legacy_salt & is not null, and confirm the username is adminusername, do migration\
      var legacysalt = "');  ngx.print( cui.legacysalt ); ngx.print('";\
      var aduser = "');  ngx.print( cui.adusrname ); ngx.print('";\
      if (("" != legacysalt) && (aduser == username))\
      {\
          var hashObj = new jsSHA((legacysalt+tch.stringToHex(password)), "HEX");\
          password = hashObj.getHash("SHA-1", "HEX");\
      }\
      var srp = new SRP();\
      srp.success = function() {\
        //when do migration the legacy_salt is null and current user is admin, do the reset pass operation\
        if (("" != legacysalt) && (aduser == username))\
        {\
          srp.generateSaltAndVerifierTheCallback(username, tmppassword, function(salt, verStr) {\
            $.post("/login.lp", { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), salt:salt, verifier:verStr, resetpass:"1" },\
              function reloadPage(){\
                if (window.location.pathname.search(/\\/login\\.lp$/) == -1)\
                  window.location.reload();\
                else\
                  window.location = "/";\
              });\
          });\
        }\
        else\
        {\
          if (window.location.pathname.search(/\\/login\\.lp$/) == -1)\
            window.location.reload();\
          else\
            window.location = "/";\
        }\
      }\
      srp.error_message = function() {\
        $(".sign-me-in").text(\'');  ngx.print( T"Sign in" ); ngx.print('\');\
        login_container.find(".erroruserpass").show();\
        login_container.find(".control-group").addClass("error");\
\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            login_container.find(".defaultpassword").show();\
        }\
      }\
      srp.identify("/authenticate", username, password);\
    });\
\
    $(".more_info").on("click", function() {\
      $(".more_info").hide();\
      $("#login_part").removeClass("visible-desktop").addClass("hide");\
      $("#detailed_info").removeClass("hide").addClass("visible-desktop");\
      $("#footer_picture").removeClass("hide").addClass("visible-desktop");\
\
      $("#icon_down").removeClass("hidden-desktop").addClass("hide");\
      $("#device_pic").removeClass("hide").addClass("hidden-desktop");\
      $("#detailed_list").removeClass("hide").addClass("hidden-desktop");\
      $("#login_part_mobile").removeClass("hidden-desktop").addClass("hide");\
      $("#detailed_info_mobile").removeClass("hidden-desktop").addClass("hide");\
      $("#footer_picture_mobile").removeClass("hide").addClass("hidden-desktop");\
\
      $("#less_info").show();\
    });\
    $("#detailed_list").on("click", function() {\
      $("#detailed_info").removeClass("hide").addClass("visible-desktop");\
      $("#footer_picture").removeClass("hide").addClass("visible-desktop");\
\
      $(this).removeClass("hidden-desktop").addClass("hide");\
      $("#device_pic").removeClass("hidden-desktop").addClass("hide");\
      $("#detailed_list").removeClass("hidden-desktop").addClass("hide");\
      $("#detailed_info_mobile").removeClass("hide").addClass("hidden-desktop");\
      $("#top_page").removeClass("hide").addClass("hidden-desktop");\
      $("#footer_picture_mobile").removeClass("hide").addClass("hidden-desktop");\
    });\
    $("#less_info").on("click", function() {\
      $(this).hide();\
      $("#login_part").removeClass("hide").addClass("visible-desktop");\
      $("#detailed_info").removeClass("visible-desktop").addClass("hide");\
      $("#footer_picture").removeClass("visible-desktop").addClass("hide");\
\
      $("#login_part_mobile").removeClass("hide").addClass("hidden-desktop");\
      $("#detailed_info_mobile").removeClass("hidden-desktop").addClass("hide");\
      $("#icon_down").removeClass("hide").addClass("hidden-desktop");\
      $("#detailed_list").removeClass("hidden-desktop").addClass("hide");\
      $("#device_pic").removeClass("hidden-desktop").addClass("hide");\
      $("#footer_picture_mobile").removeClass("hidden-desktop").addClass("hide");\
\
      $(".more_info").show();\
    });\
    $("#top_page").on("click", function() {\
      $("#detailed_info").removeClass("visible-desktop").addClass("hide");\
      $("#login_part").removeClass("hide").addClass("visible-desktop");\
      $("#footer_picture").removeClass("visible-desktop").addClass("hide");\
\
      $("#login_part_mobile").removeClass("hide").addClass("hidden-desktop");\
      $("#icon_down").removeClass("hide").addClass("hidden-desktop");\
      $("#detailed_info_mobile").removeClass("hidden-desktop").addClass("hide");\
      $("#footer_picture_mobile").removeClass("hidden-desktop").addClass("hide");\
      $(this).removeClass("hidden-desktop").addClass("hide");\
\
      $(".more_info").show();\
    });\
  })\
</script>\
</body>\
</html>\
'); 