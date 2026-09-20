--pretranslated: do not change this file
 ngx.print(' ');  
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ngx, io, os  = ngx, io, os
local postHelper   = require("web.post_helper")
local session = ngx.ctx.session
local string = string
local untaint, find, match = string.untaint, string.find, string.match
local validateIfPropertyExist = postHelper.getValidationIfPropInList
local isStringLengthValid = postHelper.getValidateStringLengthInRange
local gAV = postHelper.getAndValidation
local contentHelper = require("web.content_helper")
local x509 = require("tch.crypto.x509")

session:store("isUpload",true)
local acsData = {
  acsPassword = "uci.cwmpd.cwmpd_config.acs_pass",
  connectionReqPassword = "uci.cwmpd.cwmpd_config.connectionrequest_password",
  acsUrl = "uci.cwmpd.cwmpd_config.acs_url",
  informState           = "uci.cwmpd.cwmpd_config.state",
  informInterval        = "uci.cwmpd.cwmpd_config.periodicinform_interval",
  acsUserName           = "uci.cwmpd.cwmpd_config.acs_user",
  connectionReqUserName = "uci.cwmpd.cwmpd_config.connectionrequest_username",
}
contentHelper.getExactContent(acsData)

local function validateServer(value,data,key)
  if value then
    if string.match(value,"^https?://*") then
      return true
    end
  end
  return nil,"Website url is not valid"
end

local function validateUrlLength(url)
  if #url > 0 and #url < 255 then
    return true
  end
end

local hashfilename
local function receive_file(filename, param)
  local upload = require("web.fileupload")
  local form, err = upload.fromstream()
  if not form then
    return false, 1, "failed to create upload ctx: " .. err
  end
  local file
  local discard = false
  while true do
    local token, data, err1 = form:read()
    if not token then
      return false, 2, "read failed: " .. err1
    end
    if token == "header" then
      if not discard and not file and find(data[2], param, 1, true) then
        file = io.open(filename, "w")
      end
      if not discard and not file then
        return false, 3, "failed to start receiving file"
      end
    elseif token == "body" then
      if file then
        if string.find(data, "^(%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-\n)") and string.find(data, "\n(%-%-%-%-%-END CERTIFICATE%-%-%-%-%-)") then
          if string.find(data, ".+%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-") then
            file:close()
            file = nil
            discard = true
            os.remove(filename)
            return false, 5, "Invalid certificate 2"
          else
            file:write(data)
            local cert = x509.new_from_string(data)
            hashfilename = cert:subject_hash() .. ".0"
            os.rename(filename, "/tmp/" .. hashfilename)
          end
        else
          file:close()
          file = nil
          discard = true
          os.remove(filename)
          return false, 4, "Invalid certificate 1"
        end
      end
    elseif token == "part_end" then
      if file then
        file:close()
        file = nil
        discard = true
      end
    elseif token == "eof" then
      break
    end
  end
  return true
end

local function validateFilename(filename)
  if filename and #filename > 0 and #filename < 64 and match(filename, "^.*%.0$") then
    return true
  end
end

local function import_config()
local filename = untaint(ngx.req.get_uri_args().name)
local rcv_ok
if validateFilename(filename) then
  filename = "/tmp/" .. filename
    rcv_ok = receive_file(filename, 'name="configfile"')
  end
return rcv_ok
end
local resettr69 = {
  reset_inform = "uci.uci-defaults.tr69clientconfiguration.inform",
  reset_inform_interval = "uci.uci-defaults.tr69clientconfiguration.inform_interval",
  reset_acs_url = "uci.uci-defaults.tr69clientconfiguration.acs_url",
  reset_acs_username = "uci.uci-defaults.tr69clientconfiguration.acs_username",
  reset_acs_password = "uci.uci-defaults.tr69clientconfiguration.acs_password",
  reset_connection_req_username = "uci.uci-defaults.tr69clientconfiguration.connection_req_username",
  reset_connection_req_password = "uci.uci-defaults.tr69clientconfiguration.connection_req_password"
}
contentHelper.getExactContent(resettr69)

