--pretranslated: do not change this file
 
--[[
Version 1.0 DHCP Relay Setup Page

  - Allow direct configuration of DHCP Relay

]]
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local valEnumSel = post_helper.getValidateInEnumSelect
local format, match, ngx = string.format, string.match, ngx


local warning =
{
  alert = {
    class = "alert-range"
  }
}

if ngx.req.get_method() == "POST" then
  local setIPValues = {}
  if ngx.req.get_post_args().uciRelayStatus == "0" then
    setIPValues["uci.dhcp.relay.@relay.server_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.local_addr"] = ""
    setIPValues["uci.dhcp.relay.@relay.interface"] = ""
    proxy.del("uci.dhcp.relaybackup.")
    proxy.add("uci.dhcp.relaybackup.", post_helper.getRandomKey())
    proxy.set(setIPValues)
  else
    proxy.del("uci.dhcp.relaybackup.")
  end
  proxy.apply()
end

local uciRelayStatus = "0"

local relayParams = {
  uciRelayServerIp = "uci.dhcp.relay.@relay.server_addr",
  uciRelayLocalIp  = "uci.dhcp.relay.@relay.local_addr",
  uciRelayInterface = "uci.dhcp.relay.@relay.interface"
}

local validateIP = post_helper.validateStringIsIP()
local validateAdvancedIP = post_helper.advancedIPValidation
local validatePublicIP = post_helper.isPublicIP
local getValidation = post_helper.getAndValidation
local validateLXC = post_helper.validateLXC

--the [value] a valid IPv4 address
--the [value] is not the GW IP address
--the [value] is not the GW WAN IP address
--@return nil+error message
local function validateRelay(value, object)
  if validateIP(value) then
    local content = {
      ipaddr = "rpc.network.interface.@lan.ipaddr",
      wanIpaddr = "rpc.network.interface.@wan.ipaddr"
    }
    content_helper.getExactContent(content)

    if content.ipaddr == value then
      return nil, T"Cannot use the gateway IP address."
    end
    if content.wanIpaddr == value then
      return nil, T"Cannot use the gateway WAN IP address."
    end
    local success, errmsg = post_helper.reservedIPValidation(value)
    if not success then
      return nil, errmsg
    end
    --Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
    object.localdevmask = proxy.get("uci.network.interface.@lan.netmask")[1].value
    return true
  end
end

-- Description Function to get the list of wan interface Paths
-- @function getWanInterfacePath
-- @return table
local function getWanInterfacePath()
  local interfaceList = proxy.getPN("rpc.network.interface.", true)
  local wanIntfPaths = {}
  if interfaceList then
    for _,intf in ipairs(interfaceList) do
      local values = proxy.get(intf.path .. "type")
      if values ~= "" and values[1].value == "wan" then
        wanIntfPaths[#wanIntfPaths + 1] = values[1].path
      end
    end
  end
  return wanIntfPaths
end

local wanIntfPaths = getWanInterfacePath()
local wanData = content_helper.convertResultToObject("rpc.network.interface.", proxy.get(unpack(wanIntfPaths)))

local wanConInfo = {}
for _, wanInfo in ipairs(wanData) do
  if wanInfo.type == "wan" then
    wanConInfo[#wanConInfo + 1] = {}
    wanConInfo[#wanConInfo].interface = match(wanInfo.paramindex, "([%w%_]+)")
  end
end

local WanDetails = {}
for _, wanConf in ipairs(wanConInfo) do
  if wanConf.interface ~= "wan6" then
    WanDetails[#WanDetails + 1] = {
      wanConf and wanConf.interface,
      wanConf and wanConf.interface,
    }
  end
end

local relayValid = {
  uciRelayServerIp = getValidation(validateRelay, validateAdvancedIP, validateLXC),
  uciRelayLocalIp  = getValidation(validateRelay, validatePublicIP, validateLXC),
  uciRelayInterface = valEnumSel(WanDetails)
}

local function getRelayBackUpValues()
  local getBackUpValues = content_helper.convertResultToObject("uci.dhcp.relaybackup.", proxy.get("uci.dhcp.relaybackup."))
  if getBackUpValues and next(getBackUpValues) then
    for _, relayBackup in pairs(getBackUpValues) do
      relayParams.uciRelayServerIp = format("uci.dhcp.relaybackup.%s.server_addr", relayBackup.paramindex)
      relayParams.uciRelayLocalIp  = format("uci.dhcp.relaybackup.%s.local_addr", relayBackup.paramindex)
      relayParams.uciRelayInterface = format("uci.dhcp.relaybackup.%s.interface", relayBackup.paramindex)
    end
  end
end

if (ngx.req.get_method() == "POST" and  ngx.req.get_post_args().uciRelayStatus == "0") or (proxy.get("uci.dhcp.relay.@relay.server_addr")[1].value == "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value == "") then
  getRelayBackUpValues()
end

local relayValues, helpmsg = post_helper.handleQuery(relayParams, relayValid)

if proxy.get("uci.dhcp.relay.@relay.server_addr")[1].value ~= "" and proxy.get("uci.dhcp.relay.@relay.local_addr")[1].value ~= "" then
  uciRelayStatus = "1"
end

local title = T"DHCP Relay Setup"
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(title, false, false))   ngx.print('\
<div class="modal-body update">\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/relay-modal.lp">\
  <fieldset>\
    <legend>');  ngx.print( T"DHCP Relay" ); ngx.print('</legend>\
      ');  
        local html = {}
        html[#html + 1] = ui_helper.createSwitch(T"Status", "uciRelayStatus", uciRelayStatus)
        html[#html + 1] = ui_helper.createInputText(T"Server IP", "uciRelayServerIp", relayValues.uciRelayServerIp, nil, helpmsg.uciRelayServerIp)
        html[#html + 1] = ui_helper.createInputText(T"Local IP", "uciRelayLocalIp", relayValues.uciRelayLocalIp, nil, helpmsg.uciRelayLocalIp)
        html[#html + 1] = ui_helper.createInputSelect(T"Interface", "uciRelayInterface", WanDetails, relayValues.uciRelayInterface)
        ngx.print(html)
        ngx.print(ui_helper.createAlertBlock(T"When changing any parameters in this section you will need to reboot the Router to make the changes take effect. Reboot option is present in System Information Modal.", warning))
        ngx.print('\
\
  </fieldset>\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 