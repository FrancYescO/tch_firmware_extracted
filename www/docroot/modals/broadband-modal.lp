--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local session = ngx.ctx.session
local role = session:getrole()
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local wanIntf = post_helper.getActiveInterface()
local format = string.format
local eth4lanwanmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value or ""
local content_wan = {
  proto = format("uci.network.interface.@%s.proto", wanIntf),
  wans_enable = "uci.wansensing.global.enable"
}
if post_helper.isFeatureEnabled("broadBandWanLanPort", role) then
  content_wan.iface = format("uci.network.interface.@%s.ifname", wanIntf)
  content_wan.sfp = "uci.env.rip.sfp"
end
if post_helper.isFeatureEnabled("broadBandVariantCheck", role) then
  content_wan.variant = "uci.env.var.iinet_variant"
end

content_helper.getExactContent(content_wan)
local isVariantNovas = false
if content_wan.variant == "novus" then
  isVariantNovas = true
end

local tabdata
local availableConnections
local content, helpmsg = {}, {}
local bmh, mode_current, mode_options
if post_helper.isFeatureEnabled("broadBandVariantCheck", role) then
  bmh = require("broadbandmode_helper").get(content_wan.proto)
  tabdata = dyntab_helper.process(bmh)
  mode_options = tabdata.options
  availableConnections = bmh
  if content_wan.proto ~= "pppoe" and content_wan.proto ~= "" then
    table.remove(mode_options, 5)
    table.remove(mode_options, 3)
  end
else
  bmh = require("broadbandmode_helper")
  if bmh.broadBandDetails then
    tabdata = dyntab_helper.process(bmh.broadBandDetails())
    availableConnections = bmh.broadBandDetails()
  else
    tabdata = dyntab_helper.process(bmh)
    availableConnections = bmh
  end
end

mode_current = tabdata.current.name
mode_options = tabdata.options
local mode_current_val = mode_current

for _, mode in pairs(mode_options) do
  if mode[1] == mode_current then
    mode_current_val = mode[2]
    break
  end
end

local advancedMode = true
if not post_helper.isFeatureEnabled("broadBandModalView", role) and mode_current == "ethernet" or (not post_helper.isFeatureEnabled("broadBandModalPVC", role) and mode_current == "ethernet" and role ~= "admin") then
  advancedMode = false
end

if post_helper.isFeatureEnabled("broadBandWanLanPort", role) then
  if content_wan.sfp == "1" and content_wan.wans_enable == "1" and eth4lanwanmode ~= "" then
    local mapParSFP = {
      ethsfp = "uci.ethernet.globals.eth4lanwanmode"
    }
    local mapValSFP = {
      ethsfp = post_helper.validateBoolean
    }
    content, helpmsg = post_helper.handleQuery(mapParSFP, mapValSFP)
  end
end

local function validatePvc(value, object, key)
  local intf = string.match(key, "^vpi_(.*)$")
  local vpi = "vpi_" .. intf
  local vci = "vci_" .. intf
  if content_wan.wans_enable == "0" then
    local pattern = "^(%d+)%/(%d+)$"
    local data = { string.match(value, pattern) }
    if #data == 2 then
      object[vpi] = data[1]
      object[vci] = data[2]
      if intf == wanIntf and content_wan.proto == "pppoa" then
        object["wan_vpi"] = object[vpi]
        object["wan_vci"] = object[vci]
      end
      return true
    else
      return nil, T"Invalid VPI/VCI, it must be of the form 0/00"
    end
  else
    object[vpi] = nil
    object[vci] = nil
  end
  return true
end

local function validateVlanID(value, object, key)
  if content_wan.wans_enable == "0" then
    local pattern = "^(%d+)$"
    local number = { string.match(value, pattern) }
    if #number == 1 and tonumber(number[1]) >= 2 and tonumber(number[1]) <= 4094 then
      return true
    else
      return nil,  T"Invalid VLAN ID, it must be a number on the range 2-4094"
    end
  end
  return true
end

