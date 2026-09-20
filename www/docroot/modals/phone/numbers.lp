--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx, ipairs          = ngx, ipairs
local proxy                = require("datamodel")
local contentHelper        = require("web.content_helper")
local validateStringLength = require("web.post_helper").getValidateStringLengthInRange(0,63)
local string               = string
local format               = string.format
local find                 = string.find
local subStr               = string.sub

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local success = true
  local setParam = {}
  local rows = tonumber(postargs.rows)
  for i=1,rows do
    local index = postargs["index" .. i]
    if not validateStringLength(postargs["name" .. i]) then
      success = false
      break
    end
    setParam[format("uci.mmpbxrvsipnet.profile.%s.display_name",index)] = postargs["name" .. i]
  end
  if success and proxy.set(setParam) then
    proxy.apply()
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end

local fxsDevices = contentHelper.convertResultToObject("uci.mmpbxbrcmfxsdev.device.", proxy.get("uci.mmpbxbrcmfxsdev.device."))

local phoneNumbersData = {}
local profile_config

local map_conf = contentHelper.convertResultToObject("uci.mmpbx.incoming_map.", proxy.get("uci.mmpbx.incoming_map."))

for i,x in ipairs(fxsDevices) do
  phoneNumbersData[i] = {}
  phoneNumbersData[i].device_name = subStr(x.paramindex, 2)
  phoneNumbersData[i].user_friendly_name = x.user_friendly_name
  --Default values
  phoneNumbersData[i].sip_profile_index = ""
  phoneNumbersData[i].display_name = ""
  phoneNumbersData[i].uri = ""
  phoneNumbersData[i].number = ""

  for _,v in ipairs(map_conf) do
    if find(v.profile, "sip_profile_") then
      local j = 1
      while v["device.@"..j..".value"] do
        if v["device.@"..j..".value"] == phoneNumbersData[i].device_name then
          phoneNumbersData[i].sip_profile_index = "@"..v.profile
          profile_config = contentHelper.convertResultToObject("uci.mmpbxrvsipnet.profile.", proxy.get("uci.mmpbxrvsipnet.profile.@".. v.profile .."."))
    if profile_config[1] then
            phoneNumbersData[i].display_name = profile_config[1].display_name
            phoneNumbersData[i].uri = profile_config[1].uri
          end
          break
        end
        j = j+1
      end
    elseif find(v.profile, "internal_profile_") then
      local j = 1
      while v["device.@"..j..".value"] do
        if v["device.@"..j..".value"] == phoneNumbersData[i].device_name then
          profile_config = contentHelper.convertResultToObject("uci.mmpbxinternalnet.profile.", proxy.get("uci.mmpbxinternalnet.profile.@".. v.profile .."."))
    if profile_config[1] then
            phoneNumbersData[i].number = profile_config[1].number
          end
          break
        end
        j = j+1
      end
    end
  end
