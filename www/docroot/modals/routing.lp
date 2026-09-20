--pretranslated: do not change this file
 ngx.print(' ');  
-- Enable localization
gettext.textdomain('webui-core')
local ngx, pairs    = ngx, pairs
local proxy         = require("datamodel")
local contentHelper = require("web.content_helper")
local match = string.match

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


  ngx.print('\
\
<h1><span>');  ngx.print(T"Routing"); ngx.print('</span></h1>\
      <h3><span>');  ngx.print(T"IPv4"); ngx.print('</span></h3>\
<div class="h3-content content-voice-status">\
<div class="table-responsive">\
	  <table class="table wan-table routingv4">\
		<thead><tr>\
				<td><span>');  ngx.print(T"Destination IP"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Destination Subnet Mask"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Metric"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Gateway IP"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Interface"); ngx.print('</span></td>\
			</tr>\
    ');  
      for _,v in pairs(ipv4List) do
      ngx.print('\
     <tr><td>');  ngx.print((v["Destination"] == "0.0.0.0" and "*" or v["Destination"]) ); ngx.print('</td><td>');  ngx.print(v["Mask"]); ngx.print('</td><td>');  ngx.print(v["Metric"]); ngx.print('</td><td>');  ngx.print((v["Gateway"] == "0.0.0.0" and "*" or v["Gateway"])); ngx.print('</td><td>');  ngx.print(v["Iface"]); ngx.print('</td></tr>\
      ');  end  ngx.print('\
	</thead>\
	  </table>\
  </div>\
</div>\
     <h3><span>');  ngx.print(T"IPv6"); ngx.print('</span></h3>\
\
<div class="h3-content content-voice-status">\
<div class="table-responsive">\
  <table class="table wan-table routingv6">\
	  <thead><tr>\
				<td><span>');  ngx.print(T"Destination IP"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Metric"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Gateway IP"); ngx.print('</span></td>\
				<td><span>');  ngx.print(T"Interface"); ngx.print('</span></td>\
			</tr>\
   ');  
      for _,v in pairs(ipv6List) do
      ngx.print('\
\
      <tr><td>');  ngx.print((v["Destination"] == "::/0" and "*" or v["Destination"])); ngx.print('</td><td>');  ngx.print(v["Metric"]); ngx.print('</td><td>');  ngx.print((v["Gateway"] == "::" and "*" or v["Gateway"])); ngx.print('</td><td>');  ngx.print(v["Iface"]); ngx.print('</td></tr>\
       ');  end  ngx.print('\
	</thead>\
	  </table>\
	  </div>\
  </div>\
'); 