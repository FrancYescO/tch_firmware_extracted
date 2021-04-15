--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber
local format, match, find, sub = string.format, string.match, string.find, string.sub
local session = ngx.ctx.session
local role = session:getrole()

local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_ex_helper")
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local wan6Intf = post_helper.getActiveInterface_v6()

local function checkBlockValue(str)
  local val = tonumber(str, 16)
  if val and val <= 0xFFFF then
    return true
  else
    return false
  end
end

local function validateAddressGroup(value, borderl, compressed, borderh, len)
  --check all the address group, and save the address group numbers
  while true do
  --find "::", we assume it's compressed address
    if sub(value,borderl, borderl) == ":" then
      if compressed then
        return nil, T"Invalid IPv6 Prefix, two or more '::'."
      end
      compressed = true
      borderl = borderl + 1
      if borderl > len then
        if counter < 8 then
          return true
        else
          return nil, T"Invalid IPv6 Prefix, address group is invalid."
        end
      end
    end

    borderh = find(value, ":", borderl, true)
    if borderh == borderl then
      return nil, T"Invalid IPv6 Prefix, ':::' was found."
    end

    --last address group
    if not borderh then
      if not checkBlockValue(sub(value, borderl, len)) then
        return nil, T"Invalid IPv6 Prefix, group value is too large."
      end
      counter = counter + 1
      break
    end
    if not checkBlockValue(sub(value, borderl, borderh-1)) then
      return nil, T"Invalid IPv6 Prefix, group value is too large."
    end
    counter = counter + 1

    if borderh+1 > len then
      if counter < 8 then
        return true
      else
        return nil,  T"Invalid IPv6 Prefix, address group is invalid."
      end
    else
      borderl = borderh + 1
    end
  end

  if counter == 8 and not compressed then
    return true
  elseif counter < 8 then
    return true
  else
    return nil,  T"Invalid IPv6 Prefix, address group is invalid."
  end
end

local function validateStringIsIPv6Prefix(prefix, object, key)
  local compressed = false
  local counter, borderl = 0, 1
  local borderh
  local value, length = match(prefix, "^(.*)/(.*)$")

  if not value or value == "" or not length or length == "" then
    return nil, T"Invalid string."
  end

  local len = #value
  object["wan6_ip6prefix"] = value

  local success, msg = post_helper.getValidateNumberInRange(0,128)(length)
  if not success then
    return nil, msg
  end

  object["wan6_ip6prefixlen"] = length

  --The address start with "::"
  if sub(value,1,2) == "::" then
    borderl = 3
    compressed = true
  end

  local addressGroup, errmsg= validateAddressGroup(value, borderl, compressed, borderh, len)
  if not addressGroup then
     return nil, errmsg
  else
     return addressGroup
  end
end

local function alwaysTrue()
  return true
end

-- Configurable data
local mapParams = {
  wan6_ip4prefixlen = format("uci.network.interface.@%s.ip4prefixlen", wan6Intf),
  wan6_ip6prefix = format("uci.network.interface.@%s.ip6prefix", wan6Intf),
  wan6_ip6prefixlen =format("uci.network.interface.@%s.ip6prefixlen", wan6Intf),
  wan6_peeraddr = format("uci.network.interface.@%s.peeraddr", wan6Intf)
}

--wan6_ip6prefixlen was checked in the function validateStringIsIPv6Prefix and there is no need to check it again in validation function of wan6_ip6prefixlen.
local mapValid = {
  wan6_ip4prefixlen    = post_helper.getValidateNumberInRange(0,32),
  wan6_ip6prefix   = validateStringIsIPv6Prefix,
  wan6_peeraddr   = post_helper.validateStringIsIP(),
  wan6_ip6prefixlen = alwaysTrue
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<div class="modal-body update">\
');  
local tabs = {
  {
    desc = T"IPv4 Configuration",
    target = "modals/internet-modal.lp"
  },
  {
    desc = T"IPv6 Configuration",
    active = "active",
    target = "modals/internet-ex-modal.lp"
  }
}
ngx.print(ui_helper.createModalTabs(tabs))

if session:hasAccess("/modals/internet-"..mode_current.."-routed-configuration.lp") then
  local tab = {
    {
      desc = T"Status",
      target = "modals/internet-"..mode_current.."-routed-status.lp"
    },
    {
       desc = T"Configuration",
       active = "active",
       target = "modals/internet-"..mode_current.."-routed-configuration.lp"
    },
  }
  if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
    tab[#tab+1] = {
      desc = T"Settings",
      target = "modals/internet-"..mode_current.."-routed-settings.lp"
    }
  end
  ngx.print(ui_helper.createModalTabs(tab))
end
  ngx.print('\
\
<form class = "form-horizontal" method = "post" action = "modals/internet-6rd-routed-configuration.lp">\
<fieldset>\
  <legend>');  ngx.print( T"6rd configuration" ); ngx.print('</legend>\
  ');  
    local html = {}

    html[#html+1] = ui_helper.createInputText(T"IPv4 Mask Length", "wan6_ip4prefixlen", content["wan6_ip4prefixlen"], nil, helpmsg["wan6_ip4prefixlen"])
    local ip6prefix = content["wan6_ip6prefix"]
    if content["wan6_ip6prefixlen"] ~= "" then
      ip6prefix = format("%s/%s", content["wan6_ip6prefix"], content["wan6_ip6prefixlen"])
    end
    html[#html+1] = ui_helper.createInputText(T"6rd Prefix", "wan6_ip6prefix", ip6prefix, nil, helpmsg["wan6_ip6prefix"])
    html[#html+1] = ui_helper.createInputText(T"Border Relay Address", "wan6_peeraddr", content["wan6_peeraddr"], nil, helpmsg["wan6_peeraddr"])

    ngx.print(html)
    ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 