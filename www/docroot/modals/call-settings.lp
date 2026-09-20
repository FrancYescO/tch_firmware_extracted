--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local proxy = require("datamodel")
local string = string
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local match, format = string.match, string.format
local pairs, ipairs = pairs, ipairs
local maxTelnoLength = 390

-- Description -> Function to validate Telephone number
-- @function - > validateTelephoneNumber
-- @parm -> Number
-- @return  -> return boolean
local function validateTelephoneNumber(value)
  if #value > 0 and #value <= maxTelnoLength then
    local pattern = match(value , "[%a%d%+]*")
    if pattern == value then
      return true
    end
  end
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  local json = require("dkjson")
  local jsonReq = json.decode(string.untaint(postArgs.callsettingReq))
  local callSettingPostParams = {}
  local callSettingPostParam = {}
  local callSettingPostParamVal = {}
  local name, index
  for k,v in pairs(jsonReq) do
    callSettingPostParam[k] = v
    name, index =  string.match(k, "(%a+)(%d+)")
    callSettingPostParams[format("uci.mmpbx.service.%s.%s",index, name)] = v
    if name == "timeout" then
      callSettingPostParamVal[k] =  post_helper.getValidateNumberInRange(1,65535)
    elseif name == "destination" then
      callSettingPostParamVal[k] = validateTelephoneNumber
    else
      callSettingPostParamVal[k] = post_helper.validateBoolean
    end
  end

--Server side Validation is done for the GUI elements.
  if content_helper.validateObject(callSettingPostParam, callSettingPostParamVal) then
    if proxy.set(callSettingPostParams) then
      proxy.apply()
      ngx.print('<input type="hidden" id="post_status" value="success">')
    else
      ngx.print('<input type="hidden" id="post_status" value="error">')
    end
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end

--Fetching the data under the path uci.mmpbx.service and storing it in variable callSettingPath.
--The callSettingPath variable is looped through and a check is made for the param Type. The indexes in the path are not constant, so based on the type matched, the indexes
--are stored in a table. The activated and provisioned values are also stored in a table for the respective type matched.
local callSettingPath = content_helper.convertResultToObject("uci.mmpbx.service.", proxy.get("uci.mmpbx.service."))
local devices = setMetaTable({
  fxs_dev_0 = {},
  fxs_dev_1 = {},
}, untaint_mt)

local deviceTypes = setMetaTable({
   CALL_WAITING = "callWaiting",
   CONFERENCE   = "conference",
   TRANSFER     = "transfer",
   WARMLINE     = "warmline"
}, untaint_mt)

if callSettingPath then
--Only for Type == "HOLD" the mapping for the device value(fsx_dev_0 or fsx_dev_1) is not direct.
--So we get the profile paths and extract the profile names from it(ex: sip_profile_0).
--We then get the incoming profile mapping paths.
  for i, v in ipairs(callSettingPath) do
    if (v.type == "HOLD") then
      local profilePaths = proxy.getPN("uci.mmpbxrvsipnet.profile.", true)
      local incomingProfileMapping = content_helper.convertResultToObject("uci.mmpbx.incoming_map.", proxy.get("uci.mmpbx.incoming_map."))
      local profileNames = {}
      for index, profilePath in pairs(profilePaths) do
        if (string.match(profilePath.path, "uci.mmpbxrvsipnet.profile.@(.+)%.") ~= "") then
          profileNames[index] = string.match(profilePath.path, "uci.mmpbxrvsipnet.profile.@(.+)%.")
        end
      end
--We then try to match the profile names and with the names in the incomingProfile Paths. once matched we then try to check if the profile names corresponds to device1 or device 2
--Based on the device it matches too we get the values of activated and provisioned and store it in appropriate variables.
      for index, _ in pairs(profileNames) do
        for _, incomingMapPath in ipairs(incomingProfileMapping) do
          if (incomingMapPath.profile == profileNames[index]) and (devices[incomingMapPath["device.@1.value"]]) and (incomingMapPath.profile == v["profile.@1.value"]) then
            devices[incomingMapPath["device.@1.value"]].callHold             = {}
            devices[incomingMapPath["device.@1.value"]].callHold.activated   = v.activated
            devices[incomingMapPath["device.@1.value"]].callHold.provisioned = v.provisioned
            devices[incomingMapPath["device.@1.value"]].callHold.paramindex  = v.paramindex
          end
        end
      end
    end
    if (deviceTypes[v["type"]]) and (devices[v["device.@1.value"]]) then
      devices[v["device.@1.value"]][deviceTypes[v["type"]]]            = {}
      devices[v["device.@1.value"]][deviceTypes[v.type]].activated     = v.activated
      devices[v["device.@1.value"]][deviceTypes[v.type]].provisioned   = v.provisioned
      devices[v["device.@1.value"]][deviceTypes[v.type]].paramindex    = v.paramindex
      if (v.type == "WARMLINE") then
        devices[v["device.@1.value"]][deviceTypes[v.type]].destination = v.destination
        devices[v["device.@1.value"]][deviceTypes[v.type]].timeout     = v.timeout
      end
    end
  end
