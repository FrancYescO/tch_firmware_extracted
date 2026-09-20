--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local io, ngx, os = io, ngx, os
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local string = string
local session = ngx.ctx.session
local untaint, sub, find, format = string.untaint, string.sub, string.find, string.format
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local postHelper = require("web.post_helper")
local getContent = {
  mnemonic   = "uci.env.rip.board_mnemonic",
  serial     = "uci.env.var.serial",
  version    = "uci.version.version.@version[0].version",
  date       = "sys.time.CurrentLocalTime",
  upnp       = "uci.upnpd.config.enable_upnp",
}
content_helper.getExactContent(getContent)

local resetupnp = {
  reset_upnp = "uci.uci-defaults.upnp.upnp"
}
content_helper.getExactContent(resetupnp)

local date      = getContent.date
local fileNameToSave  = getContent.serial .. sub(date, 9,10) .. sub(date, 6,7) .. sub(date,1,4).. sub(getContent.version,1,9) .. ".bin"
local gatewayName = vdf_helper.productName()

if vdf_helper.getVariant() == "VF-UK" then
  computer = "an external device"
else
  computer = "a computer"
end

local function waitForCompletion(basePath, returnJson, fileName)
  local statePath = basePath .. "state"
  local infoPath  = basePath .. "info"
  local location  = basePath .. "location"
  local sleepTime = 0.250
  local maxTime   = 5
  local totalTime = 0
  local content
  repeat
    ngx.sleep(sleepTime)
    totalTime = totalTime + sleepTime
    content   = { state = statePath, info = infoPath, loc = location }
    content_helper.getExactContent(content)

    if content.state ~= "Requested" then
      break
    end
  until (totalTime >= maxTime)
  if fileName then
    os.remove(fileName)
  end
  if content.state ~= "Complete" then
    os.remove(untaint(content.loc) .. fileName)
    if content.state == "Requested" then
      ngx.log(ngx.ERR, "Timeout on ", basePath)
    else
      ngx.log(ngx.ERR, string.format('Error on %s (state="%s", info="%s")',
      basePath, content.state, content.info or ""))
    end
    if returnJson then
      ngx.print("error")
      ngx.exit(ngx.OK)
    else
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function exportConfig()
  local exportBasePath = "rpc.system.config.export."

  local content = {
    exportState    = exportBasePath .. "state",
    exportLocation = exportBasePath .. "location",
    exportFilename = exportBasePath .. "filename",
  }

  -- Get transformer content
  content_helper.getExactContent(content)

  if content.exportState ~= "Requested" then
    -- start new export request
    local uptime = content_helper.readfile("/proc/uptime", "number", floor)
    uptime       = tostring(uptime)
    content.exportFilename = string.format("config_export.%s", uptime)

    proxy.set({ [exportBasePath .. "filename"] = content.exportFilename })
    proxy.set({ [exportBasePath .. "state"] = "Requested" })
  end

  -- wait for completion; does not return on error or timeout
  waitForCompletion(exportBasePath)

  -- return exported data
  ngx.header.content_disposition = "attachment; filename=" .. untaint(fileNameToSave)
  ngx.header.content_type        = "application/octet-stream"
  ngx.header.set_cookie          = "fileDownload=true; Path=/"  -- the JS download code requires this cookie
  local export_path = untaint(content.exportLocation .. content.exportFilename)
  local f = io.open(export_path, "r")
  ngx.print(f:read("*all"))
  f:close()

  -- cleanup (reset state and remove export file)
  proxy.set({ [exportBasePath .. "filename"] = "" })

  -- and we're done
  ngx.exit(ngx.HTTP_OK)
end

local function receiveFile(filename, match)
  function doReceive(outfile, match)
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
    result, err_code, err_msg = doReceive(file, match)
  else
    file = io.open("/dev/null", "w")
    doReceive(file, match)
    result = false
    err_code = 4
    err_msg = "internal error"
  end

  file:close()
  return result, err_code, err_msg
end

