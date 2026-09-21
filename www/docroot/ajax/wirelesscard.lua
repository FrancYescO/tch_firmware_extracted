local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local proxy = require("datamodel")
local format, match, ngx = string.format, string.match, ngx
local frequency = {}
local json = require("dkjson")
local wirelessSSID_helper = require("wirelessSSID_helper")

if ngx.req.get_uri_args().auto_update == "true" then
  local ssid_list = wirelessSSID_helper.getSSID()
  local qtnMac = { mac = "uci.env.var.qtn_eth_mac" }
  qtnAvail = content_helper.getExactContent(qtnMac)
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
        if i < 4 then
          status = "light off"
          if(v.state == "1") then
            status = "light green"
          else
            status = "light off"
          end
          render[i] = {listatus = status, ssid = v.ssid, radio = v.radio}
          if(ssidStatus == 0) then
            status = "light orange"
            if render ~= '' then
              render[i+1] = {listatus = status}
            else
              render[i] = {listatus = status}
            end
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