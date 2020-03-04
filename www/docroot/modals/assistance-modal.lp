--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local assistance = require("web.assistance")
local path = proxy.get("uci.web.assistance.")[1].path
local uci_assistance = "uci.web.assistance."
local content_assistance = content_helper.convertResultToObject(uci_assistance .. "@.", proxy.get(uci_assistance))
local timeout = content_assistance[1].timeout
local secname = content_assistance[1].paramindex
local assistant = assistance.getAssistant(secname)
local interface = proxy.get(path .. "interface")[1].value
local interface6 = proxy.get(path .. "interface6")[1].value
local gVChkbox = post_helper.getValidateCheckboxSwitch()
local format = string.format

local mode_map = {
    { "0", T'Temporary' },
    { "1", T'Permanent'},
}

local mode_map2 = setmetatable({
    ["0"]= T'Temporary',
    ["1"]= T'Permanent',
}, untaint_mt)

local checkbox_map = setmetatable({
    ["0"]= T'No',
    ["1"]= T'Yes',
}, untaint_mt)

local srp_param_map = {
    srp_salt = "salt",
    srp_verifier = "verifier",
}

local function get_srp_from_uci(user)
    local srp_pair, user_map = {}, {}
    local cfg=proxy.get("uci.web.user.")
    local srp
    if cfg then
        for _, entry in ipairs(cfg) do
            local name = string.match(entry.path,"%.@([^.]*)%.")
            if name then
                if entry.param == "name" then
                    user_map[entry.value] = name
                elseif srp_param_map[entry.param] and entry.value ~= "" then
                    srp_pair[name] = srp_pair[name] or {}
                    srp_pair[name][srp_param_map[entry.param]] = entry.value
                end
            end
        end
        srp = srp_pair[user_map[user]]
        if srp and (not srp["salt"] or not srp["verifier"]) then
            srp = nil
        end
    end
    return srp, user_map[user]
end

local uci_assist_user = content_assistance[1].user
local uci_assist_srp, uci_assist_user_sec = get_srp_from_uci(uci_assist_user)

local state = assistant:enabled() and "1" or "0"
local error

local helpmsg={}
local content=nil
if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        gVChkbox(content["ra_enabled"], content, "ra_enabled")
        local password = nil
        local newstate = content["ra_enabled"] or state
        if newstate~=state and newstate=="1" then
            gVChkbox(content["random_psw"], content, "random_psw")
            if content["random_psw"] == "0" then
                -- the new setting is to use fixed password
                if content["salt"]=="" or not content["salt"] then
                    if not uci_assist_srp then
                       -- return error if previous password is random and no password is given by user
                       helpmsg["password"]="Password is empty"
                    else
                       -- set password to false and use the existing password
                       password=uci_assist_srp
                       content["salt"] = nil
                       content["verifier"] = nil
                    end
                 else
                    -- set password to the new salt and verifier
                    password = {
                        salt = content["salt"],
                        verifier = content["verifier"]
                    }
                end
            else
                -- remove passowrd for user assist if random password mode is enabled
                content["salt"] = ""
                content["verifier"] = ""
            end
        else
           content["random_psw"] = uci_assist_srp and "0" or "1"
           content["mode"] = assistant:isPermanentMode() and "1" or "0"
           password = false
        end
        if next(helpmsg)==nil then
           if newstate~=state and newstate=="1" then
              local assist_user_path_pattern = "uci.web.user.@%s.%s"
              local assistance_path_pattern = "uci.web.assistance.@%s.%s"
              local sets = {
                 [format(assist_user_path_pattern, uci_assist_user_sec, "srp_salt")] = content["salt"],
                 [format(assist_user_path_pattern, uci_assist_user_sec, "srp_verifier")] = content["verifier"],
                 [format(assistance_path_pattern, secname, "timeout")] = content["mode"] == "1" and "-1" or "",
              }
              proxy.set(sets)
              assistant._persistent = (content["mode"] == "1")
              assistant._timeout = assistant._persistent and -1 or 1800
           end
           if type(password) == 'table' then
                password.salt = string.untaint(password.salt)
                password.verifier = string.untaint(password.verifier)
           end
           local ok, err = assistant:enable(newstate=="1", content["mode"] == "1", password)
           state = assistant:enabled() and "1" or "0"
           if not ok then
              error = err
           end
           message_helper.pushMessage(T"Changes saved successfully", "success")
        else
           content["ra_enabled"] = newstate
           message_helper.pushMessage(T"Some parameters failed validation", "error")
        end
    end
end

---End of POST query processing

if not content then
   content = {}
   content["ra_enabled"] = assistant:enabled() and "1" or "0"
   content["mode"] = (timeout == "-1") and "1" or "0"
   content["random_psw"] = uci_assist_srp and "0" or "1"
end

