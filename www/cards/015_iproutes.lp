<%
-- Enable localization
gettext.textdomain('webui-core')

local logger = require("transformer.logger")
local log = logger.new("sys.class.routes", 2)

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
modalPath = "/modals/iproutes-modal.lp"
--if session:hasAccess(modalPath) then

--Dynamic Routes
local route_sys_path = "sys.class.iproutes."
local route_sys_content = content_helper.getMatchedContent (route_sys_path)
local dyn_count = 0
for _, v in pairs (route_sys_content) do
   dyn_count = dyn_count +1
end


--Dynamic Routes
local route_uci_path = "uci.network.route."
local route_uci_content = content_helper.getMatchedContent (route_uci_path)
local static_count = 0
--dyn_count = dyn_count - static_count
--DNS

function split(x,sep)
        x = tostring(x)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

--[[
local dns_rpc_path = "rpc.network.interface."
local dns_rpc_content = content_helper.getMatchedContent (dns_rpc_path)
local dns_count = 0

for i, v in pairs (dns_rpc_content) do
   if v["dnsservers"] ~= "" then
      local subcount = split(format("%s",v["dnsservers"]),",")
       
      --ngx.log(ngx.ERR, format("path=%s v=%s subcount=%s",v["path"],v["dnsservers"], #subcount)) 
      dns_count = dns_count +#subcount
   end
end
]]
local dns_count = 0
local content_rpc_dns = {
  wan  = "rpc.network.interface.@wan.dnsservers",
  wan6 = "rpc.network.interface.@wan6.dnsservers",
}
content_helper.getExactContent(content_rpc_dns)
local subcountwan = split(format("%s",content_rpc_dns.wan),",")
local subcountwan6 = split(format("%s",content_rpc_dns.wan6),",")
dns_count = dns_count +#subcountwan +#subcountwan6
%>

<div class="span3">
    <div class="smallcard">
        <%= ui_helper.createCardHeader(T"IP Extras", "modals/iproutes-modal.lp") %>
        <div class="content card_bg" data-bg-text="&#xf124;">
        <div class="divtable">
            <p class="subinfos">
            <%
            local modal_link=format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"iproutes-modal\"",modalPath)
            ngx.print(
            format( N('<strong %1$s>%2$d Route</strong>', 
                      '<strong %1$s>%2$d Routes</strong> ', dyn_count), 
                      modal_link, dyn_count))
            %>
            </p>
            <p class="subinfos">
            <%
            ngx.print(
            format( N('<strong %1$s>%2$d DNS Server</strong>', 
                      '<strong %1$s>%2$d DNS Servers</strong>', dns_count), 
                      modal_link, dns_count))
            %>
            </p>
         </div>
         </div>
    </div>
</div>
<%
--end
%>


