--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local format, find, untaint = string.format, string.find, string.untaint
local floor, ipairs = math.floor, ipairs
local session = ngx.ctx.session
local role = session:getrole()
local process = require 'tch.process'
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "SystemInfo", "configuration")

local resetrtfdValue = "true"
if post_helper.isFeatureEnabled("resetReboot", role) then
  resetrtfdValue = "false"
end
local system_time = os.date("%F %T", os.time())

local function wait_for_completion(base_path, return_json, filename)
  local state_path = base_path .. "state"
  local info_path = base_path .. "info"
  local sleep_time = 0.250
  local max_time = 5
  local total_time = 0
  local content
  repeat
    ngx.sleep(sleep_time)
    total_time = total_time + sleep_time

    content = { state = state_path, info = info_path }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (total_time >= max_time)
  if filename then
    os.remove(filename)
  end
  if content.state ~= "Complete" then
    if content.state == "Requested" then
      ngx.log(ngx.ERR, "Timeout on ", base_path)
    else
      ngx.log(ngx.ERR, format('Error on %s (state="%s", info="%s")',
      base_path, content.state, content.info or ""))
    end
    if return_json then
      ngx.print('{ "error":"10" }')
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function export_config()
  local export_rpc_path = "rpc.system.config.export."
  local content = {
    export_state = export_rpc_path .. "state",
    export_location = export_rpc_path .. "location",
    export_filename = export_rpc_path .. "filename"
  }
  content_helper.getExactContent(content)

  if content.export_state ~= "Requested" then
    -- start new export request
    local uptime = content_helper.readfile("/proc/uptime", "number", floor)
    content.export_filename = format("config_export.%d", uptime)

    proxy.set({ [export_rpc_path .. "filename"] = content.export_filename })
    proxy.set({ [export_rpc_path .. "state"] = "Requested" })
  end

  -- wait for completion; does not return on error or timeout
  wait_for_completion(export_rpc_path)

  -- return exported data
  ngx.header.content_disposition = "attachment; filename=config.bin"
  ngx.header.content_type = "application/octet-stream"
  ngx.header.set_cookie = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local export_path = untaint(content.export_location .. content.export_filename)
  local fileOpen = io.open(export_path, "r")
  ngx.print(fileOpen:read("*all"))
  fileOpen:close()

  -- cleanup (reset state and remove export file)
  proxy.set({ [export_rpc_path .. "filename"] = "" })

  -- and we're done
  ngx.exit(ngx.HTTP_OK)
end

local function receive_file(filename, match)
  function do_receive(outfile, match)
    local upload = require("web.fileupload")
    local form, err = upload.fromstream()
    if not form then
      return false, 1, "failed to create upload ctx: " .. err
    end
    local totalsize = 0
    local file
    local discard = false
    while true do
      local token, data, err = form:read()
      if not token then
        return false, 2, "read failed: " .. err
      end
      if token == "header" then
        if not discard and not file and find(data[2], match, 1, true) then
          file = outfile
        end
        if not discard and not file then
          return false, 3, "failed to start receiving file"
        end
      elseif token == "body" then
        if file then
          totalsize = totalsize + #data
          file:write(data)
        end
      elseif token == "part_end" then
        if file then
          file = nil
          discard = true
        end
      elseif token == "eof" then
        break
      end
    end
    return true
  end

  local file = io.open(filename, "w")
  local result, err_code, err_msg
  if file then
    result, err_code, err_msg = do_receive(file, match)
  else
    file = io.open("/dev/null", "w")
    do_receive(file, match)
    result = false
    err_code = 4
    err_msg = "internal error"
  end

  file:close()

  return result, err_code, err_msg
end

