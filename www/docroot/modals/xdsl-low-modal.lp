--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local ngx, pairs, string, table = ngx, pairs, string, table
local format, match, untaint = string.format, string.match, string.untaint

local all_modes = {}
local dsl_modes = content_helper.convertResultToObject("uci.xdsl.xdsl.@dsl0.multimode.", proxy.get("uci.xdsl.xdsl.@dsl0.multimode."))
for _, v in pairs(dsl_modes) do
  all_modes[#all_modes + 1] = (string.format("%s", v.value))
end

table.sort(all_modes, function(a, b)
  return a<b
end)


if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  if postArgs["action"] == "SAVE" then
    local mode2prog = {}
    for _, modeValue in pairs(all_modes) do
      mode2prog[modeValue] = {prog = 0, found = 0 }
    end
    if type(postArgs["modes"])=="table" then
      for _, modesValue in pairs(postArgs["modes"]) do
        for mode2progKey, _ in pairs(mode2prog) do
          if mode2progKey == modesValue then
            mode2prog[format("%s", mode2progKey)].prog = 1
          end
        end
      end
    else
      for mode2progKey, _ in pairs(mode2prog) do
        if mode2progKey == postArgs["modes"] then
          mode2prog[format("%s", mode2progKey)].prog = 1
        end
      end
    end
    local modes_content = content_helper.getMatchedContent("uci.xdsl.xdsl.@dsl0.multimode.")
    for _, modesContentValue in pairs(modes_content) do
      local found = 0
      for mode2progKey, _ in pairs(mode2prog) do
        if modesContentValue.value == mode2progKey then
          mode2prog[format("%s", mode2progKey)].found = modesContentValue.path
          found = 1
          break
        end
      end
      if found == 0 then
        mode2prog[format("%s", modesContentValue.path)].found = modesContentValue.path
        mode2prog[format("%s", modesContentValue.path)].prog = 0
      end
    end
    for mode2progKey, mode2progValue in pairs(mode2prog) do
      proxy.get("uci.xdsl.xdsl.@dsl0.multimode.")
      if mode2progValue.prog == 1 and mode2progValue.found then
        proxy.set("uci.xdsl.xdsl.@dsl0.selectedmode", mode2progKey)
      end
    end
    proxy.apply()
  end
end

local content = {
  dsl0_enabled                    = "rpc.xdsl.status",
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
  dsl0_xdsl_FirmwareVersion       = "sys.class.xdsl.@line0.FirmwareVersion"
}

content_helper.getExactContent(content)

content.dsl0_enabled = (string.format("%s", content.dsl0_enabled)) ~= "Idle" and "1" or "0"

local state_map = {
  ["0"] = T"Disabled",
  ["1"] = T"Enabled"
}

local light_map = {
  ["0"] = "off",
  ["1"] = "green"
}
local list
local function listContent(content)
  list = nil
  table.sort(content, function(a, b)
    return match(a.path, "@(%d)")< match(b.path, "@(%d)")
  end)
  for _, contentValue in pairs (content) do
    if not list then
      list = format("%s", contentValue.value)
    else
      list = format("%s, %s", list, contentValue.value)
    end
  end
end
local modes_content = content_helper.getMatchedContent("uci.xdsl.xdsl.@dsl0.multimode.")
listContent(modes_content)

local profiles_content = content_helper.getMatchedContent("uci.xdsl.xdsl.@dsl0.profile.")
listContent(profiles_content)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"xDSL Details", false, false))   ngx.print('\
<div class="modal-body update">\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))   ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"Core Settings" ); ngx.print('</legend>\
    <form class="form-horizontal" method="post" action="modals/xdsl-low-modal.lp">\
      ');  
      local span5 = { span = { class = "span5" } }
      ngx.print(
        ui_helper.createLight(T"Status", nil, state_map[content.dsl0_enabled], { light = { class = light_map[content.dsl0_enabled] } }),
        ui_helper.createLabel(T"Firmware Version", content.dsl0_xdsl_FirmwareVersion, span5 ),
        ui_helper.createLabel(T"EOC Vendor ID", content.dsl0_eoc_vendor_id, span5 ),
        ui_helper.createLabel(T"EOC Serial Number", content.dsl0_eoc_serial_number, span5 )
      )
      local html = {}
      html[#html + 1] = [[<div class="control-group"><label class="control-label">]]
      html[#html + 1] = T"Modes"
      html[#html + 1] = [[</label><div class="controls"><select multiple class="form-control" name="modes">]]
      for index = 1, #all_modes do
        local selected = ""
        for _, modesContentValue in pairs (all_modes) do
          if all_modes[index]  == (proxy.get("uci.xdsl.xdsl.@dsl0.selectedmode")[1].value) then
            selected = "selected"
          end
        end
        html[#html + 1] = format("<option name=\"%s\" %s>%s</option>", all_modes[index], selected, all_modes[index])
      end
      html[#html + 1] = [[  </select></div></div>]]
      ngx.print(html)
      ngx.print(
        ui_helper.createLabel(T"Profiles", list or "", span5),
        ui_helper.createLabel(T"HS Switch Timeout", content.dsl0_handshake_switch_timeout, span5 ),
        ui_helper.createLabel(T"Demod Cap Value", content.dsl0_demod_cap_value, span5 ),
        ui_helper.createLabel(T"Demod Cap Mask", content.dsl0_demod_cap_mask, span5 ),
        ui_helper.createLabel(T"2nd Demod Cap Value", content.dsl0_demod_cap2_value, span5 ),
        ui_helper.createLabel(T"2nd Demod Cap Mask", content.dsl0_demod_cap2_mask, span5 ),
        ui_helper.createLabel(T"Aux Features Value", content.dsl0_aux_features_value, span5 ),
        ui_helper.createLabel( T"Aux Features Mask", content.dsl0_aux_features_mask, span5 ),
        ui_helper.createLabel(T"VDSL Flags Value", content.dsl0_vdsl_cfg_flags_value, span5 ),
        ui_helper.createLabel(T"VDSL Flags Mask", content.dsl0_vdsl_cfg_flags_mask, span5 ),
        ui_helper.createLabel(T"Phy Extra Value", content.dsl0_xdsl_cfg1_value, span5 ),
        ui_helper.createLabel(T"Phy Extra Mask", content.dsl0_xdsl_cfg1_mask, span5 )
      )
        ngx.print('\
    </form>\
  </fieldset>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 