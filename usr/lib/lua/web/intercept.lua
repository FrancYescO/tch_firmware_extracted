local M = {}

function M.process()
  local req_uri = ngx.var.http_host .. ngx.unescape_uri(ngx.var.request_uri)
  ngx.log(ngx.NOTICE, "Intercept: uri=" .. string.untaint(req_uri))
  local format = string.format
  
  
  local proxy = require("datamodel")
  local ip = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
  local host = ngx.var.host
  if ip ~= host then
    return ngx.redirect(format("http://%s/httpi.lp?url=%s",ip, ngx.var.host),302 )
  else
      local CPEname = format("%s", proxy.get("uci.env.var.prod_friendly_name")[1].value)
      
      
      ngx.header.content_type = "text/html"
      
      ngx.say([[<html><head></head>
      <body><center>
      <p><b>LAN IP Address Change</b></p>
      <div>
      <p><b>The change made to your routers LAN IP address requires you to reboot the device.</b><br>
      Please turn off the <b>]], CPEname,[[</b>, then turn it back on again.</p>
      <div>
      </center></body>
      </html>]])
      
      ngx.exit(ngx.HTTP_OK)
  
  end
  
  
  

end

return M
