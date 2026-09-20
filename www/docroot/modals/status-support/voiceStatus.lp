--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local content = {
  uri0 = "uci.mmpbxrvsipnet.profile.@sip_profile_0.uri",
  hookstate0 = "rpc.mmpbx.device.@fxs_dev_0.hookstate",
  profileUsable0 = "rpc.mmpbx.profile.@sip_profile_0.sipRegisterState",
}
content_helper.getExactContent(content)

local content_line2 = {
  uri1 = "uci.mmpbxrvsipnet.profile.@sip_profile_1.uri",
  hookstate1 = "rpc.mmpbx.device.@fxs_dev_1.hookstate",
  profileUsable1 = "rpc.mmpbx.profile.@sip_profile_1.sipRegisterState",
}
content_helper.getExactContent(content_line2)

  ngx.print('\
  <h1>');  ngx.print(T"Voice Status"); ngx.print('</h1>\
  <h2><span style="padding-right: 5px;">');  ngx.print(T"Here you find the overview of your active phone numbers. For any configurations you would like to make, please go to the Phone menu."); ngx.print('</span></h2>\
  <h3>');  ngx.print(T"Phone Number Status"); ngx.print('</h3>\
  <div class="h3-content content-voice-status">\
    <div class="mobile voice-status table">\
      <div class="mobile-entry">\
        <div class="mobile-title">\
          <span>');  ngx.print(T"Phone Number"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  ngx.print(content["uri0"]); ngx.print('</span>\
        </div>\
        <div class="mobile-title">\
          <span>');  ngx.print(T"Line"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  if(content["hookstate0"] == "onHook") then  ngx.print(T"On hook"); elseif(content["hookstate0"] == "offHook") then  ngx.print(T"Off hook"); end  ngx.print('</span></div>\
        <div class="mobile-title">\
           <span>');  ngx.print(T"Service Status"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  if(content["profileUsable0"] == "Registered") then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span></div>\
      </div>\
       ');  if(content_line2["hookstate1"] ~= "") then  ngx.print('\
       <div class="mobile-entry">\
        <div class="mobile-title">\
          <span>');  ngx.print(T"Phone Number"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  ngx.print(content_line2["uri1"]); ngx.print('</span>\
        </div>\
        <div class="mobile-title">\
          <span>');  ngx.print(T"Line"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  if(content_line2["hookstate1"] == "onHook") then  ngx.print(T"On hook"); elseif(content_line2["hookstate1"] == "offHook") then  ngx.print(T"Off hook"); end  ngx.print('</span></div>\
        <div class="mobile-title">\
           <span>');  ngx.print(T"Service Status"); ngx.print('</span></div>\
        <div class="mobile-content">\
          <span>');  if(content_line2["profileUsable1"] == "Registered") then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span></div>\
      </div>\
      ');  end  ngx.print('\
    </div>\
\
    <div class="table voice-status desktop">\
      <div class="table-row table-row-head">\
        <div class="table-col phone_width table-col1">\
          <span>');  ngx.print(T"Phone Number"); ngx.print('</span></div>\
        <div class="table-col table-col2">\
          <span>');  ngx.print(T"Line"); ngx.print('</span></div>\
        <div class="table-col table-col3">\
          <span>');  ngx.print(T"Service Status"); ngx.print('</span></div>\
      </div>\
      <div class="table-row">\
        <div class="table-col phone_width table-col1">\
          <span id="voiceStat-info-uri0">');  ngx.print(content["uri0"]); ngx.print('</span>\
        </div>\
        <div class="table-col table-col2">\
          <span id="voiceStat-info-hookstate0">');  if(content["hookstate0"] == "onHook") then  ngx.print(T"On hook"); elseif(content["hookstate0"] == "offHook") then  ngx.print(T"Off hook"); end  ngx.print('</span></div>\
        <div class="table-col table-col3">\
          <span id="voiceStat-info-profileUsable0">');  if(content["profileUsable0"] == "Registered") then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span></div>\
      </div>\
      ');  if(content_line2["hookstate1"] ~= "") then  ngx.print('\
      <div class="table-row">\
        <div class="table-col phone_width table-col1">\
          <span id="voiceStat-info-uri1">');  ngx.print(content_line2["uri1"]); ngx.print('</span>\
        </div>\
        <div class="table-col table-col2">\
          <span id="voiceStat-info-hookstate1">');  if(content_line2["hookstate1"] == "onHook") then  ngx.print(T"On hook"); elseif(content_line2["hookstate1"] == "offHook") then  ngx.print(T"Off hook"); end  ngx.print('</span></div>\
        <div class="table-col table-col3">\
          <span id="voiceStat-info-profileUsable1">');  if(content_line2["profileUsable1"] == "Registered") then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span></div>\
      </div>\
      ');  end  ngx.print('\
    </div>\
  </div>\
\
'); 