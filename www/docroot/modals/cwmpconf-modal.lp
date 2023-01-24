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
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "CwmpdPage", "cwmpdtab")
local concat = table.concat
local inet = require("tch.inet")

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
if post_helper.getVariantValue(variantHelper, "xmppconfig") then
  mapParams.xmppPass = "uci.cwmpd.cwmpd_config.xmpp_pass"
  mapParams.xmppUser = "uci.cwmpd.cwmpd_config.xmpp_user"
  mapParams.xmppPort = "uci.cwmpd.cwmpd_config.xmpp_port"
  mapParams.xmppEnable = "uci.cwmpd.cwmpd_config.xmpp_enable"
end

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

-- To split the string into ipv4 and ipv6
local function splitIPv4IPv6(ip, separator, ipType)
  local ipv4Table, ipv6Table = {}, {}
  if ip and separator ~= "" then
    for i in ip:gmatch("[^"..separator.."]+") do
      local ipaddress, netmask = match(i,"^([^/]+)/?(%d*)$")
      if post_helper.GetIPType(ipaddress) == 4 then
        ipv4Table[#ipv4Table+1] = string.untaint(i)
      elseif post_helper.GetIPType(ipaddress) == 6 then
        ipv6Table[#ipv6Table+1] = string.untaint(i)
      else
	return nil , format("%s%d", T"Please enter valid IPv", ipType)
      end
    end
  end
  return ipv4Table, ipv6Table
end

local function ipv4Validate(ipaddr, object)
  local msg1, msg2 = splitIPv4IPv6(ipaddr, ',', 4)
  if not msg1 then
    return nil, msg2
  end
  if object.cwmpState == '1' then
    for _, ip in pairs(msg1) do
      if ip ~= "0.0.0.0/0" then
        local success, errmsg = post_helper.validateIPAndSubnet(4)(ip)
        if not success then
          return nil, errmsg
        end
      end
    end
  end
  return true
end

local function ipv6Validate(ipaddr, object)
  local msg1, msg2 = splitIPv4IPv6(ipaddr, ',', 6)
  if not msg1 then
    return nil, msg2
  end
  if object.cwmpState == '1' then
    for _, ip in pairs(msg2) do
      if ip ~= "::/0" then
        local success, errmsg = post_helper.validateIPAndSubnet(6)(ip)
        if not success then
          return nil, errmsg
        end
      end
    end
  end
  return true
end

local function xmppPassValidation(value, object, key)
  if object.xmppEnable == "1" then
    local success, errmsg = post_helper.validatePass(value, object, key)
    if not success then
      return nil, errmsg
    end
  end
  return true
end

local function xmppUserValidation(value, object, key)
  if object.xmppEnable == "1" then
    local success, errmsg = post_helper.validateUserUrl(value, object, key)
    if not success then
      return nil, errmsg
    end
  end
  return true
end

local function cwmpUrlValidation(value, object, key)
  local new_val = value:match('^%w+://([^:]+)')
  local success, errmsg
  if (new_val and inet.isValidIPv4(untaint(new_val))) or inet.isValidIPv4(untaint(value)) or post_helper.validateStringIsMAC(value) then
    value = new_val and new_val or value
    success, errmsg = post_helper.validateLXC(value)
  end
  if not errmsg then
    success, errmsg = post_helper.validateUserUrl(value, object)
  end
  if errmsg then
    return nil, errmsg
  end
  return true
end

local mapvalid = {
  cwmpUrl                      = cwmpUrlValidation,
  cwmpAcsUser                  = post_helper.validateUserUrl,
  cwmpAcsPass                  = post_helper.validatePass,
  cwmpState                    = post_helper.validateBoolean,
  cwmpPeriodic                 = validateAND(validateWholeNumber, validateNumber(10, 300000)),
  connectionrequestAuth        = post_helper.getValidateInEnumSelect(conreqauthSelect),
  connectionrequestUser        = post_helper.getOptionalValidation(validateOR(post_helper.validateConnReqNone, valiateStringLength)),
  connectionrequestPass        = post_helper.getOptionalValidation(validateOR(post_helper.validateConnReqNone, validatePassword(valiateStringLength))),
  ipPreference                 = post_helper.getValidateInEnumSelect(ipPreferenceSelect),
  connectionrequestAllowedIPv4 = ipv4Validate,
  connectionrequestAllowedIPv6 = ipv6Validate
}

if post_helper.getVariantValue(variantHelper, "xmppconfig") then
  mapvalid.xmppPass = xmppPassValidation
  mapvalid.xmppUser = xmppUserValidation
  mapvalid.xmppPort =  post_helper.validateStringIsPort
  mapvalid.xmppEnable = post_helper.validateBoolean
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapvalid)

local conreqauthclass = {
  group = {
    class ="monitor-connectionrequestAuth monitor-1 monitor-2",
  }
}

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

local function import_config()
  local filename = untaint(ngx.req.get_uri_args().name)
  local rcvOk
  if post_helper.validateFilename(filename) then
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
    if not next(helpmsg) and (postContent.connectionrequestAllowedIPv4 ~= "" or postContent.connectionrequestAllowedIPv6 ~= "") then
      local ipv4 = postContent.connectionrequestAllowedIPv4
      local ipv6 = postContent.connectionrequestAllowedIPv6
      local allowedIPs
      if ipv4 and ipv6 then
        if ipv6 == "" then
	  allowedIPs = ipv4
	elseif ipv4 == "" then
	  allowedIPs = ipv6
	else
          allowedIPs = ipv4 .. "," .. ipv6
	end
        proxy.set("uci.cwmpd.cwmpd_config.connectionrequest_allowedips", allowedIPs)
      end
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
local tableIPv4, tableIPv6 = splitIPv4IPv6(ips, ",")
local allowedIPv4, allowedIPv6 = table.concat(tableIPv4, ",") or "", table.concat(tableIPv6, ",") or ""
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"CWMP Settings", false, true) ); ngx.print('\
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
        ui_helper.createInputText(T"Connection Request Allowed IPv4", "connectionrequestAllowedIPv4", allowedIPv4, cwmpinput, helpmsg.connectionrequestAllowedIPv4),
        ui_helper.createInputText(T"Connection Request Allowed IPv6", "connectionrequestAllowedIPv6", allowedIPv6, cwmpinput, helpmsg.connectionrequestAllowedIPv6),
        ui_helper.createInputSelect(T"IPv4/IPv6", "ipPreference", ipPreferenceSelect, content.ipPreference)
      )
      local html = {}
      if post_helper.getVariantValue(variantHelper, "xmppconfig") then
        local xmpp_class_enable = {
          input = {
            class = "monitor-changes",
          }
        }
        html[#html + 1] = ui_helper.createSwitch(T"XMPP Enabled", "xmppEnable", content.xmppEnable, xmpp_class_enable)
        local xmppinput = {
          group = {
            class ="monitor-xmppEnable monitor-1",
          },
          input = {
            maxlength= "255",
            class = "span2"
          }
        }
        html[#html+1] = ui_helper.createInputText(T"XMPP Port", "xmppPort", content.xmppPort, xmppinput, helpmsg.xmppPort)
        html[#html+1] = ui_helper.createInputText(T"XMPP Username", "xmppUser", content.xmppUser, xmppinput, helpmsg.xmppUser)
        html[#html+1] = ui_helper.createInputPassword(T"XMPP Password", "xmppPass", content.xmppPass, xmppinput, helpmsg.xmppPass)
        ngx.print(html)
      end
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
var FileUpload = "');  ngx.print( allowedIpContent["uploadFile"] ); ngx.print('";\
var form_dataSession = "');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('"\
</script>\
<script src="/js/cwmpconf.js"></script>\
'); 