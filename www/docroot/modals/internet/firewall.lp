--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx           = ngx
local next          = next
local postHelper    = require("web.post_helper")
local CSRFtoken     = ngx.ctx.session:getCSRFtoken()
local contentHelper = require("web.content_helper")
local proxy = require("datamodel")
local getValInEnum = postHelper.getValidateInEnumSelect
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")

local basePath, validTarget
if vdf_helper.getVariant() == "VF-UK" then
  basePath = contentHelper.getMatchedContent("uci.firewall.rule.", { name = "Allow-Ping"})
  validTarget = {{""}, {"icmp_trusted_network"}}
  if next(basePath) and basePath[1].path then
    basePath = basePath[1].path.."ipset"
  end
else
  basePath = contentHelper.getMatchedContent("uci.firewall.rule.", { name = "Allow-Ping-Vodafone-wan"})
  validTarget = {{"1"}, {"0"}}
  if next(basePath) and basePath[1].path then
    basePath = basePath[1].path.."enabled"
  end
end
local basePathPing6 = contentHelper.getMatchedContent("uci.firewall.rule.", { name = "Allow-Ping6"})
if next(basePathPing6) and basePathPing6[1].path then
  basePathPing6 = basePathPing6[1].path.."target"
end

local paramMap = {
  pingButton  = basePath,
  fireWall    = "rpc.network.firewall.enable",
}

local function validate_SetIPv6(value, postData, key)
  if getValInEnum(validTarget) then
    if value == "1" or value == "" then
     proxy.set(basePathPing6, "ACCEPT")
    else
     proxy.set(basePathPing6, "DROP")
    end
    proxy.apply()
    return true
  end
  return nil
end

local validateMap = {
  pingButton      = validate_SetIPv6,
  fireWall        = postHelper.validateBoolean
}

local pageInfo = vdf_helper.handlePOST(postHelper.handleQuery, {paramMap, validateMap})
local resetfirewall = {
  reset_allow_ping_to_wan_interface = "uci.uci-defaults.firewall.allow_ping_to_wan_interface",
  reset_firewall = "uci.uci-defaults.firewall.firewall"
}
contentHelper.getExactContent(resetfirewall)

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<script src="js/global-min.js"></script>\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-8 col-sm-8">\
    <h1>');  ngx.print(T"Firewall"); ngx.print('</h1>\
  </div>\
</div>\
<h2>');  ngx.print(T"Your router provides extensive firewall functionality which protects against common attacks. Vodafone recommends not to turn off firewall."); ngx.print('\
</h2>\
\
<div class="h3-content fireWall-msg" style="display:none">\
  <div class="message message-info">\
    <span class="font-normal">\
      ');  ngx.print(T"Disabling the firewall will make your network vulnerable to security breaches on the internet. It is highly recommended that the Firewall setting remain ON."); ngx.print('\
    </span>\
  </div>\
</div>\
\
 <form id="firewall_form" class="form-horizontal" method="post" action="modals/internet/firewall.lp">\
    <input type="hidden" name= "pingButton" id= "pingStatus"  value = "');  ngx.print(pageInfo.pingButton); ngx.print('"></input>\
    <input type="hidden" name= "fireWall" id= "firewallStatus" value = "');  ngx.print(pageInfo.fireWall); ngx.print('"></input>\
    <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
    <input type="hidden" name= "action" id="action" value = "SAVE"></input>\
     ');  
      local row = {
          {
              label = T"Allow Ping to WAN interface",
              element = ui_helper.createButton({
                id = "ping-btn-onoff",
                class = ((pageInfo.pingButton == "1") or (pageInfo.pingButton == "")) and "pull-right button button-on ping-btn-onoff" or "pull-right button button-off ping-btn-onoff"
              })
          },
          {
              label = T"Firewall",
              element = ui_helper.createButton({
                id = "firewall-btn-onoff",
                class = (pageInfo.fireWall == "1") and "pull-right button button-on firewall-btn-onoff" or "pull-right button button-off firewall-btn-onoff"
              })
          }
      }
      ngx.print(ui_helper.createTable(row, "", "h3-content-firewall"))
      ngx.print('\
</form>\
</div>\
');  
 lp.include("apply-cancel.lp")
 lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script>\
  var firewallState = "');  ngx.print(pageInfo.fireWall); ngx.print('"\
  var resetAllowPing = "');  ngx.print(resetfirewall["reset_allow_ping_to_wan_interface"]); ngx.print('"\
  var resetFirewall = "');  ngx.print(resetfirewall["reset_firewall"]); ngx.print('"\
</script>\
\
<script src= "js/internet/firewall.js"></script>\
\
'); 