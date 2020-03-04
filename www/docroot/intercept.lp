--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)

local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local logo_class = cui["nsplogo"]:match("(.+)%.")
if logo_class then
    logo_class = string.format('class="%s"',logo_class)
else
    logo_class = ""
end

local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"
stylesheet = stylesheet .."?".. cui.timestamp

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.do_signout then
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css?');  ngx.print(cui.timestamp); ngx.print('" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?');  ngx.print(cui.timestamp); ngx.print('"><![endif]-->\
    <script src="/js/main-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js?');  ngx.print(cui.timestamp); ngx.print('"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway HTTP Intercept" ); ngx.print('</title>\
  </head>\
\
<body>\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="');  ngx.print('/img/' .. cui.nsplogo ); ngx.print('" ');  ngx.print(logo_class ); ngx.print(' ></a>\
      </div>\
    </div>\
    <div class="row">\
      <div class="body span12">\
        <div style="font-size: 20px;line-height: normal;padding:30px 10px 30px 10px;margin-bottom:30px;background-color:white;border:1px solid white;-webkit-border-radius:8px;-moz-border-radius:8px;border-radius:8px;box-shadow:rgba(0, 0, 0, 0.25) 0px 2px 5px 0px;">\
            ');  

                local content_helper = require("web.content_helper")

                local ipairs, string = ipairs, string
                local items = {
                    ["OK"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Do connection check in 'Diagnostics' card <a href=/gateway.lp> here </a>.<br>&nbsp;&nbsp;&nbsp;&nbsp;2. Restart my gateway."},
                    -- error msg for no previous connection method
                    ["E_NO_PRE"] = {"error", T"You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone or Ethernet cable is firmly connected to the correct port on your Gateway, the Filter on the Telephone socket or the Ethernet socket in the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/gateway.lp> here </a> .<br>&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway.",},
                    -- error msg if PPPoEoDSL was previously connected
                    ["E_PPP_DSL"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone cable is firmly connected to the correct port on your Gateway or the Filter on the Telephone socket in the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/gateway.lp> here </a> . <br>&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway.",},
                    -- error msg if PPPoEoEWAN was previously connected
                    ["E_PPP_ETH"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Ethernet cable is firmly connected to the correct port on your Gateway or the Ethernet socket in the wall.<br>&nbsp;&nbsp;&nbsp;&nbsp;2. Check that your username is correct and re-enter your password <a href=/gateway.lp> here </a> . <br>&nbsp;&nbsp;&nbsp;&nbsp;3. Restart my gateway.",},
                    -- error msg if IPoEoDSL was previously connected
                    ["E_IPoE_DSL"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Telephone cable is firmly connected to the correct port on your Gateway or the Filter on the Telephone socket in the wall. <br>&nbsp;&nbsp;&nbsp;&nbsp;2. Restart my gateway.",},
                    -- error msg if IPoEoEWAN was previously connected
                    ["E_IPoE_ETH"] = {"error", T"Your Internet connection is currently down. You can try the following: <br>&nbsp;&nbsp;&nbsp;&nbsp;1. Check that your Ethernet cable is firmly connected to the correct port on your Gateway or the Ethernet socket in the wall. <br>&nbsp;&nbsp;&nbsp;&nbsp;2. Restart my gateway.",},
                }
                local html = {}

                local content = {
                    wanip = "rpc.network.interface.@wan.ipaddr",
                    wwanip = "rpc.network.interface.@wwan.ipaddr",
                }
                content_helper.getExactContent(content)

                -- in case wan6 is not configured in uci, protection is needed
                local content_wan6 = {
                    ipaddr = "rpc.network.interface.@wan6.ipaddr",
                }
                content_helper.getExactContent(content_wan6)

                local msg_key = "OK"
                if content.wanip:len() == 0 and content_wan6.ipaddr:len() == 0 and content.wwanip:len() == 0 then
                    local content_type = {
                        wan_ifname = "uci.network.interface.@wan.ifname",
                        wan_proto = "uci.network.interface.@wan.proto",
                        vlan_ppp_ifname = "uci.network.device.@vlan_ppp.ifname",
                        vlan_hfc_ifname = "uci.network.device.@vlan_hfc.ifname",
                        wans_enable = "uci.wansensing.global.enable",
                        l2 = "uci.wansensing.global.l2type",
                        l3 = "uci.wansensing.global.l3type",
                    }
                    content_helper.getExactContent(content_type)

                    local L3, L2 = "NO", "PRE"
                    if content_type.wans_enable == "1" then
                        if content_type.l2 == "ADSL" or content_type.l2 == "VDSL" then
                            L2 = "DSL"
                        elseif content_type.l2 == "ETH" then
                            L2 = "ETH"
                        end
                        if content_type.l3 == "L3PPP" or content_type.l3 == "L3PPPV" or content_type.l3 == "L3PPPSense" or content_type.l3 == "L3PPPVSense" then
                            L3 = "PPP"
                        elseif content_type.l3 == "L3DHCP" or content_type.l3 == "L3DHCPSense" then
                            L3 = "IPoE"
                        end
                    else
                        if content_type.wan_ifname == "atm_ppp" or content_type.wan_ifname == "atm_ipoe" or content_type.wan_ifname == "ptm0" or
                         (content_type.wan_ifname == "vlan_ppp" and content_type.vlan_ppp_ifname == "ptm0") or
                         (content_type.wan_ifname == "vlan_hfc" and content_type.vlan_hfc_ifname == "ptm0") then
                            L2 = "DSL"
                        elseif content_type.wan_ifname == "eth4" or (content_type.wan_ifname == "vlan_hfc" and content_type.vlan_hfc_ifname == "eth4") then
                            L2 = "ETH"
                        end
                        if content_type.wan_proto == "pppoe" or content_type.wan_proto == "pppoa" then
                            L3 = "PPP"
                        elseif content_type.wan_proto == "dhcp" or content_type.wan_proto == "static" then
                            L3 = "IPoE"
                        end
                    end

                    msg_key = string.format("E_%s_%s", L3, L2)
                end

                local item = items[msg_key]

                html[#html+1] = string.format('%s', item[2])
                ngx.print(html)

              ngx.print('\
        </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
</body>\
</html>\
'); 