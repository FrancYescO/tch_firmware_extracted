--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local io = io
local ngx = ngx
local pairs = pairs
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local filePath, content
local connContent = {
  activeConnections = "sys.conn.ActiveConnections"
}
content_helper.getExactContent(connContent)
local connectedHosts =  content_helper.convertResultToObject("sys.conn.host.", proxy.get("sys.conn.host."))
local downloadNat, removeTemp = {}, {}

if ngx.req.get_method() == "POST" then
  if ngx.req.get_post_args().action == "downloadipv4nat" then
    downloadNat = {["sys.conn.DownloadIPv4NatTable"] = "1"}
    filePath = "/tmp/ipv4Session.csv"
    content = "attachment; filename=ipv4Session.csv"
    removeTemp  = {["sys.conn.DownloadIPv4NatTable"] = "0"}
  elseif ngx.req.get_post_args().action == "downloadipv6nat" then
    downloadNat = {["sys.conn.DownloadIPv6NatTable"] = "1"}
    filePath = "/tmp/ipv6Session.csv"
    content = "attachment; filename=ipv6Session.csv"
    removeTemp = {["sys.conn.DownloadIPv6NatTable"] = "0"}
  else
    ngx.exit(ngx.HTTP_OK)
  end
  proxy.set(downloadNat)
  ngx.header.content_disposition = content
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local file = io.open(filePath)
  if file then
    ngx.print(file:read("*all"))
    file:close()
  else
    ngx.print(T"Error reading the file")
  end
  proxy.set(removeTemp)
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end
  ngx.print('\
<div id = "nat-mapping">\
<h1>');  ngx.print(T"NAT Mapping Table"); ngx.print('</h1>\
<h2>');  ngx.print(T"The NAT Mapping Table displays the current NAT address mappings."); ngx.print('</h2>\
<div class="h3-content nat-mapping-padding-bottom-50">\
    <div class="row">\
        <div class="col-xs-9 col-md-10 col-sm-10 col-lg-10 padding-top-bottom-20">\
            <span>');  ngx.print(T"Active Connections"); ngx.print('</span>\
        </div>\
        <div class="col-xs-3 col-md-2 col-sm-2 col-lg-2 text-right padding-top-bottom-20">\
            <span id = "natmapping_info_conn">');  ngx.print(connContent["activeConnections"]); ngx.print('</span>\
        </div>\
    </div>\
</div>\
<h3>');  ngx.print(T"Connections Per Host"); ngx.print('</h3>\
<div class="h3-content content-nat-mapping nat-mapping-padding-bottom-50">\
    <div class="table-responsive">\
        <table class="table wan-table lan-table">\
            <tbody>\
                <tr>\
                    <td> </td>\
                    <td><span>');  ngx.print(T"Host Name"); ngx.print('</span>\
                    </td>\
                    <td><span>');  ngx.print(T"IP Address"); ngx.print('</span>\
                    </td>\
                    <td><span>');  ngx.print(T"Number of Connections"); ngx.print('</span>\
                    </td>\
                </tr>\
                ');  local index = 0
                for i,v in pairs(connectedHosts) do  ngx.print('\
                  ');  if (v["IPAddress"] ~= "") then
                    index = index + 1   ngx.print('\
                    <tr>\
                      <td>');  ngx.print(index); ngx.print('</td>\
                      <td>');  ngx.print(v["HostName"]); ngx.print('</td>\
                      <td>');  ngx.print(v["IPAddress"]); ngx.print('</td>\
                      <td>');  ngx.print(v["NumberOfConnections"]); ngx.print('</td>\
                    </tr>\
                 ');  end  ngx.print('\
                ');  end  ngx.print('\
            </tbody>\
        </table>\
    </div>\
</div>\
   <div class="h3-content vdf-table nat-mapping-padding-bottom-50">\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
            <span>');  ngx.print(T"Download the complete NAT address mapping table in CSV format"); ngx.print('</span>\
        </div>\
        <div class="right text-right mobile-margin-top">\
       ');  if connContent["activeConnections"] ~= "" then   ngx.print('\
			   <input class="button button-cancel mob-button-width" id = "natmapping-btn-dwnloadhost" value=');  ngx.print(T"Download"); ngx.print(' type="button">\
      ');  end  ngx.print('\
        </div>\
    </div>\
   </div>\
	<h3>');  ngx.print(T"Neighbour Table"); ngx.print('</h3>\
   <div class="h3-content content-nat-mapping nat-mapping-padding-bottom-50">\
    <div class="table-responsive">\
        <table class="table wan-table lan-table">\
            <thead>\
                <tr class = "nat-head-bdr">\
                    <th> </th>\
                    <th><span>');  ngx.print(T"Host Name"); ngx.print('</span>\
                    </th>\
                    <th><span>');  ngx.print(T"IPv6 Global Address"); ngx.print('</span>\
                    </th>\
                    <th><span>');  ngx.print(T"# Connections"); ngx.print('</span>\
                    </th>\
                </tr>\
                </thead>\
                <tbody>\
                ');  local indexv6 = 0
                for i,v in pairs(connectedHosts) do  ngx.print('\
                ');  if (v["IP6Address"] ~= "") then
                  indexv6 = indexv6 + 1   ngx.print('\
                  <tr>\
                    <td>');  ngx.print(indexv6); ngx.print('</td>\
                    <td>');  ngx.print(v["HostName"]); ngx.print('</td>\
                    <td>');  ngx.print(v["IP6Address"]); ngx.print('</td>\
                    <td>');  ngx.print(v["NeighborNumberOfConnections"]); ngx.print('</td>\
                  </tr>\
                ');  end  ngx.print('\
                ');  end  ngx.print('\
            </tbody>\
        </table>\
    </div>\
</div>\
<div class="h3-content vdf-table nat-mapping-padding-bottom-50">\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
            <span>');  ngx.print(T"Download the complete NAT address mapping table in CSV format"); ngx.print('</span>\
        </div>\
        <div class="right">\
      ');  if connContent["activeConnections"] ~= "" then   ngx.print('\
			  <input class="button button-cancel mob-button-width" id = "natmapping-btn-neigh" value=');  ngx.print(T"Download"); ngx.print(' type="button">\
      ');  end  ngx.print('\
        </div>\
    </div>\
   </div>\
</div>\
<script>\
var target = "modals/nat-mapping-table.lp";\
var actionValue;\
$(function() {\
$("#natmapping-btn-neigh, #natmapping-btn-dwnloadhost").click(function() {\
  if (this.id == \'natmapping-btn-dwnloadhost\') {\
      actionValue = "downloadipv4nat"\
    }\
    else if (this.id == \'natmapping-btn-neigh\') {\
      actionValue = "downloadipv6nat"\
    }\
$.fileDownload(target, {\
        httpMethod: "POST",\
        data: new Array({ name : "action", value : actionValue },\
                        { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" }),\
        failCallback: function() {\
          window.location("/");\
        }\
      });\
});\
});\
</script>\
\
'); 