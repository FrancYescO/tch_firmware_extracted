local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local proxy = require("datamodel")
local format, match, ngx = string.format, string.match, ngx
local frequency = {}
local json = require("dkjson")
local wirelessSSID_helper
local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout ~= "" and isNewLayout[1].value or "0"
if isNewLayout == "1" then
  wirelessSSID_helper = require("wireless-card_helper-newEM")
else
  wirelessSSID_helper = require("wirelessSSID_helper")
end
local qtnMac = {
  mac = "uci.env.var.qtn_eth_mac",
  isNewLayout = "uci.env.var.em_new_ui_layout"
}
content_helper.getExactContent(qtnMac)

if ngx.req.get_uri_args().auto_update == "true" then
  local ssid_list = wirelessSSID_helper.getSSID()
  if qtnMac.mac ~= "" then
    ssidStatus = 0
    local device = "sys.proc.net.arp."
    local deviceDetails = content_helper.convertResultToObject(device,proxy.get(device))
    for _,l in ipairs(deviceDetails) do
      if (string.upper(l.hw_address)==qtnMac.mac) then
        ssidStatus = 1
      end
    end
  end

  function ssidDisplay()
    if ssidStatus ~= nil then
      local render = {}
      for i,v in pairs(ssid_list) do
        if i <= 4 then
          status = (v.state == "1") and "light green" or "light off"
          if ssidStatus == 0  and v.radio == "5Ghz" then
            render[i] = {listatus = "light orange"}
          else
            if qtnMac.isNewLayout == "1" then
              v.radio = ((v.radio == "2.4GHz" and "2.4 GHz") or (v.radio == "5GHz" and "5 GHz")) or v.radio
              -- in case of merge show both radios
              v.radio = v.split and v.split == "0" and "2.4 GHz & 5 GHz" or v.radio
            end
            render[i] = {listatus = status, ssid = v.ssid, radio = v.radio}
          end
        end
      end
      return render
    end
    render = ""
    return render
  end
  local htmlRender = ssidDisplay()
  ngx.header.content_type = "application/json"
  ngx.print(json.encode(htmlRender))
  ngx.exit(ngx.HTTP_OK)
end