end
local headers = {
  ["callHold"]    = T"Call Hold",
  ["callWaiting"] = T"Call Waiting",
  ["conference"]  = T"Three-way-calling",
  ["transfer"]    = T"Call Transfer",
  ["warmline"]    = T"Automatic call",
}
local callSettingParamsOrder = {"callHold", "callWaiting", "conference", "transfer", "warmline"}
-- Description -> Function to validate create HTML content for fxs1 and fsx2 params having buttons for status and provisioning
-- @function - > generateCallSettingHtml
-- @parm -> fxsNumber
-- @return  -> return content(html page)
local function generateCallSettingHtml(fxsNumber)
  local content = {}
  for _,v in ipairs(callSettingParamsOrder) do
    local activated   = devices[fxsNumber][v].activated
    local provisioned = devices[fxsNumber][v].provisioned
    local paramindex  = devices[fxsNumber][v].paramindex
    content[#content + 1] = '<div class="table-row">'
    content[#content + 1] = format('<div class="table-col table-col1 %s"><span>%s</span></div>', (provisioned == "0" and "op40" or ""), headers[v])
    content[#content + 1] = format('<input type="hidden" name = "activated%d" id="callSettings-txt-%s_%sStatus" value ="%d"></input>', paramindex, fxsNumber, v, activated)
    content[#content + 1] = format('<div class="table-col table-col2"><div id="callSettings-btn-%s_%sStatus" class="button button-callSettings %s toggle-content-button"></div></div>', fxsNumber, v, (provisioned == "0") and ("button-off op40") or (activated == "1" and "button-on" or "button-off"))
    content[#content + 1] = format('<input type="hidden" name = "provisioned%d" id="callSettings-txt-%s_%sProvision" value ="%d"></input>', paramindex, fxsNumber, v, provisioned)
    content[#content + 1] = format('<div class="table-col table-col3"><div id="callSettings-btn-%s_%sProvision" class="button button-callSettings %s toggle-content-button"></div></div>', fxsNumber, v, provisioned == "1" and "button-on" or "button-off")
    content[#content + 1] = '</div>'
  end
  return content
end

-- Description -> Function to validate create HTML content for fxs1 and fsx2 number text fields
-- @function - > generateCallSettingHtmlNumber
-- @parm -> fxsNumber
-- @return  -> return content(html page)
local function generateCallSettingHtmlNumber(fxsNumber)
  local destination = devices[fxsNumber]["warmline"].destination
  local timeout     = devices[fxsNumber]["warmline"].timeout
  local paramindex  = devices[fxsNumber]["warmline"].paramindex
  local content     = {}
  content[#content + 1] = '<div class="table call-settings-table">'
  content[#content + 1] = '<div class="table-row">'
  content[#content + 1] = format('<div class="table-col table-col1" style="width:250px"><span>%s</span></div>', T"Number")
  content[#content + 1] = format('<div class="table-col table-col3"><input type="text" id="callSettings-txt-%s_number" name="destination%d" value="%s"></input></div>',fxsNumber, paramindex, destination)
  content[#content + 1] = '<div class="table-col table-col2"></div>'
  content[#content + 1] = '</div>'
  content[#content + 1] = '<div class="table-row">'
  content[#content + 1] = format('<div class="table-col table-col1"><span>%s</span></div>',T"Timeout")
  content[#content + 1] = format('<div class="table-col table-col3"><input type="text" id ="callSettings-txt-%s_timeout" name="timeout%d" value="%s"></input></div>',fxsNumber, paramindex, timeout)
  content[#content + 1] = '<div class="table-col table-col2"></div>'
  content[#content + 1] = '</div>'
  content[#content + 1] = '</div>'
  return content
end
  ngx.print('\
<script>\
  $(function() {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
\
<form id="callSettings_form" class="form-horizontal" method="post" action="modals/call-settings.lp">\
<input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
<input type="hidden" name= "action" id= "action" value = "SAVE"></input>\
\
<h1><span>');  ngx.print(T"Call Settings"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"This device has the following voice services available"); ngx.print('</span></h2>\
\
\
<h3><span>');  ngx.print(T"Call Services"); ngx.print('</span></h3>\
<div class="h3-content">\
    <div class="table big-padding-bottom call-settings-table">\
        <div class="table-row table-row-head">\
            <div class="table-col table-col1" style="width: 200px;">');  ngx.print(T"FXS 1"); ngx.print('</div>\
            <div class="table-col table-col2" style="width: 80px;"><span>');  ngx.print(T"Status"); ngx.print('</span></div>\
            <div class="table-col table-col3 " style="width: 230px;"><span>');  ngx.print(T"Provisioning"); ngx.print('</span></div>\
        </div>\
        ');  ngx.print(generateCallSettingHtml("fxs_dev_0"))  ngx.print('\
      </div>\
    ');  ngx.print(generateCallSettingHtmlNumber("fxs_dev_0"))  ngx.print('\
</div>\
<div class="h3-content">\
    <div class="table big-padding-bottom call-settings-table">\
        <div class="table-row table-row-head">\
            <div class="table-col table-col1" style="width: 200px;">');  ngx.print(T"FXS 2"); ngx.print('</div>\
            <div class="table-col table-col2" style="width: 80px;"><span>');  ngx.print(T"Status"); ngx.print('</span></div>\
            <div class="table-col table-col3 " style="width: 230px;"><span>');  ngx.print(T"Provisioning"); ngx.print('</span></div>\
        </div>\
        ');  ngx.print(generateCallSettingHtml("fxs_dev_1"))  ngx.print('\
      </div>\
    ');  ngx.print(generateCallSettingHtmlNumber("fxs_dev_1"))  ngx.print('\
</div>\
</form>\
');  
    local lp = require("web.lp")
    lp.setpath("/www/docroot/")
    lp.include("apply-cancel.lp")
    ngx.print('\
\
<script src="js/global.js"></script>\
<script>\
  var isAlphaNumeric = (/^[0-9a-zA-Z+]*$/);\
  var isNumber = /^[0-9]+$/;\
  var elements = {}, validations = {};\
\
  //function to validate Number fields\
  function validateNumberFields(number, timeout) {\
    elements[number] = "#"+number;\
    elements[timeout] = "#"+timeout;\
    validations[number] = function(value) { return validateStringLength(1, 390)(value) && isAlphaNumeric.test(value) };\
    validations[timeout] = function(value) { return validateNumberRange(1, 65535)(value) && isNumber.test(value) };\
  }\
\
  //function to disable or enable the Number text fields\
  function changeNumberFieldType(fxs1Id,fxs2Id){\
    $("#callSettings-txt-fxs_dev_0_number").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_0_timeout").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_1_number").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_1_timeout").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_0_number").closest(".table-row").find(".table-col1").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_0_timeout").closest(".table-row").find(".table-col1").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_1_number").closest(".table-row").find(".table-col1").removeClass("op40");\
    $("#callSettings-txt-fxs_dev_1_timeout").closest(".table-row").find(".table-col1").removeClass("op40");\
    if($(fxs1Id).hasClass(\'button-off\')){\
      $("#callSettings-txt-fxs_dev_0_number").addClass("op40");\
      $("#callSettings-txt-fxs_dev_0_timeout").addClass("op40");\
      $("#callSettings-txt-fxs_dev_0_number").closest(".table-row").find(".table-col1").addClass("op40");\
      $("#callSettings-txt-fxs_dev_0_timeout").closest(".table-row").find(".table-col1").addClass("op40");\
    }\
    if($(fxs2Id).hasClass(\'button-off\')){\
      $("#callSettings-txt-fxs_dev_1_number").addClass("op40");\
      $("#callSettings-txt-fxs_dev_1_timeout").addClass("op40");\
      $("#callSettings-txt-fxs_dev_1_number").closest(".table-row").find(".table-col1").addClass("op40");\
      $("#callSettings-txt-fxs_dev_1_timeout").closest(".table-row").find(".table-col1").addClass("op40");\
    }\
  }\
\
  $(document).ready(function(){\
    changeNumberFieldType("#callSettings-btn-fxs_dev_0_warmlineStatus", "#callSettings-btn-fxs_dev_1_warmlineStatus");\
    if ($("#home-sel-mode").val() == 35) {\
      $(".table-col3 span").removeClass("hide");\
      $(".table-col3").children("div").removeClass("hide");\
    } else {\
      $(".table-col3 span").addClass("hide");\
      $(".table-col3").children("div").addClass("hide");\
    }\
\
    //function to disable the Field Name and status Button for the corresponding provisioning button disabled.\
    $(".table-col3 .button").click(function() {\
      var statusLabel = $(this).closest(".table-row").find(".table-col1");\
      var statusButton = $(this).closest(".table-row").find(".table-col2 .button");\
      var statusButtonState = $(this).closest(".table-row").find("input");\
      if ($(this).hasClass("button-off")) {\
        if(statusButton.hasClass("button-on")) {\
          statusButton.removeClass("button-on").addClass("button-off");\
          statusButtonState.val("0");\
          if((statusButton.prop("id") == "callSettings-btn-fxs_dev_0_warmlineStatus") ||\
             (statusButton.prop("id") == "callSettings-btn-fxs_dev_1_warmlineStatus"))\
            changeNumberFieldType("#callSettings-btn-fxs_dev_0_warmlineStatus", "#callSettings-btn-fxs_dev_1_warmlineStatus");\
        }\
        statusButton.addClass("op40");\
        statusLabel.addClass("op40");\
      }\
      else {\
        statusButton.removeClass("op40");\
        statusLabel.removeClass("op40");\
      }\
    });\
\
    $(".button-callSettings").click(function(){\
      var currentid  = $(this).attr("id");\
      var hiddenid= $(this).closest(".table-col").prev().attr("id");\
      if ($(this).hasClass("button-on")){\
        $("#"+hiddenid).val("1");\
      } else {\
        $("#"+hiddenid).val("0");\
      }\
    });\
\
    $("#global-apply").click(function() {\
      elements = {}, validations = {};\
      //Client side validation done for the GUI elements.\
      if($("#callSettings-txt-fxs_dev_0_warmlineStatus").val() == "1"){\
        validateNumberFields("callSettings-txt-fxs_dev_0_number", "callSettings-txt-fxs_dev_0_timeout");\
      }\
      if($("#callSettings-txt-fxs_dev_1_warmlineStatus").val() == "1"){\
        validateNumberFields("callSettings-txt-fxs_dev_1_number", "callSettings-txt-fxs_dev_1_timeout");\
      }\
      if (!validateElements(elements, validations)) return false;\
      var target         = "/modals/call-settings.lp";\
      var params         = [];\
      var jsonParam      = {};\
      $(".table-row input").each(function(){\
        if($("#callSettings-txt-fxs_dev_0_warmlineStatus").val() == "0"){\
          if (($("#callSettings-txt-fxs_dev_0_number").attr(\'name\')) == $(this).attr("name")) return;\
          if (($("#callSettings-txt-fxs_dev_0_timeout").attr(\'name\')) == $(this).attr("name")) return;\
        }\
        if($("#callSettings-txt-fxs_dev_1_warmlineStatus").val() == "0"){\
          if ($("#callSettings-txt-fxs_dev_1_number").attr(\'name\') == $(this).attr("name")) return;\
          if ($("#callSettings-txt-fxs_dev_1_timeout").attr(\'name\') == $(this).attr("name")) return;\
        }\
        jsonParam[$(this).attr("name")] = $(this).val();\
      });\
      var jsonStr = JSON.stringify(jsonParam);\
      params.push({\
        name  : "callsettingReq",\
        value : jsonStr\
      },{\
        name  : "action",\
        value : "SAVE"\
      },{\
        name  : "CSRFtoken",\
        value : "');  ngx.print(CSRFtoken); ngx.print('"\
      });\
      postHandler(target, params);\
    });\
\
    $("#global-cancel").click(function() {\
      $("#content").load("/modals/call-settings.lp");\
    });\
\
    $("#callSettings-btn-fxs_dev_0_warmlineStatus, #callSettings-btn-fxs_dev_1_warmlineStatus").click(function() {\
      changeNumberFieldType("#callSettings-btn-fxs_dev_0_warmlineStatus", "#callSettings-btn-fxs_dev_1_warmlineStatus");\
    });\
\
    $("#home-sel-mode").change(function() {\
      if ($("#home-sel-mode").val() == 35) {\
        $(".table-col3 span").removeClass("hide");\
        $(".table-col3").children("div").removeClass("hide");\
      } else {\
        $(".table-col3 span").addClass("hide");\
        $(".table-col3").children("div").addClass("hide");\
      }\
    });\
  });\
</script>\
'); 