--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local admin = session:hasAccess("/modals/usermgr-modal.lp")
local assistance = require 'web.assistance'
local assistant = assistance.getAssistant('remote')

if assistant then
    local content
    local state
    if assistant:enabled() then
        state = "1"
        local light = ui_helper.createSimpleLight(state, T"Remote assistance enabled")
        if admin then
            if assistant:isRandomPassword() then
                content = {
                    light,'<br/>',
                    T"Port:",format(' <strong id="port">%s</strong>', assistant:port()),'<br/>',
                    T"Username:",format(' <strong id="username">%s</strong>', assistant:username()),"<br/>",
                    T"Password:", format(' <strong id="password">%s</strong>', assistant:password()),
                }
            else
                -- We will not show the password which was given by user
                content = {
                    light,'<br/>',
                    T"Port:",format(' <strong id="port">%s</strong>', assistant:port()),'<br/>',
                    T"Username:",format(' <strong id="username">%s</strong>', assistant:username()),"<br/>",
                }
            end
        else
            content = {light}
        end
    else
        state = "0"
        content = {
            ui_helper.createSimpleLight(state, T"Remote assistance disabled")
        }
    end
  ngx.print('\
\
<div class="span3">\
    <div class="smallcard">\
        ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Management", "modals/usermgr-modal.lp") ); ngx.print('\
        <div class="content">\
            ');  ngx.print( content ); ngx.print('\
        </div>\
    </div>\
</div>\
');  end   ngx.print('\
'); 