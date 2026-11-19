local lfs = require("lfs")
local proxy = require("datamodel")
local function decode_request_certificate(certificate, ngx)
  if certificate:match("--BEGIN CERTIFICATE--") then
    return certificate
  else
    return ngx.decode_base64(certificate)
  end
end

function noStringDifference(str1,str2)
    for i = 1,#str1 do --Loop over strings
        if str1:sub(i,i) ~= str2:sub(i,i) then --If that character is not equal to it's counterpart
          return false
        end
    end
    return true
end

function attrdir (path, certificate)
   local files = {}
   local cert_file = ""
   local certificates = ""
   local keytable = proxy.get("uci.generic_app.certificate.")
   for i = 1, #keytable-3 do
     if keytable[i].param == "key" and keytable[i].value then
       cert_file = io.open(path..string.untaint(keytable[i].value), "r")
       if cert_file then
         certificates = cert_file:read("*a")
         if noStringDifference(certificates, certificate) then
           proxy.del(keytable[i].path)
         end
         cert_file:close()
       end
     end
   end
end

local function duplicate(certificate)
   attrdir("/etc/ssl/paired/", certificate)
end

local function certificateFromRequest(request, ngx)
  if request.data then
    local cert = request.data.certificate
    if cert then
      return decode_request_certificate(cert, ngx)
    end
  end
end

local function mapPairingResult(pairer, r, err)
  if r == pairer.PAIRING_INITIATED then
    return "-2", "Pairing initiated"
  elseif r == pairer.PAIRING_COMPLETE then
    return "0", "Pairing complete"
  elseif r == pairer.PAIRING_TIMEOUT then
    return "9003", "Pairing timed out"
  elseif r == pairer.PAIRING_IN_PROGRESS then
    return "-1", "Pairing waiting for WPS button press"
  elseif r == pairer.PAIRING_ALREADY_ONGOING then
    return "9003", "Another pairing is already ongoing"
  end
  return "9003", err or "Specific error info is not available"
end

local function handlePairingRequest(ngx, pairer, request, token)
  local pem = certificateFromRequest(request, ngx)
  if pem then
    local success,msg = mapPairingResult(pairer, pairer:createPairing(pem, token))
    if success == "0" then
      duplicate(pem)
    end
    return success,msg
  else
    return "9003", "No certificate supplied"
  end
end

local function logResult(ngx, status, msg)
  local loglevel = ngx.ERR
  if status=="0" or status=="-1" then
    loglevel = ngx.INFO
  end
  ngx.log(loglevel, "setClientCertificate status="..status.." : "..msg)
end

local function setClientCertificate(ngx, pairer, request, token)
  local status, msg = handlePairingRequest(ngx, pairer, request, token)
  logResult(ngx, status, msg)
  return {
    status = status,
    msg = msg,
  }
end

local function new_setClientCertificate(ngx, pairer)
  return function(_, request, token)
    return setClientCertificate(ngx, pairer, request, token)
  end
end

return {
  setClientCertificate = new_setClientCertificate
}
