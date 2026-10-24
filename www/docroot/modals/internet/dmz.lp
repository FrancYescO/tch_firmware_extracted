--pretranslated: do not change this file
 

-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local vdf_helper = require("vodafone_helper")
local ui_helper = require("vdf_ui_helper")
local proxy = require("datamodel")
local string, table = string, table
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local untaint = string.untaint
local format = string.format
local getAndValidation = post_helper.getAndValidation
local validateQTN = post_helper.validateQTN
local variant = vdf_helper.getVariant()
local rule_name

local network_details = {
  gateway_ip = "uci.network.interface.@lan.ipaddr",
  netmask    = "uci.network.interface.@lan.netmask",
  public_IP  = "rpc.network.interface.@wan.ipaddr",
  public_lte_IP  = "rpc.network.interface.@wwan.ipaddr",
}
if variant == "VF-UK" then
  network_details.cwmpPort   = "uci.cwmpd.cwmpd_config.connectionrequest_port"
  network_details.sshPort    = "uci.system.wan-service.@dropbear.ports"
  network_details.mmbxPort   = "uci.system.wan-service.@mmpbx_udp.ports"
end
content_helper.getExactContent(network_details)

local public_IP = network_details.public_IP
local public_lte_IP = network_details.public_lte_IP
if variant ~= "VF-UK" and public_IP and public_IP == "" and public_lte_IP and public_lte_IP ~= "" then
  public_IP = public_lte_IP
end

local wanService = proxy.get("uci.system.wan-service.", "uci.cwmpd.cwmpd_config.connectionrequest_port")

local validateDeviceIP  = post_helper.getValidateStringIsDeviceIPv4(network_details.gateway_ip, network_details.netmask)

local function isDupPort(tmpPortsTable, port)
  for _, v in pairs(tmpPortsTable) do
    if v == port then
      return true
    end
  end
  return false
end

