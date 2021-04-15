--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local find, sub, match = string.find, string.sub, string.match
local floor = math.floor
local ngx = ngx
local proxy = require("datamodel")
local role = ngx.ctx.session:getrole()


-- Non-configurable data
local content = {
  vendor = "uci.env.var.company_name",
  product_name = "uci.env.var.prod_friendly_name",
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  firmware_version = "uci.env.var.friendly_sw_version_activebank",
  firmware_oid = "uci.version.version.@version[0].oid",
  bootloader_version = "uci.env.var.bootloader_version",
  bootloader_oid = "uci.env.var.bootloader_oid",
  hardware_version = "uci.env.var.hardware_version",
  serial_number = "uci.env.var.serial",
  mac_address = "uci.env.rip.eth_mac",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override",
  sys_mem_total = "sys.mem.RAMTotal",
  sys_mem_free = "sys.mem.RAMFree",
  sys_cpu_usage = "sys.proc.CPUUsage",
  sys_reboot_cause = "rpc.system.RebootCause",
}

if post_helper.isFeatureEnabled("productname", role) then
 content.product_name = "uci.env.var.variant_friendly_name"
end

content_helper.getExactContent(content)

local dsl_firmware = proxy.get('sys.class.xdsl.@line0.FirmwareVersion')  --custo, value for datapump NG-56123
if dsl_firmware then
  dsl_firmware = dsl_firmware[1].value
  content["dsl_firmware"] = dsl_firmware
end

local sys_memory = ((content["sys_mem_total"] - content["sys_mem_free"])/content["sys_mem_total"])*100
if sys_memory then
  sys_memory = match(sys_memory,"([%d]+)")
end

local rebootCause = {
  ["PWR"]   = T"Power",
  ["CLI"]   = T"Support",
  ["BOOTP"] = T"Support",
  ["CWMP"]  = T"Support",
  ["STS"]   = T"Support",
  ["TR64"]  = T"Support",
  ["GUI"]   = T"User Initiated",
  ["RTFD"]  = T"Factory Reset",
  ["UPGRADE"] = T"Upgrade",
  ["ROLLBACK"] = T"Upgrade",
  ["SWOVER"] = T"Upgrade",
  ["CRASH"]   = T"System Self",
  ["UERR"]   = T"System Self",
  ["WATCHDOG"]   = T"System Self",
  ["WANSENS"]   = T"System Self",
}

local rebootCauseStr = rebootCause[string.untaint(content["sys_reboot_cause"])]
if content["firmware_version"] then
  local version = content["firmware_version"]
  local newversion
  local pos=find(version, "%-[^%-]*$")
  if pos then
     newversion = sub(version, 1, pos-1)
  end
  if content.fwversion_override ~= "" then
    if content.fwversion_override == "override1" then
      pos=find(version, "%-")
      if pos then
         newversion = sub(version, 1, pos-1)
      end
    else
      newversion = content.fwversion_override
    end
  end
  if newversion then
     version = newversion
  end
  content["firmware_version"] = content.fwversion_prefix .. version .. content.fwversion_suffix
end
content["uptime"] = content_helper.readfile("/proc/uptime", "number", floor)

ngx.print(ui_helper.createHeader(T"System Information", true, true))
  ngx.print('\
\
<div class="modal-body update">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  lp.setpath("/www/snippets/")
  lp.include("tabs-system-info.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/system-info-modal.lp">\
  <fieldset>\
  <legend>');  ngx.print( T"Information" ); ngx.print('</legend>\
    ');  
      local basic = {
        span = {
          class = "span5"
        },
      }
      local advanced = {
        group = {
          class = "advanced hide",
        },
        span = {
          class = "span5"
        },
      }

      local html = {}
      html[#html + 1] = ui_helper.createLabel(T"Product Vendor", content["vendor"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Product Name", content["product_name"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Serial Number", content["serial_number"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Software Version", content["software_version"], basic)
      html[#html + 1] = ui_helper.createLabel(T"Uptime since last reboot", post_helper.secondsToTime(content["uptime"]), basic)
      html[#html + 1] = ui_helper.createLabel(T"Firmware Version", content["firmware_version"], advanced)
      if post_helper.isFeatureEnabled("firmwareoid", role) then
        if post_helper.isFeatureEnabled("dataPumpVersion", role) and content["dsl_firmware"] then
          html[#html + 1] = ui_helper.createLabel(T"Datapump Version", content["dsl_firmware"], advanced)
        end
        html[#html + 1] = ui_helper.createLabel( T"Firmware OID", content["firmware_oid"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Bootloader Version", content["bootloader_version"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Bootloader OID", content["bootloader_oid"], advanced)
      end
      html[#html + 1] = ui_helper.createLabel( T"Hardware Version", content["hardware_version"], advanced)
      html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["mac_address"], advanced)
      ngx.print(html)
      ngx.print('\
  </fieldset>\
  <fieldset class="advanced hide">\
  <legend>');  ngx.print( T"System Health" ); ngx.print('</legend>\
    ');  
      html = {}
      html[#html + 1] = ui_helper.createLabel(T"Memory Usage",  sys_memory.." %", advanced)
      html[#html + 1] = ui_helper.createLabel(T"CPU Usage", content["sys_cpu_usage"].." %", advanced)
      html[#html + 1] = ui_helper.createLabel(T"Reboot Cause", rebootCauseStr, advanced)
      ngx.print(html)
      ngx.print('\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 