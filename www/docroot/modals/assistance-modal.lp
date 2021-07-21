--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local assistance = require("web.assistance")
local uciAssistance = "uci.web.assistance."
local contentAssistance = content_helper.convertResultToObject(uciAssistance .. "@.", proxy.get(uciAssistance))
local timeout = contentAssistance[1].timeout
local secname = contentAssistance[1].paramindex
local assistant = assistance.getAssistant(secname)
local validateCheckbox = post_helper.getValidateCheckboxSwitch()
local format, untaint = string.format, string.untaint
local untaint_mt = require("web.taint").untaint_mt
local state = assistant:enabled() and "1" or "0"
local error
local session = ngx.ctx.session
local role = session:getrole()
local variant_helper = require("variant_helper")
local assistanceHelper = post_helper.getVariant(variant_helper, "Assistance", "assistance")
local remoteAssistance = post_helper.getVariantValue(assistanceHelper, "remoteAssistance")

local modeMap = {
  { "0", T"Temporary"},
  { "1", T"Permanent"}
}

local untaintModeMap = setmetatable({
  ["0"] =  T"Temporary",
  ["1"] = T"Permanent"
}, untaint_mt)

local checkboxMap = setmetatable({
  ["0"] = T"No",
  ["1"] = T"Yes"
}, untaint_mt)

local srpParamMap = {
  srp_salt = "salt",
  srp_verifier = "verifier"
}

-- Srp is fetched from uci path
local function getSrpFromuci(user)
  local srpPair, userMap = {}, {}
  local cfg = proxy.get("uci.web.user.")
  local srp
  if cfg then
    for _, entry in ipairs(cfg) do
      local name = string.match(entry.path, "%.@([^.]*)%.")
      if name then
        if entry.param == "name" then
          userMap[entry.value] = name
        elseif srpParamMap[entry.param] and entry.value ~= "" then
          srpPair[name] = srpPair[name] or {}
          srpPair[name][srpParamMap[entry.param]] = entry.value
        end
      end
    end
    srp = srpPair[userMap[user]]
    if srp and (not srp["salt"] or not srp["verifier"]) then
      srp = nil
    end
  end
  return srp, userMap[user]
end

local uciAssistUser = contentAssistance[1].user
local uciAssistSrp, uciAssistUserSec = getSrpFromuci(uciAssistUser)

local helpmsg = {}
local content
if ngx.var.request_method == "POST" then
  content = ngx.req.get_post_args()
  if content.action == "SAVE" then
    if remoteAssistance then
      content.random_psw = "1"
      content.mode = "0"
      -- make remote assistant to disable after timeout even if actively used
      assistant._hardtimeout = true
    end
    local password
    local newstate = content.ra_enabled or state
    if newstate ~= state and newstate == "1" then
      validateCheckbox(content.random_psw, content, "random_psw")
      if content.random_psw == "0" then
        -- the new setting is to use fixed password
        if content.salt == "" or not content.salt then
          if not uciAssistSrp then
            -- return error if previous password is random and no password is given by user
            helpmsg["password"] = T"Password is empty"
          else
            -- set password to false and use the existing password
            password = uciAssistSrp
            content.salt = nil
            content.verifier = nil
          end
        else
          -- set password to the new salt and verifier
          password = {
            salt = content.salt,
            verifier = content.verifier
          }
        end
      else
        -- remove passowrd for user assist if random password mode is enabled
        content.salt = ""
        content.verifier = ""
      end
    else
      content.random_psw = uciAssistSrp and "0" or "1"
      content.mode = assistant:isPermanentMode() and "1" or "0"
      password = false
    end
    if not next(helpmsg) then
      if newstate ~= state and newstate == "1" then
        local assistUserPathPattern = "uci.web.user.@%s.%s"
        local assistancePathPattern = "uci.web.assistance.@%s.%s"
        local sets = {
          [format(assistUserPathPattern, uciAssistUserSec, "srp_salt")] = content.salt,
          [format(assistUserPathPattern, uciAssistUserSec, "srp_verifier")] = content.verifier,
          [format(assistancePathPattern, secname, "timeout")] = content.mode == "1" and "-1" or ""
        }
        proxy.set(sets)
        assistant._persistent = content.mode == "1"
        assistant._timeout = assistant._persistent and -1 or 1800
      end
      if type(password) == 'table' then
        password.salt = untaint(password.salt)
        password.verifier = untaint(password.verifier)
      end
      local ok, err = assistant:enable(newstate == "1", content.mode == "1", password)
      if not ok then
        error = err
      end
      message_helper.pushMessage(T"Changes saved successfully", "success")
    else
      content.ra_enabled = newstate
      message_helper.pushMessage(T"Some parameters failed validation", "error")
    end
  end
end

