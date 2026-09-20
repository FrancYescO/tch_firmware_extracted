--pretranslated: do not change this file
 

-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local untaint = string.untaint
local format = string.format

local network_details = {
  gateway_ip = "uci.network.interface.@lan.ipaddr",
  netmask    = "uci.network.interface.@lan.netmask",
  public_IP  = "rpc.network.interface.@wan.ipaddr",
}
content_helper.getExactContent(network_details)

local wanService = proxy.get("uci.system.wan-service.")
local validateDeviceIP  = post_helper.getValidateStringIsDeviceIPv4(network_details.gateway_ip, network_details.netmask)
local wanServicePorts = {}

for _,v in pairs(wanService) do
  if v.param == "ports" then
    wanServicePorts[#wanServicePorts + 1] = untaint(v.value)
  end
end
local wanPorts = table.concat(wanServicePorts, ",")
local RW_parameters = {
  dmz_enable              = "rpc.network.firewall.dmz.enable",
  dmz_redirect_enable     = "rpc.network.firewall.dmz.redirect.enabled",
  local_IP                = "rpc.network.firewall.dmz.redirect.dest_ip",
  -- dropbear_port and firewall_ssh_wan_path needs to be set as 2222 if DMZ is enabled
  -- 22 when DMZ is disabled
  dropbear_port           = "uci.dropbear.dropbear.@wan.Port",
}

local firewall_ssh_wan_path = content_helper.getMatchedContent("uci.firewall.rule.", { name = "Allow-SSH-Vodafone-wan"} )

RW_parameters.firewall_ssh_wan_path = "uci.firewall.rule." .. (firewall_ssh_wan_path[1].path):match("%d+") .. ".dest_port"

local valid_ports = {
  {"22"},
  {"2222"}
}

local validations = {
  dmz_enable               = post_helper.validateBoolean,
  dmz_redirect_enable      = post_helper.validateBoolean,
  local_IP                 = post_helper.getValidationIfPropInList(validateDeviceIP, "dmz_enable", {"1"}),
  dropbear_port            = post_helper.getValidateInEnumSelect(valid_ports),
  firewall_ssh_wan_path    = post_helper.getValidateInEnumSelect(valid_ports)
}

local content, error_msg = post_helper.handleQuery(RW_parameters, validations)
local resetdmz = {
  reset_dmz_function = "uci.uci-defaults.dmz.dmz_function",
  reset_local_ip_address = "uci.uci-defaults.dmz.local_ip_address"
}
content_helper.getExactContent(resetdmz)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  ngx.header.content_type = "application/json"
  if not next(error_msg) then   ngx.print('\
  <input type="hidden" id="post_status" value="success">\
  ');  else  ngx.print('\
  <input type="hidden" id="post_status" value="error">\
  ');  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
\
<link rel="stylesheet" type="text/css" href="css/dmz.css" />\
<script src="js/global.js"></script>\
  <h1>');  ngx.print(T"DMZ"); ngx.print('</h1>\
</div>\
<h2>');  ngx.print(T"If you have a local client PC that cannot run an Internet application properly from behind the NAT firewall, you can open the client to unrestricted two-way Internet access by defining a Virtual Exposed Host."); ngx.print('\
</h2>\
<form id="dmz-form" class="form-horizontal" method="post" action="/modals/dmz.lp" autocomplete="off">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name= "action" id= "action" value = "SAVE"></input>\
  <div class="h3-content h3-content-mobile dmz-padding-bottom">\
    <div class="row padding-top-20 padding-top-bottom-20">\
      <div class="col-xs-6 col-md-6 col-sm-6 dmz-line-height-30">\
        <span>');  ngx.print(T"DMZ Function"); ngx.print('\
        </span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6">\
        <div class="button pin-enable pull-right ');  if content.dmz_enable == "0" then  ngx.print('button-off');  else  ngx.print('button-on');  end  ngx.print('" id="dmz-btn-enable">\
           <input type="hidden" name="dmz_enable" id="dmz_enable" value="">\
           <input type="hidden" name="dmz_redirect_enable" id="dmz_redirect_enable" value="">\
           <input type="hidden" name="dropbear_port" id="dropbear_port" value="');  ngx.print( content.dmz_enable == "1" and "2222" or "22" ); ngx.print('">\
           <input type="hidden" name="firewall_ssh_wan_path" id="firewall_ssh_wan_path" value="');  ngx.print( content.dmz_enable == "1" and "2222" or "22" ); ngx.print('">\
        </div>\
      </div>\
    </div>\
\
    <div id="dmz-div-exposedHost" class="exposedHost" ');  if content.dmz_enable == "0" then  ngx.print('style="display:none"');  end  ngx.print('>\
\
      <div class="row padding-top-bottom-20 dmz-padding-left-14">\
        <div class="col-md-12 col-xs-12 col-sm-12">\
          <div class="message message-info font-bold line-height-24">\
            ');  ngx.print(format(T"Warning: By using the exposed host function you bypass the firewall of your router. Please make sure that your computer is protected against attacks from internet. The following ports will not be forwarded: %s.", wanPorts)); ngx.print('\
          </div>\
        </div>\
      </div>\
\
      <div class="row dmz-padding-left-14">\
        <div class="col-xs-12 col-md-12 col-sm-12 ">\
          <hr/>\
        </div>\
      </div>\
\
      <div class="row dmz-padding-left-14">\
        <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 line-height-24">\
          <p>');  ngx.print(T"One PC can be exposed to the Internet for two-way communications e.g. Internet gaming, video conferencing, or VPN connections. To use the Exposed Host, you must set a static IP address for that PC."); ngx.print('\
          </p>\
        </div>\
      </div>\
\
      <div class="row dmz-padding-left-14">\
        <div class="col-xs-12 col-sm-6 col-md-6 padding-top-bottom-20 restart-text-left mobile-padding-bottom-none">\
          <span>');  ngx.print(T"Public IP Address"); ngx.print('\
          </span>\
        </div>\
        <div class="col-xs-12 col-md-6 col-sm-6 padding-top-bottom-20 restart-text-right mobile-padding-top-none">\
          <span id="dmz-info-publicIP">');  ngx.print(network_details.public_IP); ngx.print('\
        </span>\
      </div>\
      </div>\
\
      <div class="row dmz-padding-left-14">\
        <div class="col-xs-12 col-md-12 col-sm-12">\
          <hr/>\
        </div>\
      </div>\
\
      <div class="row dmz-padding-left-14 dmz-padding-bottom-50">\
        <div class="col-xs-12 col-sm-6 col-md-6 padding-top-bottom-20 restart-text-left mobile-padding-bottom-10 mobile-padding-top-20">\
          <span>');  ngx.print(T"Local IP Address"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-6 col-sm-6 restart-text-right">\
          <div class="mobile-border-kill padding-top-bottom-20 mobile-padding-top-none">\
            <input class="max3 dmz-height-45" type="number" min="0" max="255" step="1" maxlength="3" id="dmz-txt-localIP1"><span>.</span><input class="max3 dmz-height-45" type="number" min="0" max="255" step="1" maxlength="3" id="dmz-txt-localIP2"><span>.</span><input class="max3 dmz-height-45" type="number" min="0" max="255" step="1" maxlength="3" id="dmz-txt-localIP3"><span>.</span><input class="max3 dmz-height-45" type="number" min="0" max="255" step="1" maxlength="3" id="dmz-txt-localIP4"></div>\
           <input type="hidden" name="local_IP" id="dmz-txt-localIP" value="">\
        </div>\
      </div>\
    </div>\
\
  </div>\
\
  ');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
