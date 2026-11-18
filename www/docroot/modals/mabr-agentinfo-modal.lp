--pretranslated: do not change this file
 
--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ngx = ngx
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local format, untaint = string.format, string.untaint

local agent_info = {
  status = "rpc.X_TELECOMITALIA_IT_MABRAgent.Status",
  sessionNumber = "rpc.X_TELECOMITALIA_IT_MABRAgent.SessionNumber",
  minSession = "rpc.X_TELECOMITALIA_IT_MABRAgent.MinSession",
  maxSession = "rpc.X_TELECOMITALIA_IT_MABRAgent.MaxSession",
  multicastBitRate = "rpc.X_TELECOMITALIA_IT_MABRAgent.MulticastsBitrate",
  minBitRate = "rpc.X_TELECOMITALIA_IT_MABRAgent.MinBitRate",
  maxBitRate = "rpc.X_TELECOMITALIA_IT_MABRAgent.MaxBitRate",
  mcastFrame = "rpc.X_TELECOMITALIA_IT_MABRAgent.Mcast_Frame"
}

content_helper.getExactContent(agent_info)

local status = agent_info.status and untaint(agent_info.status) or "disabled"

local mabr_state_map = {
  disabled = T"disabled",
  running = T"running",
  error = T"error"
}

local status_light_map = {
  disabled = "off",
  running ="green",
  error = "red"
}

  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"M-ABR", false, true))   ngx.print('\
<div class="modal-body update">\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  lp.setpath("/www/snippets/")
  lp.include("tabs-wanservices.lp")
    ngx.print('\
  <form class = "form-horizontal" method = "post" action = "modals/mabr-agentinfo-modal.lp">\
    <fieldset>\
      <legend>\
        ');  ngx.print( T" M-ABR Agent Info" ); ngx.print('\
      </legend>\
     ');  local iconUp = "<i class=\"icon-upload icon-large gray\"></i>"
     local iconDown = "<i class=\"icon-download icon-large gray\"></i>"
     ngx.print(ui_helper.createLight(T"Status", nil, mabr_state_map[status] , { light = { class = status_light_map[status] } }))
     if agent_info.status == "running" then
       ngx.print(ui_helper.createLabel(T"Session Number", agent_info.sessionNumber))
       ngx.print(ui_helper.createLabel(T"Min Session Number", agent_info.minSession))
       ngx.print(ui_helper.createLabel(T"Max Session Number", agent_info.maxSession))
       ngx.print(ui_helper.createLabel(T"Multicast Bitrate", agent_info.multicastBitRate))
       ngx.print(ui_helper.createLabel(T"Min Multicast Bitrate", agent_info.minBitRate))
       ngx.print(ui_helper.createLabel(T"Max Multicast Bit Rate", agent_info.maxBitRate))
       ngx.print(ui_helper.createLabel(T"Multicast Frame", agent_info.mcastFrame))
     end   ngx.print('\
   </fieldset>\
 </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 