if ngx.req.get_method() == "POST" then
  if ngx.req.get_uri_args().action == "import_config" then
    ngx.header.content_type = "application/json"
    local rcv_ok = import_config()
    if not rcv_ok then
      ngx.print('{"uploadStatus":"failure"}')
    else
      ngx.print('{"uploadStatus":"success"}')
      proxy.set("rpc.system.upload_ca_file", hashfilename)
      proxy.apply()
    end
  else
    local acsPostdata  = {
      informState           = ngx.req.get_post_args().informState,
      informInterval        = ngx.req.get_post_args().informInterval,
      acsUserName           = ngx.req.get_post_args().acsUserName,
      connectionReqUserName = ngx.req.get_post_args().connectionReqUserName,
    }
    local validationMap = {
      informState           = postHelper.validateBoolean ,
      acsUserName           = isStringLengthValid(1,63),
      connectionReqUserName = isStringLengthValid(1,63),
      informInterval        = validateIfPropertyExist(isStringLengthValid(1,63), "informState",{"1"}),
    }
    local valid = contentHelper.validateObject(acsPostdata, validationMap)
    if valid then
      local paramMap = {
        informState = "state",
        informInterval = "periodicinform_interval",
        acsUserName = "acs_user",
        connectionReqUserName = "connectionrequest_username",
      }
      local acsDetails = {
        informState = ngx.req.get_post_args().informState,
        informInterval = ngx.req.get_post_args().informInterval,
        acsUserName  = ngx.req.get_post_args().acsUserName,
        connectionReqUserName = ngx.req.get_post_args().connectionReqUserName,
      }
      contentHelper.setObject(acsDetails, paramMap, "uci.cwmpd.cwmpd_config.")
    end
    local success1 = true
    local success2 = true

    if not (acsData["acsPassword"] ~= "" and ngx.req.get_post_args().acsPassword == "") or (acsData["acsUserName"] ~= ngx.req.get_post_args().acsUserName) then
      success1 = isStringLengthValid(ngx.req.get_post_args().acsPassword)
    end
    if not (acsData["connectionReqPassword"] ~= "" and ngx.req.get_post_args().connectionReqPassword == "") or (acsData["connectionReqUserName"] ~= ngx.req.get_post_args().connectionReqUserName) then
      success2 = isStringLengthValid(ngx.req.get_post_args().connectionReqPassword)
    end
    local success3 = gAV(validateServer,validateUrlLength)(ngx.req.get_post_args().acsUrl)
    if valid and success1 and success2 and success3 then
      local acspasswd = ngx.req.get_post_args().acsPassword == "" and acsData["acsPassword"] or ngx.req.get_post_args().acsPassword
      local cnctreqpasswd = ngx.req.get_post_args().connectionReqPassword == "" and acsData["connectionReqPassword"] or ngx.req.get_post_args().connectionReqPassword
      local acsUrl = ngx.req.get_post_args().acsUrl
      local setParams = {
        ["uci.cwmpd.cwmpd_config.acs_url"] = acsUrl
      }
      if (ngx.req.get_post_args().acsPassword ~= "") then
        setParams["uci.cwmpd.cwmpd_config.acs_pass"] = acspasswd
      end
      if (ngx.req.get_post_args().connectionReqPassword ~= "") then
        setParams["uci.cwmpd.cwmpd_config.connectionrequest_password"] = cnctreqpasswd
      end
      proxy.set(setParams)
      proxy.apply()
      ngx.print('<input type="hidden" id="post_status" value="success">')
    else
      ngx.print('<input type="hidden" id="post_status" value="error">')
    end
  end
  ngx.exit(ngx.HTTP_OK)
end


