--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local format, match = string.format, string.match

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local validatePassword = post_helper.getValidationPassword
local validateOR = post_helper.getOrValidation
local valiateStringLength = post_helper.getValidateStringLengthInRange(1, 255)
local validateAND = post_helper.getAndValidation
local validateNumber = post_helper.getValidateNumberInRange
local validateWholeNumber   = post_helper.getValidateWholeNumber
local ngx, io, os  = ngx, io, os
local untaint, find, match = string.untaint, string.find, string.match
local x509 = require("tch.crypto.x509")

local allowedIpContent = {
  uploadFile = "rpc.system.upload_ca_file"
}content_helper.getExactContent(allowedIpContent)

local mapParams = {
  cwmpUrl                      = "uci.cwmpd.cwmpd_config.acs_url",
  cwmpState                    = "uci.cwmpd.cwmpd_config.state",
  cwmpPeriodic                 = "uci.cwmpd.cwmpd_config.periodicinform_interval",
  connectionrequestAuth        = "uci.cwmpd.cwmpd_config.connectionrequest_auth",
  cwmpAcsUser                  = "uci.cwmpd.cwmpd_config.acs_user",
  cwmpAcsPass                  = "uci.cwmpd.cwmpd_config.acs_pass",
  connectionrequestUser        = "uci.cwmpd.cwmpd_config.connectionrequest_username",
  connectionrequestPass        = "uci.cwmpd.cwmpd_config.connectionrequest_password",
  --[[ Note: if you add parameter connectionrequest_port, please change deny_cwmp.ext_ports
  in /etc/config/upnpd at the same time, for details please check NG-78919.
  connectionrequestPort        = "uci.cwmpd.cwmpd_config.connectionrequest_port",
  ]]
  ipPreference = "uci.cwmpd.cwmpd_config.ip_preference",
  connectionrequestAllowedIPv4 = "uci.cwmpd.cwmpd_config.connectionrequest_allowedips",
  connectionrequestAllowedIPv6 = "uci.cwmpd.cwmpd_config.connectionrequest_allowedips"
}

local conreqauthSelect = {
  { "0", T'None'},
  { "1", T'Basic'},
  { "2", T'Digest'}
}

local ipPreferenceSelect = {
  { "v4_only", T'IPv4 Only'},
  { "v6_only", T'IPv6 Only'},
  { "prefer_v4", T'Prefer IPv4'},
  { "prefer_v6", T'Prefer IPv6'}
}

-- function that can be used to validate connectionrequest user/pass for auth mode selected as None
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @return #boolean or nil
local function validateConnReqNone(value, object)
  if object.connectionrequestAuth == "0" then
    return true
  end
  return nil
end
-- validate the user name and Url
local function validateUserUrl(value, object)
  if object.cwmpState ~= "1" then
    return false
  else
    return valiateStringLength(value)
  end
end
-- validate the password
local function validatePass(value, object, key)
  if object.cwmpState ~= "1" then
    return false
  else
    return validatePassword(valiateStringLength)(value, object, key)
  end
end

local mapvalid = {
  cwmpUrl                      = validateUserUrl,
  cwmpAcsUser                  = validateUserUrl,
  cwmpAcsPass                  = validatePass,
  cwmpState                    = post_helper.validateBoolean,
  cwmpPeriodic                 = validateAND(validateWholeNumber, validateNumber(10, 300000)),
  connectionrequestAuth        = post_helper.getValidateInEnumSelect(conreqauthSelect),
  connectionrequestUser        = validateOR(validateConnReqNone, valiateStringLength),
  connectionrequestPass        = validateOR(validateConnReqNone, validatePassword(valiateStringLength)),
  ipPreference                 = post_helper.getValidateInEnumSelect(ipPreferenceSelect),
  connectionrequestAllowedIPv4 = post_helper.validateIPAndSubnet(4),
  connectionrequestAllowedIPv6 = post_helper.validateIPAndSubnet(6)
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)

local conreqauthclass = {
  group = {
    class ="monitor-connectionrequestAuth monitor-1 monitor-2",
  }
}

