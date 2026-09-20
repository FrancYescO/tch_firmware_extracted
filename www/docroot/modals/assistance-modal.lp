--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

local state = assistant:enabled() and "1" or "0"
local error

local dm = require("datamodel")
local function get_srp_from_uci(user)
    local srp_pair, user_map = {}, {}
    local cfg=dm.get("uci.web.user.")
    local srp
    if cfg then
        for _, entry in ipairs(cfg) do
            local name = string.match(string.untaint(entry.path),"%.@([^.]*)%.")
            if name then
                if entry.param == "name" then
                    user_map[entry.value] = name
                end
                if (entry.param == "srp_salt" or entry.param == "srp_verifier") and entry.value ~= "" then
                    srp_pair[name] = srp_pair[name] or {}
                    srp_pair[name][string.match(entry.param, "srp_(.*)")] = string.untaint(entry.value)
                end
            end
        end
        srp = srp_pair[user_map[user]]
        if srp and (not srp["salt"] or not srp["verifier"]) then
            srp = nil
        end
    end
    return srp
end

local function get_user(name)
    local result = dm.get("uci.web.assistance.@" .. name .. ".user")
    local user
    if result then
       user = result[1].value
    end
    return user
end

if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content["action"]=="SAVE" then
        local newstate = content["ra_enabled"] or state
        local user = get_user("remote")
        local password = get_srp_from_uci(user)
        local ok, err = assistant:enable(newstate=="1", true, password)
        state = assistant:enabled() and "1" or "0"
        if not ok then
            error = err
        else
            message_helper.pushMessage(T"Changes saved successfully", "success")
        end
    end
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Assistance") ); ngx.print('\
<div class="modal-body-update">\
<form class="form-horizontal" method="post" action="modals/assistance-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
  ');  ngx.print( ui_helper.createSwitch(T"Remote Assistance", "ra_enabled", state) ); ngx.print('\
  ');  if assistant:enabled() then
    ngx.print{
        ui_helper.createLabel(T"Port", assistant:port()),
        ui_helper.createLabel(T"Username", assistant:username()),
        ui_helper.createLabel(T"Password", assistant:password()),
        error and ui_helper.createLabel("Error", error) or '',
    }
  end   ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 