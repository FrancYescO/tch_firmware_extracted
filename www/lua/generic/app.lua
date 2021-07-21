
local require = require

require 'web.web' --set up proper string tainting

local ngx = ngx
local dm = require 'datamodel'
local dm_pairing = require("generic.pairing.dm_pairing").new(dm)

local auth = require 'webservice.accesscontrol_token'
local webservice = require 'webservice.api'

local appauth = require 'generic.generic_app.auth'
local appsetcert = require 'generic.generic_app.setcert'
local identify = require 'generic.generic_app.identify'

local registry = require("generic.pairing.registry").new{
  size=16,
  pemToCert = require("generic.pairing.certificate").new,
  dm_pairing = dm_pairing,
}
local button = require("generic.pairing.button").new()

local pairer = require("generic.pairing.pairer").new{
  registry = registry,
  button = button,
  chrono = require("generic.pairing.chrono").new(),
  setPairingState = function(state) dm_pairing:setPairingState(state) end,
  alwaysUpdate = true,
}

local function at_pairer_check_expired(premature)
  if not premature then
    pairer:checkProgressOnCurrentPairings()
    ngx.timer.at(5, at_pairer_check_expired)
  end
end
at_pairer_check_expired(false)

local function serverPort()
  return ngx.var.server_port
end

auth.add_authenticator("optional_certificate", appauth.optional_certificate(serverPort))
auth.add_authenticator("certificate", appauth.certificate(serverPort, registry))

webservice.add_command("setClientCertificate", appsetcert.setClientCertificate(ngx, pairer))
webservice.add_command("identifyMe", identify.identifyMe(ngx, dm))

local M = {}

function M.process()
  local token = ngx.var.ssl_client_raw_cert or ""
  webservice.process(
    auth.authenticate(token:untaint())
  )
end

function M.buttonPressed()
  if button:pressed() then
    ngx.print("handled")
  else
    ngx.print("rejected")
  end
end

return M
