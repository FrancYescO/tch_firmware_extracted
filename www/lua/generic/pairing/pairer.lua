
local setmetatable = setmetatable

local PAIRING_SETUP = 0
local PAIRING_INITIATED = 1
local PAIRING_COMPLETE = 2
local PAIRING_TIMEOUT = 3
local PAIRING_IN_PROGRESS = 4
local PAIRING_ALREADY_ONGOING = 5
local PAIRING_FAILED = 6

local Pairer = {
  PAIRING_INITIATED = PAIRING_INITIATED,
  PAIRING_COMPLETE = PAIRING_COMPLETE,
  PAIRING_TIMEOUT = PAIRING_TIMEOUT,
  PAIRING_IN_PROGRESS = PAIRING_IN_PROGRESS,
  PAIRING_ALREADY_ONGOING = PAIRING_ALREADY_ONGOING,
  PAIRING_FAILED = PAIRING_FAILED,
}
Pairer.__index = Pairer

local function nullPairingState()
end

local PairingRequest = {}
PairingRequest.__index = PairingRequest

local function calculateDeadline(chrono, waitTimeInSeconds)
  local now = chrono:ticks()
  local waitTimeInTicks = waitTimeInSeconds * chrono:ticks_per_second()
  return now + waitTimeInTicks
end

local function setPairingState(pairing, state)
  pairing.state = state
end

local function PairingRequest_new()
  return setmetatable({
    state = PAIRING_SETUP,
    eventPairingState = nullPairingState,
  }, PairingRequest)
end

function PairingRequest.forCertificate(cert)
  local pairing = PairingRequest_new()
  pairing.newCert = cert
  return pairing
end

function PairingRequest.withErrorState(state)
  local pairing = PairingRequest_new()
  pairing.state = state
  return pairing
end

function PairingRequest:withTimeout(chrono, timeoutInSeconds)
  self.deadline = calculateDeadline(chrono, timeoutInSeconds)
  self.obsoleteAfter = calculateDeadline(chrono, timeoutInSeconds + 120)
  self.chrono = chrono
  return self
end

function PairingRequest:withStateEvent(setState)
  self.eventPairingState = setState or nullPairingState
  return self
end

function PairingRequest:withRegistry(registry)
  self.registry = registry
  return self
end

function PairingRequest:asUpdateFor(cert)
  if cert and cert:commonName() == self.newCert:commonName() then
    self.updateForCert = cert
  end
  return self
end

local function pairingSetupCorrectly(pairing)
  if not pairing.state == PAIRING_SETUP then
    pairing.errmsg = "Internal Error: Already initiated"
    return false
  end
  if not pairing.chrono then
    pairing.errmsg = "Internal Error: No timeout set"
    return false
  end
  return true
end

local function alreadyPaired(pairing)
  return pairing.registry:paired(pairing.newCert:pemData())
end

local function isPairingUpdate(pairing)
  return pairing.updateForCert~=nil
end

local function nameFreeToPair(pairing)
  local inUse = pairing.registry:nameInUse(pairing.newCert:commonName())
  if inUse then
    if not (alreadyPaired(pairing) or isPairingUpdate(pairing)) then
      pairing.errmsg = "certificate commonName already registered"
      return false
    end
  end
  return true
end

local function canInitiatePairing(pairing)
  return pairingSetupCorrectly(pairing) and
         nameFreeToPair(pairing)
end

function PairingRequest:initiate()
  if canInitiatePairing(self) then
    setPairingState(self, PAIRING_IN_PROGRESS)
    self.eventPairingState("Initiated")
    return PAIRING_INITIATED
  end
  setPairingState(self, PAIRING_FAILED)
  return self.state, self.errmsg or "Internal Error"
end

function PairingRequest:pemData()
  if self.newCert then
    return self.newCert:pemData()
  end
  return ""
end

local function deadlinePassed(pairing)
  return pairing.deadline < pairing.chrono:ticks()
end

local function pairingIsObsolete(pairing)
  if pairing.obsoleteAfter then
    return pairing.obsoleteAfter <= pairing.chrono:ticks()
  end
end

local function registerPairing(pairing)
  if pairing.registry then
    local paired, errmsg
    if pairing.updateForCert then
      paired, errmsg = pairing.registry:updatePairing(pairing.updateForCert, pairing.newCert)
    else
      paired, errmsg = pairing.registry:createPairing(pairing.newCert)
    end
    if paired then
      return true
    end
    pairing.errmsg = errmsg
  end
end

local function pairingIsInProgress(pairing)
  return pairing.state == PAIRING_IN_PROGRESS