end
  ngx.print('\
\
 <h1>');  ngx.print(T"Phone Numbers"); ngx.print('</h1>\
<h2>');  ngx.print(T"Give your phone numbers and connections individual names."); ngx.print('</h2>\
<h3>');  ngx.print(T"Your Phone Numbers"); ngx.print('</h3>\
<form id="phno-form" class="form-horizontal" method="post" action="/modals/phone/numbers.lp" autocomplete="off">\
<div class="phoneNumbersInfo hidden-xs">\
<div class="phoneNumbersContent">\
      <div class="h3-content no-mobile hidden-xs">\
    <table class="table-three-columns">\
      <thead>\
      <tr>\
        <th><span>');  ngx.print(T"Connection"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Internal Number"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Phone Number"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Name"); ngx.print('</span></th>\
      </tr>\
      </thead>\
      <tbody>\
    ');  for i=1, #phoneNumbersData do  ngx.print('\
  <tr>\
  <input class="indexValue" type="hidden" value="');  ngx.print(phoneNumbersData[i].sip_profile_index); ngx.print('"/>\
          <td>');  ngx.print(phoneNumbersData[i].user_friendly_name); ngx.print('</td>\
          <td>');  ngx.print(phoneNumbersData[i].number); ngx.print('</td>\
          <td>');  ngx.print(phoneNumbersData[i].uri); ngx.print('</td>\
          <td><input class = "profileName" id="phonenumbers-txt-name');  ngx.print(i); ngx.print('" value= "');  ngx.print(phoneNumbersData[i].display_name); ngx.print('"  type="text" /></td>\
        </tr>\
  ');  end  ngx.print('\
      </tbody>\
    </table>\
  </div>\
     </div>\
</div>\
<div class = "mobPhoneNumbersInfo visible-xs">\
<div class="h3-content mobile" id="phoneNumbers">\
    ');  for i=1, #phoneNumbersData do   ngx.print('\
  <div class="vdf-row">\
   <div class="mobile-input-row">\
   <input class="indexValue" type="hidden" value="');  ngx.print(phoneNumbersData[i].sip_profile_index); ngx.print('"/>\
            <div class="left">');  ngx.print(T"Connection"); ngx.print('</span></div>\
            <div class="right">');  ngx.print(phoneNumbersData[i].user_friendly_name); ngx.print('</div>\
        </div>\
        <div class="mobile-input-row">\
            <div class="left"><span>');  ngx.print(T"Internal Number"); ngx.print('</span></div>\
            <div class="right">');  ngx.print(phoneNumbersData[i].number); ngx.print('</div>\
        </div>\
        <div class="mobile-input-row">\
            <div class="left"><span>');  ngx.print(T"Phone Number"); ngx.print('</span></div>\
            <div class="right">');  ngx.print(phoneNumbersData[i].uri); ngx.print('</div>\
        </div>\
        <div class="mobile-input-row mobile-full">\
            <div class="left"><span>');  ngx.print(T"Name"); ngx.print('</span></div>\
            <div class="right"><input class="profileName" id="phonenumbers-txt-name');  ngx.print(i); ngx.print('" value= "');  ngx.print(phoneNumbersData[i].display_name); ngx.print('"  type="text" /></div>\
        </div>\
   </div>\
  ');  end  ngx.print('\
  </div>\
</div>\
');  
    local lp = require("web.lp")
    lp.setpath("/www/docroot/")
    lp.include("apply-cancel.lp")
  ngx.print('\
</form>\
<script src="js/global-min.js"></script>\
<script>\
var MAX_MOBILE_WIDTH = 767;\
var ProfileName = {\
  Name   : "#phno-form [id*=name]:visible",\
}\
var ProfileNameValidation = {\
  Name   : function(value) { return (validateStringLength(0, 63)(value) && hasNoWhiteSpace(value))},\
}\
$(function(){\
  var target = "/modals/phone/numbers.lp";\
  sessionStorage.setItem(\'apply_changes\', "Y");\
  $("#global-apply, #modal-apply").click(function() {\
    $("[role=dialog] .input-error").removeClass("input-error");\
    var params = [];\
    var iserror = false;\
    if (!validateElements(ProfileName, ProfileNameValidation)) return false;\
\
    /*Check if desktop view*/\
    if ($(window).width() > MAX_MOBILE_WIDTH) {\
      $(".phoneNumbersInfo:visible tbody tr").each(function(index){\
        var i = index + 1;\
        var userName = $(this).find(\'.profileName\').val();\
        params.push({\
          name  : "index"+i,\
          value : $(this).find(\'.indexValue\').val()\
        }, {\
          name  : "name"+i,\
          value : userName\
        });\
      });\
      params.push({\
        name  : "rows",\
        value : $(".phoneNumbersInfo:visible .indexValue").length\
      });\
    }\
\
    /*else mobile view*/\
    else\
    {\
       $("#phoneNumbers .vdf-row").each(function(index){\
        var i = index + 1;\
        var userName = $(this).find(\'input[type=text]\').val();\
        params.push({\
          name  : "index"+i,\
          value : $(this).find(\'.indexValue\').val()\
        }, {\
          name  : "name"+i,\
          value : userName\
        });\
      });\
      params.push({\
        name  : "rows",\
        value : $(".mobPhoneNumbersInfo:visible .indexValue").length\
      });\
    }\
    params.push({\
      name  : "CSRFtoken",\
      value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    });\
    postHandler(target, params);\
  });\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/phone/numbers.lp");\
  });\
});\
</script>\
'); 