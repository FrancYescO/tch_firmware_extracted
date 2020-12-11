local M = {}

local open = io.open
local ddnsDir = "/var/run/ddns/"

local errors = {
  ["fail"]   = "Connection",
  ["nohost"] = "Connection",
  ["401"]    = "Authenticating",
  ["badauth"] = "Authenticating",
  ["ERR Not authenticated"] = "Authenticating",
  ["500"]       = "Authenticating",
  ["notify NG"] = "Authenticating",
  ["200 OK"]  = "Updated",
  ["good"]      = "Updated",
  ["nochg"]     = "Updated",
  ["HTTP Basic: Access denied"] = "Protocol",
}

local statusErrorMap = {
  Authenticating = "AUTHENTICATION_ERROR",
  Connection     = "CONNECTION_ERROR",
  Updated        = "NO_ERROR",
  Protocol       = "PROTOCOL_ERROR"
}

local function readFile(fileName)
  local fd = open(ddnsDir .. fileName)
  if fd then
    local err = fd:read("*a")
    fd:close()
    return err
  end
  return
end

function M.getDdnsInfo(key)
  local err = readFile(key .. ".err")
  if err then
    if err:match("nslookup") then
      return "Error", "CONNECTION_ERROR"
    end
  else
    return "Connecting", "NO_ERROR"
  end
  local err = readFile(key .. ".dat")
  if not err then
    return "Connecting", "NO_ERROR"
  end
  for errorMessage, status in pairs(errors) do
    if err:match(errorMessage) then
      return status, statusErrorMap[status]
    end
  end
  return "Error", "MISCONFIGURATION_ERROR"
end

return M
