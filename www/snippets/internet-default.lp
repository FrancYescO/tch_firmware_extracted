--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require ("web.content_helper")
local message_helper = require("web.uimessage_helper")

local content_wans = {
    enable = "uci.wansensing.global.enable",
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_wans)

local content, helpmsg
if content_wans.enable == "1" then
    -- Process POST query
    local post_helper = require("web.post_helper")

    local mapParams = {
        uci_wan_username = "uci.network.interface.@ppp.username",
        uci_wan_password = "uci.network.interface.@ppp.password",
        uci_pppv_username = "uci.network.interface.@pppv.username",
        uci_pppv_password = "uci.network.interface.@pppv.password",
    }

    if content_wans.variant == "novas" then
        mapParams.uci_pppv_username = "uci.network.interface.@wan.username"
        mapParams.uci_pppv_password = "uci.network.interface.@wan.password"
    end

    -- Shortcuts to validation helpers to make lines shorter
    local vNES = post_helper.validateNonEmptyString
    local gVP = post_helper.getValidationPassword

    local mapValid = {
        uci_wan_username = function(value, object, key)
          local ok, msg = vNES(value)
          if ok then
            object["uci_pppv_username"] = object["uci_wan_username"]
            return true
          else
            return ok, msg
          end
        end,
        uci_wan_password = function(value, object, key)
          local validate = gVP(vNES)
          local ok, msg = validate(value, object, key)
          if ok then
            object["uci_pppv_password"] = object["uci_wan_password"]
            return true
          else
            return ok, msg
          end
        end,

        uci_pppv_username = function(value,object)
            return true
        end,
        uci_pppv_password = function(value,object)
            return true
        end,
    }

    content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
    -- End POST process
end
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Connection" ); ngx.print('</legend>\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
\
');  
local info_class = {
    alert = {
        class = "alert-info",
        }
    }
local html = {}
if content_wans.enable == "0" then
    html[#html+1] =  ui_helper.createAlertBlock(T"The internet access is not available because the internet mode is not configured. You can try to either enable auto WAN sensing or configure it manually", info_class)
else
    html[#html+1] =  ui_helper.createAlertBlock(T"Auto WAN Sensing is on and trying to connect ...", info_class)

    -- PPP username
    local class_username = {
        input = {
            maxlength= "128",
            class = "span6",
        }
    }
    html[#html + 1] = ui_helper.createInputText(T"PPPoE Username", "uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    html[#html + 1] = ui_helper.createInputPassword(T"PPPoE Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
end
ngx.print(html)
  ngx.print('\
</fieldset>\
'); 