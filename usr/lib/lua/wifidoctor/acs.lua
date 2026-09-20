local proxy = require("datamodel")

function set_acs_allowed_channels(pradio, pchannels, pauthority)
  local channels
  local radio

  channels = tostring(pchannels)
  radio = tostring(pradio)
  proxy.set({["uci.wireless.wifi-device.@" .. radio .. ".acs_allowed_channels"]=channels})
  proxy.apply()
  return 0
end
