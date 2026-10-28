
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local setmetatable = setmetatable

local DMPATH = "sys.generic_app.Pairing."

local DMPairing = {}
DMPairing.__index = DMPairing

local function new(dm)
  return setmetatable({
    _dm = dm
  }, DMPairing)
end

local validPairingStates = {
  Initiated = true,
  Paired = true,
  TimedOut = true,
  Failed = true,
}
function DMPairing:setPairingState(state)
  if validPairingStates[state] then
    self._dm.set{["sys.generic_app.PairingState"]=state}
  end
end

function DMPairing:create()
  local key, err = self._dm.add(DMPATH)
  if not key then
    return nil, err
  end
  return tostring(key)
end

function DMPairing:delete(key)
  local path = DMPATH..key.."."
  local deleted, err = self._dm.del(path)
  if not deleted then
    return nil, err
  end
  return true
end

function DMPairing:update(key, values)
  local num_sets = 0
  local sets = {}
  for param, value in pairs(values) do
    local path = DMPATH..key.."."..param
    sets[path] = value
    num_sets = num_sets + 1
  end
  if num_sets > 0 then
    local updated, err = self._dm.set(sets)
    if not updated then
      return nil, err
    end
  end
  return true, num_sets
end

function DMPairing:apply()
  return self._dm.apply()
end

function DMPairing:loadall()
  local all = {}
  local r, err = self._dm.get(DMPATH)
  if not r then
    return nil, err
  end
  local keymatch = "^"..DMPATH:gsub("%.", "%%.").."(%d+)%.$"
  for _, param in ipairs(r) do
    local key = param.path:match(keymatch)
    if key then
      local obj = all[key] or {}
      all[key] = obj
      obj[param.param] = param.value
    end
  end
  return all
end

return {
  new = new,
}