local updatedacsData = {
  acsPassword = "uci.cwmpd.cwmpd_config.acs_pass",
  connectionReqPassword = "uci.cwmpd.cwmpd_config.connectionrequest_password",
  acsUrl                = "uci.cwmpd.cwmpd_config.acs_url",
  informState           = "uci.cwmpd.cwmpd_config.state",
  informInterval        = "uci.cwmpd.cwmpd_config.periodicinform_interval",
  acsUserName           = "uci.cwmpd.cwmpd_config.acs_user",
  connectionReqUserName = "uci.cwmpd.cwmpd_config.connectionrequest_username",
  uploadFile            = "rpc.system.upload_ca_file",
}
contentHelper.getExactContent(updatedacsData)

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<h1><span>');  ngx.print(T"TR-069 Client Configuration"); ngx.print('</span></h1>\
<h2 class="tr069">&nbsp;</h2>\
<h3>');  ngx.print(T"TR-069 Client Configuration"); ngx.print('</h3>\
<div class="h3-content">\
  <form id="tr-069_form" method="post" action="modals/tr-069.lp">\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
      <div class="col-xs-6 col-md-6 col-sm-6 no-padding-left-right">\
        <span>');  ngx.print(T"Inform"); ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <div id="tr069-btn-onoff" class="button ');  if updatedacsData["informState"] == "1" then   ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' tr069-btn-onoff"></div>\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div id="hide-inform-interval">\
      <div class="row padding-top-bottom-20 no-margin-left-right">\
        <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
          <span>');  ngx.print(T"Inform Interval"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
          <input id="tr069-inform-interval" value="');  ngx.print(updatedacsData["informInterval"]); ngx.print('" type="text" />\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-12">\
          <hr/>\
        </div>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
      <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
        <span>');  ngx.print(T"ACS URL"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <input id="tr069-acs-url" value="');  ngx.print(updatedacsData["acsUrl"]); ngx.print('" type="text" />\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
      <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
        <span>');  ngx.print(T"ACS Username"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <input id="tr069-acs-username" value="');  ngx.print(updatedacsData["acsUserName"]); ngx.print('" type="text" />\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
      <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
        <span>');  ngx.print(T"ACS Password"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <input id="tr069-acs-password" name = "acsPassword" value="" type = "password" placeholder="********" />\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
\
    <div class="row padding-top-bottom-20 no-margin-left-right mobile-padding-left-right-none">\
      <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
        <span>');  ngx.print(T"Connection Request Username"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <input id="tr069-connection-requsrname" value="');  ngx.print(updatedacsData["connectionReqUserName"]); ngx.print('" type="text" />\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
\
    <div class="row padding-top-bottom-20 no-margin-left-right mobile-padding-left-right-none">\
      <div class="col-xs-12 col-md-6 col-sm-6 line-height-40 no-padding-left-right">\
        <span>');  ngx.print(T"Connection Request Password"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
        <input id="tr069-connection-reqpswd" name = "connectionReqPassword" value="" type="password" placeholder="********">\
      </div>\
    </div>\
  </form>\
</div>\
<h3><span>');  ngx.print(T"TR-069 Certification"); ngx.print('</span></h3>\
<div class="h3-content">\
  <div class="row padding-bottom-20 no-margin-left-right no-padding-left-right">\
    <div class="col-xs-12 col-md-12 col-sm-12 line-height-40 no-padding-left-right">\
      <span>');  ngx.print(T"Load TR-069 Certification"); ngx.print('</span>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-sm-6 col-md-8">\
      <span>');  ngx.print(T"Certification File:"); ngx.print('</span>\
      <span class="first-update-step notification">\
        <span id= "tr069-nofile">');  ngx.print(T"No file selected."); ngx.print('</span>\
      </span>\
      <span class="second-update-step error" style="display:none;">\
        <span id="tr69-info-invalidFile">');  ngx.print(T"The selected file is not a valid update."); ngx.print('</span>\
      </span>\
      <span class="third-update-step bold" id="filename" style="position: relative; display:none;">\
      </span>\
      <img src="img/look_4/icons/darkClose.png" alt="Loading..." id="del1" style="display:none;" />\
    </div>\
    <div class="col-xs-12 col-sm-6 col-md-4">\
      <div class="btn-select-file">\
        <div class="upload" id="uploadManual">\
          <input style="display: none;" class="uploadStuff" type="file" />\
          <input id="fileupload" class="uploadStuffButton button button-blank" value="Select File" type="button" />\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
\
<div class="table-wrapper">\
  <div id = "tr069-successmsg" class="message message-info message-error not-8-characterss">\
    ');  ngx.print( T"New Certificate Uploaded. Please reboot the Gateway for the changes to take effect."); ngx.print('\
  </div>\
</div>\
');  
 lp.include("apply-cancel.lp")
 lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<script>\
var isDone = false;\
result = true;\
$(function() {\
  $(\'select\').chosen({\
    disable_search_threshold: 100000,\
    allow_single_deselect: true\
  });\
  var FileUpload = "');  ngx.print(updatedacsData["uploadFile"]); ngx.print('";\
  if (FileUpload.length == 0)\
  {\
    $("#tr069-successmsg").removeClass("show").addClass("hide");\
  }\
  else\
    $("#tr069-successmsg").removeClass("hide").addClass("show");\
  $(\'input,textarea\').focus(function () {\
    $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
  }).blur(function () {\
    $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
  });\
\
  var oldAcsUsername = "');  ngx.print(acsData["acsUserName"]); ngx.print('";\
  var oldconnectionReqUserName = "');  ngx.print(acsData["connectionReqUserName"]); ngx.print('";\
  if("');  ngx.print(acsData["informState"]); ngx.print('" == 0){\
    $("#hide-inform-interval").removeClass(\'show\').addClass(\'hide\');\
  }\
  else\
  {\
    $("#hide-inform-interval").removeClass(\'hide\').addClass(\'show\');\
  }\
\
  $(\'.uploadStuff\').change(function() {\
    var stat=true;\
    if ($(\'.uploadStuff\').val()) {\
      $("#fileupload").hide();\
      var fileName = $(\'.uploadStuff\')[0].files[0].name;\
      var extensionPattern = new RegExp(/.+\\.0$/);\
      if (!extensionPattern.test(fileName) || stat==false) {\
        $("#fileupload").show();\
        $("#tr069-nofile").hide();\
        $(".error").show();\
        $(".uploadStuff").val("");\
        return;\
      } else {\
        $("#tr069-nofile").hide();\
        $(".error").hide();\
        $("#filename").show();\
        $("#filename").html(fileName);\
        $("#del1").show();\
        $("#tr069-successmsg").removeClass("hide").addClass("show");\
      }\
    }\
  });\
\
  $("#fileupload").click(function() {\
    $(\'.uploadStuff\').trigger(\'click\');\
  });\
\
  $("#del1").click(function() {\
    $("#fileupload").show();\
    $(\'#tr069-nofile\').show();\
    $("#filename").hide();\
    $("#del1").hide();\
    $(".uploadStuff").val("");\
    $("#tr069-successmsg").removeClass("show").addClass("hide");\
  });\
\
  $("div#tr069-btn-onoff").click(function(){\
    if ($(this).hasClass(\'button-on\')) {\
      $(this).removeClass(\'button-on\');\
      $(this).addClass(\'button-off\');\
      $("#hide-inform-interval").removeClass(\'show\').addClass(\'hide\');\
    } else {\
      $(this).removeClass(\'button-off\');\
      $(this).addClass(\'button-on\');\
      $("#hide-inform-interval").removeClass(\'hide\').addClass(\'show\');\
    }\
    if (typeof(Storage) !== "undefined") {\
      // Save data to sessionStorage\
      sessionStorage.setItem(\'apply_changes\', "N");\
    } else {\
      console.log("Sorry! No Web Storage support..");\
    }\
  });\
\
  $("#global-apply").click(function() {\
    if ($("#tr69-info-invalidFile").is(":visible")) {\
      $(".articlediv > .msg-error").removeClass("hide").addClass("show");\
      $(".articlediv > .msg-warning").removeClass("show").addClass("hide");\
      $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");\
      $(".articlediv").removeClass("hide").addClass("show");\
      setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide") }, 3000);\
      return false;\
    }\
\
    $("#tr069-inform-interval").removeClass("input-length");\
    $("#tr069-acs-url").removeClass("input-length");\
    $("#tr069-acs-username").removeClass("input-length");\
    $("#tr069-acs-password").removeClass("input-length");\
    $("#tr069-connection-requsrname").removeClass("input-length");\
    $("#tr069-connection-reqpswd").removeClass("input-length");\
    var regUrl = /^((http[s]?:\\/\\/){1})/;\
    var iserror = false;\
    var target                = "/modals/tr-069.lp";\
    var form                  = $("#tr-069_form");\
    var params                = [];\
    var informState           = $("#tr069-btn-onoff").hasClass("button-on") ? 1 : 0;\
    var informInterval        = $("#tr069-inform-interval").val();\
    var acsUrl                = $("#tr069-acs-url").val();\
    var acsUserName           = $("#tr069-acs-username").val();\
    var acsPassword           = $("#tr069-acs-password").val();\
    var connectionReqUserName = $("#tr069-connection-requsrname").val();\
    var connectionReqPassword = $("#tr069-connection-reqpswd").val();\
    if (regUrl.test(acsUrl) == false)\
    {\
      $("#tr069-acs-url").addClass("input-length");\
      iserror = true;\
    }\
    if (informState == 1) {\
      if (informInterval == "" || informInterval <= 9 || informInterval > 2147483648 || isNaN(informInterval) == true)\
      {\
        $("#tr069-inform-interval").addClass("input-length");\
        iserror = true;\
      }\
    }\
    if ((oldAcsUsername != acsUserName)|| (oldAcsUsername.length == 0 && acsUserName.length == 0)){\
      if((acsPassword.length == 0) || (acsPassword.length > 63)){\
        $("#tr069-acs-password").addClass("input-length");\
        iserror = true;\
      }\
    }\
    if ((oldconnectionReqUserName != connectionReqUserName)|| (oldconnectionReqUserName.length == 0 && connectionReqUserName.length == 0))\
    {\
      if((connectionReqPassword.length == 0) || (connectionReqPassword.length > 63)){\
        $("#tr069-connection-reqpswd").addClass("input-length");\
        iserror = true;\
      }\
    }\
    if (acsUserName.length == 0 || acsUserName.length > 63){\
      $("#tr069-acs-username").addClass("input-length");\
      iserror = true;\
    }\
    if (connectionReqUserName.length == 0 || connectionReqUserName.length > 63){\
      $("#tr069-connection-requsrname").addClass("input-length");\
      iserror = true;\
    }\
    if (iserror) return;\
\
    params.push({\
      name  : "informState",\
      value : informState\
    }, {\
      name  : "informInterval",\
      value : informInterval\
    }, {\
     name  : "acsUrl",\
     value :  acsUrl\
    }, {\
      name  : "acsUserName",\
      value :  acsUserName\
    }, {\
      name  : "acsPassword",\
      value :  acsPassword\
    }, {\
      name  : "connectionReqUserName",\
      value :  connectionReqUserName\
    }, {\
      name  : "connectionReqPassword",\
      value :  connectionReqPassword\
    }, {\
      name  : "CSRFtoken",\
      value :  "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    }, {\
      name  : "action",\
      value :  "SAVE"\
    });\
\
    if ($(".uploadStuff").val()) {\
      var file_data = $(".uploadStuff").prop("files")[0];\
      var form_data = new FormData();\
      form_data.append("CSRFtoken", "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('");\
      form_data.append("configfile", file_data);\
      $.ajax({\
        url: "modals/tr-069.lp?action=import_config&name="+$(\'.uploadStuff\')[0].files[0].name,\
        dataType: \'json\',\
        cache: false,\
        contentType: false,\
        processData: false,\
        data: form_data,\
        type: \'post\',\
        error: function(data, textStatus, errorThrown) {\
          $(".articlediv > .msg-error").removeClass("hide").addClass("show");\
          $(".articlediv > .msg-warning").removeClass("show").addClass("hide");\
          $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");\
          $(".articlediv").removeClass("hide").addClass("show");\
          setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide") }, 3000);\
        }\
      }).done(function(data) {\
        if (data.uploadStatus == "failure") {\
          $("#filename").hide();\
          $("#del1").hide();\
          $("#fileupload").show();\
          $("#tr069-nofile").hide();\
          $(".error").show();\
          $(".articlediv > .msg-error").removeClass("hide").addClass("show");\
          $(".articlediv > .msg-warning").removeClass("show").addClass("hide");\
          $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");\
          $(".articlediv").removeClass("hide").addClass("show");\
          setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide") }, 3000);\
        } else {\
          postHandler(target, params);\
        }\
      });\
    } else {\
      postHandler(target, params);\
    }\
  });\
