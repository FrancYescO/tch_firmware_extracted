--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')
local session = ngx.ctx.session
local match, format  = string.match, string.format
local find, untaint = string.find, string.untaint
local proxy = require("datamodel")
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local bit = require("bit")
local reboot = 0


local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")

local curintf = "lan"

-- Shortcuts to validation helpers to make lines shorter
local aIPV = post_helper.advancedIPValidation
local vB = post_helper.validateBoolean
local vIP4N = post_helper.validateIPv4Netmask
local gVIES = post_helper.getValidateInEnumSelect

-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))

local lan_intfs = {}
for k,v in ipairs(all_intfs) do
    if v.type == "lan" and (not find(v["ppp.ll_intf"], "wl") or wireless_radio[untaint(v["ppp.ll_intf"])])then
         if v.name and v.name ~= "" then
            lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex}
         elseif v.paramindex ~= "lan_public" then
            lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex}
         end
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
    end
end

-- Listbox that shows the supported Network modes
local ip_mode = {
      { "dhcp", T"DHCP" },
      { "static", T"Static" }, 
}


function processOperations(operations)
    if type(operations) ~= "table" then
        return
    end
    local success, msg
    for _,v in ipairs(operations) do
        local path = v[1]
        local val = v[2]
        local setdel = v[3]
        if setdel == "del" then
            success, msg = proxy.del(path)
        elseif setdel == "add" then
            success, msg = proxy.add(path, val)
        else
            success, msg = proxy.set(path, val)
        end
    end 
end

-- Standard parameters
local mapParams = {
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
} 

local function validateGWIP(value, object, key)
   local val, errmsg = aIPV(value, object, key)

   if not val then
      return nil, errmsg
   end

   local ip = ipv42num(value)

   for _,intf in pairs(lan_intfs) do
      if intf.index ~= curintf then
        local ipaddr = proxy.get("uci.network.interface.@" .. intf.index .. ".ipaddr")[1].value
        local mask = proxy.get("uci.network.interface.@" .. intf.index .. ".netmask")[1].value
        local baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
        local netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)

        local network, ipmax
        if baseip and netmask then
          network = bit.band(baseip, netmask)
          ipmax = bit.bor(network, bit.bnot(netmask))
        end

      	if network and ipmax then
      	  if ip >= network and ip <= ipmax then
                return nil, T"Gateway IP should not be in " .. intf.name .. T" IP Range"
          end
      	end
      end
   end

   if ip >= ipv42num("10.0.0.0") and ip <= ipv42num("10.255.255.255") or
      ip >= ipv42num("172.16.0.0") and ip <= ipv42num("172.31.255.255") or
      ip >= ipv42num("192.168.0.0") and ip <= ipv42num("192.168.255.255") then
        return true
   else
      return nil, T"Public IP Range should not be used"
   end
end

local mapValid = {
    localdevIP = validateGWIP,
    localdevmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
    devIP = validateGWIP,
    devmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
} 

content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
-- If so move it to localdevmask
if helpmsg["localdevIP"] then
  local msg = match(helpmsg["localdevIP"], '^%[netmask%] (.*)')
  if msg then
    helpmsg["localdevIP"] = nil
    helpmsg["localdevmask"] = msg
  end
end

if ngx.var.request_method == "POST" then
    local action = ngx.req.get_post_args().action
  
      if not next(helpmsg) then        
          local changecommands = require("AP_helper")
          proxy.set("uci.network.interface.@lan.ipaddr", content["devIP"])
          proxy.set("uci.network.interface.@lan.netmask", content["devmask"])
          processOperations(changecommands)
          proxy.apply()
          ngx.exit(ngx.HTTP_OK)
      end
end

ngx.print(ui_helper.createHeader(T"Setup Your Gateway", true, true), '\
\
<div class="modal-body update">\
<div class="advanced hide">');

local tabs = {}
if session:hasAccess("/modals/setup-modal.lp") then
    tabs[#tabs+1] = {
        desc = T"Connection Setup",
        target = "modals/setup-modal.lp", 
    }
end
if session:hasAccess("/modals/subnet-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Routed Subnet",
        target = "modals/subnet-modal.lp", 
    }
end
if session:hasAccess("/modals/AP-modal.lp") then
    tabs[#tabs+1] ={
        desc = T"Convert to Access Point",
        target = "modals/AP-modal.lp",
        active = "active",
    }
end
ngx.print(ui_helper.createModalTabs(tabs), '\
\
</div>\
<form class="form-horizontal" method="post" action="modals/AP-modal.lp">',
ui_helper.createMessages(message_helper.popMessages()), '\
\
<fieldset>\
  <legend>', T"IP Settings", '</legend>');

              local advanced = {
                group = {
                  class = "advanced hide"
                }
              }
              local IP_warn = {
              alert = {
                      class = "alert-warning ip-warn"
                  },
              }
              local reset_warn = {
              alert = {
                      class = "alert-error reset-warn"
                  },
              }
              local AP_info = {
              alert = {
                      class = "alert-info AP-info"
                  },
              }
              --Routed Type
              local WANType = {
                  group = {
                      class = "",
                  },
                  select = {
                      class = "monitor-changes span2"
                  }
              }
    
              
              
              -- Labels that shows the Local Device IP address & network subnet
              ngx.print(
                --ui_helper.createInputSelect(T"Routed Type", "localdevproto", ip_mode, content["localdevproto"], WANType),
                ui_helper.createInputText(T"Local Device IP address", "devIP", content["localdevIP"],{},helpmsg["devIP"]),
                ui_helper.createInputText(T"Local Network subnet", "devmask", content["localdevmask"], {}, helpmsg["devmask"]),
                ui_helper.createAlertBlock(format("%s",T"This will be the fixed IP used for access to this device after the conversion to ACCESS POINT mode."),  IP_warn),
                ui_helper.createAlertBlock(format("%s<br/><br/>%s",T"Once SAVE is clicked the Router will reboot in the new config.",T"You will need to connect a Yellow Network port to your main network."),  AP_info),
                ui_helper.createAlertBlock(format("%s",T"This can only be reverted via a factory reset and all your setting will be lost."),  reset_warn),
'</fieldset>\
</form>\
</div>\
<script type=\'text/javascript\'>\
  $("#modal-no-change").hide();\
  $("#modal-changes").show();\
  $("[name=localdevIP]").focus(function(){$(".ip-warn").slideDown();});\
  $("#save-config").click(function() {\
      window.setTimeout(function(){tch.removeProgress();tch.removeProgress();tch.showProgress("', T"Applying, if the page does not auto refresh please type your new IP address in your browser.<br/><br/>Allow up to 2 minutes for the Router to reboot.",' ")}, 10);\
  });\
\
$(function() {\
});\
</script>',
ui_helper.createFooter());