local function import_config()
  local import_rpc_path = "rpc.system.config.import."
  local filename = "importconfig.bin"

  local content = {
    import_state = import_rpc_path .. "state",
    import_location = import_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.import_state == "Requested" then
    ngx.log(ngx.ERR, "import already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  local rcv_ok, rcv_errno, rcv_errmsg = receive_file(untaint(content.import_location) .. filename, 'name="configfile"')

  if not rcv_ok then
    ngx.log(ngx.ERR, rcv_errmsg)
    ngx.print('{ "error":"' .. rcv_errno .. '" }')
    ngx.exit(ngx.OK)
  end

  -- start actual import through rpc
  proxy.set({ [import_rpc_path .. "filename"] = filename })
  proxy.set({ [import_rpc_path .. "state"] = "Requested" })

  -- wait for completion
  wait_for_completion(import_rpc_path, true, filename)
  ngx.print('{ "success":"true" }')
  -- import is completed; reboot by scheduling a timer so
  -- we can still get our response out
  ngx.timer.at(0, function()
    proxy.set({ ["rpc.system.reboot"] = "GUI" })
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefw()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."
  local filename = "fwupgrade.bin"
  local content = {
    fwupgrade_state = fwupgrade_rpc_path .. "state",
    fwupgrade_location = fwupgrade_rpc_path .. "location"
  }
  content_helper.getExactContent(content)
  if content.fwupgrade_state == "Requested" then
    ngx.log(ngx.ERR, "upgrade already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  -- flush the web template cache
  lp.flush()

  local dl = untaint(content.fwupgrade_location) .. filename
  process.execute("mkfifo", {dl})
  process.execute("rm", {"-f", dl})

  -- start actual upgrade through rpc
  -- sysupgrade will create the pipe
  -- separate requests as the order is important
  proxy.set({[fwupgrade_rpc_path .. "filename"] = filename})
  proxy.set({[fwupgrade_rpc_path .. "state"] = "Requested"})

  -- force GC to run to try to prevent lua from taking more memory during
  -- the upgrade action by having it reclaim some unused objects. This won't
  -- shrink the linux memory usage, but it might prevent it from becoming
  -- even bigger.
  collectgarbage()
  receive_file(dl, 'name="upgradefile"')
  ngx.print('{ "success":"true" }')
  ngx.exit(ngx.HTTP_OK)
end

local function upgradefwstatus()
  local fwupgrade_rpc_path = "rpc.system.fwupgrade."

  local state = proxy.get(fwupgrade_rpc_path .. "state")[1].value

  ngx.header.content_type = "application/json"
  if state == "Requested" then
    ngx.print('{ "success":"true" }')
  else
    local content = {}
    local results = proxy.get(fwupgrade_rpc_path)
    for _, result in ipairs(results) do
      content[result.param] = result.value
    end

    os.remove(untaint(content.location .. content.filename))
    ngx.print('{ "success":"false" , "errorcode":"' .. untaint(content.errorcode) .. '" }')
  end

  ngx.exit(ngx.HTTP_OK)
end

local function resetReboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function schedulerebootset(scheduledatetime)
  proxy.set("rpc.system.scheduledreboot",scheduledatetime)
  proxy.set("uci.system.scheduledreboot.enabled","1")
  proxy.set("rpc.system.scheduledrebootreason","GUI")
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  upgradefw = "uci.web.uiconfig.@uidefault.upgradefw",
}
content_helper.getExactContent(cui)

-- Handle fwupgrade/configimport/configexport specific GET/POSTs.
if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_uri_args().action
  -- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  if action == "import_config" then
    return import_config()
  end
  if action == "upgradefw" then
    if not post_helper.isUpgradeAllowed(cui.upgradefw, role) then
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    return upgradefw()
  end
  -- now process non-file POSTs
  action = ngx.req.get_post_args().action
  if action == "export_config" then
    return export_config()
  end
  if action == "system_reset" then
    local soft_rtfd = proxy.get("uci.env.var.rtfds")
    if soft_rtfd and soft_rtfd[1].value == "0" then
      proxy.set("uci.env.var.rtfda", "1")
    end
    return resetReboot("rpc.system.reset", "1")
  end
  if action == "system_softReset" then
    proxy.set("uci.env.var.rtfds", "1")
    return resetReboot("rpc.system.reset", "1")
  end
  if action == "system_reboot" then
    return resetReboot("rpc.system.reboot", "GUI")
  end
  if action == "schedulerebootset" then
    return schedulerebootset(ngx.req.get_post_args().paramvalue)
  end
  if action == "system_bootp" then
    return resetReboot("sys.bootp.enable", "1")
  end
elseif ngx.req.get_method() == "GET" then
  local action = ngx.req.get_uri_args().action
  local content = {
    fwflash_size = "uci.env.var.banksize"
  }
  content_helper.getExactContent(content)

  if action == "upgradefwstatus" and post_helper.isUpgradeAllowed(cui.upgradefw, role) then
    return upgradefwstatus()
  end
  if action == "getbanksize" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true", "banksize":"' .. untaint(content.fwflash_size) .. '" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

-- Non-configurable data
local content = {
  schedule_reboot_get = "uci.system.scheduledreboot.enabled",
}
content_helper.getExactContent(content)

ngx.print(ui_helper.createHeader(T"Configuration", true, true))
  ngx.print('\
\
<div class="modal-body update">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  lp.setpath("/www/snippets/")
  lp.include("tabs-system-info.lp")
  local wait_for_reboot = {
    group = {
      class = "wait-for-reboot"
    },
    button = {
      id = "btn-system-reboot",
      class = "custom-handler"
    }
  }
  local schedule_reboot = {
    group = {
      class = "wait-for-reboot"
    },
    button = {
      id = "btn-schedule-reboot",
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
  local wait_for_softReset = {
    group = {
      class = "wait-for-softReset"
    },
    button = {
      id = "btn-system-softReset",
      class = "custom-handler"
    }
  }
  local export_config_button = {
    button = {
      class = "export-config custom-handler"
    }
  }
  local import_config = {
    button = {
      class = "import-config custom-handler",
      id = "btn-import"
    }
  }
  local upgradefw = {
    button = {
      class = "upgradefw",
      id = "btn-upgrade"
    }
  }
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/system-config-modal.lp">\
');  if post_helper.isFeatureEnabled("systemConfiguration", role) then
  local hideConfiguration = post_helper.getVariantValue(variantHelper, "hideConfiguration")
  if not hideConfiguration or (hideConfiguration and session:getrole() == "engineer") then   ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
      ');  
        local html = {}
        html[#html + 1] = ui_helper.createButton(T"Export Configuration", T"Export", "icon-download-alt", export_config_button)
        html[#html + 1] = ui_helper.alertAttributes(T"Exporting configuration, please wait...", "alert-info hide", "exporting-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Exporting failed; please try again.", "alert-error hide", "export-failed-msg")
        html[#html + 1] = '</form><form class="form-horizontal" id="form-import" method="post" action="modals/system-config-modal.lp?action=import_config" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Import Configuration")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="file" name="configfile" id="file-import">&nbsp;'
        html[#html + 1] = ui_helper.createSimpleButton(T"Import", "icon-upload-alt", import_config)
        html[#html + 1] = '</div></div>'
        html[#html + 1] = ui_helper.alertAttributes(T"No file selected.", "alert-error hide", "import-nofile-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing configuration, please wait...", "alert-info hide", "importing-msg")
        html[#html + 1] = ui_helper.alertAttributes( T"Importing failed; please try again.", "alert-error hide", "import-failed-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing failed; Invalid file used: " .. T"expected file with extension bin.  Please use correct file.", "alert-error hide", "import-wrong-ext-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing failed; Invalid file used: " .. T"file too large. Please use correct file..", "alert-error hide", "import-too-big-msg")
        ngx.print(html)
        ngx.print('\
    </fieldset>\
  ');  end   ngx.print('\
');  end   ngx.print('\
</form>\
<form class="form-horizontal" method="post" action="modals/system-config-modal.lp">\
  <fieldset>\
  <legend>');  ngx.print( T"Reset & Reboot" ); ngx.print('</legend>\
    ');  
      local html = {}
      html[#html + 1] = ui_helper.alertAttributes(T"Restarting, please wait...", "alert hide", "rebooting-msg")
      html[#html + 1] = ui_helper.createButton(T"Restart Device", T"Restart", "icon-refresh", wait_for_reboot)
      html[#html + 1] = ui_helper.alertAttributes(T"Resetting to factory defaults, please wait...","alert hide", "resetting-msg")
      html[#html + 1] = ui_helper.createButton(T"Factory Defaults", T"Reset", "icon-bolt", wait_for_reset)
      if post_helper.isFeatureEnabled("softReset", role) then
        html[#html + 1] = ui_helper.alertAttributes(T"Soft Resetting to defaults, please wait...", "alert hide", "resetting-msg")
        html[#html + 1] = ui_helper.createLabelWithButton("", "", T"Semi-Reset", "icon-bolt", wait_for_softReset, T"This function will reset all configuration except user settings.")
      end
      if post_helper.isFeatureEnabled("schedulereboot", role) then
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Schedule Reboot")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="date"  name="date_schedule" id="date_schedule" ><input type="time" value="00:00"  name="time_schedule" id="time_schedule">&nbsp;'
        html[#html + 1] =  ui_helper.createSimpleButton(T"Schedule Reboot", "icon-time", schedule_reboot)
        html[#html + 1] = ui_helper.alertAttributes(T"Schedule failed :  please select correct Time and date.", "alert-error hide", "schedule-failed-msg")
        html[#html + 1] = '<label class="schedule_message_get hide">A Reboot has been Scheduled</label>'
        html[#html + 1] = '</div></div>'
      end
      ngx.print(html)
      ngx.print('\
  </fieldset>\
</form>\
');  if post_helper.isUpgradeAllowed(cui.upgradefw, role) or post_helper.isFeatureEnabled("bootp", role) then   ngx.print('\
  <fieldset>\
    ');  
      local html = {}
      if post_helper.isUpgradeAllowed(cui.upgradefw, role) then   ngx.print('\
        <legend>');  ngx.print( T"Local Upgrade" ); ngx.print('</legend>\
        ');  
        html[#html + 1] = '</form><form class="form-horizontal" id="form-upgradefw" method="post" action="modals/system-config-modal.lp?action=upgradefw" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>',  T"Upgrade firmware")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="file" name="upgradefile" id="file-upgradefw">&nbsp;'
        html[#html + 1] = ui_helper.createSimpleButton(T"Upgrade", "icon-shield", upgradefw)
        html[#html + 1] = '</div></div>'
        html[#html + 1] = ui_helper.alertAttributes(T"No file selected.", "alert-error hide", "upgrade-nofile-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Uploading firmware, please wait...", "alert hide", "upgrade-transfer-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Firmware upgrade in progress, please wait...", "alert hide", "upgrade-busy-msg")
        html[#html + 1] = ui_helper.alertAttributes("", "alert-error hide", "upgrade-failed-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Firmware upgrade failed." .. " " ..T"Invalid file used: expected file with extension rbi.  Please use correct firmware.", "alert-error hide", "upgrade-wrong-ext-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Firmware upgrade failed." .. " " ..T"Invalid file used: file too large.  Please use correct firmware.", "alert-error hide", "upgrade-too-big-msg")
      end
      if post_helper.isFeatureEnabled("bootp", role) then
        html[#html + 1] = '<div class="control-group advanced hide custom-handler" id="btn-system-bootp">'
        html[#html + 1] = ui_helper.createButton(T"LAN Upgrade", T"BOOTP", "icon-exchange")
        html[#html + 1] = '<div class="alert alert-info hide" id="bootp-msg">'
        html[#html + 1] = ui_helper.createAlertBlock(T"Entering BOOTP, please wait...")
        html[#html + 1] = '</div></div>'
      end
      ngx.print(html)
      ngx.print('\
  </fieldset>\
');  end   ngx.print('\
</form>\
</div>\
<script>\
  var schedule_reboot_get = "');  ngx.print(content["schedule_reboot_get"]); ngx.print('";\
  var system_time = "');  ngx.print(system_time); ngx.print('";\
  var resetrtfdValue = "');  ngx.print(resetrtfdValue); ngx.print('";\
var T = {\
   "upgrading" : "');  ngx.print(T'Upgrading...'); ngx.print('",\
   "lanUpgradeMsg" : "');  ngx.print(T'This will put your gateway into LAN Upgrade'); ngx.print('",\
   "lanUpgrade" : "');  ngx.print(T'LAN Upgrade'); ngx.print('",\
   "reboot" : "');  ngx.print(T'Rebooting...'); ngx.print('",\
   "confirmmsg" : "');  ngx.print(T'Do you want to continue?'); ngx.print('",\
   "factoryDefaults" : "');  ngx.print(T'Factory Defaults'); ngx.print('",\
   "resetting" : "');  ngx.print(T'Resetting'); ngx.print('",\
   "upgradeFailed" : "');  ngx.print(T'Firmware upgrade failed.'); ngx.print('",\
   "errorCode" : "');  ngx.print(T'Errorcode:'); ngx.print('",\
   "upgrading" : "');  ngx.print(T'Upgrading...'); ngx.print('",\
   "restartDev" : "');  ngx.print(T'Restart Device'); ngx.print('",\
   "noFreeMemory" : "');  ngx.print(T'Insufficient free memory available. Please reboot and try again.'); ngx.print('",\
   "incorrectFirmware" : "');  ngx.print( T'please use the correct firmware.'); ngx.print('",\
   "wrongKey" : "');  ngx.print(T'build signed with wrong key'); ngx.print('"\
}\
\
</script>\
<script src="/js/system-config.js"></script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 