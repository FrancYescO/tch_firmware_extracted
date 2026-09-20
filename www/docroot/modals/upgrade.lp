--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  local ngx = ngx
  local collectgarbage = collectgarbage
  local proxy = require("datamodel")
  local content_helper = require("web.content_helper")
  local session = ngx.ctx.session
  local lp = require("web.lp")
  local string = string
  local untaint = string.untaint
  local get_from_transformer = {
    ["firmware-version"] = "InternetGatewayDevice.DeviceInfo.SoftwareVersion",
  }
  content_helper.getExactContent(get_from_transformer)
  session:store("isUpload", true)

  local function receive_file(filename)
    local upload = require("web.fileupload")
    local form, form_err = upload.fromstream()
    if not form then
      return false, 1, "failed to create upload ctx: " .. form_err
    end
    local file, token, data, errMsg
    -- parse through various sections of POST request for valid firmware information
    while token ~= "eof" do
      token, data, errMsg = form:read()
      if not token then
        return false, 3, "no information read: " .. errMsg
      end
      if token == "header" then
        if not file and string.find(data[2], 'name="upgradefile"', 1, true) then
          file = io.open(filename, "w")
          if not file then
            return false, 4, "could not create download file"
          end
        end
      elseif token == "body" then
        if file then
          file:write(data)
        end
      elseif token == "part_end" then
        if file then
          file:close()
          break
        end
      end
    end
    return true
  end

  local function upgradefw()
    local fwupgrade_rpc_path = "rpc.system.fwupgrade."
    local filename = "fwupgrade.bin"

    local fwcontent = {
      fwupgrade_state = fwupgrade_rpc_path .. "state",
      fwupgrade_location = fwupgrade_rpc_path .. "location"
    }
    content_helper.getExactContent(fwcontent)

    if fwcontent.fwupgrade_state == "Requested" then
      ngx.log(ngx.ERR, "upgrade already in progress")
      ngx.print('{ "error":"0" }')
      ngx.exit(ngx.OK)
    end

    -- flush the web template cache
    lp.flush()

    -- force GC to run to try to prevent lua from taking more memory during
    -- the upgrade action by having it reclaim some unused objects. This wont
    -- shrink the linux memory usage, but it might prevent it from becoming
    -- even bigger.
    collectgarbage()
    collectgarbage()

    local uploaded = receive_file(untaint(fwcontent.fwupgrade_location) .. filename)

    -- start actual upgrade through rpc
    proxy.set({ [fwupgrade_rpc_path .. "filename"] = "fwupgrade.bin" })
    proxy.set({ [fwupgrade_rpc_path .. "state"] = "Requested" })

    if uploaded then
      ngx.print('{ "uploaded":true }')
    else
      ngx.print('{ "uploaded":false }')
    end
    ngx.exit(ngx.HTTP_OK)
  end

  if ngx.var.request_method == "POST" then
    ngx.header.content_type = "application/json"
    local action = ngx.req.get_uri_args().action
    if action == "upgradefw" then
      return upgradefw()
    end
  end

  if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().getstatus == "true" then
    local fwupgrade_rpc_path = "rpc.system.fwupgrade."
    local state = proxy.get(fwupgrade_rpc_path .. "state")[1].value
    ngx.header.content_type = "application/json"
    if state == "Error" then
      local content = {}
      local results = proxy.get(fwupgrade_rpc_path)
      for _, result in ipairs(results) do
        content[result.param] = result.value
      end
      os.remove(untaint(content.location .. content.filename))
      ngx.print('{ "status":"error", "errorcode":"' .. untaint(content.errorcode) .. '" }')
    else
      ngx.print('{ "status":"progress" }')
    end
    ngx.exit(ngx.HTTP_OK)
  end
  ngx.print('\
<h1>');  ngx.print(T"Firmware Update"); ngx.print('</h1>\
<h2>');  ngx.print(T"It is possible to update the router firmware. Your customised configuration settings will not be changed or affected by upgrading."); ngx.print('</h2>\
<div class="h3-content firmware-upgrade mobile-padding-bottom-lg">\
  <div class="row not-flex-row">\
    <div class="col-md-6 col-sm-6 col-xs-12 mobile-bottom-20 padding-top-bottom-20">\
      <span class="font-bold" id="upgrade-lbl-version">');  ngx.print(T"Current Firmware Version"); ngx.print('\
      </span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-12 txt-align padding-right-12 padding-top-bottom-20 mobile-padding-top-none">\
      <span class="font-bold" id="upgrade-info-version">\
        ');  ngx.print(get_from_transformer["firmware-version"]); ngx.print('\
      </span>\
    </div>\
    </div>\
  </div>\
  <h3><span>');  ngx.print(T"Manual Firmware Update"); ngx.print('</span></h3>\
      <div class="h3-content no-padding-bottom">\
    <div class="row padding-top-bottom-20 not-flex-row">\
      <span style="font-weight: normal">');  ngx.print(T"It is possible to update the firmware from a saved update file."); ngx.print('</span>\
    </div>\
  </div>\
    <div class="h3-content mobile-no-float firmware-upgrade">\
    <div class="row">\
      <div class="col-xs-12 col-sm-8 col-md-8 col-lg-8 padding-top-bottom-20 firmware-file">\
        <span class="font-bold">');  ngx.print(T"Firmware File"); ngx.print('&#58;\
        </span>\
        <span id="upgrade-info-nofile" class="first-update-step notification" style="font-weight: normal">');  ngx.print(T"No file selected."); ngx.print('</span>\
        <span id="upgrade-info-invalid_update" class="second-update-step error" style="display:none;">');  ngx.print(T"The selected file is not a valid update."); ngx.print('</span>\
        <span class="third-update-step bold" id="upgrade-info-filename" style="position: relative; display:none;"></span>\
        <img src="img/look_4/icons/darkClose.png" alt="');  ngx.print(T"Loading..."); ngx.print('" id="upgrade-img-remove_file" style="display:none;cursor:pointer" />\
      </div>\
      <div class="col-xs-12 col-sm-4 col-md-4 btn-upload-file padding-top-bottom-20 mobile-padding-top-none text-right">\
        <div class="btn-select-file">\
          <div class="upload" id="uploadManual">\
            <form id="form-upgradefw" method="post" action="modals/upgrade.lp?action=upgradefw" enctype="multipart/form-data">\
              <input style="display: none;" class="uploadStuff" type="file" name="upgradefile" />\
            </form>\
            <input id="upgrade-btn-fileUpload" class="uploadStuffButton button button-blank " value="');  ngx.print(T"Select File"); ngx.print('" type="button" />\
          </div>\
          <input id="upgrade-btn-install" class="installUpdateButton button button-blank" data-popup-queue=".install-update-popup-1" style="display:none;" value="');  ngx.print(T"Install Update"); ngx.print('" type="button" />\
        </div>\
      </div>\
    </div>\
  </div>\
  <!-- Install Update Modal Success/Failure Message -->\
  <!-- Popup1 -->\
  <div class="row">\
    <!-- Modal -->\
    <div class="modal install-update-popup-1" id="upgrade-info-installUpdatePopup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body no-padding">\
            <p>\
              <span>');  ngx.print(T"Phone calls, internet connections and LAN connections will be interrupted due to the upgrade. Please press apply if you want to continue."); ngx.print('\
              </span>\
            </p>\
          </div>\
          <div class="modal-footer">\
            <input class="button button-apply " value="');  ngx.print(T"Apply"); ngx.print('" type="button" id="upgrade-btn-apply" />\
            <input class="button button-cancel " value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal"  id="upgrade-btn-cancel" />\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <!-- Popup2 -->\
  <div class="row">\
    <!-- Modal -->\
    <div class="modal install-update-popup-2" id="upgrade-info-uploadingPopup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body">\
            <img src="img/look_4/icons/icon-thinking.gif" alt="');  ngx.print(T"Loading..."); ngx.print('" />\
            <p class="modal-title tL">\
              <span class="padding-bottom-20">');  ngx.print(T"Uploading Firmware File"); ngx.print('\
              </span>\
            </p>\
            <p class="big">\
              <span>');  ngx.print(T"The firmware file is being uploaded to your Vodafone Ultra Hub."); ngx.print('\
              </span>\
            </p>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <!-- Popup3 -->\
  <div class="row">\
    <!-- Modal -->\
    <div class="modal install-update-popup-3" id="upgrade-info-installingPopup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body">\
            <p class="modal-title tL">\
              <span>');  ngx.print(T"Installing Updated Firmware"); ngx.print('\
              </span>\
            </p>\
            <p class="padding-top-bottom-20">\
              <span>');  ngx.print(T"Do not turn off your Vodafone Ultra Hub"); ngx.print('\
              </span>\
            </p>\
            <div class="progress">\
              <div class="progress-bar progress-bar-striped active progress-bar-success" role="progressbar"\
                    style="width:100%">\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <!-- Popup4 -->\
  <div class="row">\
    <!-- Modal -->\
    <div class="modal install-update-popup-4" id="upgrade-info-updateFailedPopup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body">\
            <p class="modal-title tL">\
              <span>');  ngx.print(T"Firmware Upgrade failed"); ngx.print('</span>\
            </p>\
            <p class="padding-top-bottom-20">\
              <span id="upgrade-info-updateFailureMessage"></span>\
            </p>\
            <div class="modal-footer">\
              <input class="button button-apply " value="');  ngx.print(T"Ok"); ngx.print('" type="button" id="upgrade-btn-ok" />\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <!-- Popup5 -->\
  <div class="row">\
    <!-- Modal -->\
    <div class="modal install-update-popup-5" id="upgrade-info-updateSuccessPopup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body">\
            <img src="img/look_4/icons/icon-thinking.gif" alt="');  ngx.print(T"Loading..."); ngx.print('" />\
            <p class="modal-title tL">\
              <span>');  ngx.print(T"Firmware Successfully Updated"); ngx.print('\
              </span>\
            </p>\
            <p class="big">\
              <span>');  ngx.print(T"Your Vodafone Ultra Hub is now restarting. Please do not turn it off or press any buttons until it has restarted."); ngx.print('\
              </span>\
            </p>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <script>\
    var startTime = 0;\
    var elapsedTime = 0;\
    $(function() {\
      $(\'.uploadStuff\').change(function() {\
        if ($(\'.uploadStuff\').val()) {\
          $("#upgrade-btn-fileUpload").hide();\
          $(\'.installUpdateButton\').show();\
          var fileName = $(".uploadStuff").val().match(/[^\\/\\\\]+$/)[0];\
          var extensionPattern = new RegExp(/.+\\.rbi$/);\
          if (!extensionPattern.test(fileName)) {\
            $("#upgrade-btn-fileUpload").show();\
            $(\'.installUpdateButton\').hide();\
            $("#upgrade-info-nofile").hide();\
            $(".error").show();\
            return;\
          } else {\
            $("#upgrade-info-nofile").hide();\
            $(".error").hide();\
            $("#upgrade-info-filename").show();\
            $("#upgrade-info-filename").html(fileName);\
            $("#upgrade-img-remove_file").show();\
          }\
        }\
      }\
                              );\
      $("#upgrade-btn-fileUpload").click(function() {\
        $(\'.uploadStuff\').trigger(\'click\');\
      }\
                            );\
      $(".installUpdateButton").click(function() {\
        $(\'#upgrade-info-installUpdatePopup\').modal();\
      }\
                                     );\
      $("#upgrade-img-remove_file").click(function() {\
        $("#upgrade-btn-fileUpload").show();\
        $(\'.installUpdateButton\').hide();\
        $(\'#upgrade-info-nofile\').show();\
        $("#upgrade-info-filename").hide();\
        $("#upgrade-img-remove_file").hide();\
        $(".uploadStuff").val("");\
      }\
                      );\
      $("#upgrade-btn-ok").click(function() {\
        $(\'#upgrade-info-updateFailedPopup\').modal(\'hide\');\
      });\
\
      $("#upgrade-btn-apply").click(function() {\
        $(\'#upgrade-info-installUpdatePopup\').modal(\'hide\');\
        $(\'#upgrade-info-uploadingPopup\').modal();\
\
          if (!(window.File || window.FormData)) {\
            $.fileUpload($("#form-upgradefw"), {\
              params: { CSRFtoken: $("[name=CSRFtoken]").val() },\
              completeCallback: function(form, response) {\
                $("#upgrade-transfer-msg").addClass("hide");\
                if (response.uploaded) {\
                  $(\'#upgrade-info-installingPopup\').modal();\
                  startTime = new Date();\
                  getStatus("/modals/upgrade.lp?getstatus=true");\
                }\
                else {\
                $(\'#upgrade-info-updateFailedPopup\').modal();\
                }\
              }\
            });\
          } else {\
\
        var file_data = $(".uploadStuff").prop("files")[0];\
        var form_data = new FormData();\
        form_data.append("CSRFtoken", "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('");\
        form_data.append("upgradefile", file_data)\
        $.ajax({\
          url: "modals/upgrade.lp?action=upgradefw",\
          dataType: \'json\',\
          timeout: 60000, // If file upload takes more than 60 seconds, Show timeout message\
          cache: false,\
          contentType: false,\
          processData: false,\
          data: form_data,\
          type: \'post\'\
        })\
        .success(function(data) {\
          $(\'#upgrade-info-uploadingPopup\').modal(\'hide\');\
          if (data.uploaded) {\
            $(\'#upgrade-info-installingPopup\').modal();\
            startTime = new Date();\
            getStatus("/modals/upgrade.lp?getstatus=true");\
          } else {\
            $(\'#upgrade-info-updateFailedPopup\').modal();\
          }\
        })\
        .fail(function() {\
          $(\'#upgrade-info-uploadingPopup\').modal(\'hide\');\
          $("#upgrade-info-updateFailureMessage").text("');  ngx.print( T'Upload timed out. Please try again.' ); ngx.print('");\
          $(\'#upgrade-info-updateFailedPopup\').modal();\
        });\
      }\
      });\
    });\
\
    function getStatus(target) {\
      elapsedTime = Math.floor((new Date() - startTime)/1000);\
      if (elapsedTime > 600) { // If upgrade takes more than 10 minutes, Show timeout message\
        $(\'#upgrade-info-installingPopup\').modal(\'hide\');\
        $("#upgrade-info-updateFailureMessage").text("');  ngx.print( T'Upgrade timed out. Please try again.' ); ngx.print('");\
        $(\'#upgrade-info-updateFailedPopup\').modal();\
        return;\
      }\
      var isDone = false;\
      $.get(target, function(responseTxt, statusTxt, xhr){\
        if ( isDone || !(responseTxt.status) ) {\
          $(\'#upgrade-info-installingPopup\').modal(\'hide\');\
          $(\'#upgrade-info-updateSuccessPopup\').modal();\
          window.setTimeout(function() {\
            window.location = "/";\
          }, 5000);\
          return;\
        }\
        else if (responseTxt.status == "error") {\
          $(\'#upgrade-info-installingPopup\').modal(\'hide\');\
          $(\'#upgrade-info-updateFailedPopup\').modal();\
          var failure_msg = $("#upgrade-info-updateFailureMessage");\
          switch (responseTxt.errorcode) {\
          case "1":\
            failure_msg.text("');  ngx.print( T'Insufficient free memory available. Please reboot and try again.' ); ngx.print('");\
            break;\
          case "9":\
            failure_msg.text("');  ngx.print( T'File is corrupted.' ); ngx.print('");\
            break;\
          case "10":\
          case "255":\
            failure_msg.text("');  ngx.print( T'Please use the correct firmware.' ); ngx.print('");\
            break;\
          default:\
            failure_msg.text("');  ngx.print( T'Firmware upgrade failed.' ); ngx.print('");\
            break;\
          }\
          return;\
        }\
        else {\
          window.setTimeout(function(){\
            getStatus("modals/upgrade.lp?getstatus=true");\
          }, 5000);\
        }\
      }).fail(function(data) {\
        isDone = true;\
        window.setTimeout(function() {\
          getStatus("/")\
        }, 5000);\
      });\
    }\
  </script>\
'); 