\
  $("#global-cancel").click(function() {\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    $("#content").load("/modals/tr-069.lp");\
  });\
});\
\
$("#resetR, .resetR").click(function(){\
  $("#tr069-btn-onoff").val("');  ngx.print(resettr69["reset_inform"]); ngx.print('");\
  if ("');  ngx.print(resettr69["reset_inform"]); ngx.print('" == "1") {\
    $(\'#tr069-btn-onoff\').addClass(\'button-on\').removeClass(\'button-off\');\
    $(\'#hide-inform-interval\').removeClass("hide").addClass("show");\
  } else {\
    $(\'#tr069-btn-onoff\').addClass(\'button-off\').removeClass(\'button-on\');\
  }\
  $("#tr069-inform-interval").val("');  ngx.print(resettr69["reset_inform_interval"]); ngx.print('");\
  $("#tr069-acs-url").val("');  ngx.print(untaint(resettr69["reset_acs_url"])); ngx.print('");\
  $("#tr069-acs-username").val("');  ngx.print(resettr69["reset_acs_username"]); ngx.print('");\
  $("#tr069-acs-password").val("');  ngx.print(resettr69["reset_acs_password"]); ngx.print('");\
  $("#tr069-connection-requsrname").val("');  ngx.print(resettr69["reset_connection_req_username"]); ngx.print('");\
  $("#tr069-connection-reqpswd").val("');  ngx.print(resettr69["reset_connection_req_password"]); ngx.print('");\
});\
</script>\
'); 