end

local function pairingTimedOut(pairing)
  setPairingState(pairing, PAIRING_TIMEOUT)
  pairing.eventPairingState("TimedOut")
end

local function pairingCompleted(pairing)
  if registerPairing(pairing) then
    setPairingState(pairing, PAIRING_COMPLETE)
    pairing.eventPairingState("Paired")
  else
    setPairingState(pairing, PAIRING_FAILED)
    pairing.eventPairingState("Failed")
  end
end

local function progressPairing(pairing)
  if pairingIsInProgress(pairing) then
    if deadlinePassed(pairing) then
      pairingTimedOut(pairing)
    elseif pairing.buttonPressed then
      pairingCompleted(pairing)
    end
  end
end

local function getCurrentPairing(pairer)
  local pairing = pairer._currentPairing
  if pairing then
    progressPairing(pairing)
  end
  return pairing
end

local function buttonPressed(pairer)
  local pairing = getCurrentPairing(pairer)
  if pairing and pairingIsInProgress(pairing) then
    pairing.buttonPressed = true
    return true
  end
  return false
end

local function listenForButtonPress(pairer)
  pairer._button:listenForPress(function()
    return buttonPressed(pairer)
  end)
end

local function makePairingStateCollectible(pairer, pairing)
  if pairing then
    pairer._collectablePairings[pairing:pemData()] = pairing
  end
end

local function setCurrentPairing(pairer, pairing)
  makePairingStateCollectible(pairer, pairer._currentPairing)
  pairer._currentPairing = pairing
end

local function pairedTokenCert(self, token, newCert)
  local cert
  if self._alwaysUpdate then
    cert = self._registry:certForName(newCert:commonName())
  end
  if not cert and token and token~="" then
    cert = self._registry:pairedCert(token)
  end
  return cert
end

local function startPairing(self, newPemdata, token)
  local cert, err = self._registry:pemToCert(newPemdata)
  if not cert then
    return nil, err
  end
  local pairing = PairingRequest.forCertificate(cert)
                    :withTimeout(self._chrono, self._timeoutInSeconds)
                    :withStateEvent(self._setPairingState)
                    :withRegistry(self._registry)
                    :asUpdateFor(pairedTokenCert(self, token, cert))
  setCurrentPairing(self, pairing)
  return pairing:initiate()
end

local function pairingComplete(pairer, pairing)
  if pairer._currentPairing == pairing then
    pairer._currentPairing = nil
  end
  pairer._collectablePairings[pairing:pemData()] = nil
end

local function continuePairing(pairer, pairing)
  if not pairingIsInProgress(pairing) then
    pairingComplete(pairer, pairing)
  end
  return pairing.state, pairing.errmsg
end

local function collectablePairingFor(pairer, pem)
  return pairer._collectablePairings[pem]
end

local errorOngoingPairing = PairingRequest.withErrorState(PAIRING_ALREADY_ONGOING)

local function updateIfPairingForOtherPemdata(pairer, pairing, pemdata)
  if pairing:pemData()~=pemdata then
    local collectable = collectablePairingFor(pairer, pemdata)
    if not pairingIsInProgress(pairing) then
      return collectable
    else
      return collectable or errorOngoingPairing
    end
  end
  return pairing
end

local function getPairingForPemdata(pairer, pemData)
  local pairing = getCurrentPairing(pairer)
  if pairing then
    pairing = updateIfPairingForOtherPemdata(pairer, pairing, pemData)
  end
  if pairing and pairingIsObsolete(pairing) then
    pairingComplete(pairer, pairing)
    pairing = nil
  end
  return pairing
end

function Pairer:createPairing(newPemdata, token)
  local pairing = getPairingForPemdata(self, newPemdata)
  if pairing then
    return continuePairing(self, pairing)
  else
    return startPairing(self, newPemdata, token)
  end
end

function Pairer:checkProgressOnCurrentPairings()
  getCurrentPairing(self)
end

local function newPairer(args)
  if not args.registry then
    return nil, "missing registry"
  end
  if not args.button then
    return nil, "missing button"
  end
  if not args.chrono then
    return nil, "missing chrono"
  end
  local pairer = setmetatable({
    _registry = args.registry,
    _button = args.button,
    _chrono = args.chrono,
    _timeoutInSeconds = args.timeoutInSeconds or 120,
    _setPairingState = args.setPairingState,
    _collectablePairings = {},
    _alwaysUpdate = args.alwaysUpdate,
  }, Pairer)
  listenForButtonPress(pairer)
  return pairer
end

return {
  new = newPairer,
}
