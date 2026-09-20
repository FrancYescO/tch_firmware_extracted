--pretranslated: do not change this file

--[[
Version 1.0 DHCP Relay Setup Page

  - Allow direct configuration of DHCP Relay

]]
-- Enable localization
gettext.textdomain('webui-core')

local bit = require("bit")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local format, match = string.format, string.match

local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")

local function resetreboot(path,value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "system_reset" then
    return resetreboot("rpc.system.reset", "1")
  elseif action == "system_reboot" then
    return resetreboot("rpc.system.reboot", "GUI")
  end
end

-- Listbox that shows the supported Interfaces
local iflist = {}
for _, v in pairs(proxy.getPN("uci.network.interface.",true)) do
    local if_name = match(v.path, "@([^%.]+)%.")
    if if_name and if_name ~= "loopback" then
        iflist[#iflist + 1] = {if_name , if_name:upper()}
    end
end


-- TODO: Hardcoded to "1" since there’s no option to enable/disable dhcp relay
local uci_relay_status = "1"

local relay_Params = {
    uci_username = "uci.network.interface.@wan.username",
    uci_password = "uci.network.interface.@wan.password",
    uci_lan_ip = "uci.network.interface.@lan.ipaddr",
    uci_lan_mask = "uci.network.interface.@lan.netmask",
    uci_relay_interface = "uci.dhcp.relay.@relay.interface",
    uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
    uci_relay_local_ip  ="uci.dhcp.relay.@relay.local_addr",
}

local vSII = post_helper.validateStringIsIP
local aIPV = post_helper.advancedIPValidation
local pIPV = post_helper.isPublicIP
local gAV = post_helper.getAndValidation
local gCV = post_helper.getConditionalValidation
local gOV = post_helper.getOptionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local gVP = post_helper.getValidationPassword
local vNES = post_helper.validateNonEmptyString
local vIP4N = post_helper.validateIPv4Netmask

--the [value] a valid IPv4 address
--the [value] is not the GW IP address
--the [value] is not the GW WAN IP address
--@return nil+error message
local function validateRelay(value, object, key)
  if vSII(value) then
    local ipaddr = proxy.get("rpc.network.interface.@lan.ipaddr")[1].value
    local wan_ipaddr = proxy.get("rpc.network.interface.@wan.ipaddr")[1].value
    if ipaddr == value then
       return nil, T"Cannot use the gateway IP address."
    end
    if wan_ipaddr == value then
       return nil, T"Cannot use the gateway WAN IP address."
    end
    --Adding localdevicemask in post to find the input is a network or broadcast IPv4 address in advancedIPValidation
    object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
    return true
  end
end

local function isEnabled(value, object, key)
    return object["uci_relay_status"] ~= "0"
end

local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end

  return true
end

local function validateGWIP(value, object, key)
   local val, errmsg = aIPV(value, object, key)

   if not val then
      return nil, errmsg
   end

   local ip = ipv42num(value)

    for _,intf in pairs(iflist) do
        if intf[1] ~= "lan" then
          local ipaddr = proxy.get("uci.network.interface.@" .. intf[1] .. ".ipaddr")[1].value
          local mask = proxy.get("uci.network.interface.@" .. intf[1] .. ".netmask")[1].value
          local baseip = vSII(ipaddr) and ipv42num(ipaddr)
          local netmask = vSII(mask) and ipv42num(mask)

          local network, ipmax
          if baseip and netmask then
            network = bit.band(baseip, netmask)
            ipmax = bit.bor(network, bit.bnot(netmask))
          end

        	if network and ipmax then
        	  if ip >= network and ip <= ipmax then
                  return nil, T"Gateway IP should not be in " .. intf[1] .. T" IP Range"
            end
        	end
        end
   end
   return true
end

local relay_valid = {
    uci_username    	  = validateUsername,
    uci_password    	  = gVP(vNES), gVP(),
    uci_lan_ip 		      = validateGWIP,
    uci_lan_mask 	      = gAV(vIP4N,vSII),
    uci_relay_interface = gVIES(iflist),
    uci_relay_server_ip = gCV(isEnabled, gAV(validateRelay, aIPV), true),
    uci_relay_local_ip  = gCV(isEnabled, aIPV, true),

}



local relay_Values, helpmsg = post_helper.handleQuery(relay_Params, relay_valid)


if ngx.var.request_method == "POST" and #helpmsg == 0 then
  local args = ngx.req.get_post_args()
  local action = args["action"]
  if action == "SAVE" then
    if relay_Values["uci_relay_status"] == "0" then
        proxy.set("uci.dhcp.relay.@relay.interface","")
        proxy.set("uci.dhcp.relay.@relay.server_addr","")
        proxy.set("uci.dhcp.relay.@relay.local_addr","")
        proxy.apply()
        relay_Values["uci_relay_server_ip"] = ""
        relay_Values["uci_relay_local_ip"] = ""
    end
  end
end
if relay_Values["uci_relay_server_ip"] == "" and  relay_Values["uci_relay_local_ip"] == "" then
  uci_relay_status = "0"
end

if relay_Values["uci_relay_interface"] == "" then
   relay_Values["uci_relay_interface"] = "wan"
end

local relay_off = {
        group = { class = "monitor-uci_relay_status monitor-1" },
    }

local switch_monitor = { input = { class = "monitor-changes" } }


ngx.print(ui_helper.createHeader(T"DHCP Relay Setup", false, false))   ngx.print('\
<div class="modal-body update">\
');
ngx.print(ui_helper.createMessages(message_helper.popMessages()), '\
<form class="form-horizontal" method="post" action="modals/relay-modal.lp">\
<fieldset>\
  <legend>', T"PPP", '</legend>');
    html = {}
    -- PPP username
    local class_username = {
      input = {
        maxlength= "64",
        class = "span4",
      }
    }
    html[#html + 1] = format("<div class='control-group'><label class='control-label'>%s</label><div class='controls'>",T"Username")
    html[#html + 1] = ui_helper.createSimpleInputText("uci_username", relay_Values["uci_username"], class_username, helpmsg["uci_username"])
    html[#html + 1] = [[</div></div>]]
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputText(T"Password", "uci_password", relay_Values["uci_password"], class_username, helpmsg["uci_password"])
    ngx.print(html, '\
</fieldset>\
<fieldset>\
  <legend>', T"LAN", '</legend>');
         local html = {}
         html[#html + 1] = ui_helper.createInputText(T"IP Address", "uci_lan_ip", relay_Values["uci_lan_ip"],{},helpmsg["uci_lan_ip"])
         html[#html + 1] = ui_helper.createInputText(T"Subnet Mask", "uci_lan_mask", relay_Values["uci_lan_mask"], nil, helpmsg["uci_lan_mask"])
         ngx.print(html, '\
</fieldset>\
<fieldset>\
  <legend>', T"DHCP Relay", '</legend>');
         local html = {}
         html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_relay_status", uci_relay_status, switch_monitor)
         html[#html + 1] = ui_helper.createInputSelect(T"Network Server Interface", "uci_relay_interface", iflist, relay_Values["uci_relay_interface"], relay_off)
         html[#html + 1] = ui_helper.createInputText(T"Server IP", "uci_relay_server_ip", relay_Values["uci_relay_server_ip"], relay_off, helpmsg["uci_relay_server_ip"])
         html[#html + 1] = ui_helper.createInputText(T"Local IP", "uci_relay_local_ip", relay_Values["uci_relay_local_ip"], relay_off, helpmsg["uci_relay_local_ip"])
         ngx.print(html, '\
\
</fieldset>\
<fieldset>\
  <legend>', T"Quick Links", '</legend>');
        local wait_for_reboot = {
          group = {
            class = "wait-for-reboot"
          },
          button = {
            id = "btn-system-reboot",
            class = "custom-handler"
          }
        }

        local wait_for_reset = {
          group = {
            class = "wait-for-reset"
          },
          button = {
            id = "btn-system-reset",
            class = "custom-handler"
          }
        }
        local rebooting = {
        alert = {
          class = "alert hide",
          id = "rebooting-msg"
        }
      }
        local resetting = {
        alert = {
          class = "alert hide",
          id = "resetting-msg"
        }
      }
        local html = {}
        html[#html + 1] = ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting)
        html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
        html[#html + 1] = ui_helper.createAlertBlock(T"Resetting to factory defaults, please wait...", resetting)
        html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)
        ngx.print(html, '\
\
</fieldset>\
\
</form>\
</div>\
<script>\
(function() {\
  var refreshTimeOut = 5000;\
  var refreshDelay = 10000;\
  var target = $(".modal form").attr("action");\
\
  function wait_for_webserver_running() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"} })\
    .done(function(data) {\
      window.location.href = "/";\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
\
  function wait_for_webserver_down() {\
    $.ajax({ url: target, timeout: refreshTimeOut, data: { check: "1"}  })\
    .done(function() {\
      window.setTimeout(wait_for_webserver_down, refreshDelay);\
    })\
    .fail(function() {\
      window.setTimeout(wait_for_webserver_running, refreshDelay);\
    });\
  }\
  function resetreboot(msg, msg_dst, action) {\
    msg_dst.after(msg);\
    msg.removeClass("hide");\
    msg[0].scrollIntoView();\
    $.post(\
      target,\
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
      wait_for_webserver_down,\
      "json"\
    );\
    return false;\
  }\
\
$("#btn-system-reboot").click(function() {\
     var heading = "', T'Restart Device', '";\
     var processMsg = "', T'Rebooting', '";\
     confirmationDialogue(\'', T"Do you want to continue?", '\',heading);\
     $(document).on("click", ".Restart", function() {\
          tch.removeProgress();\
          tch.showProgress(processMsg);\
          return resetreboot($("#rebooting-msg"), $(this), "system_reboot" );\
     });\
  });\
\
\
$("#btn-system-reset").click(function() {\
      var heading = "', T'Factory Defaults', '";\
      var processMsg = "', T'Resetting', '";\
      confirmationDialogue(\'', T"Do you want to continue? ", '\',heading);\
      $(document).on("click", ".Factory", function() {\
          tch.removeProgress();\
          tch.showProgress(processMsg);\
          return resetreboot($("#resetting-msg"), $(this), "system_reset");\
      });\
  });\
$(document).on("click", "#cancel", function() {\
      tch.removeProgress();\
  });\
\
}());\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');