content["password"]=""
if content["random_psw"] == "1" and assistant:enabled() then
   content["password"] = assistant:password()
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Assistance") ); ngx.print('\
\
<div class="modal-body update">\
\
<form class="form-horizontal" method="post" action="modals/assistance-modal.lp">\
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
               class = "alert-info",
          }
     }
    local info
    if assistant:enabled() then
        info = string.format("<p>Remote assistance is currently enabled. </p><p>Click 'Apply' button with the 'Enabled' checkbox disabled to disable remote assistance on your gateway </p>")
    else
        info = string.format("<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Enabled' checkbox enabled your gateway will be accessible from your broadband connection. After %s minutes of inactivity, or on reboot, remote assistance will be automatically disabled for 'Temporary' mode. </p><p> Please provide the following parameters to your ISP:</p>", timeout )
    end
    local html={}
    html[#html + 1] = ui_helper.createAlertBlock(T(info), infomessage)
    local ra_enable_class = {
        input = {
           class = "monitor-changes",
        }
    }
    local ra_cfg_class = {
        group = {
           class ="monitor-ra_enabled monitor-1",
        }
    }
    local ra_class = {
        group = {
           class ="monitor-ra_enabled monitor-0",
        }
    }
    local ra_random_class = {
        group = {
           class ="monitor-ra_enabled monitor-1",
        },
        input = {
           class = "monitor-changes",
        }
    }
    local ra_psw_class = {
        group = {
           class ="monitor-random_psw monitor-0",
        }
    }

  html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "ra_enabled", content["ra_enabled"], ra_enable_class)
  if assistant:enabled() then
     local data = proxy.get("rpc.network.interface.@" .. interface .. ".ipaddr")
     local wanipv4 = data and data[1] and data[1].value or ""
     local wanipv6 = ""
     if interface6 ~= "" then
        data = proxy.get("rpc.network.interface.@" .. interface6 .. ".ip6addr")
        wanipv6 = data and data[1] and data[1].value and string.match(data[1].value, "^%S+") or ""
     end
     local url = ""
     local urls = {}
     local port = assistant:port()
     if port ~= nil and port ~= "" then
        urls[#urls + 1] = wanipv4 ~= "" and string.format("https://%s:%s/", wanipv4, port) or nil
        urls[#urls + 1] = wanipv6 ~= "" and string.format("https://[%s]:%s/", wanipv6, port) or nil
        url = table.concat(urls, "<br>")
     end
     html[#html + 1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]])
     html[#html + 1] = ui_helper.createLabel(T"URL", (#url ~= 0 and url) or T"Not connected to the Internet", {span = { class = "span6" }})
  else
     html[#html + 1] = ui_helper.createInputRadio(T"Mode", "mode", mode_map, content["mode"],ra_cfg_class)
     html[#html + 1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]],ra_class)
  end

  html[#html + 1] = ui_helper.createLabel(T"Username", assistant:username())
  local password = assistant:password()
  if (assistant:enabled() and password =="") or (content["random_psw"] == "0") then
     password = "********"
  end
  if assistant:enabled() then
     html[#html + 1] = ui_helper.createLabel(T"Use Random Password", checkbox_map[content["random_psw"]])
     html[#html + 1] = ui_helper.createLabel(T"Password", password)
     html[#html + 1] = error and ui_helper.createLabel("Error", error) or ''
  else
     html[#html + 1] = ui_helper.createCheckboxSwitch(T"Use Random Password", "random_psw", content["random_psw"],ra_random_class)
     html[#html + 1] = ui_helper.createLabel(T"Use Random Password", checkbox_map[content["random_psw"]],ra_class)
     html[#html + 1] = "<div class='monitor-ra_enabled monitor-1'>"
     html[#html + 1] = ui_helper.createInputText(T"Password", "password", content["password"], ra_psw_class, helpmsg["password"])
     html[#html + 1] = "</div>"
     if content["random_psw"] == "0" then
       html[#html + 1] = ui_helper.createLabel(T"Password", password,ra_class)
     end
     html[#html + 1] = ui_helper.createSimpleInputHidden("salt", "")
     html[#html + 1] = ui_helper.createSimpleInputHidden("verifier", "")
  end

  ngx.print(html)
    ngx.print('\
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
<script src="/js/srp-min.js" ></script>\
<script type="text/javascript" >\
    $("#save-assistance-config").click(function () {\
        function sendData()\
        {\
            var form = $(".modal form");\
            var params = form.serializeArray();\
            params.push({\
                 name : "action",\
                 value : "SAVE"\
            }, tch.elementCSRFtoken());\
            var target = form.attr("action");\
            tch.loadModal(target, params, function () {\
                var error = $(\'.error\');\
                if (error.length > 0) {\
                    // We are in an error case\
                    // Show the save/close buttons since nothing has been saved\
                    $(\'#modal-no-change\').hide();\
                    $(\'#modal-changes\').show();\
                 }\
\
                 $(\'.error input:not([type="hidden"])\').first().focus();\
            });\
        };\
\
        var user = "');  ngx.print(assistant:username()); ngx.print('";\
        var password = $(\'input[name="password"]\').val();\
\
        if(password != "" && password != undefined) {\
             var srp = new SRP();\
             srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {\
                 $(\'input[name="salt"]\').val(salt);\
                 $(\'input[name="verifier"]\').val(verifier);\
                 $(\'input[name="password"]\').val(""); // clean that up no need to send it over the air\
                 sendData();\
                 return;\
             });\
        }\
        else {\
             sendData();\
             return;\
        }\
    });\
</script>\
'); 