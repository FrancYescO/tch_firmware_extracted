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
      
      ngx.say([[
      <html>
        <head>
        <style>
        
        p         {text-align: left;}
        ol        {type="1"; width: 500px;}
        .divtitle {text-align: left; width: 500px;}
        </style>
        </head>
        <body>
          <center>
            <h2><b>An Issue Has Occured</b></h2>
            <div class="divtitle"><b>Please check the following:</b></div>
            <ol>
              <li>
                <p><b>Browser Issue</b></p>
                <div>
                <p>Some computers can see this page if there are setting issues on their browser, if another browser is installed please try it ( e.g. Chrome, Firefox, Internet Explorer).
                <br/><br/>Alternatively use another device such as a phone, tablet or computer.</p>
                <div>
              </li>
              <li>
                <p><b>Config Change</b></p>
                <div>
                <p>If you have recently made a change to your routers config this requires you to reboot the device.</b><br>
                Please turn off the <b>]], CPEname,[[</b>, then turn it back on again.</p>
                <div>
              </li>
            </ol>
            
          </center>
        </body>
      </html>
      
      ]]) 
      ngx.exit(ngx.HTTP_OK)
  
  end
  
  
  

end

return M
