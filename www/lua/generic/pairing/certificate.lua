
local require = require
local setmetatable = setmetatable

local x509 = require 'tch.crypto_x509'

local Certificate = {}
Certificate.__index = Certificate

local function untaint(s)
  if s.untaint then
    return s:untaint()
  end
  return s
end

local function newCertificate(pemdata)
  pemdata = untaint(pemdata)
  local cert = x509.new_from_string(pemdata)
  if not cert then
    return nil, "invalid pemdata"
  end
  local name = cert:commonName()
  if not name then
    return nil, "commonName missing from certificate"
  end
  local self = setmetatable({
    _pem = pemdata,
    _name = name,
  }, Certificate)
  return self
end

function Certificate:pemData()
  return self._pem
end

function Certificate:commonName()
  return self._name
end

return {
  new = newCertificate
}
