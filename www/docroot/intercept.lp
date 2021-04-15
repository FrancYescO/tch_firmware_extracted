--pretranslated: do not change this file
 
local tinsert = table.insert

gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Intercept", "intercept")
local cui = {}
local format = string.format
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()

if post_helper.isFeatureEnabled("interceptPage", role) then
  function get_intercept_reasons()
    local intercept_reasons_results = content_helper.convertResultToObject("rpc.intercept.reason.", proxy.get("rpc.intercept.reason."))
    local reasons = {}
    if intercept_reasons_results then
      for _, reason in ipairs(intercept_reasons_results) do
        if reason.reason then
          reasons[string.untaint(reason.reason)] = true
        end
      end
    end
    return reasons
  end

  function bytes_to_data_volume(val)
    local data_volume_map = {
      {
        value = 1024*1024*1024,
        unit = T"GB"
      },
      {
        value = 1024*1024,
        unit = T"MB"
      },
      {
        value = 1024,
        unit = T"KB"
      }
    }
    for _, data_volume in ipairs(data_volume_map) do
      if val > data_volume.value then
        val = val / data_volume.value
        return format("%.0f %s", val, data_volume.unit)
      end
    end
    return format("%.0f %s", val, T"B")
  end

  function get_datausage_volume(condition)
    local datausage_interfaces_results = content_helper.convertResultToObject("rpc.datausage.interface.", proxy.get("rpc.datausage.interface."))
    local interface_data = {}
    if datausage_interfaces_results then
      for key, interface in ipairs(datausage_interfaces_results) do
        if interface[condition] == 'true' then
          local tx_bytes = tonumber(interface.tx_bytes_total)
          local rx_bytes = tonumber(interface.rx_bytes_total)
          if tx_bytes and rx_bytes then
            tinsert(interface_data, { interface = string.gsub(interface.paramindex, '@', ''), data_volume = bytes_to_data_volume(tx_bytes + rx_bytes) })
          end
        end
      end
    end
    return interface_data
  end

  function get_page_content()
    local html = {}
    local reasons = get_intercept_reasons()
    if reasons['wan_down'] then
      local server_addr = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
      local req_uri = ngx.var.http_host .. ngx.unescape_uri(ngx.var.request_uri)

      tinsert(html, [[<center>
        You have been intercepted for the following destination:<br>
      <i>]])
      tinsert(html, req_uri)
      tinsert(html, [[</i>
        <div>
        <p><b>WAN connection is unavailable.</b><br>
        Please check internet access settings, close your browser and try again.</p>
        <div>
        <p><a href="http://]])
      tinsert(html, server_addr)
      tinsert(html, [[">Click here to access Gateway web interface</a></p>
        </center>]])
    elseif reasons['datausage_limit_reached'] then
      tinsert(html, '<div>')
      tinsert(html, '<form class="form-horizontal" method="post" action="/">')
      for _, interface in ipairs(get_datausage_volume('usage_limit_reached')) do
        tinsert(html, ui_helper.createAlertBlock(format(T"You have reached the limit of your configured data volume on %s", interface.interface)))
      end
      tinsert(html, '<div id="ignore_datausage_limit" class="btn pull-right"><i class="icon-ok-sign"></i> ' .. T"Continue" .. '</div></form></div>')
      tinsert(html, '<center style="color: #3a87ad; clear: both;">'.. T"* You may be charged extra by your network operator after clicking continue" ..'</center>')
    elseif reasons['datausage_threshold_reached'] then
      tinsert(html, '<form class="form-horizontal" method="post" action="/">')
      for _, interface in ipairs(get_datausage_volume('usage_threshold_reached')) do
        tinsert(html, ui_helper.createAlertBlock(format(T"You have consumed %s of your total data volume on %s", interface.data_volume, interface.interface)))
      end
      tinsert(html, '<div id="ignore_datausage_threshold" class="btn pull-right"><i class="icon-ok-sign"></i> ' .. T"Continue" .. '</div></form>')
    else
      tinsert(html, ui_helper.createAlertBlock(T"You have been intercepted for an unknown reason"))
    end
    return html
  end

  if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]
    if action == "ignore_datausage_limit" then
      proxy.set("rpc.datausage_notifier.event", "ignore_limit")
    elseif action == "ignore_datausage_threshold" then
      proxy.set("rpc.datausage_notifier.event", "ignore_threshold")
    end
    ngx.exit(ngx.HTTP_OK)
  end

  cui = {
    timestamp = "uci.version.version.@version[0].timestamp",
    datausage_interface = "uci.datausage_notifier.interface"
  }
  content_helper.getExactContent(cui)

  local current_year = (string.sub(cui.timestamp, 1, 4))
else
  cui = {
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
    logo_class = format('class="%s"',logo_class)
  else
    logo_class = ""
  end

  local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"

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
end
  ngx.print('\
\
<!DOCTYPE HTML>\
<html>\
');  ngx.print( format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    ');  if post_helper.isFeatureEnabled("interceptPage", role) then   ngx.print('\
      <link href="/css/gw.css" rel="stylesheet">\
    ');  else   ngx.print('\
      <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
      <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
      <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    ');  end   ngx.print('\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <script src="/js/jquery-eval-patch.js"></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    ');  if post_helper.isFeatureEnabled("interceptPage", role) then   ngx.print('\
      <title>');  ngx.print( T"Datausage warning" ); ngx.print('</title>\
    </head>\
\
    <body>\
      </div>\
      <div class="container">\
        <div class="row">\
          <div class="header span12">\
             ');  if post_helper.getVariantValue(variantHelper, "logo") then   ngx.print('\
               <img src="/img/logo.gif">\
             ');  else   ngx.print('\
               <img class="logo" src="/img/logo.png">\
             ');  end   ngx.print('\
          </div>\
        </div>\
        ');  ngx.print( get_page_content() ); ngx.print('\
        <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
      </div>\
    </body>\
    <script>\
      $(document).ready(function() {\
        $("#ignore_datausage_limit, #ignore_datausage_threshold").click(function() {\
          var params = [{ name: "action", value: $(this).attr(\'id\')}];\
          $.post("", params, function(data) {\
            setTimeout(function() {\
              location.reload();\
            }, 1000);\
          });\
        });\
      });\
    </script>\
  </html>\
\
  ');  
    ngx.exit(ngx.HTTP_OK)
    ngx.print('\
');  else   ngx.print('\
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
                      wanip = format("rpc.network.interface.@%s.ipaddr", wanIntf),
                      wwanip = "rpc.network.interface.@wwan.ipaddr"
                  }
                  content_helper.getExactContent(content)

                  -- in case wan6 is not configured in uci, protection is needed
                  local content_wan6 = {
                      ipaddr = format("rpc.network.interface.@%s.ipaddr", wan6Intf),
                  }
                  content_helper.getExactContent(content_wan6)

                  local msg_key = "OK"
                  if content.wanip:len() == 0 and content_wan6.ipaddr:len() == 0 and content.wwanip:len() == 0 then
                      local content_type = {
                          wan_ifname = format("uci.network.interface.@%s.ifname", wanIntf),
                          wan_proto = format("uci.network.interface.@%s.proto", wanIntf),
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

                      msg_key = format("E_%s_%s", L3, L2)
                  end

                  local item = items[msg_key]

                  html[#html+1] = format('%s', item[2])
                  ngx.print(html)

                ngx.print('\
          </div>\
        </div>\
      </div>\
      <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
    </div>\
  </body>\
  </html>\
');  end   ngx.print('\
'); 