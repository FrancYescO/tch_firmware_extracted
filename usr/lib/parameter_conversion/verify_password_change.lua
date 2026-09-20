--[[ This logic is based on the login authentication logic implemented in
both client and server side.

The login authentetication logic flow is as follows:
 - We receive the username 'I' and ephemeral value 'A' from the client.
 - We instantiate a new SRP verifier object and return a salt 's'
   and our ephemeral value 'B' to the client.
 - We receive the value 'M' from the client.
 - If that value matches our value then we send our 'M2' value.
   Otherwise authentication failed.

Here, the same logic is used to verify whether the password has been
changed by the user or it is still the default password
 --]]

local srp = require("srp")
local uci_conv = require 'uciconv'
local uci_new = uci_conv.uci('new')

-- The salt and verifier stored in UCI web config
local salt = uci_new:get('web', 'usr_admin', 'srp_salt')
local verifier = uci_new:get('web', 'usr_admin', 'srp_verifier')

-- The known username and password
local username = "admin"
local password = "Telstra"

-- Normally Client logic (eg. the browser)
local srp_user, A = srp.User(username, password)
-- Normally Server logic (eg. nginx)
local srp_verifier, B = srp.Verifier(username, salt, verifier, A)
-- Normally Client logic where we receive the value "M"
local M = srp_user:get_M(salt, B)
-- Normally Server logic. If this verify fails, you know the password is incorrect.
local M2, errmsg = srp_verifier:verify(M)

if errmsg then
  uci_new:set('web', 'usr_admin', 'password_changed', '1')
  uci_new:commit('web')
end
