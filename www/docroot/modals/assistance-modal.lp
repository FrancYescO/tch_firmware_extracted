--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local assistance = require("web.assistance")
local path = proxy.get("uci.web.assistance.")[1].path
local _, _, secname = string.find(path, "web%.assistance%.@([^%.]*)%.")
local assistant = assistance.getAssistant(secname)
local timeout = proxy.get(path .. "timeout")[1].value
local interface = proxy.get(path .. "interface")[1].value
local gVChkbox = post_helper.getValidateCheckboxSwitch()
local bridged = require("bridgedmode_helper")
local format = string.format

local state = assistant:enabled() and "1" or "0"
local error

local mode_map = {
    { "0", T'Temporary' },
    { "1", T'Permanent'},
}

local mode_map2 = {
    ["0"]= T'Temporary',
    ["1"]= T'Permanent',
}

local checkbox_map = {
    ["0"]= T'No',
    ["1"]= T'Yes',
}

local helpmsg={}
local content=nil
if ngx.var.request_method == "POST" then
    content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        gVChkbox(content["ra_enabled"], content, "ra_enabled")
        local password = nil
        local newstate = content["ra_enabled"] or state
        if newstate~=state and newstate=="1" then
            content["mode"] = string.untaint(content["mode"])
            gVChkbox(content["random_psw"], content, "random_psw")
            if content["random_psw"] == "0" then
                -- the new setting is to use fixed password
                content["salt"] =string.untaint(content["salt"])
                content["verifier"] =string.untaint(content["verifier"])
                if content["salt"]=="" or not content["salt"] then
                    if assistant:isRandomPassword() then
                       -- return error if previous password is random and no password is given by user
                       helpmsg["password"]="Password is empty"
                    else
                       -- set password to false and use the existing password
                       password=false
                    end
                 else
                    -- set password to the new salt and verifier
                    password=password or {}
                    password["salt"]=content["salt"]
                    password["verifier"] = content["verifier"]
                end
            end
        else
           content["random_psw"] = assistant:isRandomPassword() and "1" or "0"
           content["mode"] = assistant:isPermanentMode() and "1" or "0"
           password = false
        end
        if next(helpmsg)==nil then
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
   content["mode"] = assistant:isPermanentMode() and "1" or "0"
   content["random_psw"] = assistant:isRandomPassword() and "1" or "0"
end
--clear all srp info
content["salt"] = ""
content["verifier"]=""

content["password"]=""
if content["random_psw"] == "1" and assistant:enabled() then
   content["password"] = assistant:password()
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Management", false, false, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
');  
if not bridged.isBridgedMode() then
    local tabs = {
    {
        desc = T"User Manager",
        target = "modals/usermgr-modal.lp",
    },
    {
        desc = T"Remote Assistance",
        active = "active",
        target = "modals/assistance-modal.lp",
    },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
end
  ngx.print('\
\
<form class="form-horizontal" method="post" action="modals/assistance-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
');  
     if timeout == "" then
        timeout = "30"
     end
     if interface == "" then
        interface = "wan"
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
        info = string.format("<p>Remote assistance is currently disabled.</p><p> By clicking on the 'Apply' button with the 'Enabled' checkbox enabled your gateway will be accessible from your broadband connection. After %s minutes of inactivity, or on reboot, remote assistance will be automatically disabled. </p><p> Please provide the following parameters to your ISP:</p>", timeout )
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
     local wanip = proxy.get("rpc.network.interface.@" .. interface .. ".ipaddr")[1].value
     local url =""
     if wanip ~= "" then
         url=string.format("https://%s:%s/", wanip, assistant:port())
     end
     html[#html + 1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]])
     html[#html + 1] = ui_helper.createLabel(T"URL", url)
  else
     html[#html + 1] = ui_helper.createInputRadio(T"Mode", "mode", mode_map, content["mode"],ra_cfg_class)
     html[#html + 1] = ui_helper.createLabel(T"Mode", mode_map2[content["mode"]],ra_class)
  end

  html[#html + 1] = ui_helper.createLabel(T"Username", assistant:username())
  local password = assistant:password()
  if content["random_psw"] == "0" then
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
     html[#html + 1] = ui_helper.createSimpleInputHidden("salt", content["salt"])
     html[#html + 1] = ui_helper.createSimpleInputHidden("verifier", content["verifier"])
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