--pretranslated: do not change this file

--[[
Version 1.2 xDSL Page 

  -Debug XDSL page 
  
  -- Made dynamic for external switch devices
  -- 1.1 Fixed teh multi select and single select issue raised by Michel Kester
  --      Also added the "BrcmPriv1" as an option for 35b 
  -- 1.2 Changeds for the 17.2 pretranslate
]]
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format,find,sub,untaint, match = string.format, string.find, string.sub, string.untaint, string.match
local floor, ipairs = math.floor, ipairs

local all_modes = {"adsl2", "adsl2annexl", "adsl2annexm", "adsl2plus", "gdmt", "glite", "t1413", "vdsl2"}

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local function validateModes (value, postdata)
  local function validateMode(x)
     local result = false
     for i=1,#all_modes do
         if all_modes[i] == x then
            result = true
         end
     end
     return result
  end
  
  
  
  if type(value)=="table" then                                                 
      for _, v in pairs(value) do
        if not validateMode(v) then
           return nil, ""
        end
      end
  else
      if not validateMode(value) then
         return nil, ""
      end
  end
  return true
end

local dsldiag_Params = {
      dsldiag                 = "sys.dsldiag.Enable",
      
}

local dsldiag_valid = {
      dsldiag            = post_helper.validateBoolean,
      modes              = validateModes,
}
local dsldiag_Params, helpmsg = post_helper.handleQuery(dsldiag_Params, dsldiag_valid)        
if ngx.var.request_method == "POST" then
    local vars = ngx.req.get_post_args()
    if vars["action"] == "SAVE" then
      local mode2prog = {}
      for _, v in pairs(all_modes) do
         mode2prog[v] = {prog = 0, found = 0 }
      end
      if type(vars["modes"])=="table" then
          for _, x in pairs(vars["modes"]) do
            for k,_ in pairs(mode2prog) do
               if k == x then
                  mode2prog[format("%s",k)].prog = 1
               end
            end    
          end
      else
          for k,_ in pairs(mode2prog) do
             if k == vars["modes"] then
                mode2prog[format("%s",k)].prog = 1
             end
          end 
      end
      local modes_content = content_helper.getMatchedContent ("uci.xdsl.xdsl.@dsl0.multimode.")
      for _,v in pairs(modes_content) do
        
         local found = 0 
          for k,w in pairs(mode2prog) do
            if v.value == k then
               mode2prog[format("%s",k)].found = v.path
               found = 1
            end
          end
          if found == 0  then
              
             mode2prog[format("%s",v.value)].found = v.path
             mode2prog[format("%s",v.value)].prog = 0 
          end
      end

      local todel = {}
      for k,v in pairs(mode2prog) do
         if v.prog == 1 and v.found == 0 then
               local addvalue = proxy.add("uci.xdsl.xdsl.@dsl0.multimode.")
               proxy.set("uci.xdsl.xdsl.@dsl0.multimode.@" .. addvalue .. ".value",k)
         elseif v.prog == 0 and v.found ~= 0 then
               todel[#todel+1] = v.found
         end
      end
      table.sort (todel, function (a, b) return a > b end )
      for k,v in pairs(todel) do
          proxy.del(v)
      end
    -- Check if switch configured for VLAN's 
    
      if #content_helper.getMatchedContent("uci.network.switch_vlan.") ~= 0 then
          local uci_lan_ports = proxy.get("uci.network.interface.@lan.ifname")[1].value
          local lan_ports = split(uci_lan_ports, " ")
          local eth0, eth1, eth2, eth3          
          if vars["dsldiag"] == "1" then
              for _, v in pairs(lan_ports) do
                if v == "eth0" then eth0 = true end
                if v == "eth1" then eth1 = true end
                if v == "eth2" then eth2 = true end
                if v == "eth3" then eth3 = true end
              end
              if not eth0 then lan_ports[#lan_ports+1] = "eth0" end
              if not eth1 then lan_ports[#lan_ports+1] = "eth1" end
              if not eth2 then lan_ports[#lan_ports+1] = "eth2" end
              if not eth3 then lan_ports[#lan_ports+1] = "eth3" end
              proxy.set("uci.network.switch.@bcmsw_ext.enable_vlan","0")
          else
              for k, v in pairs(lan_ports) do
                if v == "eth0" or v == "eth1" or v == "eth2" or v == "eth3" then lan_ports[k] = nil end   
              end
              proxy.set("uci.network.switch.@bcmsw_ext.enable_vlan","1")
          end
          local returnstr = ""
          for _, v in pairs(lan_ports) do
                returnstr = format("%s %s",returnstr,v) 
          end
          proxy.set("uci.network.interface.@lan.ifname",returnstr)

      end
      proxy.apply()
    end
end

local content = {
    dsl0_enabled                    = "uci.xdsl.xdsl.@dsl0.enabled",
    dsl0_eoc_vendor_id              = "uci.xdsl.xdsl.@dsl0.eoc_vendor_id",
    dsl0_eoc_serial_number          = "uci.xdsl.xdsl.@dsl0.eoc_serial_number",
    dsl0_handshake_switch_timeout   = "uci.xdsl.xdsl.@dsl0.handshake_switch_timeout",
    dsl0_demod_cap_value            = "uci.xdsl.xdsl.@dsl0.demod_cap_value",
    dsl0_demod_cap_mask             = "uci.xdsl.xdsl.@dsl0.demod_cap_mask",
    dsl0_demod_cap2_value           = "uci.xdsl.xdsl.@dsl0.demod_cap2_value",
    dsl0_demod_cap2_mask            = "uci.xdsl.xdsl.@dsl0.demod_cap2_mask",
    dsl0_aux_features_value         = "uci.xdsl.xdsl.@dsl0.aux_features_value",
    dsl0_aux_features_mask          = "uci.xdsl.xdsl.@dsl0.aux_features_mask",
    dsl0_vdsl_cfg_flags_value       = "uci.xdsl.xdsl.@dsl0.vdsl_cfg_flags_value",
    dsl0_vdsl_cfg_flags_mask        = "uci.xdsl.xdsl.@dsl0.vdsl_cfg_flags_mask",
    dsl0_xdsl_cfg1_value            = "uci.xdsl.xdsl.@dsl0.xdsl_cfg1_value",
    dsl0_xdsl_cfg1_mask             = "uci.xdsl.xdsl.@dsl0.xdsl_cfg1_mask",
    dsl0_xdsl_FirmwareVersion       = "sys.class.xdsl.@line0.FirmwareVersion",
}

content_helper.getExactContent(content)

local xDSL_State = "Disabled"
if content.dsl0_enabled == "1" then
   xDSL_State = "Enabled"
end

local state_map = {
    Disabled = T"Disabled",
    Enabled = T"Enabled",
}

local light_map = {
  Disabled = "off",
  Enabled = "green",
}


local modes_content = content_helper.getMatchedContent ("uci.xdsl.xdsl.@dsl0.multimode.")

local mode_list = nil
for _, v in pairs (modes_content) do
  if not mode_list then
      mode_list = format("%s",v.value)
  else
      mode_list = format("%s, %s",mode_list,v.value)
  end
end

local profiles_content = content_helper.getMatchedContent ("uci.xdsl.xdsl.@dsl0.profile.")
table.sort(profiles_content, function(a,b)
         return match(a.path, "@(%d)")< match(b.path, "@(%d)")
      end)
local profile_list = nil
for _, v in pairs (profiles_content) do
  if not profile_list then
      if v.value == "BrcmPriv1" then
        profile_list = format("%s","35b")                                            
      else
        profile_list = format("%s",v.value)
      end
  else
      if v.value == "BrcmPriv1" then
        profile_list = format("%s, %s",profile_list,"35b")
      else 
        profile_list = format("%s, %s",profile_list,v.value)
      end
  end
end

local title = T"xDSL Details"

ngx.print(ui_helper.createHeader(title, false, false), '\
<div class="modal-body update">',
ui_helper.createMessages(message_helper.popMessages()), '\
<fieldset>\
  <legend>', T"Core Settings", '</legend>\
    <form class="form-horizontal" method="post" action="modals/xdsl-low-modal.lp">');
      local span5 = { span = { class = "span5" } }
      local html = {}
      html[#html + 1] = ui_helper.createLight(T"Status", nil, state_map[xDSL_State], { light = { class = light_map[xDSL_State] } })
      html[#html + 1] = ui_helper.createSwitch(T"Enable dsldiagd", "dsldiag",  dsldiag_Params["dsldiag"], {input = {class = "monitor-changes",}})
      local diag_warning = {
              alert = {
                  class = "alert-danger monitor-dsldiag monitor-1 "
              },
          }
      html[#html + 1] = ui_helper.createAlertBlock(T"ONLY FOR EXPERT USE - THE SYSTEM MAY BECOME UNSTABLE - THE DIAGTOOL WILL NOT SURVIVE A REBOOT, BUT THE OTHER CHANGES WILL, IF ISSUES ARE FOUND PLEASE FACTORY RESET THE CPE", diag_warning)
      html[#html + 1] = ui_helper.createLabel(T"Firmware Version",content.dsl0_xdsl_FirmwareVersion, span5 )
      html[#html + 1] = ui_helper.createLabel(T"EOC Vendor ID",content.dsl0_eoc_vendor_id, span5 )
      html[#html + 1] = ui_helper.createLabel(T"EOC Serial Number",content.dsl0_eoc_serial_number, span5 )
      
      html[#html + 1] = [[<div class="control-group"><label class="control-label">]]
      html[#html + 1] = T"Modes"
      html[#html + 1] = [[</label><div class="controls"><select multiple class="form-control" name="modes">]]
      for i=1,#all_modes do
          local selected = ""
          for _, w in pairs (modes_content) do
                if all_modes[i]  == w.value then 
                  selected = "selected"
                end 
          end
          html[#html + 1] = format("<option name=\"%s\" %s>%s</option>",all_modes[i],selected,all_modes[i])
      end
      html[#html + 1] = [[  </select></div></div>]]
      html[#html + 1] = ui_helper.createLabel(T"Profiles",profile_list,span5 )
      html[#html + 1] = ui_helper.createLabel(T"HS Switch Timeout",content.dsl0_handshake_switch_timeout, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Demod Cap Value",content.dsl0_demod_cap_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Demod Cap Mask",content.dsl0_demod_cap_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"2nd Demod Cap Value",content.dsl0_demod_cap2_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"2nd Demod Cap Mask",content.dsl0_demod_cap2_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Aux Features Value",content.dsl0_aux_features_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Aux Features Mask",content.dsl0_aux_features_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"VDSL Flags Value",content.dsl0_vdsl_cfg_flags_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"VDSL Flags Mask",content.dsl0_vdsl_cfg_flags_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Phy Extra Value",content.dsl0_xdsl_cfg1_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Phy Extra Mask",content.dsl0_xdsl_cfg1_mask, span5 )
      
      ngx.print(html, '\
    </form>\
  </fieldset>\
</div>',
ui_helper.createFooter());
