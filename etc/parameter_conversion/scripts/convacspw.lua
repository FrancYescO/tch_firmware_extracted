local crypto = require("tch.simplecrypto")
local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local cwmpd = {
  config = 'cwmpd',
  section = 'cwmpd_config'
}

local function encrypt(option)
  local pass = o:get(cwmpd.config, cwmpd.section, option)
  if (pass ~= nil and pass ~= '') then
    local d_pass = crypto.decrypt(pass) or pass
    local e_pass = crypto.encrypt(d_pass, crypto.AES_256_CBC)
    if e_pass then
      n:set(cwmpd.config, cwmpd.section, option, e_pass)
    end
  end
end

encrypt('acs_pass')
encrypt('connectionrequest_password')

