--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
ngx.print('\
\
<div class="span3">\
    <div class="smallcard">',
        ui_helper.createCardHeader(T"Management", "modals/usermgr-modal.lp"), '\
        <div class="content card_bg" data-bg-text="&#xf0c0;">\
         <div class="divtable">\
            <p class="subinfos">\
               <strong class="modal-link" data-toggle="modal" data-remote="/modals/usermgr-modal.lp" data-id="usermgr-modal">', T"User Management", '</strong>\
	    </p>\
            <p class="subinfos">\
               <strong class="modal-link" data-toggle="modal" data-remote="/modals/logviewer-modal.lp" data-id="logviewer-modal">', T"Log Viewer", '</strong>\
            </p>\
         </div>\
        </div>\
    </div>\
</div>');

