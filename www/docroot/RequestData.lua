local xml = require("xml").xmlCreate
local proxy = require("datamodel")

local configurationData = ngx.req.get_uri_args().ConfigurationData
local lanIP = proxy.get("rpc.network.interface.@lan.ipaddr")
local host = ngx.var.host

-- Allow only lan interface to make request
if host ~= lanIP[1].value then
  return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

if configurationData == "WidgetAssurance" or configurationData == "Device" then
  local xmlData = xml(configurationData)

  if not xmlData then
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  ngx.header.content_type = "application/xml"
  ngx.print(xmlData)
  ngx.exit(ngx.HTTP_OK)
end
ngx.exit(ngx.HTTP_BAD_REQUEST)