</form>\
\
<script>\
\
function assignIP(id_str,ip_addr) {\
  if (!ip_addr) return;\
  var splitIP = ip_addr.split(".");\
  for(var i=1;i<=4;i++) {\
    document.getElementById(id_str+i).value = splitIP[i-1];\
  }\
}\
\
$(function() {\
\
  assignIP("dmz-txt-localIP","');  ngx.print(content.local_IP); ngx.print('");\
\
  $("#dmz-btn-enable").click(function () {\
    $("#dmz-btn-enable").hasClass("button-on") ? $(".exposedHost").slideDown("fast") : $(".exposedHost").slideUp("fast");\
  });\
\
  $("#dmz-form .max3").blur(function() {\
    if (!validateNumberRange(0, 255)($(this).val())) $(this).addClass(\'input-error\');\
    else $(this).removeClass(\'input-error\');\
  });\
\
  var elements = {\
    ipOctet: "#dmz-form .max3:visible"\
  }\
  var validations = {\
    ipOctet: validateNumberRange(0, 255)\
  }\
\
  $("#global-apply").click(function() {\
    if(!validateElements(elements, validations)) return false;\
    var form = $("#dmz-form");\
    var target = form.attr("action");\
    var localIP = ""\
    $(".max3").each(function() {\
      var thisValue = $(this).val();\
      var octet = thisValue.replace(/^0+(\\d+)/, \'$1\'); // Remove leading zeros\
      localIP = localIP + octet + ".";\
    });\
\
    var dmz_enable = $("#dmz-btn-enable").hasClass("button-on") ? 1 : 0;\
    $("#dmz-txt-localIP").val(localIP.substring(0,localIP.length-1));\
    $("#dmz_enable").val(dmz_enable);\
    $("#dmz_redirect_enable").val(dmz_enable);\
    $("#dropbear_port").val(dmz_enable ? "2222" : "22");\
    $("#firewall_ssh_wan_path").val(dmz_enable ? "2222" : "22");\
    var params = form.serializeArray();\
    postHandler(target, params);\
  })\
\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/dmz.lp");\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  $("#dmz-btn-enable").val("');  ngx.print(resetdmz["reset_dmz_function"]); ngx.print('");\
  if ("');  ngx.print(resetdmz["reset_dmz_function"]); ngx.print('" == "1") {\
    $(\'#dmz-btn-enable\').addClass(\'button-on\').removeClass(\'button-off\');\
    $(\'#dmz-div-exposedHost\').show();\
  }\
  else\
  {\
    $(\'#dmz-btn-enable\').addClass(\'button-off\').removeClass(\'button-on\');\
    $(\'#dmz-div-exposedHost\').hide();\
  }\
  var resetIP = "');  ngx.print(resetdmz.reset_local_ip_address); ngx.print('";\
  assignIP("dmz-txt-localIP", resetIP || "...");\
});\
\
</script>\
'); 