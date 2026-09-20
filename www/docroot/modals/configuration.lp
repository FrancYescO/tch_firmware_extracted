--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local io, ngx, os = io, ngx, os
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local string = string
local session = ngx.ctx.session
local untaint, sub, find = string.untaint, string.sub, string.find

local getContent = {
  serial     = "uci.env.var.serial",
  version    = "uci.version.version.@version[0].version",
  date       = "InternetGatewayDevice.Time.CurrentLocalTime"
}
content_helper.getExactContent(getContent)
local date      = getContent["date"]
local fileNameToSave  = getContent["serial"] .. sub(date, 9,10) .. sub(date, 6,7) .. sub(date,1,4).. sub(getContent["version"],1,9) .. ".bin"

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

if ngx.req.get_method() == "POST" then
  if ngx.req.get_method() then
    if ngx.req.get_uri_args().action == "import_config" then
      importConfig()
    end
  end
  if ngx.req.get_post_args() then
   if ngx.req.get_post_args().action == "exportConfig" then
      exportConfig()
    elseif ngx.req.get_post_args().action == "system_reset" then
     reset("rpc.system.reset", "1")
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
  ngx.print('\
<!DOCTYPE html>\
<html>\
  <head>\
    <script>\
      $(function () {\
        $(\'select\').chosen({\
          disable_search_threshold: 100000,\
          allow_single_deselect: true\
        });\
    });\
</script>\
\
        <h1><span>');  ngx.print(T"Configuration"); ngx.print('</span></h1>\
\
<h2>');  ngx.print(T"Save your settings, restore previously saved settings, and reset your Vodafone Ultra Hub to its factory state."); ngx.print('\
<br><br>');  ngx.print(T"Your Vodafone Ultra Hub can save your configuration to a computer. We recommend to always save your last changed settings to a computer."); ngx.print('</h2>\
\
            <h3>');  ngx.print(T"Configuration"); ngx.print('</h3>\
\
<div class="h3-content h3-content-mobile settings-config vdf-table">\
    <div class="vdf-row no-margin-left-right config-mobile-full">\
        <div class="left">\
            <span>');  ngx.print(T"Save settings to computer"); ngx.print('</span>\
        </div>\
        <div class="right">\
            <input class="button button-blank mob-button-width config-btn-save" id="config_btn_save" value="');  ngx.print(T"Save"); ngx.print('" type="button" />\
        </div>\
    </div>\
   <div class="vdf-row no-margin-right config-mobile-full">\
        <div class="left">\
            <span>');  ngx.print(T"Restore settings from a configuration saved on a computer"); ngx.print('</span>\
        </div>\
        <div class="right">\
            <input class="button button-blank mob-button-width config-btn-load" id="config-btn-loadConfig" value="');  ngx.print(T"Load"); ngx.print('" type="button" />\
        </div>\
    </div>\
</div>\
\
\
            <h3>');  ngx.print(T"Factory Settings"); ngx.print('</h3>\
\
<div class="h3-content h3-content-mobile settings-config vdf-table">\
    <div class="vdf-row no-margin-right config-mobile-full">\
        <div class="left">\
            <span class="line-height-24">');  ngx.print(T"Reset restores the factory default settings of your Vodafone Ultra Hub and forces a restart."); ngx.print('</span>\
        </div>\
        <div class="right">\
            <input class="button button-blank mob-button-width config-btn-reset" id="config-btn-reset" value= "');  ngx.print(T"Reset"); ngx.print('"  type="button" />\
        </div>\
    </div>\
</div>\
<div class="h3-content h3-content-mobile settings-config">\
&nbsp;\
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
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                           <input style="display: none;" class="uploadFile" type="file" />\
                            <input id="config-btn-fileUpload" class="button button-apply mob-button-width button-ok" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                            <input id="config-btn-cancelupload" class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal">\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="title">');  ngx.print(T"Load Configuration from Computer"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group padding-top-bottom-20 no-margin-bottom">\
                        <div class="col-sm-6 col-md-6">\
                            <span>');  ngx.print(T"Created on"); ngx.print('</span>\
                        </div>\
                        <div class="col-sm-6 col-md-6 text-right">\
                            <span id = "config-span-loaddate"></span>\
                        </div>\
                    </div>\
                    <div class="form-group padding-top-bottom-20 no-margin-bottom">\
                        <div class="col-sm-6 col-md-6">\
                            <span>');  ngx.print(T"Firmware version"); ngx.print('</span>\
                        </div>\
                        <div class="col-sm-6 col-md-6 text-right">\
                            <span id = "config-span-loadversion"></span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                            <input id="config-btn-loadFile" class="button button-apply mob-button-width config-btn-load" value="');  ngx.print(T"Load"); ngx.print('" type="button">\
                            <input id="cancelLoadButton" class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Cancel"); ngx.print('"  type="button" data-dismiss="modal">\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." class="padding-top-bottom-20" />\
                            <p class="title">');  ngx.print(T"Configuration Restoration in Progress"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-bottom-20">\
                            <span>');  ngx.print(T"Do not turn off your Vodafone Ultra Hub."); ngx.print('</span>\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="title">');  ngx.print(T"Configuration Restored Successfully"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20">\
                            <span>');  ngx.print(T"Please press OK to continue."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                            <input id="loadSuccess" class="button button-apply mob-button-width button-ok" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                        </div>\
                    </div>\
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
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title">');  ngx.print(T"Importing failed; Invalid file used: expected file with extension bin. Please use correct file."); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <span>');  ngx.print(T"Please press OK to continue."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
                            <input id="config-invalid-fileok" class="button button-apply mob-button-width" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                        </div>\
                    </div>\
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
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title">');  ngx.print(T"Importing failed; please try again."); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <span>');  ngx.print(T"Please press OK to continue."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
                            <input id="config-wrong-fileok" class="button button-apply mob-button-width" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="title">');  ngx.print(T"Factory Reset"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20">\
                            <p><span>');  ngx.print(T"Are you sure you want to reset your Vodafone Ultra Hub to the default factory settings?"); ngx.print('</span>\
                            </p>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                            <input value="');  ngx.print(T"Apply"); ngx.print('" class="button button-apply mob-button-width" id="config-btn-resetapply" type="button">\
                            <input id="config-btn-resetcancel" class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal">\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="title">');  ngx.print(T"Configuration Restoration in Progress"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20">\
                            <span>');  ngx.print(T"Do not turn off your Vodafone Ultra Hub."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="progress">\
                        <div class="progress-bar progress-bar-striped active" role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width:100%; background-color: #a8b400;">\
                        </div>\
                    </div>\
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
                    <div class="form-group no-margin-bottom">\
                        <div class="col-sm-12">\
                            <p class="title">');  ngx.print(T"Configuration Restored Successfully"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20">\
                            <span>');  ngx.print(T"Please press OK to continue."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                            <input id="loadSuccess" class="button button-apply mob-button-width button-ok" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                        </div>\
                    </div>\
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
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title">');  ngx.print(T"Configuration Restored Successfully"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <span>');  ngx.print(T"Please press OK to continue."); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
                            <input id="factorySuccess" class="button button-apply mob-button-width" value="');  ngx.print(T"OK"); ngx.print('" type="button">\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
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
    var target = "modals/configuration.lp";\
    $("#config_btn_save").click(function() {\
      $(\'#saveEasy-inprogress-modal\').modal();\
      setTimeout(function() {\
        $(\'#saveEasy-inprogress-modal\').modal(\'hide\');\
      }, 3000);\
      $.fileDownload(target, {\
        httpMethod: "POST",\
        data: new Array({ name : "action", value : "exportConfig" },\
                      { name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" }),\
        failCallback: function() {\
        window.location("/");\
        }\
      });\
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
    })\
    $("#config-btn-fileUpload").click(function(){\
      $(\'.uploadFile\').trigger(\'click\');\
    });\
\
    $(\'.uploadFile\').change(function() {\
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
          if((numberPattern.test(dateFromName) == true) && (dateFromName <= "31") && (numberPattern.test(monthFromName) == true) && (monthFromName <= "12") && (numberPattern.test(yearFromName) == true) && (fileSerialNumber == "');  ngx.print(getContent["serial"]); ngx.print('"))\
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
              }}\
            };\
            reader.readAsBinaryString(file);\
          }\
          else {\
            if((fileName.substring(21,22) == ".") && (fileName.substring(23,24) == ".") && (fileSerialNumber == "');  ngx.print(getContent["serial"]); ngx.print('"))\
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
\
  $("#cancelLoadButton").click(function(){\
    $("#config-span-loadversion").text(\'\');\
    $("#config-span-loaddate").text(\'\');\
    $(\'.uploadFile\').val(\'\');\
  });\
  $("#config-btn-loadFile").click(function(){\
    $(\'#loadFromComp-inprogress-modal3\').modal();\
    $(\'#loadFromComp-inprogress-modal2\').modal(\'hide\');\
    var file_data = $(".uploadFile").prop("files")[0];\
    var form_data = new FormData();\
    form_data.append("CSRFtoken", "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('");\
    form_data.append("configfile", file_data)\
    $.ajax({\
      url: "modals/configuration.lp?action=import_config",\
      dataType: \'script\',\
      cache: false,\
      contentType: false,\
      processData: false,\
      data: form_data,\
      type: \'post\'\
    }).complete(function(responseTxt){\
      if(responseTxt.responseText == "error") {\
        $(\'#loadFromComp-inprogress-modal3\').modal(\'hide\');\
        $("#config-wrong-format").modal();\
        return;\
      } else {\
        getStatus("/modals/configuration.lp?getstatus=true");\
      }\
    });\
  });\
\
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
        getStatus("modals/configuration.lp?getstatus=true");\
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
    var target = "/modals/configuration.lp"\
    params.push({\
      name : "action",\
      value : "system_reset"\
      },{\
      name : "CSRFtoken",\
      value : "');  ngx.print(CSRFtoken); ngx.print('"\
      });\
      $.post(target,params);\
        getStatusReset("/modals/configuration.lp?getstatus=true");\
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
          getStatusReset("/modals/configuration.lp?getstatus=true");\
          }, 5000);\
        }\
    }).fail(function(data) {\
      isDone = true;\
      window.setTimeout(function(){\
      getStatusReset("/")}, 5000);\
    });\
  }\
});\
</script>\
'); 