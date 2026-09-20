local proxy = require("datamodel")

function set_acs_allowed_channels(pradio, pchannels, pauthority)
  local channels
  local radio
  local authority
  local auth_timestamp
  local uci_txmember_acs_authority = tonumber(proxy.get("uci.txmember.acs.authority")[1].value) or 0
  if (pauthority >= uci_txmember_acs_authority) then
    authority = tostring(pauthority)
    proxy.set({["uci.txmember.acs.authority"] = authority})
 --  proxy.set({["uci.txmember.acs.auth_timestamp"]=auth_timestamp})
    channels = tostring(pchannels)
    radio = tostring(pradio)
    proxy.set({["uci.wireless.wifi-device.@" .. radio .. ".acs_allowed_channels"]=channels})
    proxy.apply()
    end
  return 0
end