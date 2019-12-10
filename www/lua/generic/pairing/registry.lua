
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring

local HUGE = math.huge

local DBCert = require 'generic.pairing.dbcert'

local Registry = {}
Registry.__index = Registry

local dummyDM = {
  -- this dummy datamodel implementation is used in case the user
  -- of the registry did not specify a datamodel interface.
  -- using a dummy instead of nil will remove the need for conditional
  -- code.
  create = function() return "" end,
  delete = function() return true end,
  update = function() return true, 0 end,
  loadall = function() return {} end,
}

local function new(options)
  local self = setmetatable({
    _certificates = {},
    _maxSize = options.size or HUGE,
    _pemToCert = options.pemToCert,
    _dm = options.dm_pairing or dummyDM,
    _generation = 0,
  }, Registry)
  return self
end

local function requiredOptionsPresent(options)
  if not options.pemToCert then
    return false
  end
  return true
end

local function registryFull(self)
  return #self._certificates >= self._maxSize
end

local function setRawDBCertAt(certs, dbcert, idx)
  certs[idx] = dbcert
  certs[dbcert:pemData()] = idx
end

local function restoreGeneration(self, dbcert)
  if self._generation < dbcert:generation() then
    self._generation = dbcert:generation()
  end
end

local function loadPairings(self)
  local dmdata = DBCert.loadall(self._dm, self._pemToCert)
  for i, dbcert in pairs(dmdata) do
    if not registryFull(self) then
      setRawDBCertAt(self._certificates, dbcert, i)
      restoreGeneration(self, dbcert)
    end
  end
end

local function newRegistry(options)
  options = options or {}
  if requiredOptionsPresent(options) then
    local self = new(options)
    loadPairings(self)
    return self
  end
  return nil, "A required option (pemToCert) was missing"
end

function Registry:pemToCert(pemdata)
  return self._pemToCert(pemdata)
end

local function nextGeneration(self)
  local gen = self._generation + 1
  self._generation = gen
  return gen
end

local function findCertByPem(self, pemdata)
  local certs = self._certificates
  local idx = certs[pemdata]
  return idx and certs[idx]:cert(), idx
end

local function locateCertByCommonName(self, name)
  for idx, dbcert in ipairs(self._certificates) do
    if dbcert:name() == name then
      return idx, dbcert:cert()
    end
  end
end

local function removeCertAt(self, idx)
  local certs = self._certificates
  local oldcert = certs[idx]
  if oldcert then
    certs[oldcert:pemData()] = nil
  end
end

local function findLeastRecentlyUsed(self)
  local oldestGen = HUGE
  local lruIndex = 1
  for i, dbcert in ipairs(self._certificates) do
    local gen = dbcert:generation()
    if gen < oldestGen then
      oldestGen = gen
      lruIndex = i
    end
  end
  return lruIndex
end

local function dropCertificateAt(self, idx)
  removeCertAt(self, idx)
end

local function dropLeastRecentlyUsed(self)
  local lru = findLeastRecentlyUsed(self)
    dropCertificateAt(self, lru)
  return lru
end

local function getFreeCertificateIndex(self, cert)
  local idx = locateCertByCommonName(self, cert:commonName())
  if idx then
    removeCertAt(self, idx)
  elseif registryFull(self) then
    idx = dropLeastRecentlyUsed(self)
  else
    idx = #self._certificates+1
  end
  return idx
end

local function makeMostRecentlyUsed(self, idx)
  local dbcert = self._certificates[idx]
  local gen = dbcert:generation() or -1
  if self._generation > gen then
    dbcert:setGeneration(nextGeneration(self))
    return true
  end
end

local function saveCertificateAt(self, idx)
  local dbcert = self._certificates[idx]
  dbcert:save(self._dm)
end

local function setCertificateAt(self, idx, cert)
  local certs = self._certificates
  local dbcert = certs[idx] or DBCert.new(tostring(idx))
  dbcert:setCert(cert)
  setRawDBCertAt(certs, dbcert, idx)
end

local function updateCertificate(self, newcert)
  local idx = getFreeCertificateIndex(self, newcert)
  setCertificateAt(self, idx, newcert)
  makeMostRecentlyUsed(self, idx)
  saveCertificateAt(self, idx)
  return true
end

local function insertCertificate(self, cert)
  if not locateCertByCommonName(self, cert:commonName()) then
    return updateCertificate(self, cert)
  end
  return nil, "tried to pair a duplicate commonName"
end

local function nonEmptyString(v)
  return type(v)=="string" and v~="";
end

local function validCert(cert)
  local pem = cert:pemData()
  local name = cert:commonName()
  return nonEmptyString(pem) and nonEmptyString(name)
end

function Registry:pairingCount()
  return #self._certificates
end

function Registry:paired(pemdata)
  local _, idx = findCertByPem(self, pemdata)
  if idx then
    if makeMostRecentlyUsed(self, idx) then
      saveCertificateAt(self, idx)
    end
    return true
  end
  return false
end

function Registry:pairedCert(pemdata)
  return findCertByPem(self, pemdata)
end

function Registry:createPairing(cert)
  if validCert(cert) then
    return insertCertificate(self, cert)
  end
  return nil, "invalid certificate"
end

local function validUpdate(self, oldCert, newCert)
  if not self:paired(oldCert:pemData()) then
    return nil, "not paired"
  end
  if not validCert(newCert) then
    return nil, "invalid certificate"
  end
  if oldCert:commonName() ~= newCert:commonName() then
    return nil, "cannot update with different commonName"
  end
  return true
end

function Registry:updatePairing(oldCert, newCert)
  local valid, err = validUpdate(self, oldCert, newCert)
  if valid then
    return updateCertificate(self, newCert)
  end
  return nil, err
end

function Registry:nameInUse(name)
  local idx, cert = locateCertByCommonName(self, name)
  return idx~=nil, cert
end

function Registry:certForName(name)
  local idx, cert = locateCertByCommonName(self, name)
  return idx and cert
end

return {
  new = newRegistry,
}