if not content then
  content = {}
  content.ra_enabled = assistant:enabled() and "1" or "0"
  content.mode = (timeout == "-1") and "1" or "0"
  content.random_psw = uciAssistSrp and "0" or "1"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Assistance") ); ngx.print('\
<div class = "modal-body-update">\
  <form class = "form-horizontal" method = "post" action = "modals/assistance-modal.lp">\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
    <fieldset>\
    ');  
      if timeout == "-1" or timeout == "" then
        timeout = "30"
      end
      local infomessage = {
        alert = {
          class = "alert-info"
        }
      }
      local info
      if assistant:enabled() then
        info = string.format("<p>Remote assistance is currently enabled. </p><p>Click 'Apply' button with the 'Remote Assistance' toggle button disabled to disable remote assistance on your gateway </p>")
      else
        if remoteAssistance then
          info = string.format("<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Remote Assistance' toggle button enabled your gateway will be accessible from your broadband connection. After %s minutes from the moment enabled, or on reboot, remote assistance will be automatically disabled. </p><p> Please provide the following parameters to your ISP:</p>", timeout )
        else
          info = string.format("<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Remote Assistance' toggle button enabled your gateway will be accessible from your broadband connection. After %s minutes of inactivity, or on reboot, remote assistance will be automatically disabled for 'Temporary' mode. </p><p> Please provide the following parameters to your ISP:</p>", timeout )
        end
      end
      local html = {}
      local ra_enable_class = {
        input = {
          class = "monitor-changes"
        }
      }
      local ra_cfg_class = {
        group = {
          class = "monitor-ra_enabled monitor-1"
        }
      }
      local ra_class = {
        group = {
          class = "monitor-ra_enabled monitor-0"
        }
      }
      local span5 = { span = { class = "span5" } }
      if post_helper.isFeatureEnabled("assistport", role) then
        html[#html + 1] = ui_helper.createAlertBlock(T(info), infomessage)
      end
      if remoteAssistance then
        html[#html + 1] = ui_helper.createSwitch(T"Remote Assistance", "ra_enabled", content.ra_enabled)
      else
        html[#html + 1] = ui_helper.createSwitch(T"Remote Assistance", "ra_enabled", content.ra_enabled, ra_enable_class)
      end
      if assistant:enabled() then
        if post_helper.isFeatureEnabled("assistport", role) then
          local url = assistant:URL()
          local url6 = assistant:URL6()
          html[#html + 1] = ui_helper.createLabel(T"Mode", untaintModeMap[content.mode])
          html[#html + 1] = ui_helper.createLabel(T"URL", url or T"Not connected to the Internet", span5)
          html[#html + 1] = remoteAssistance and url6 and ui_helper.createLabel(T"URL6", url6, span5)
        else
          html[#html + 1] = ui_helper.createLabel(T"Port", assistant:port())
        end
      else
        if post_helper.isFeatureEnabled("assistport", role) then
          if remoteAssistance then
            html[#html + 1] = ui_helper.createLabel(T"Mode", untaintModeMap[content.mode])
          else
            html[#html + 1] = ui_helper.createInputSelect(T"Mode", "mode", modeMap, content.mode)
          end
        end
      end
      password = assistant:password()
      if not remoteAssistance then
        if (assistant:enabled() and password == "") or (content.random_psw == "0") then
          password = ""
        end
      end
      if (not post_helper.isFeatureEnabled("assistport", role) and assistant:enabled()) or post_helper.isFeatureEnabled("assistport", role) then
        html[#html + 1] = ui_helper.createLabel(T"Username", assistant:username())
      end
      if post_helper.isFeatureEnabled("assistport", role) then
        html[#html + 1] = ui_helper.createLabel(T"Use Random Password", checkboxMap[content.random_psw] ,not assistant:enabled() and ra_class or {})
      end
      if (not post_helper.isFeatureEnabled("assistport", role) and assistant:enabled()) or post_helper.isFeatureEnabled("assistport", role) then
        html[#html + 1] = ui_helper.createLabel(T"Password", password ,not assistant:enabled() and ra_class or {})
      end
      if assistant:enabled() then
        html[#html + 1] = error and ui_helper.createLabel("Error", error) or ''
      else
        if post_helper.isFeatureEnabled("assistport", role) then
          if not remoteAssistance then
            html[#html + 1] = ui_helper.createCheckboxSwitch(T"Use Random Password", "random_psw", content.random_psw,ra_cfg_class)
            html[#html + 1] = ui_helper.createInputText( T"Password", "password", content.password, ra_cfg_class, helpmsg["password"])
            html[#html + 1] = ui_helper.createSimpleInputHidden("salt", "")
            html[#html + 1] = ui_helper.createSimpleInputHidden("verifier", "")
          end
        end
      end
      ngx.print(html)  ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
');  ngx.print(string.format([[
  <div class="modal-footer">
    <div id="modal-no-change">
      <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
    </div>
    <div id="modal-changes" class="hide">
      <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
      <div id="save-assistance-config" class="btn btn-primary btn-large">%s</div>
    </div>
  </div>
  ]], T"Close", T"Cancel", T"Apply")); ngx.print('\
\
<script src = "/js/srp-min.js"></script>\
<script type = "text/javascript" >\
  var user = "');  ngx.print( assistant:username() ); ngx.print('";\
  var passErrMsg  = "');  ngx.print( T"Password is empty" ); ngx.print('";\
  var passCondMsg = "');  ngx.print( T"Password must contain at least 12 alphanumeric characters including both upper and lower case letters," .. "<br/>" .. T"at least one number and at least one special character" ); ngx.print('";\
</script>\
<script src="/js/assistance.js"></script>\
'); 