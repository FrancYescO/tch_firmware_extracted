--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')
local content_helper = require("web.content_helper")
local ipairs, string, table = ipairs, string, table
local lfs = require("lfs")
local proxy = require("datamodel")
local checkgpon = require("checkgponboard_helper")
local is_gpon = checkgpon.isGPONBoard()
local items = {
    {"diagnostics-xdsl-modal.lp", T"xDSL"},
    {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
    {"diagnostics-connection-modal.lp", T"Connection"},
    {"diagnostics-network-modal.lp", T"Network"},
    {"diagnostics-igmpproxy-modal.lp", T"Igmpproxy"},
    {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
}
if is_gpon then
  items = {
      {"diagnostics-gpon-modal.lp", T"GPON"},
      {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
      {"diagnostics-connection-modal.lp", T"Connection"},
      {"diagnostics-network-modal.lp", T"Network"},
      {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
  }
end

local xdsl_exist = true

if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  local eth4_data = {
    eth4_status = "sys.eth.port.@eth4.status",
    eth4_operstate = "sys.class.net.@eth4.operstate",
    intf_name = "uci.network.interface.@wan.ifname"
  }
  content_helper.getExactContent(eth4_data)
  local eth4Intf = string.match(eth4_data["intf_name"], "eth4") or ""
  if eth4Intf == "" then
    local dev_name = "uci.network.device.@"..eth4_data["intf_name"]..".ifname"
    eth4Intf = proxy.get(dev_name) and proxy.get(dev_name)[1] and proxy.get(dev_name)[1].value or ""
  end
  if eth4_data["eth4_status"] == "up" and eth4_data["eth4_operstate"] == "up" and eth4Intf == "eth4" then
    xdsl_exist = false
  end
end

local tabs = {}
local session = ngx.ctx.session

for _,v in pairs(items) do
    if session:hasAccess("/modals/" .. v[1])  and (v[1] ~= "diagnostics-xdsl-modal.lp"  or  xdsl_exist ) then
       tabs[#tabs+1] = v
    end
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(tabs) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 