-- To split the string
local function splitIPv4IPV6(ip, separator)
  local table = {}
  if ip and separator ~= "" then
    for i in ip:gmatch("[^"..separator.."]+") do
      table[#table+1] = i
    end
  end
  return table or ""
end

local hashfilename
local function receiveFile(filename, param)
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
            hashfilename = cert:subjectHash() .. ".0"
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
  local rcvOk
  if validateFilename(filename) then
    filename = "/tmp/" .. filename
    rcvOk = receiveFile(filename, 'name="configfile"')
  end
  return rcvOk
end

if ngx.var.request_method == "POST" then
if ngx.req.get_uri_args().action == "import_config" then
  ngx.header.content_type = "application/json"
  local rcv_ok = import_config()
  if not rcv_ok then
    ngx.print('{ "uploadStatus":"error" }')
  else
    ngx.print('{"uploadStatus":"success"}')
    proxy.set("rpc.system.upload_ca_file", hashfilename)
  end
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end
  local postContent = ngx.req.get_post_args()
  if postContent.action == "SAVE" then
    if not next(helpmsg) then
      local ipv4 = postContent.connectionrequestAllowedIPv4
      local ipv6 = postContent.connectionrequestAllowedIPv6
      local allowedIPs = ipv4 .. "," .. ipv6
      proxy.set("uci.cwmpd.cwmpd_config.connectionrequest_allowedips", allowedIPs)
    end
    if postContent.connectionrequestAuth == "0" then
      mapParams.connectionrequestUser = nil
      mapParams.connectionrequestPass = nil
    end
  end
  if postContent.cwmpState == "0" then
    proxy.set({["uci.cwmpd.cwmpd_config.acs_url"] = content.cwmpUrl,
    ["uci.cwmpd.cwmpd_config.acs_user"] = content.cwmpAcsUser,
    ["uci.cwmpd.cwmpd_config.acs_pass"] = content.cwmpAcsPass })
  end
  proxy.apply()
end

local ips = proxy.get("uci.cwmpd.cwmpd_config.connectionrequest_allowedips")[1].value
local allowedIP = splitIPv4IPV6(ips, ",")

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"CWMP Settings", false, true, nil, help_link) ); ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" id="mainForm" method="post" action="modals/cwmpconf-modal.lp">\
    <fieldset>\
      ');  local numbersOnly = {
        input = {
          pattern = "[0-9]{2,6}",
          maxlength = "6"
        }
      }
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      local html = {}
      local switch_class_enable = {
        input = {
          class = "monitor-changes",
        }
      }
      html[#html + 1] = ui_helper.createSwitch(T"Enabled", "cwmpState", content.cwmpState, switch_class_enable)
      local cwmpinput = {
        group = {
          class ="monitor-cwmpState monitor-1",
        },
        input = {
          maxlength= "255",
          class = "span2"
        },
      }
      if content.cwmpState == "0" then
        html[#html+1] = ui_helper.createInputText(T"ACS URL", "cwmpUrl", content.cwmpUrl, cwmpinput, helpmsg.cwmpUrl)
        html[#html+1] = ui_helper.createInputText(T"ACS Username", "cwmpAcsUser", content.cwmpAcsUser, cwmpinput, helpmsg.cwmpAcsUser)
        html[#html+1] = ui_helper.createInputPassword(T"ACS Password", "cwmpAcsPass", content.cwmpAcsPass, cwmpinput, helpmsg.cwmpAcsPass)
      else
        html[#html+1] = ui_helper.createInputText(T"ACS URL", "cwmpUrl", content.cwmpUrl, cwmpinput, helpmsg.cwmpUrl)
        html[#html+1] = ui_helper.createInputText(T"ACS Username", "cwmpAcsUser", content.cwmpAcsUser, cwmpinput, helpmsg.cwmpAcsUser)
        html[#html+1] = ui_helper.createInputPassword(T"ACS Password", "cwmpAcsPass", content.cwmpAcsPass, cwmpinput, helpmsg.cwmpAcsPass)
      end
      ngx.print(html)
      ngx.print(
        ui_helper.createInputText(T"Periodic Interval", "cwmpPeriodic", content.cwmpPeriodic, numbersOnly, helpmsg.cwmpPeriodic),
        ui_helper.createInputSelect(T"Connection Request Auth", "connectionrequestAuth", conreqauthSelect, content.connectionrequestAuth, {select={class="monitor-changes"}}),
        ui_helper.createInputText(T"Connection Request Username", "connectionrequestUser", content.connectionrequestUser, conreqauthclass, helpmsg.connectionrequestUser),
        ui_helper.createInputPassword(T"Connection Request Password", "connectionrequestPass", content.connectionrequestPass, conreqauthclass, helpmsg.connectionrequestPass),
        ui_helper.createInputText(T"Connection Request Allowed IPv4", "connectionrequestAllowedIPv4", allowedIP[1], cwmpinput, helpmsg.connectionrequestAllowedIPv4),
        ui_helper.createInputText(T"Connection Request Allowed IPv6", "connectionrequestAllowedIPv6", allowedIP[2], cwmpinput, helpmsg.connectionrequestAllowedIPv6),
        ui_helper.createInputSelect(T"IPv4/IPv6", "ipPreference", ipPreferenceSelect, content.ipPreference)
      )
        ngx.print('\
    </fieldset>\
    <fieldset>\
      <legend>');  ngx.print( T"CWMP Certification" ); ngx.print('</legend>\
      ');  
        local import_config = {
          button = {
            class = "import-config custom-handler",
            id = "btn-import"
          }
        }
        local html = {}
        html[#html + 1] = '</form><form class="form-horizontal" id="form-import" enctype="multipart/form-data">'
        html[#html + 1] = '<div class="control-group">'
        html[#html + 1] = format('<label class="control-label">%s</label>', T"Load Certification File")
        html[#html + 1] = '<div class="controls">'
        html[#html + 1] = '<input type="file" name="configfile" id="fileupload">&nbsp;'
        html[#html + 1] = ui_helper.createSimpleButton(T"Import", "icon-upload-alt", import_config)
        html[#html + 1] = '</div></div>'
        html[#html + 1] = ui_helper.alertAttributes(T"No file chosen", "alert-error hide", "tr069-nofile")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing configuration, please wait...", "alert-info hide", "importing-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing failed; please try again.", "alert-error hide", "import-failed-msg")
        html[#html + 1] = ui_helper.alertAttributes(T"Importing failed; Invalid file used: expected file with extension 0", "second-update-step hide", "tr69-info-invalidFile")
        html[#html + 1] = ui_helper.alertAttributes(T"New Certificate Uploaded. Please reboot the Gateway for the changes to take effect.", "alert-success third-update-step hide", "filename")
        ngx.print(html)
        ngx.print('\
      </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
$(function() {\
  var FileUpload = "');  ngx.print(allowedIpContent["uploadFile"]); ngx.print('";\
  if (FileUpload.length == 0)\
  {\
    $("#tr069-successmsg").removeClass("show").addClass("hide");\
  }\
  else\
    $("#tr069-successmsg").removeClass("hide").addClass("show");\
  $(\'input, textarea\').focus(function () {\
    $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
  }).blur(function () {\
    $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
  });\
\
  $("#btn-import").click(function() {\
    $(\'#import-nofile-msg, #import-failed-msg, #tr69-info-invalidFile\').css("display", "none")\
    $("#importing-msg").addClass("hide");\
    var stat = true;\
\
    var nofile_msg = $("#tr069-nofile");\
    if ($("#fileupload").val() == "") {\
      nofile_msg.removeClass("hide");\
      nofile_msg[0].scrollIntoView();\
      return false;\
    }\
    nofile_msg.addClass("hide");\
\
    if ($("#fileupload").val()) {\
      $("#fileupload").hide();\
      var fileName = $("#fileupload").val();\
      var extensionPattern = new RegExp(/.+\\.0$/);\
      if (!extensionPattern.test(fileName) || stat == false) {\
        $("#fileupload").show();\
        nofile_msg.hide();\
        $("#tr69-info-invalidFile").show();\
        $("#fileupload").val("");\
        return false;\
      }\
    }\
    var _this = $(this).parents(".control-group");\
    $("#fileupload").show();\
    $("#import-failed-msg", "#tr69-info-invalidFile").addClass("hide");\
    var importing_msg = $("#importing-msg");\
    importing_msg.removeClass("hide");\
    importing_msg[0].scrollIntoView();\
    var params = [];\
    var target = "modals/cwmpconf-modal.lp";\
    var file = $("#fileupload").val();\
    var myUrl = "modals/cwmpconf-modal.lp?action=import_config&name="+$(\'#fileupload\')[0].files[0].name;\
    var file = $("#fileupload").prop("files")[0];\
    var form_data = new FormData();\
    form_data.append("CSRFtoken", "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('");\
    form_data.append("configfile", file);\
    $.ajax({\
        url: myUrl,\
        dataType: \'json\',\
        cache: false,\
        contentType: false,\
        processData: false,\
        data: form_data,\
        type: \'post\',\
        success: function(data){\
          if (data.uploadStatus == "error" ) {\
            $("#mainForm").prepend(data);\
            $("#importing-msg").addClass("hide");\
            $(".third-update-step").addClass("hide");\
            $("#import-failed-msg").css("display", "block")\
            return false;\
          }\
          else {\
             var scrolltop = $(".modal-body").scrollTop();\
             tch.loadModal(target, function () {\
             $(".modal-body").scrollTop(scrolltop);\
             $(".third-update-step").removeClass("hide");\
             });\
         }}\
      });\
   return false;\
  });\
});\
</script>\
'); 