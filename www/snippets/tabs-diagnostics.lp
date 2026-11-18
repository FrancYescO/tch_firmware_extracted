--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs, string = ipairs, string
local format = string.format
local lfs = require("lfs")
local proxy = require("datamodel")
local checkgpon = require("checkgponboard_helper")
local is_gpon = checkgpon.isGPONBoard()
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local session = ngx.ctx.session
local role = session:getrole()
local items = {
  {"diagnostics-connection-modal.lp", T"Connection"}
}

if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  items[#items + 1] = {"diagnostics-xdsl-modal.lp", T"xDSL"}
end

items[#items + 1] = {"diagnostics-ping-modal.lp", T"Ping & Traceroute"}
items[#items + 1] = {"diagnostics-network-modal.lp", T"Network"}

if post_helper.isFeatureEnabled("diagnosticsIgmpProxy", role) then
  items[#items + 1] = {"diagnostics-igmpproxy-modal.lp", T"Igmpproxy"}
end
if post_helper.isFeatureEnabled("diagnosticsGraphingAndTcp", role) then
  items[#items + 1] = {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
  items[#items + 1] = {"diagnostics-graphs-modal.lp", T"Graphing"}
end
if post_helper.isFeatureEnabled("diagnosticsTcp", role) then
  if role == "engineer" then
    items[#items + 1] = {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
  end
end

if is_gpon then
  items = {
    {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
    {"diagnostics-connection-modal.lp", T"Connection"},
    {"diagnostics-network-modal.lp", T"Network"},
    {"diagnostics-tcpdump-modal.lp", T"Tcpdump"},
    {"diagnostics-graphs-modal.lp", T"Graphing"}
  }
end

local xdsl_exist = true

if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  local eth4_data = {
    eth4_status = "sys.eth.port.@eth4.status",
    eth4_operstate = "sys.class.net.@eth4.operstate",
    intf_name = format("uci.network.interface.@%s.ifname", wanIntf)
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

for _, itemsValue in pairs(items) do
  if post_helper.isFeatureEnabled("diagnosticsIgmpProxy", role) then
    local xdsl_data = {
      dsl_status = "sys.class.xdsl.@line0.Status"
    }
    local xdsl_data_one = {
      dsl_status = "sys.class.xdsl.@line1.Status"
    }
    content_helper.getExactContent(xdsl_data)
    if session:hasAccess("/modals/" .. itemsValue[1]) and (itemsValue[1] ~= "diagnostics-xdsl-modal.lp" or xdsl_data["dsl_status"] == "Up" or xdsl_data_one["dsl_status"] == "Up") then
      tabs[#tabs+1] = itemsValue
    end
  elseif session:hasAccess("/modals/" .. itemsValue[1]) and (itemsValue[1] ~= "diagnostics-xdsl-modal.lp" or xdsl_exist) then      
      tabs[#tabs+1] = itemsValue                                                                         
  end
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

local html = {}

for _, v in ipairs(tabs) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end
    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

  ngx.print('\
</ul>\
'); 