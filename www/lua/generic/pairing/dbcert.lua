
local tostring = tostring
local pairs = pairs
local tonumber = tonumber
local setmetatable = setmetatable
local sort = table.sort
local pcall = pcall
local error = error

local DBCert = {}
DBCert.__index = DBCert

local function new()
  return setmetatable({
    _changes = {},
    _params = {},
  }, DBCert)
end

local function markAsSaved(dbcert)
  dbcert._changes = {}
end

local function setField(dbcert, field, value)
  dbcert._params[field] = value
  dbcert._changes[field] = true
end

local function fieldValue(dbcert, field)
  return dbcert._params[field]
end

local function newDBCert()
  return new()
end

local function loadDBCert(key, data, pemToCert)
  local dbcert = new()
  dbcert._key = key
  local cert = data.Certificate and pemToCert(data.Certificate)
  dbcert:setCert(cert)
  dbcert:setGeneration(data.Generation)
  markAsSaved(dbcert)
  return dbcert
end

local function loadallDBCerts(dm_pairing, pemToCert)
  local dbcerts = {}
  local all = dm_pairing:loadall()
  for key, data in pairs(all) do
    local cert = loadDBCert(key, data, pemToCert)
    dbcerts[#dbcerts+1] = cert
  end
  return dbcerts
end

local function sortInMruOrder(dbcerts)
  sort(dbcerts, function(c1, c2)
    return c1:generation() > c2:generation()
  end)
  return dbcerts
end

local function loadall(dm_pairing, pemToCert)
  return sortInMruOrder(
    loadallDBCerts(dm_pairing, pemToCert)
  )
end

local function getDbKey(dbcert, dm_pairing)
  local key = dbcert._key
  if not key then
    local err
    key, err = dm_pairing:create()
    if not key then
      error("Failed to create key: "..err)
    end
    dbcert._key = key
  end
  return key, dm_pairing
end

local function updateDbData(dbcert, key, dm_pairing)
  local data = {}
  for field in pairs(dbcert._changes) do
    data[field] = tostring(fieldValue(dbcert, field))
  end
  local updated, nUpdated = dm_pairing:update(key, data)
  if not updated then
    --nUpdated is now the error message
    error("Failed to update data for key "..key.." : "..nUpdated)
  end
  if nUpdated>0 then
    dm_pairing:apply()
  end
end

function DBCert:save(dm_pairing)
  local saved, err = pcall(function()
    updateDbData(self, getDbKey(self, dm_pairing))
    markAsSaved(self)
  end)
  if not saved then
    return nil, err
  end
  return true
end

function DBCert:name()
  return fieldValue(self, "Name")
end

function DBCert:pemData()
  return fieldValue(self, "Certificate")
end

function DBCert:setCert(cert)
  self._cert = cert
  setField(self, "Certificate", cert and cert:pemData() or "")
  setField(self, "Name", cert and cert:commonName() or "")
end

function DBCert:cert()
  return self._cert
end

function DBCert:setGeneration(gen)
  setField(self, "Generation", gen)
end


function DBCert:generation()
  return tonumber(fieldValue(self, "Generation")) or -1
end

return {
  new = newDBCert,
  loadall = loadall,
}
