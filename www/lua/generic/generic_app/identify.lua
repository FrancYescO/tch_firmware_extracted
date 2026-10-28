
local function retrieveMACofIP(ip, dm)
local path = "rpc.generic_app.hostbyip.@"..ip:gsub("%.", "_")..".MACAddress"
  local param = dm.get(path)
  if param and param[1] then
    return param[1].value
  end
end

local function identify_remote(ngx, dm)
  local ip = ngx.var.remote_addr
  local mac = retrieveMACofIP(ip:untaint(), dm)
  local error
  if not mac then
    error = "no info found for ip address "..ip
  end
  return {
    mac = mac,
    error = error,
  }
end

local function new_IdentifyMe(ngx, dm)
  return function() --ignore role, request and token
    return identify_remote(ngx, dm)
  end
end

return {
  identifyMe = new_IdentifyMe
}