local cType = "PVC"
local mapParams, mapValid = {},{}
if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
  mapParams.iface = format("uci.network.interface.@%s.ifname", wanIntf)
  mapParams.dsl_status = "sys.class.xdsl.@line0.Status"
end
if post_helper.isFeatureEnabled("broadBandPVCConfig", role) then
  if mode_current == "ethernet" or mode_current == "vdsl" or mode_current == "vdslvlan" or mode_current == "ethernetvlan" then
    cType = "VLAN"
    if not post_helper.isFeatureEnabled("broadBandPVCMapParam", role) then
      mapParams.id_wan = "uci.network.device.@vlan_ppp.vid"
      mapParams.id_hfc = "uci.network.device.@vlan_hfc.vid"
    else
      local pathifname = format("uci.network.interface.@%s.ifname", wanIntf)
      local iface = proxy.get(pathifname)[1].value
      local vid, difname = "", ""
      if string.match(iface, "%.") then
        difname = string.match(iface, "eth4%.[%d]+")
        vid = string.match(difname, "[^eth4%.]+")
      end
    end
    if isVariantNovas then
      mapParams.id_voip = "uci.network.device.@vlan_voip.vid"
      mapParams.id_wan = nil
    end
    if not post_helper.isFeatureEnabled("broadBandPVCMapParam", role) then
      mapValid["id_hfc"] = validateVlanID
      mapValid["id_voip"] = validateVlanID
    else
      mapValid.id_wan = validateVlanID
    end
  else
    mapParams.wan_vpi = format("uci.network.interface.@%s.vpi", wanIntf)
    mapParams.wan_vci = format("uci.network.interface.@%s.vci" , wanIntf)
    mapParams.vpi_wan = "uci.xtm.atmdevice.@atm_ppp.vpi"
    mapParams.vci_wan = "uci.xtm.atmdevice.@atm_ppp.vci"
    mapParams.vpi_ipoe = "uci.xtm.atmdevice.@atm_ipoe.vpi"
    mapParams.vci_ipoe = "uci.xtm.atmdevice.@atm_ipoe.vci"

    if isVariantNovas then
      mapParams.vpi_ipoe = nil
      mapParams.vci_ipoe = nil
    end
    mapValid.vpi_wan = validatePvc
    mapValid.vci_wan = function (val, object)
      return true
    end
    mapValid.vpi_ipoe = validatePvc
    mapValid.vci_ipoe = function (val, object)
      return true
    end
    mapValid.wan_vpi = function (val, object)
      return true
    end
    mapValid.wan_vci = function (val, object)
      return true
    end
  end

  if post_helper.isFeatureEnabled("broadBandMTUConfig", role) then
    local mapParams_mtu = {
      wan_mtu = "uci.network.device.@eth4.mtu",
      atm_ppp_mtu = "uci.network.device.@atm_ppp.mtu",
      atm_ipoe_mtu = "uci.network.device.@atm_ipoe.mtu",
      ptm0_mtu = "uci.network.device.@ptm0.mtu"
    }

    local function validateMTU (value)
      local num = tonumber (value)
      if (num >= 1280 and num <= 1500) then
        return true
      end
      return nil,  T"MTU is invalid. It should be between 1280 and 1500"
    end
    local mapValid_mtu = {
      wan_mtu = validateMTU,
      ptm0_mtu = function(value,object)
        object["ptm0_mtu"] = object["wan_mtu"]
        return true
      end,
      atm_ppp_mtu = function(value,object)
        object["atm_ppp_mtu"] = object["wan_mtu"]
        return true
      end,
      atm_ipoe_mtu = function(value,object)
        object["atm_ipoe_mtu"] = object["wan_mtu"]
        return true
      end
    }

    for index, mtuVal in pairs(mapParams_mtu) do
      mapParams[index] = mtuVal
      mapValid[index] = mapValid_mtu[index]
    end
  end

  if not post_helper.isFeatureEnabled("broadBandWanSensing", role) then
    local mapParams_wansensing = {
      wans_enable = "uci.wansensing.global.enable",
      wans_l2type = "uci.wansensing.global.l2type",
      wans_l3type = "uci.wansensing.global.l3type",
      wan_ifname = format("uci.network.interface.@%s.ifname", wanIntf),
      wan_proto = format("uci.network.interface.@%s.proto", wanIntf),
      wan_metric = format("uci.network.interface.@%s.metric", wanIntf),
      wan_username = format("uci.network.interface.@%s.username", wanIntf),
      wan_password = format("uci.network.interface.@%s.password", wanIntf),
      wan_keepalive = format("uci.network.interface.@%s.keepalive", wanIntf),
      ipoe_auto = "uci.network.interface.@ipoe.auto",
      ppp_auto = "uci.network.interface.@ppp.auto",
      pppv_auto = "uci.network.interface.@pppv.auto",
      ipoe_ifname = "uci.network.interface.@ipoe.ifname",
      ppp_ifname = "uci.network.interface.@ppp.ifname",
      pppv_ifname = "uci.network.interface.@pppv.ifname",
      atm_ulp = "uci.xtm.atmdevice.@atm_ppp.ulp",
      atm_enc = "uci.xtm.atmdevice.@atm_ppp.enc",
      pppv_username = "uci.network.interface.@pppv.username",
      pppv_password = "uci.network.interface.@pppv.password"
    }

    if isVariantNovas then
      mapParams_wansensing.pppv_auto = nil
      mapParams_wansensing.pppv_ifname = nil
      mapParams_wansensing.pppv_username = nil
      mapParams_wansensing.pppv_password = nil
    end

    local function getValidateAuto(value, object, key)
      object[key] = object.wans_enable == '1' and nil or "0"
      return true
    end
    local function getValidateIfname(value, object, key)
      object[key] = object.wans_enable == '1' and nil or ""
      return true
    end

    local function validateL2L3type(value, object, key)
      object[key] = object.wans_enable == '1' and nil or ""
      return true
    end

    local wan_ppp = {
      username = "uci.network.interface.@ppp.username",
      password = "uci.network.interface.@ppp.password"
    }

    content_helper.getExactContent(wan_ppp)

    local mapValid_wansensing = {
      wans_enable = post_helper.validateBoolean,
      wans_l2type = validateL2L3type,
      wans_l3type = validateL2L3type,
      ipoe_auto = getValidateAuto,
      ppp_auto = getValidateAuto,
      pppv_auto = getValidateAuto,
      ipoe_ifname = getValidateIfname,
      ppp_ifname = getValidateIfname,
      pppv_ifname = getValidateIfname,
      atm_ulp = function(value, object, key)
        object[key] = object.wans_enable == '1' and "eth" or nil
        return true
      end,
      atm_enc = function(value, object, key)
        object[key] = object.wans_enable == '1' and "llc" or nil
        return true
      end,
      wan_proto = function(value, object, key)
        if (object.wans_enable == '0') then
          if object[key] == "" then
            object[key] = "pppoe"
            object.wan_metric = "10"
            object.wan_keepalive = "4,20"
            object.wan_username = wan_ppp.username
            object.wan_password = wan_ppp.password
            object.pppv_username = wan_ppp.username
            object.pppv_password = wan_ppp.password
          end
          if object.wan_ifname == "" then
            object.wan_ifname = "atm_ppp"
          end
        end
        return true
      end
    }

    for indexVal, row in pairs(mapParams_wansensing) do
      mapParams[indexVal] = row
      mapValid[indexVal] = mapValid_wansensing[indexVal]
    end
  end
  if next(mapParams) then
    content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  end
  if post_helper.isFeatureEnabled("broadBandPVCMapParam", role) and content then
    content["id_wan"] = vid
  end