local function importConfig()
  local importBasePath = "rpc.system.config.import."
  local filename      = "importconfig.bin"

  local content = {
    importState    = importBasePath .. "state",
    importLocation = importBasePath .. "location"
  }
  content_helper.getExactContent(content)
  if content.importState == "Requested" then
    ngx.log(ngx.ERR, "import already in progress")
    ngx.print('{ "error":"0" }')
    ngx.exit(ngx.OK)
  end

  local rcv_ok, rcv_errno, rcv_errmsg = receiveFile(untaint(content.importLocation) .. filename, 'name="configfile"')

  if not rcv_ok then
    ngx.log(ngx.ERR, rcv_errmsg)
    ngx.print('{ "error":"' .. rcv_errno .. '" }')
    ngx.exit(ngx.OK)
  end

  -- start actual import through rpc
  proxy.set({ [importBasePath .. "filename"] = filename })
  proxy.set({ [importBasePath .. "state"] = "Requested" })

  -- wait for completion
  waitForCompletion(importBasePath, true, filename)
  ngx.print('{ "success":"true" }')
  -- import is completed; reboot by scheduling a timer so
  -- we can still get our response out
  ngx.timer.at(0, function()
    proxy.set({ ["rpc.system.reboot"] = "GUI" })
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function reset(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

local function saveUPnP(value)
  local valid = postHelper.validateBoolean(value)
  if valid then
    proxy.set("uci.upnpd.config.enable_upnp", value)
    proxy.apply()
    ngx.header.content_type = "application/json"
    ngx.print('{"status":"success"}')
  else
    ngx.print('{status:"error"}')
  end
end

if ngx.req.get_method() == "POST" then
  if ngx.req.get_uri_args().action == "import_config" then
    importConfig()
  end
  if ngx.req.get_post_args() then
    if ngx.req.get_post_args().action == "ConfigSave" then
      local pass_save = ngx.req.get_post_args().savehash
      proxy.set("uci.system.config.export_commonkey",pass_save)
      proxy.apply()
    elseif ngx.req.get_post_args().action == "ConfigLoad" then
      local pass_load = ngx.req.get_post_args().loadhash
      proxy.set("uci.system.config.import_commonkey",pass_load)
      proxy.apply()
    elseif ngx.req.get_post_args().action == "exportConfig" then
      exportConfig()
    elseif ngx.req.get_post_args().action == "system_reset" then
      reset("rpc.system.reset", "1")
    elseif ngx.req.get_post_args().action == "system_restart" then
      proxy.set({ ["rpc.system.reboot"] = "GUI" })
      proxy.apply()
    elseif ngx.req.get_post_args().action == "SAVE" then
      saveUPnP(ngx.req.get_post_args().upnp)
    end
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "GET" then
  session:store("isUpload",true)
  if ngx.req.get_uri_args().getstatus == "true" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"progress" }')
    ngx.exit(ngx.HTTP_OK)
  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<h1><span>');  ngx.print(T"Configuration"); ngx.print('</span></h1>\
');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
<h2>');  ngx.print(("Save your settings, restore previously-saved settings, and reset your " .. gatewayName .." to its factory state.")); ngx.print('\
<br><br>');  ngx.print(("Your " .. gatewayName .. " can save your configuration to " .. computer .. ". We recommend that you always save your last-changed settings to " .. computer .. ".")); ngx.print('\
');  else   ngx.print('\
<h2>');  ngx.print(T("Save your settings, restore previously saved settings, and reset your " .. gatewayName .." to its factory state.")); ngx.print('\
<br><br>');  ngx.print(T("Your " .. gatewayName .. " can save your configuration to " .. computer .. ". We recommend to always save your last changed settings to " .. computer .. ".")); ngx.print('</h2>\
');  end   ngx.print('\
<h3>');  ngx.print(T"Configuration"); ngx.print('</h3>\
\
');  
  local row = {
    {
      label = vdf_helper.getVariant() == "VF-UK" and T"Save your settings to an external device with password protection" or T"Save settings to computer",
      element = ui_helper.createClickButton({
        class = "button button-blank mob-button-width config-btn-save",
        id = "config_btn_save",
        value = T"Save",
        type = "button"
      }),
      rowClass = "vdf-row no-margin-left-right config-mobile-full"
    }, {
      label = vdf_helper.getVariant() == "VF-UK" and T"Restore your settings from a configuration saved on an external device" or T"Restore settings from a configuration saved on a computer",
      element = ui_helper.createClickButton({
        class = "button button-blank mob-button-width config-btn-load",
        id = "config-btn-loadConfig",
        value = T"Load",
        type = "button"
      })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile settings-config vdf-table led-padding-50"))
  ngx.print('\
\
<h3>');  ngx.print(T"Factory Settings"); ngx.print('</h3>\
\
');  
  row = {
    {
      label = T("Reset restores the factory default settings of your " .. gatewayName .." and forces a restart."),
      element = ui_helper.createClickButton({
        class = "button button-blank mob-button-width config-btn-reset",
        id = "config-btn-reset",
        value = T"Reset",
        type = "button"
      }),
      rowClass = "vdf-row no-margin-right config-mobile-full"
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile settings-config vdf-table"))
  ngx.print('\
\
');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
  <h3>');  ngx.print(T"Restart"); ngx.print('</h3>\
\
  ');  
    row = {
      {
        label = T"Perform Restart",
        element = ui_helper.createClickButton({
          class = "button button-blank mob-button-width config-btn-reset",
          id = "config-btn-restart",
          value = T"Restart",
          type = "button"
        }),
        rowClass = "vdf-row no-margin-right config-mobile-full",
        labelClass = "line-height-24"
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile settings-config vdf-table"))
    ngx.print('\
\
  <h3>');  ngx.print(T"UPNP"); ngx.print('</h3>\
    <div class="h3-content">\
      <div class= "row no-border-bottom">\
        <h2 class= "left mobile-no-padding-top">\
           <span>');  ngx.print(T"Universal Plug and Play (UPnP) permits networked devices, such as personal computers, printers, Internet gateways, Wi-Fi access points and mobile devices to seamlessly discover each other's presence on the network and establish functional network services for data sharing, communications, and entertainment"); ngx.print('</span>\
        </h2>\
      </div>\
    </div>\
  <form id="upnp_form" class="form-horizontal" method="post" action="modals/settings/configuration.lp">\
    <input type="hidden" name="upnp" id="upnp-txt-statusEnable" value="');  ngx.print(getContent.upnp); ngx.print('">\
    <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('">\
    <input type="hidden" name="action" id="action" value="SAVE">\
    ');  
    local row = {
      {
        label = T"UPNP",
        element = ui_helper.createButton({
          id = "upnp-btn-statusEnable",
          class = getContent.upnp == "1" and "pull-right button button-on" or "pull-right button button-off"
        })
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))
      ngx.print('\
  </form>\
\
');  end  ngx.print('\
\
<div class="modal fade" id="restart-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title tL">%s</p>', T"Restart"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Are you sure you want to restart?"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = format('<div class="modal-footer">%s %s</div>', ui_helper.createClickButton({
                  value = T"Apply",
                  class = "button button-apply mob-button-width",
                  id = "restart-btn-apply",
                  type= "button"
                }), ui_helper.createClickButton({
                  id = "restart-btn-cancel",
                  class = "button button-cancel close-password-popup mob-apply-cancel mob-button-width",
                  value = T"Cancel",
                  type= "button",
                  ["data-dismiss"] = "modal"
                })
              ),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade" id="restart-inprogress-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          <div class="col-sm-12 col-md-12 col-lg-12">\
            <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading...">\
          </div>\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Restart in Progress"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = T("Please do not switch off your " .. gatewayName .. "."),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="saveEasy-inprogress-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
              <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body">\
                <form class="form-horizontal">\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-sm-12 col-md-12 col-lg-12 text-center">\
                            <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
                            <p class="title text-left">');  ngx.print(T"Saving Configuration"); ngx.print('</p>\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
<div class="modal fade config-modal" id="loadFromComp-inprogress-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
              <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body">\
               <form class="form-horizontal">\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="line-height-24">');  ngx.print(T"Before you restore an old configuration make sure you saved the current settings."); ngx.print('</p>\
                        </div>\
                    </div>\
                    ');  
                      row = {
                        label = format('%s %s %s', ui_helper.createClickButton({
                            style = "display: none;",
                            class = "uploadFile",
                            type = "file"
                          }),
                          ui_helper.createClickButton({
                            id = "config-btn-fileUpload",
                            class = "button button-apply mob-button-width button-ok",
                            value = T"OK",
                            type = "button"
                          }),
                          ui_helper.createClickButton({
                            id = "config-btn-cancelupload",
                            class = "button button-cancel mob-button-width mob-apply-cancel",
                            value = T"Cancel",
                            type = "button",
                            ["data-dismiss"] = "modal"
                          })
                        ),
                        rowClass = "row apply-cancel-hr no-margin-right",
                        colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
                      }
                      ngx.print(ui_helper.createSingleRow(row))
                      ngx.print('\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
<div class="modal fade config-modal" id="loadFromComp-inprogress-modal2" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body mobile-span-bold">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Load Configuration from Computer"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            local rows = {
              {
                label = ui_helper.createOnlyText({}, T"Created on"),
                element = ui_helper.createOnlyText({
                  id = "config-span-loaddate"
                }),
                rowClass = "form-group padding-top-bottom-20 no-margin-bottom",
                colLeftClass = "col-sm-6 col-md-6",
                colRightClass = "col-sm-6 col-md-6 text-right"
              }, {
                label = ui_helper.createOnlyText({}, T"Firmware version"),
                element = ui_helper.createOnlyText({
                  id = "config-span-loadversion"
                }),
                rowClass = "form-group padding-top-bottom-20 no-margin-bottom",
                colLeftClass = "col-sm-6 col-md-6",
                colRightClass = "col-sm-6 col-md-6 text-right"
              }
            }
            ngx.print(ui_helper.createMultipleRows(rows))

            row = {
              label = format('%s %s', ui_helper.createClickButton({
                  id = "config-btn-loadFile",
                  class = "button button-apply mob-button-width config-btn-load",
                  value = T"Load",
                  type = "button"
                }),
                ui_helper.createClickButton({
                  id = "cancelLoadButton",
                  class = "button button-cancel mob-button-width mob-apply-cancel",
                  value = T"Cancel",
                  type = "button",
                  ["data-dismiss"] = "modal"
                })
              ),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="loadFromComp-inprogress-modal3" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" /><p class="title">%s</p>', T"Configuration Restoration in Progress"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T("Do not turn off your " .. gatewayName .. ".")),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="loadFromComp-inprogress-modal4" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Configuration Restored Successfully"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Please press OK to continue."),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createClickButton({
                id = "loadSuccess",
                class = "button button-apply mob-button-width button-ok",
                type = "button",
                value = T"OK"
              }),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="config-invalid-format" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Importing failed; Invalid file used: expected file with extension bin. Please use correct file."),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Please press OK to continue."),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createClickButton({
                id = "config-invalid-fileok",
                class = "button button-apply mob-button-width",
                type = "button",
                value = T"OK"
              }),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="config-wrong-format" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Importing failed; please try again."),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Please press OK to continue."),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createClickButton({
                id = "config-wrong-fileok",
                class = "button button-apply mob-button-width",
                type = "button",
                value = T"OK"
              }),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="factory-reset-modal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Factory Reset"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T("Are you sure you want to reset your " .. gatewayName .." to the default factory settings?")),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = format('%s %s', ui_helper.createClickButton({
                  value = T"Apply",
                  class = "button button-apply mob-button-width",
                  id = "config-btn-resetapply",
                  type= "button"
                }), ui_helper.createClickButton({
                  id = "config-btn-resetcancel",
                  class = "button button-cancel mob-button-width mob-apply-cancel",
                  value = T"Cancel",
                  type= "button",
                  ["data-dismiss"] = "modal"
                })
              ),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="factory-inprogress-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body">\
                <form class="form-horizontal">\
                    <div class="col-sm-12 col-md-12 col-lg-12">\
                      <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading...">\
                    </div>\
                    ');  
                      row = {
                        label = format('<p class="title">%s</p>', T"Configuration Restoration in Progress"),
                        rowClass = "form-group no-margin-bottom",
                        colClass = "col-md-12 col-sm-12 col-lg-12"
                      }
                      ngx.print(ui_helper.createSingleRow(row))

                      row = {
                        label = ui_helper.createOnlyText({}, T("Do not turn off your " .. gatewayName .. ".")),
                        rowClass = "form-group no-margin-bottom",
                        colClass = "col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20"
                      }
                      ngx.print(ui_helper.createSingleRow(row))
                      ngx.print('\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
<div class="modal fade config-modal" id="factory-successfully-modal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Configuration Restored Successfully"),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Please press OK to continue."),
              rowClass = "form-group no-margin-bottom",
              colClass = "col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createClickButton({
                id = "loadSuccess",
                class = "button button-apply mob-button-width button-ok",
                type = "button",
                value = T"OK"
              }),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
\
<div class="modal fade config-modal" id="factory-successfully-modal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body">\
        <form class="form-horizontal">\
          ');  
            row = {
              label = format('<p class="title">%s</p>', T"Configuration Restored Successfully"),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createOnlyText({}, T"Please press OK to continue."),
              rowClass = "form-group",
              colClass = "col-sm-12"
            }
            ngx.print(ui_helper.createSingleRow(row))

            row = {
              label = ui_helper.createClickButton({
                id = "factorySuccess",
                class = "button button-apply mob-button-width",
                type = "button",
                value = T"OK"
              }),
              rowClass = "row apply-cancel-hr no-margin-right",
              colClass = "col-md-12 col-sm-12 col-xs-12 no-padding-right"
            }
            ngx.print(ui_helper.createSingleRow(row))
            ngx.print('\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade config-modal" id="savepassword-inprogress-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body">\
                <form class="form-horizontal">\
                    <div class="form-group no-margin-bottom savepassword-table">\
                        <div class="col-sm-12 col-md-12 col-lg-12">\
                            <p class="title text-left">');  ngx.print(T"Save Configuration to Computer"); ngx.print('</p>\
                        </div>\
                        ');  
                          row = {
                            label = format('<label>%s</label>', T"Create a password to protect your data."),
                            rowClass = "vdf-row",
                            colClass = "left pad-top-bottom-10",
                            colId = "createpassword"
                          }
                          ngx.print(ui_helper.createSingleRow(row))

                          row = {
                            label = format('<label id="savepasswordword">%s</label>', T"New Password"),
                            element = ui_helper.createInputButton({
                              id = "savepasswordtext",
                              placeholder = T"Password",
                              type="password",
                              name="new_pwd"
                              }),
                          }
                          ngx.print(ui_helper.createRow(row))

                          row = {
                            label = format('<label id="saverepassword">%s</label>', T"Re-enter Password"),
                            element = ui_helper.createInputButton({
                              id = "saverepasswordtext",
                              class = "text text-apply mob-button-width",
                              placeholder = T"Password",
                              type="password",
                              name="cnf_pwd"
                              }),
                          }
                          ngx.print(ui_helper.createRow(row))
                          ngx.print('\
                        <div class="vdf-row" style="display:table;">\
                          <div class="left config-left-top" style="width: 59%;">\
                            <span>');  ngx.print(T"Password Strength"); ngx.print('</span>\
                          </div>\
                          <div class="right mobile-no-padding-left pad-top-bottom-10">\
                             <div id="passStrength" class="passwordStrength strength0">\
                                <span id="password-span-strwk" class = "show">');  ngx.print(T"Weak"); ngx.print('</span>\
                                <span id="password-span-strgd" class = "hide">');  ngx.print(T"Good"); ngx.print('</span>\
                                <span id="password-span-strsg" class = "hide">');  ngx.print(T"Strong"); ngx.print('</span>\
                             </div>\
                          </div>\
                        </div>\
                        <div class="vdf-row" style="display:table;">\
                          <div class="left" style="width:59%;">\
                          </div>\
                          <div class="right mobile-no-padding-left" style="padding-top:0px;">\
                            <div id="statement" class="statementclas" style="text-align: left;">\
                              <span id="password-span-strwkstat" class="show">');  ngx.print(T"Weak passwords are not accepted"); ngx.print('</span>\
                            </div>\
                          </div>\
                      </div>\
                        <div class="table-wrapper">\
                           <div class="message message-info message-error not-8-characterss"  id = "password-msg-infopwdstd" style="display: block;">\
                              ');  ngx.print(T"The password must be at least 8 characters and must contain at least three of the four following character sets: lower case letter, upper case letter, number or symbol"); ngx.print('\
                           </div>\
                        </div>\
                        <div class="message message-info message-error not-similiar" id ="savepassword-msg-errpwdmatch" style="display: none;">\
                             ');  ngx.print(T"The passwords you entered do not match."); ngx.print('\
                        </div>\
                        <div class="message message-info message-error min-security" id ="savepassword-msg-security" style="display: none;">\
                             ');  ngx.print(T"The password you have entered doesn't meet the minimum security requirements."); ngx.print('\
                        </div>\
                        <div class="apply-cancel">\
                           <input id="savepasswordSuccess" class="button button-apply save op40 mob-button-width" value=');  ngx.print(T"Save"); ngx.print(' type="button">\
                           <input id="savepasswordcancel" class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" value=');  ngx.print(T"Cancel"); ngx.print(' type="button">\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
<div class="modal fade config-modal" id="loadpassword-inprogress-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body">\
                <form class="form-horizontal">\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-sm-12 col-md-12 col-lg-12">\
                            <p class="title text-left">');  ngx.print(T"Enter password to load the configuration"); ngx.print('</p>\
                        </div>\
                        ');  
                          row = {
                            label = format('<label>%s</label>', T"This configuration file is password protected. Please type your assigned password in."),
                            rowClass = "vdf-row",
                            colClass = "left config-file-password"
                          }
                          ngx.print(ui_helper.createSingleRow(row))

                          row = {
                            label = format('<label id="loadpasswordword">%s</label>', T"Enter Password"),
                            element = ui_helper.createInputButton({
                              id = "loadpasswordtext",
                              placeholder = T"Password",
                              type="password"
                              }),
                            rowClass = "vdf-row loadpasswordword"
                          }
                          ngx.print(ui_helper.createRow(row))
                          ngx.print('\
                        <div class="apply-cancel">\
                          <input id="loadpasswordSuccess" class="button button-apply save mob-button-width op40" value=');  ngx.print(T"Apply"); ngx.print(' type="button">\
                          <input id="loadpasswordcancel" class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" value=');  ngx.print(T"Cancel"); ngx.print(' type="button">\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
');  
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
  ngx.print('\
<script>\
  var isDone           = false;\
  var isDoneImport     = false;\
  var date             = "";\
  var version          = "";\
  var fileReaderExists = false;\
  if(window.FileReader){\
    var reader = new FileReader();\
      if(window.reader.readAsBinaryString){\
        fileReaderExists = true;\
      }\
  }\
  function strength_refresh() {\
    $(\'#passStrength\').removeClass("strength1 strength2 strength3 strength4 strength5");\
    $("#password-span-strgd").removeClass("show").addClass("hide");\
    $("#password-span-strsg").removeClass("show").addClass("hide");\
    $("#password-span-strwk").removeClass("hide").addClass("show");\
    $(\'#passStrength\').addClass("passwordStrength strength0");\
    $("#password-span-strwkstat").removeClass("hide").addClass("show");\
    $("#savepasswordSuccess").addClass("op40");\
  }\
  function popup_resize() {\
   $("#savepassword-inprogress-modal .modal-dialog").attr("id","config-top-701");\
   $("#savepassword-inprogress-modal .modal-content").attr("id","config-padding-top-9");\
   $("#createpassword").addClass("config-padding-top-bottom-1819");\
   $("#savepassword-inprogress-modal .right,#savepassword-inprogress-modal .left ").addClass("config-left-right");\
  }\
  $(function() {\
    $("#config-btn-loadConfig").click(function() {\
      $(\'#loadFromComp-inprogress-modal\').modal();\
    });\
    $("#config-btn-reset").click(function() {\
      $(\'#factory-reset-modal\').modal();\
    });\
    $("#factorySuccess").click(function() {\
      $(\'#factory-successfully-modal\').modal(\'hide\');\
    });\
    $("#config-btn-restart").click(function() {\
      $(\'#restart-modal\').modal();\
    });\
    var target = "modals/settings/configuration.lp";\
    $("#config_btn_save").click(function() {\
      $(\'#savepassword-inprogress-modal\').modal();\
      $("#savepasswordtext").keyup(function() {\
        var password = $(\'#savepasswordtext\').val();\
        if (vdfVariant == "VF-UK") {\
          levelIndicator(passwordCheckUK(password));\
        }\
        else {\
          levelIndicator(passwordCheck(password));\
        }\
      });\
      $("#savepasswordcancel").click(function() {\
        $(\'#savepassword-inprogress-modal\').modal(\'hide\');\
        $("#savepasswordtext, #saverepasswordtext").removeClass(\'input-error\');\
        strength_refresh();\
      });\
      $("#savepasswordSuccess").click(function() {\
        var pass = $(\'#savepasswordtext\').val();\
        var repass = $(\'#saverepasswordtext\').val();\
        $(".not-similiar").css("display", "none");\
        if (( pass != repass) || (pass == "" && repass == "")) {\
          $(\'#savepassword-inprogress-modal\').modal();\
          popup_resize();\
          $("#savepasswordtext, #saverepasswordtext").addClass(\'input-error\');\
          if (pass != repass) {\
            $(".not-similiar").css("display", "block");\
          }\
          if (pass != "" && repass == "") {\
            $("#savepasswordtext").removeClass(\'input-error\');\
            $("#saverepasswordtext").addClass(\'input-error\').focus();\
            $(".not-similiar").css("display", "none");\
          }\
          else if ( pass == "" && repass != "") {\
            $("#saverepasswordtext").removeClass(\'input-error\');\
            $("#savepasswordtext").addClass(\'input-error\').focus();\
            $(".not-similiar").css("display", "none");\
          }\
        }\
        else {\
          var pass = $(\'#savepasswordtext\').val();\
          if (pass.length < 8) {\
             $(\'#savepassword-inprogress-modal\').modal();\
             $(".min-security").css("display", "block");\
          }\
          else {\
            pass = "');  ngx.print(getContent.mnemonic); ngx.print('".concat(pass);\
            var hashObj = new jsSHA(pass, "TEXT");\
            pass = hashObj.getHash("SHA-1", "HEX");\
            pass = "VF".concat(pass);\
            $.post("/modals/settings/configuration.lp", {\
              action: "ConfigSave",\
              savehash: pass,\
              CSRFtoken: $("meta[name=CSRFtoken]").attr("content")\
            });\
            $(\'#savepassword-inprogress-modal\').modal(\'hide\');\
            $.fileDownload(target, {\
              httpMethod: "POST",\
              data: new Array({ name : "action", value : "exportConfig" },\
                              { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" }),\
              failCallback: function() {\
              window.location("/");\
              }\
            });\
            $(\'#saveEasy-inprogress-modal\').modal();\
            setTimeout(function() {\
              $(\'#saveEasy-inprogress-modal\').modal(\'hide\');\
            }, 3000);\
          }\
        }\
      });\
      pass = $(\'#savepasswordtext\').val("");\
      repass = $(\'#saverepasswordtext\').val("");\
      $("#savepasswordtext, #saverepasswordtext").removeClass(\'input-error\');\
      $(".not-similiar").css("display", "none");\
      $(".min-security").css("display", "none");\
      strength_refresh();\
    });\
    $("#savepassword-inprogress-modal" ).on(\'shown.bs.modal\', function (e) {\
      popup_resize();\
    });\
    $("#config-invalid-fileok").click(function(){\
      $(\'.uploadFile\').val(\'\');\
      $("#config-invalid-format").modal(\'hide\');\
      $("#config-span-loadversion").text(\'\');\
      $("#config-span-loaddate").text(\'\');\
    });\
    $("#config-wrong-fileok").click(function(){\
      $(\'.uploadFile\').val(\'\');\
      $("#config-span-loadversion").text(\'\');\
      $("#config-span-loaddate").text(\'\');\
      $("#config-wrong-format").modal(\'hide\');\
    });\
    $("#config-btn-fileUpload").click(function(){\
      $(\'.uploadFile\').trigger(\'click\');\
    });\
\
    $(\'.uploadFile\').change(function() {\
      $(\'#loadFromComp-inprogress-modal\').modal(\'hide\');\
      $(\'#loadpassword-inprogress-modal\').modal();\
      $("#loadpasswordSuccess").click(function() {\
        var passload = $(\'#loadpasswordtext\').val();\
        passload = "');  ngx.print(getContent.mnemonic); ngx.print('".concat(passload);\
        var hashObj = new jsSHA(passload, "TEXT");\
        passload = hashObj.getHash("SHA-1", "HEX");\
        passload = "VF".concat(passload);\
        $.post("/modals/settings/configuration.lp", {\
          action: "ConfigLoad",\
          loadhash: passload,\
          CSRFtoken: $("meta[name=CSRFtoken]").attr("content")\
        });\
        $(\'#loadpassword-inprogress-modal\').modal(\'hide\');\
        if ($(\'.uploadFile\').val()) {\
          var fileName = $(\'.uploadFile\')[0].files[0].name;\
          var file = $(\'.uploadFile\')[0].files[0];\
          var extensionPattern = new RegExp(/.+\\.bin$/);\
          var numberPattern = /^[0-9]+$/;\
          if (extensionPattern.test(fileName)) {\
            $(\'#loadFromComp-inprogress-modal\').modal(\'hide\');\
            $(\'#loadFromComp-inprogress-modal2\').modal(\'show\');\
            var dateFromName = fileName.substring(11,13);\
            var monthFromName = fileName.substring(13,15);\
            var yearFromName = fileName.substring(15,19);\
            var fileSerialNumber = fileName.substring(0,11);\
            if((numberPattern.test(dateFromName) == true) && (dateFromName <= "31") && (numberPattern.test(monthFromName) == true) && (monthFromName <= "12") && (numberPattern.test(yearFromName) == true) && (fileSerialNumber == "');  ngx.print(getContent.serial); ngx.print('"))\
            {\
              date = (dateFromName + "/" + monthFromName + "/" + yearFromName);\
              $("#config-span-loaddate").text(date);\
            }\
            if(fileReaderExists == true) {\
              var reader = new FileReader();\
              reader.onload = function(progressEvent){\
                var versions=this.result.substring(0,241);\
                var lines = versions.split(\'\\n\');\
                  for(var line = 0; line < lines.length; line++) {\
                    if (lines[line].indexOf("BUILDVERSION") == 0) {\
                      version = lines[line].substring(13,22);\
                      $("#config-span-loadversion").text(version);\
                    }\
                  }\
              };\
              reader.readAsBinaryString(file);\
            }\
            else {\
              if((fileName.substring(21,22) == ".") && (fileName.substring(23,24) == ".") && (fileSerialNumber == "');  ngx.print(getContent.serial); ngx.print('"))\
              {\
                version = fileName.substring(19,28);\
                $("#config-span-loadversion").text(version);\
              }\
            }\
          }\
          else{\
            $("#config-invalid-format").modal();\
            $(\'.uploadFile\').val(\'\');\
            return;\
          }\
        }\
      });\
     });\
  function passwordcheck(pass) {\
    if (pass.length >=8 && pass.length <=63 && pass.match(/^[\\x20-\\xFE]+$/)) {\
      return true;\
    }\
    else\
      return false;\
  }\
  $("#loadpasswordtext").keyup(function(){\
    var pass = $(\'#loadpasswordtext\').val();\
    passwordcheck(pass);\
    if (passwordcheck(pass)) {\
      $("#loadpasswordSuccess").removeClass("op40");\
    }\
   else\
    $("#loadpasswordSuccess").addClass("op40");\
  });\
  $("#loadpasswordcancel").click(function() {\
    $(\'#loadpassword-inprogress-modal\').modal(\'hide\');\
    $("#config-invalid-format").modal(\'hide\');\
  });\
  $("#cancelLoadButton").click(function(){\
    $("#config-span-loadversion").text(\'\');\
    $("#config-span-loaddate").text(\'\');\
    $(\'.uploadFile\').val(\'\');\
  });\
  $("#config-btn-loadFile").click(function(){\
    $(\'#loadFromComp-inprogress-modal2\').modal(\'hide\');\
    $(\'#loadFromComp-inprogress-modal3\').modal();\
    var file_data = $(".uploadFile").prop("files")[0];\
    var form_data = new FormData();\
    form_data.append("CSRFtoken", "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('");\
    form_data.append("configfile", file_data)\
    $.ajax({\
      url: "modals/settings/configuration.lp?action=import_config",\
      dataType: \'script\',\
      cache: false,\
      contentType: false,\
      processData: false,\
      data: form_data,\
      type: \'post\'\
    }).complete(function(responseTxt){\
      if (responseTxt.responseText == "error") {\
        $(\'#loadFromComp-inprogress-modal3\').modal(\'hide\');\
        $("#config-wrong-format").modal();\
        return;\
      }\
      else {\
        getStatus("/modals/settings/configuration.lp?getstatus=true");\
      }\
    });\
  });\
  function getStatus(target){\
    $.get(target, function(responseTxt, statusTxt, xhr){\
      if ( isDoneImport || !(responseTxt.status) ) {\
        $(\'#loadFromComp-inprogress-modal3\').modal(\'hide\');\
        $(\'#loadFromComp-inprogress-modal4\').modal();\
        $("#loadSuccess").click(function(){\
        window.location = "/";\
        return;\
        });\
      } else\
      {\
        window.setTimeout(function(){\
        getStatus("modals/settings/configuration.lp?getstatus=true");\
        }, 5000);\
      }\
      }).fail(function(data) {\
        isDoneImport = true;\
        window.setTimeout(function(){\
          getStatus("/")}, 5000);\
        });\
  }\
\
// Code for reset\
  $("#config-btn-resetapply").click(function() {\
    $(\'#factory-reset-modal\').modal(\'hide\');\
    $(\'#factory-inprogress-modal\').modal();\
    var params = [];\
    var target = "/modals/settings/configuration.lp"\
    params.push({\
      name : "action",\
      value : "system_reset"\
      },{\
      name : "CSRFtoken",\
      value : "');  ngx.print(CSRFtoken); ngx.print('"\
      });\
      $.post(target,params);\
        getStatusReset("/modals/settings/configuration.lp?getstatus=true");\
  });\
\
  function getStatusReset(target) {\
    $.get(target, function(responseTxt, statusTxt, xhr){\
      if ( isDone || !(responseTxt.status) ) {\
        $(\'#factory-inprogress-modal\').modal(\'hide\');\
        $("#loadFromComp-inprogress-modal4").modal(\'show\');\
        $("#loadSuccess").click(function(){\
          window.location = "/";\
          return;\
        });\
        } else {\
          window.setTimeout(function() {\
          getStatusReset("/modals/settings/configuration.lp?getstatus=true");\
          }, 5000);\
        }\
    }).fail(function(data) {\
      isDone = true;\
      window.setTimeout(function(){\
      getStatusReset("/")}, 5000);\
    });\
  }\
  $("#restart-btn-apply").click(function() {\
     $(\'#restart-modal\').modal(\'hide\');\
     $(\'#restart-inprogress-modal\').modal();\
     var params = [];\
     var target = "/modals/settings/configuration.lp"\
     params.push({\
       name : "action",\
       value : "system_restart"\
       },{\
       name : "CSRFtoken",\
       value : "');  ngx.print(CSRFtoken); ngx.print('"\
       });\
       $.post(target,params);\
       getStatusReset("/modals/settings/configuration.lp?getstatus=true");\
  });\
  $("#upnp-btn-statusEnable").click(function(){\
    $(this).hasClass(\'button-on\') ? $("#upnp-txt-statusEnable").val("0") : $("#upnp-txt-statusEnable").val("1");\
    $(this).toggleClass("button-on button-off");\
  });\
\
  $("#global-apply").click(function() {\
   postHandler("/modals/settings/configuration.lp", $("#upnp_form").serializeArray(), true);\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  function resetButtonState(id, value, hiddenId) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenId).val("1");\
    } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenId).val("0");\
    }\
  }\
    resetButtonState("#upnp-btn-statusEnable", ');  ngx.print(resetupnp["reset_upnp"]); ngx.print(', "#upnp-txt-statusEnable");\
});\
\
\
</script>\
<script src="js/global-min.js"></script>\
'); 