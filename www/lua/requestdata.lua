local xml = require("xml").xmlCreate
local proxy = require("datamodel")

local M = {}

-- Reply with XML data, according to ConfigurationData requested.
-- Only `WidgetAssurance` is allowed and supported.
local function reply()
  local configurationData = ngx.req.get_uri_args().ConfigurationData
  if configurationData == "WidgetAssurance" then
    local xmlData = xml(configurationData)

    if not xmlData then
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    ngx.header.content_type = "application/xml"
    ngx.print(xmlData)
    ngx.exit(ngx.HTTP_OK)
  end
end

-- Requests must come from LAN
local function fromLan()
  local lanIP = proxy.get("rpc.network.interface.@lan.ipaddr")
  return ngx.var.host == (lanIP and lanIP[1] and lanIP[1].value)
end

-- Requests must come over https
local function secure()
  return ngx.var.https == "on"
end

-- Only basic authorization is supported; a fixed username and password are the only valid credentials
local function auth()
  local header = ngx.var.http_authorization

  if header then
    local userpass = header:match("^Basic (.*)$")
    -- Fixed username:password `6K5EPaeC1XVP3DBm:4i2x...`, base64 encoded
    return (userpass == "Nks1RVBhZUMxWFZQM0RCbTo0aTJ4azVJaGFhUjhob0hW")
  else
    ngx.header.www_authenticate = [[Basic realm="Telecom Italia app"]]
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
end

function M.process()
  -- Only reply if prerequisites met:
  -- from LAN over https, using valid user credentials
  if fromLan() and secure() and auth() then
    -- reply() will send the data, or exit with an error code
    reply()
  end

  -- anything else is not authorized
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

return M