end
if not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
  if content_wan.wans_enable == "1" and (mapParams.dsl_status ~= "Up" or string.match(mapParams.iface,"eth4")) then
    advancedMode = false
  else
    advancedMode = true
  end
end
if post_helper.isFeatureEnabled("broadBandWanLanPort", role) and role == "admin" and content_wan.sfp == "1" then
  advancedMode = true
end

-- Function to check whether any error message found during POST
-- @return true or false
local function errorFound()
  local checkUiMessages = true
  for _, err in ipairs(session:retrieve("uimessages") or {}) do
    if err.level == "error" then
      checkUiMessages = false
      message_helper.popMessages()
      message_helper.pushMessage(T"Some parameters failed validation", "error")
      break
    end
  end
  if checkUiMessages then
    message_helper.popMessages()
    message_helper.pushMessage(T"Changes saved successfully", "success")
  end
end
  ngx.print('\
');  
if not tabdata.current.ajax and tabdata.current.name ~= "bridge" then
-- only display if not doing an ajax request
  ngx.print('\
');  
    ngx.print(ui_helper.createHeader(T"Broadband", advancedMode, true))   ngx.print('\
  <div class = "modal-body update">\
    <form class = "form-horizontal" method = "post" action = "modals/broadband-modal.lp">\
      <div id="status_info"></div>\
    ');  
      if #availableConnections > 1 then
        -- Only included if there are 2 or more connection modes
        if post_helper.isFeatureEnabled("broadBandModalView", role) or (content_wan.wans_enable == "0" and not post_helper.isFeatureEnabled("broadBandModalPVC", role)) then  ngx.print('\
          <fieldset id="conn_mode" class="advanced hide">\
          ');  if post_helper.isFeatureEnabled("broadBandModalPVC", role) or (not post_helper.isFeatureEnabled("broadBandModalPVC", role) and content_wan.wans_enable == "0") then  ngx.print('\
            <legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
          ');  end
          local html = {}
          local mode_attributes = {
            radio = {
              class = "inline"
            },
            input = {
              class = "no-save",
              ["data-for"] = "SWITCH_MODE"
            }
          }
          local mode_button = {
            button = {
              ["data-name"] = "action",
              ["data-value"] = "SWITCH_MODE"
            }
          }
          if not post_helper.isFeatureEnabled("broadBandWanSensing", role) then  ngx.print('\
            ');  ngx.print(ui_helper.createSwitch(T"Auto WAN sensing","wans_enable", content_wan["wans_enable"])); ngx.print('\
          ');  end
          if role ~= "admin" or not post_helper.isFeatureEnabled("broadBandWanSensing", role) or not post_helper.isFeatureEnabled("broadBandModalPVC", role) then
            if content_wan.wans_enable == '0' then
              html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
              html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)
            elseif post_helper.isFeatureEnabled("broadBandModalPVC", role) then
              html[#html+1] = ui_helper.createLabel(T"Mode", mode_current_val)
            end
          else
            html[#html+1] = ui_helper.createLabel(T"Mode", mode_current_val)
          end
          ngx.print(html)
          if post_helper.isFeatureEnabled("broadBandMTUConfig", role) then  ngx.print('\
            <legend class = "advanced hide">');  ngx.print(  T"MTU configuration" ); ngx.print('</legend>\
         ');  ngx.print(ui_helper.createInputText(T"MTU", "wan_mtu", content["wan_mtu"], wan_mtu, helpmsg["wan_mtu"])); ngx.print('\
        ');  end  ngx.print('\
      </fieldset>\
   ');  end
   if content_wan.sfp == "1" and content_wan.wans_enable == "1" and content["ethsfp"] and content["ethsfp"] ~= "" then   ngx.print('\
       <fieldset id = "conn_mode" class = "advanced hide">\
         <legend>');  ngx.print( T"Set 4th Ethernet Port as WAN or as LAN" ); ngx.print('</legend>\
         ');  
         local adv = {
           values = {
             on = "0",
             off = "1"
           }
         }
         local html = {}
         html[#html + 1] = ui_helper.createSwitch(T"WAN-Mode", "ethsfp", content["ethsfp"], adv)
         ngx.print(html)
           ngx.print('\
       </fieldset>\
   ');  end
   if post_helper.isFeatureEnabled("broadBandPVCConfig", role) then
     local html = {}
     local attributes = { span = { class = "span3" } }
     if cType == "VLAN" and mode_current ~= "ethernet" and mode_current ~= "vdsl" then
       html[#html + 1] =  '<fieldset id="conn_mode" class="advanced hide">'
       html[#html + 1] = string.format([[<legend>%s</legend>]], T"VLAN configuration")
       if(content_wan["wans_enable"] == '0') then
         if isVariantNovas then
           if mode_current == "ethernetvlan" or mode_current == "vdslvlan" then
             html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_hfc", content["id_hfc"], attributes, helpmsg["id_hfc"])
             html[#html + 1] = ui_helper.createInputText(T"VLAN ID for VoIP", "id_voip", content["id_voip"], attributes, helpmsg["id_voip"])
           end
         else
           if mode_current == "vdslvlan" then
             html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_wan", content["id_wan"], attributes, helpmsg["id_wan"])
           elseif mode_current == "ethernetvlan" then
             html[#html + 1] = ui_helper.createInputText(T"VLAN ID for PPPoE", "id_hfc", content["id_hfc"], attributes, helpmsg["id_hfc"])
           end
         end
       else
         if isVariantNovas then
           if mode_current == "ethernetvlan" or mode_current == "vdslvlan" then
             html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_hfc"])
             html[#html + 1] = ui_helper.createLabel(T"VLAN ID for VoIP", content["id_voip"])
           end
         else
           if mode_current == "vdslvlan" then
             html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_wan"])
           elseif mode_current == "ethernetvlan" then
             html[#html + 1] = ui_helper.createLabel(T"VLAN ID for PPPoE", content["id_hfc"])
           end
         end
       end
       html[#html + 1] = '</fieldset>'
       elseif cType == "PVC" then
         local pvc = {}
         local intfs_over_pvc = { wanIntf, "ipoe" }
         for _, interface in ipairs(intfs_over_pvc) do
           local vpi = "vpi_" .. interface
           local vci = "vci_" .. interface
           if content[vpi] and content[vpi] ~= "" and content[vci] ~= "" then
             pvc[interface] = content[vpi] .. "/" .. content[vci]
           end
         end
         html[#html + 1] =  '<fieldset id = "conn_mode" class = "advanced hide">'
         html[#html + 1] = string.format([[<legend>%s</legend>]],T"PVC configuration")
         if(content_wan["wans_enable"] == '0') then
           if isVariantNovas then
             html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for PPPoE/PPPoA", "vpi_wan", pvc["wan"], attributes, helpmsg["vpi_wan"])
           else
             html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for PPPoE/PPPoA/IPoE", "vpi_wan", pvc["wan"], attributes, helpmsg["vpi_wan"])
             html[#html + 1] = ui_helper.createInputText(T"VPI/VCI for IPoE", "vpi_ipoe", pvc["ipoe"], attributes, helpmsg["vpi_ipoe"])
           end
         else
           if isVariantNovas then
             html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for PPPoE/PPPoA", pvc["wan"])
           else
             html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for PPPoE/PPPoA/IPoE", pvc["wan"])
             html[#html + 1] = ui_helper.createLabel(T"VPI/VCI for IPoE", pvc["ipoe"])
           end
         end
         html[#html + 1] = '</fieldset>'
       end
       ngx.print(html)
     end
   end
 end
 if tabdata.current.name == "bridge" then
   lp.setpath("/www/docroot/modals/")
   lp.include(tabdata.current.view)
 else
   lp.setpath("/www/snippets/")
   lp.include(tabdata.current.view)
 end

 if ngx.var.request_method == "POST" then
  errorFound()
 end
 status_info = ui_helper.createMessages(message_helper.popMessages())

 if not tabdata.current.ajax then
   -- only display if not doing an ajax request
  ngx.print('\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');  end   ngx.print('\
<script>\
$("#status_info").html(\'');  ngx.print(status_info); ngx.print('\');\
</script>\
'); 