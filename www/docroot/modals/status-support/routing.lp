--pretranslated: do not change this file
 ngx.print(' ');  
-- Enable localization
gettext.textdomain('webui-core')
local ngx, pairs    = ngx, pairs
local proxy         = require("datamodel")
local contentHelper = require("web.content_helper")
local match = string.match
local ui_helper = require("vdf_ui_helper")

local ipv4List   = proxy.get("sys.class.iproutes.")
ipv4List         = contentHelper.convertResultToObject("sys.class.iproutes.", ipv4List)
 table.sort(ipv4List, function(a,b)
  return tonumber(match(a.paramindex, "%d+")) < tonumber(match(b.paramindex, "%d+"))
end)

local ipv6List   = proxy.get("sys.class.ip6routes.")
ipv6List         = contentHelper.convertResultToObject("sys.class.ip6routes.", ipv6List)
 table.sort(ipv6List, function(a,b)
  return tonumber(match(a.paramindex, "%d+")) < tonumber(match(b.paramindex, "%d+"))
end)

local data_Ipv4 = {}
for _,v in pairs(ipv4List) do
  data_Ipv4[#data_Ipv4 + 1] = {
    v.Destination == "0.0.0.0" and "*" or v.Destination,
    v.Mask,
    v.Metric,
    v.Gateway == "0.0.0.0" and "*" or v.Gateway,
    v.Iface
  }
end
local data_Ipv6 = {}
for _,v in pairs(ipv6List) do
  data_Ipv6[#data_Ipv6 + 1] = {
    v.Destination == "::/0" and "*" or v.Destination,
    v.Metric,
    v.Gateway == "::" and "*" or v.Gateway,
    v.Iface
  }
end
  ngx.print('\
\
<h1><span>');  ngx.print(T"Routing"); ngx.print('</span></h1>\
<h3><span>');  ngx.print(T"IPv4"); ngx.print('</span></h3>\
');  
local columns_Ipv4 = {"Destination IP", "Destination Subnet Mask", "Metric", "Gateway IP", "Interface"}
local classInfo_Ipv4 = {
  outerDivClass = "h3-content content-voice-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table wan-table routingv4",
  tableId = "",
}
ngx.print(ui_helper.createTrTable(classInfo_Ipv4, columns_Ipv4, data_Ipv4))
  ngx.print('\
\
<h3><span>');  ngx.print(T"IPv6"); ngx.print('</span></h3>\
');  
local columns_Ipv6 = {"Destination IP", "Metric", "Gateway IP", "Interface"}
local classInfo_Ipv6 = {
  outerDivClass = "h3-content content-voice-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table wan-table routingv6",
  tableId = "",
}
ngx.print(ui_helper.createTrTable(classInfo_Ipv6, columns_Ipv6, data_Ipv6))
  ngx.print('\
\
'); 