--duplicated port cannot be added in the table
local wanServicePorts, wanPorts = {}
for _,v in pairs(wanService) do
  if v.param == "ports" or v.param == "connectionrequest_port" then
    for port in string.gmatch(v.value, "%d+") do
      if not isDupPort(wanServicePorts, untaint(port)) then
        wanServicePorts[#wanServicePorts + 1] = untaint(port)
      end
    end
  end
end

if variant == "VF-UK" then
  wanPorts = format("%s, %s, %s", network_details.sshPort, network_details.cwmpPort, network_details.mmbxPort)
else
  wanPorts = table.concat(wanServicePorts, ", ")
end

local RW_parameters = {
  DMZ_enable              = "rpc.network.firewall.dmz.enable",
  dmz_redirect_enable     = "rpc.network.firewall.dmz.redirect.enabled",
  local_IP                = "rpc.network.firewall.dmz.redirect.dest_ip",
  -- dropbear_port and firewall_ssh_wan_path needs to be set as 2222 if DMZ is enabled
  -- 22 when DMZ is disabled
  dropbear_port           = "uci.dropbear.dropbear.@wan.Port",
}

if variant == "VF-UK" then
  rule_name = "SSH-wan"
else
  rule_name = "Allow-SSH-Vodafone-wan"
end

local firewall_ssh_wan_path = content_helper.getMatchedContent("uci.firewall.rule.", { name = rule_name } )

RW_parameters.firewall_ssh_wan_path = "uci.firewall.rule." .. (firewall_ssh_wan_path[1].path):match("@%S+") .. "dest_port"

local valid_ports = {
  {"22"},
  {"2222"}
}

local validations = {
  DMZ_enable               = post_helper.validateBoolean,
  dmz_redirect_enable      = post_helper.validateBoolean,
  local_IP                 = post_helper.validateDMZ,
  dropbear_port            = post_helper.getValidateInEnumSelect(valid_ports),
  firewall_ssh_wan_path    = post_helper.getValidateInEnumSelect(valid_ports)
}

local content = vdf_helper.handlePOST(post_helper.handleQuery, {RW_parameters, validations})

local resetdmz = {
  reset_dmz_function = "uci.uci-defaults.dmz.dmz_function",
  reset_local_ip_address = "uci.uci-defaults.dmz.local_ip_address"
}
content_helper.getExactContent(resetdmz)

local dropbearPort
if variant == "VF-UK" then
  dropbearPort = proxy.get("uci.dropbear.dropbear.@wan.Port")[1].value
else
  dropbearPort = content.DMZ_enable == "1" and "2222" or "22"
end

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
\
<link rel="stylesheet" type="text/css" href="css/dmz.css" />\
<script src="js/global-min.js"></script>\
  <h1>');  ngx.print(T"DMZ"); ngx.print('</h1>\
</div>\
<h2>');  ngx.print(T"If you have a local client PC that cannot run an Internet application properly from behind the NAT firewall, you can open the client to unrestricted two-way Internet access by defining a Virtual Exposed Host."); ngx.print('\
</h2>\
<form id="dmz-form" class="form-horizontal" method="post" action="/modals/internet/dmz.lp" autocomplete="off">\
  ');  
    local hiddenFields = {
      ui_helper.createHiddenField("CSRFtoken", "CSRFtoken", CSRFtoken),
      ui_helper.createHiddenField("action", "action", "SAVE"),
      ui_helper.createHiddenField("dmz-txt-localIP", "local_IP"),
      ui_helper.createHiddenField("DMZ_enable", "DMZ_enable"),
      ui_helper.createHiddenField("dmz_redirect_enable", "dmz_redirect_enable"),
      ui_helper.createHiddenField("dropbear_port", "dropbear_port", dropbearPort),
      ui_helper.createHiddenField("firewall_ssh_wan_path", "firewall_ssh_wan_path", content.DMZ_enable == "1" and "2222" or "22"),
    }
    ngx.print(table.concat(hiddenFields, "\n"))
    local row = {
      {
        label = T"DMZ Function",
        element = ui_helper.createButton({class = (content.DMZ_enable == "0") and "button button-off pin-enable pull-right" or "button button-on pin-enable pull-right", id = "dmz-btn-enable"}),
        rowClass = "row padding-top-20",
        colLeftClass = "col-xs-6 col-md-6 col-sm-6 dmz-line-height-30",
        colRightClass = "col-xs-6 col-md-6 col-sm-6",
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile dmz-padding-bottom padding-bottom-20"))
    ngx.print('\
\
  <div id="dmz-div-exposedHost" class="exposedHost" ');  if content.DMZ_enable == "0" then  ngx.print('style="display:none"');  end  ngx.print('>\
    <div class="h3-content no-padding-bottom">\
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
    </div>\
    <div class="h3-content mobile-no-table">\
      ');  
        row = {
          label = T"Public IP Address",
          element = ui_helper.createOnlyText({id = "dmz-info-publicIP"}, public_IP),
          rowClass = "row dmz-padding-left-14",
          colLeftClass = "col-xs-12 col-sm-6 col-md-6 padding-top-bottom-20 restart-text-left mobile-padding-bottom-none",
          colRightClass = "col-xs-12 col-md-6 col-sm-6 padding-top-bottom-20 restart-text-right mobile-padding-top-none"
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
      <div class="row dmz-padding-left-14">\
        <div class="col-xs-12 col-md-12 col-sm-12">\
          <hr/>\
        </div>\
      </div>\
      ');  
        row = {
          label = T"Local IP Address",
          element = format([[
            <div class="mobile-border-kill padding-top-bottom-20 mobile-padding-top-none">
              %s
            </div>
          ]], ui_helper.createIPAddressFields("dmz-txt-localIP", "dmz-height-45", content.local_IP)),
        rowClass = "row dmz-padding-left-14 dmz-padding-bottom-50",
        colLeftClass = "col-xs-12 col-sm-6 col-md-6 padding-top-bottom-20 restart-text-left mobile-padding-bottom-10 mobile-padding-top-20",
        colRightClass = "col-xs-12 col-md-6 col-sm-6 restart-text-right"
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
    </div>\
  </div>\
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
    if (!validateNumberRange(0, 255)($(this).val())) {\
      $(this).addClass(\'input-error\');\
    } else {\
      $(this).removeClass(\'input-error\');\
    }\
  });\
\
  var elements = {\
    ipOctet: "#dmz-form .max3:visible"\
  }\
  var validations = {\
    ipOctet: validateNumberRange(0, 255)\
  }\
\
  $("#global-apply, #modal-apply").click(function() {\
    if (!validateElements(elements, validations)) return false;\
    var form = $("#dmz-form");\
    var target = form.attr("action");\
    var localIP = "";\
    $(".max3").each(function() {\
      var thisValue = $(this).val();\
      var octet = thisValue.replace(/^0+(\\d+)/, \'$1\'); // Remove leading zeros\
      if (octet != "") {\
        localIP = localIP + octet + ".";\
      }\
      else {\
        localIP = "";\
      }\
    });\
\
    var dmz_enable = $("#dmz-btn-enable").hasClass("button-on") ? 1 : 0;\
    $("#dmz-txt-localIP").val(localIP.substring(0,localIP.length-1));\
    $("#DMZ_enable").val(dmz_enable);\
    $("#dmz_redirect_enable").val(dmz_enable);\
    if ("');  ngx.print(variant); ngx.print('" == "VF-UK") {\
      $("#dropbear_port").val("');  ngx.print(dropbearPort); ngx.print('");\
    }\
    else {\
      $("#dropbear_port").val(dmz_enable ? "2222" : "22");\
    }\
    $("#firewall_ssh_wan_path").val(dmz_enable ? "2222" : "22");\
    var params = form.serializeArray();\
    postHandler(target, params);\
  })\
\
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