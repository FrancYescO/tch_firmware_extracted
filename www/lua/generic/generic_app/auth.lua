
local function newOptionalCertificate(getport)
  return function(_, user)
    return user.token == getport()
  end
end

local function newRequiredCertificate(getport, registry)
  return function(token, user)
    if user.token == getport() then
      return registry:paired(token)
    end
    return false
  end
end

return {
  optional_certificate = newOptionalCertificate,
  certificate = newRequiredCertificate
}
