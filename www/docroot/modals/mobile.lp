--pretranslated: do not change this file
 --Enable localization

gettext.textdomain('webui-core')
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local proxy = require("datamodel")
local gVIES = post_helper.getValidateInEnumSelect
local format, untaint, match = string.format, string.untaint, string.match
local ngx = ngx
local preferedNetwork, preferedNetworkIndex
local valid_network_types = {
  { "auto" , T"Auto"    },
  { "lte"  , T"4G Only" },
  { "umts"  , T"3G Only" },
  { "gsm" , T"2G Only" },
}

local pin_state = {
   ["enabled_verified"] = T"PIN verified",
   ["not_initialized"] = T"PIN not initialized",
   ["enabled_not_verified"] = T"PIN not verified",
   ["blocked"]   =    T"SIM Blocked. Awaiting PUK",
   ["permanently_blocked"] = T"PIN permanently Blocked",
   ["disabled"] = "",
}

local content_ip = {
  wan = "rpc.network.interface.@wan.ipaddr",
  wan6 = "rpc.network.interface.@wan6.ip6addr",
}
content_helper.getExactContent(content_ip)
local wan_down = (content_ip.wan =="" and content_ip.wan6 =="")

local mobile_params = {
  enable = "rpc.mobiled.enabled",
}

local mobile_nw_params = {
  save_pin = "uci.mobiled.globals.store_pin",
  autofailover = "uci.wansensing.global.autofailover",
}

if wan_down then
  mobile_nw_params.connect = "uci.network.interface.@wwan.auto"
end

local device_entries = proxy.get("rpc.mobiled.DeviceNumberOfEntries")

local mobile_valid = {
  enable = post_helper.validateBoolean,
}

local function validateConnect(value, object, key)
  if object.autofailover == "1" then
    object[key] = nil
    return true
  end
  return post_helper.validateBoolean(value)
end

local mobile_nw_valid = {
  save_pin = post_helper.validateBoolean,
  connect = validateConnect,
  autofailover = post_helper.validateBoolean,
}

local mobile_get, mobile_content ={}, {}
local mobile_errmsg = {}

local mobile_nw_content = post_helper.handleQuery(mobile_nw_params, mobile_nw_valid)
local pinDetail = content_helper.convertResultToObject("uci.mobiled.sim.", proxy.get("uci.mobiled.sim."))

-- function to findout perfer network value for mobiled device
-- return string like("lte" or "gsm" or "cdma") and index
local function preferNetworkMethod()
  local perferedNetworkPath = content_helper.convertResultToObject("uci.mobiled.device.", proxy.get("uci.mobiled.device."))
  if perferedNetworkPath then
    for _, param in ipairs(perferedNetworkPath) do
      return param.radio_pref, param.paramindex
    end
  end
end

-- If user clicks reset button, separate post will be triggerd.
-- Reset pin option will clear pin value stored in mobiled config
if ngx.req.get_method() == "POST"  then
  if ngx.req.get_post_args().reset then
    ngx.header.content_type = "application/json"
    if next(pinDetail) then
      for _, v in ipairs(pinDetail) do
        proxy.set(format("uci.mobiled.sim.%s.pin", v.paramindex), "")
       end
    end
    proxy.apply()
    ngx.print('{ "status":"success" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

local resetmobile = {
  reset_mobile_enabled = "uci.uci-defaults.mobile.mobile_enabled",
  reset_mobile_connect = "uci.uci-defaults.mobile.mobile_connect",
  reset_autofailover = "uci.uci-defaults.mobile.mobile_autofailover",
  reset_preferred_network = "uci.uci-defaults.mobile.preferred_network",
  reset_pin_enabled = "uci.uci-defaults.mobile.pin_enabled"
}
content_helper.getExactContent(resetmobile)

-- If user tries to Change Mobile button, which inturn stop and start mobiled deamon.
-- This parameter will be updated only when user changes the button value.
if ngx.req.get_method() ~= "POST" or  ngx.req.get_post_args().enable   then
  mobile_content, mobile_errmsg = post_helper.handleQuery(mobile_params, mobile_valid)
else
  mobile_content["enable"] = proxy.get("rpc.mobiled.enabled")[1].value
end

if device_entries and tonumber(device_entries[1].value) > 0 then
  mobile_get["pin_state"] = "rpc.mobiled.device.@1.sim.pin.pin_state"
  mobile_get["sim_state"] = "rpc.mobiled.device.@1.sim.sim_state"
  mobile_get["pinCount"] = "rpc.mobiled.device.@1.sim.pin.unlock_retries_left"
  mobile_get["pukCount"] = "rpc.mobiled.device.@1.sim.pin.unblock_retries_left"
  content_helper.getExactContent(mobile_get)
  preferedNetwork, preferedNetworkIndex = preferNetworkMethod()
end

-- Function to validate pin or puk should contain numbers only.
-- @param : pinpuk contain value of either pin or puk
-- @param : pukValid in order to differentiate validation from
-- pin and puk in order to return corresponding error  message
-- return boolean
local function pinValidation(pinPuk, pukValid)
  local result, msg = post_helper.validatePositiveNum(pinPuk)
  local lengthValidation
  if result then
    -- Validation to check length of PIN and PUK Number.
    if not pukValid then
      lengthValidation = post_helper.getValidateStringLengthInRange(4,4)
      result, msg = lengthValidation(pinPuk)
    else
      lengthValidation = post_helper.getValidateStringLengthInRange(8,8)
      result, msg = lengthValidation(pinPuk)
    end
 end
  if not result then
    if pukValid then
      return nil, T"Invalid PUK"
    else
      return nil, T"Invalid PIN"
    end
  end
  return true
end

-- To Handle post operation of pin related changes.
-- Before set value in config, validation will happen for each set.
-- Changes related to pin will be updated in deamon only when dongle connected to gateway.
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postArgs = ngx.req.get_post_args()
  local setTable = {}
  local errorFlag = false
  local currentPinCount, currentPukCount
  local  isPinValid,  networkValidation, isValidNetworkPref, isNewPinValid, isPukValid
  local sendpin, sendpuk, pinErrMsg, pukErrMsg = "", "", "", ""

  -- Pin validation will be done. when pin state is neither blocked nor permanently blocked
  if mobile_get["pin_state"] ~= "blocked" and mobile_get["pin_state"] ~= "permanently_blocked" then
  if postArgs["pin_enable"] then
      isPinValid, pinErrMsg = pinValidation(postArgs["pin_enable"])
    if not isPinValid then
      errorFlag = true
    end
  end
  if postArgs["pin_disable"] then
      isPinValid, pinErrMsg = pinValidation(postArgs["pin_disable"])
    if not isPinValid then
      errorFlag = true
    end
  end
  end

  -- Validation for network perference, value has to be one of enum value.
  if postArgs["network_type"] then
   networkValidation = gVIES(valid_network_types)
   isValidNetworkPref = networkValidation(postArgs["network_type"])
   if not isValidNetworkPref then
      errorFlag = true
   end
  end

  -- Getting Number of dongle connected in gateway.
  local new_device_entries = proxy.get("rpc.mobiled.DeviceNumberOfEntries")

  -- Changes related to pin will updated in deamon, When dongle connected to gateway.
  if mobile_content["enable"] and new_device_entries and tonumber(new_device_entries[1].value) > 0 then
    -- Saving unlock_retries_left in currentPinCount, Inorder to differentiate either user enters correct pin or wrong
    -- If user enters wrong pin, count will decrease. Once user provide correct pin count get will reset to default value
    currentPinCount = tonumber(mobile_get["pinCount"])

    -- Saving unblock_retries_left in currentPukCount, Inorder to differentiate either user enters correct puk or wrong
    -- If user enters wrong puk, count will decrease. Once user provide correct puk count get will reset to default value
    currentPukCount = tonumber(mobile_get["pukCount"])
     setTable[format("uci.mobiled.device.%s.radio_pref", preferedNetworkIndex)] = postArgs["network_type"]
    if  mobile_get["pin_state"] ~= "blocked" and mobile_get["pin_state"] ~= "permanently_blocked" and mobile_content["enable"] == "1" then

      -- When pin_state is locked. To unlock sim we need to enter correct pin value in unlock parameter.
      if mobile_get["sim_state"] == "locked" then
      setTable["rpc.mobiled.device.@1.sim.pin.unlock"] = postArgs["pin_enable"] and postArgs["pin_enable"] or postArgs["pin_disable"]
    end

      -- When user tries to Enable to Pin. Correct pin value will be updated in parameter enable.
      if postArgs["pin_enable"] and mobile_get["sim_state"] ~= "locked" and errorFlag ~= true then
      setTable["rpc.mobiled.device.@1.sim.pin.enable"] = postArgs["pin_enable"]
    end

      -- When user tries to disable to Pin. Correct pin value will be updated in parameter disable.
      if postArgs["pin_disable"] and mobile_get["sim_state"] ~= "locked" and errorFlag ~= true then
      setTable["rpc.mobiled.device.@1.sim.pin.disable"] = postArgs["pin_disable"]
    end

    -- When pin state is blocked. To unblock a sim user need to provide new pin and puk
    elseif mobile_get["pin_state"] == "blocked" and  mobile_content["enable"] == "1"   then

       -- When pin state is blocked. New pin will be validated
       isNewPinValid, pinErrMsg = pinValidation(ngx.req.get_post_args().newpin)
       if not isNewPinValid then
          errorFlag = true
       end

       -- Puk Validation will done. When Pin is in blocked state
       isPukValid ,pukErrMsg = pinValidation(ngx.req.get_post_args().puk, true)
       if not isPukValid then
          errorFlag = true
       end
       if not errorFlag then
         -- In order to unblock pin. User need to enter pin and puk with comma separated.
         setTable["rpc.mobiled.device.@1.sim.pin.unblock"] =  format("%s,%s",ngx.req.get_post_args().newpin, ngx.req.get_post_args().puk)
       end
    end
    -- setTable will contain all path and value user tries to set in deamon.
    if proxy.set(setTable) and errorFlag ~= true then
      proxy.apply()
    end
  ngx.sleep(4)
  -- Once Values got set in deamon, By getting values of following path
  -- we can find out weather user entered correct pin or wrong pin
  mobile_get["pin_state"] = "rpc.mobiled.device.@1.sim.pin.pin_state"
  mobile_get["sim_state"] = "rpc.mobiled.device.@1.sim.sim_state"
  mobile_get["pinCount"] = "rpc.mobiled.device.@1.sim.pin.unlock_retries_left"
  mobile_get["pukCount"] = "rpc.mobiled.device.@1.sim.pin.unblock_retries_left"
  content_helper.getExactContent(mobile_get)
  preferedNetwork, preferedNetworkIndex = preferNetworkMethod()

  -- When wrong pin entered pin count will decrease and sendpin will return currentpincount
  if mobile_get["pin_state"] ~= "blocked" and mobile_get["pin_state"] ~= "permanently_blocked" then
    if mobile_get["pinCount"] ~= "" and tonumber(mobile_get["pinCount"]) < currentPinCount then
      sendpin = mobile_get["pinCount"]
      errorFlag = true
    end
  else
   -- When wrong pin entered puk count will decrease and sendpuk will return currentpukcount
    if mobile_get["pukCount"] ~= "" and mobile_get["pin_state"] == "blocked" and tonumber(mobile_get["pukCount"]) < currentPukCount   and  mobile_get["pinCount"] ==  "0"  then
      sendpuk = mobile_get["pukCount"]
      errorFlag = true
    end
  end
 end
  if not next(mobile_errmsg) and errorFlag ~= true then   ngx.print('\
    <input type="hidden" id="post_status" value="success" >\
  ');  else  ngx.print('\
    <input type="hidden" id="post_status" value="error" data-pukmsg= \'');  ngx.print(pukErrMsg and pukErrMsg or ""); ngx.print('\' data-pinmsg=\'');  ngx.print(pinErrMsg and pinErrMsg or "" ); ngx.print('\' data-pinCount="');  ngx.print(sendpin); ngx.print('" data-pukCount="');  ngx.print(sendpuk); ngx.print('">\
  ');  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
<script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
<div class="row">\
  <div class="col-md-12">\
    <h1>');  ngx.print(T"Mobile"); ngx.print('</h1>\
  </div>\
</div>\
<div class="row">\
  <div class="col-md-12">\
    <h2>Mobile Charges will apply when connecting via Vodem Stick</h2>\
  </div>\
</div>\
\
<form id="mobile_form" class="form-horizontal" method="post" action="modals/mobile.lp">\
  <div class="h3-content no-padding-bottom">\
    <div class="row">\
      <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
        <span>');  ngx.print(T"Mobile"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
        <div id="mobile-btn-status" ');  if mobile_content and mobile_content["enable"] == "1" then  ngx.print('class="button button-on pull-right" ');  else  ngx.print(' class="button button-off pull-right"');  end  ngx.print('></div>\
      </div>\
    </div>\
  </div>\
  <div id="full-hide" class="show">\
    <div class="h3-content no-padding-bottom">\
      <div class="row">\
        <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <span>');  ngx.print(T"Auto Fail Over"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <div id="mobile-btn-autofailover" ');  if mobile_nw_content and mobile_nw_content["autofailover"] == "1" then  ngx.print('class="button button-on pull-right" ');  else  ngx.print(' class="button button-off pull-right"');  end  ngx.print('></div>\
        </div>\
      </div> ');
      if wan_down then ngx.print('\
      <div id="mobile-section-connect" '); if mobile_nw_content and mobile_nw_content["autofailover"] == "1" then ngx.print(' class="row hide"> '); else ngx.print(' class="row" >');  end
        ngx.print(' <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <span>');  ngx.print(T"Connect"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <div id="mobile-btn-connect" ');  if mobile_nw_content and mobile_nw_content["connect"] == "1" then  ngx.print('class="button button-on pull-right" ');  else  ngx.print(' class="button button-off pull-right"');  end  ngx.print('></div>\
        </div>\
      </div>');
      end ngx.print('\
      <div class="row">\
        <div class="col-md-6 col-sm-6 col-xs-12  padding-top-bottom-20 mobile-padding-bottom-none">\
          <span class="font-bold">');  ngx.print(T"Preferred Network Type"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-12 mobile-padding-top-none padding-top-bottom-20" id="mobile-dropdown-select">\
          <div id="top-info-mode" class="rel mobile-pull-left umts">\
            <select name="network_type" id="mobile-sel-nwtyp"  style="width: 165px;">\
              ');  for i,v in ipairs(valid_network_types) do
                if preferedNetwork and v[1] == preferedNetwork then
                  ngx.print(format("<option selected='selected' value='%s'>%s</option>",v[1],v[2]))
                else
                  ngx.print(format("<option value='%s'>%s</option>",v[1],v[2]))
                end
              end
              ngx.print('\
            </select>\
          </div>\
        </div>\
      </div>\
      <div class="row">\
        <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <span class="font-bold">');  ngx.print(T"PIN Enabled"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
          <div class=" pull-right">\
            <div id="mobile-btn-pinenb" ');  if mobile_get["pin_state"] and mobile_get["pin_state"] == "enabled_verified" then  ngx.print('class="button button-on"');  else  ngx.print('class="button button-off"');  end  ngx.print('></div>\
          </div>\
        </div>\
      </div>\
    </div>\
    <div id="pin-hide"  class=\'');  if mobile_get["pin_state"] and mobile_get["pin_state"] == "enabled_verified" then   ngx.print(' show ');  else  ngx.print(' hide ');  end   ngx.print('\'>\
      <div class="h3-content mobile-no-float">\
        <div class="row">\
          <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
            <span>');  ngx.print(T"PIN Status"); ngx.print('</span>\
          </div>\
          <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
            <div class=" pull-right">\
              <span id ="mobile-lbl-pin">');  ngx.print(mobile_get["pin_state"] and pin_state[untaint(mobile_get["pin_state"])] or pin_state["not_initialized"]); ngx.print('</span>\
            </div>\
          </div>\
        </div>\
        <div class="row">\
          <div class="col-md-12">\
            <hr/>\
          </div>\
        </div>\
        <div class="pinshow show">\
          <div class="row">\
            <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
              <span>');  ngx.print(T"PIN"); ngx.print('</span>\
            </div>\
            <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
              <div class="pull-right">\
                <input type="password" class="form-control pin-show" id="mobile-txt-pin" placeholder= "********" name="mobile_pin" value= "');  if pinDetail and next(pinDetail)then   ngx.print(pinDetail[1].pin); end  ngx.print('" data-placement="bottom" data-toggle = "popover" >\
              </div>\
            </div>\
          </div>\
          <div class="row padding-top-bottom-20 text-right">\
            <div class="col-md-12">\
              <span >');  ngx.print(T"Display PIN"); ngx.print('</span>\
              <input type="checkbox" class="checkbox checkbox-unchecked" id="mobile-chk-dispin" />\
              <label for="mobile-chk-dispin"></label>\
            </div>\
          </div>\
          <div class="row">\
            <div class="col-md-12">\
              <hr/>\
            </div>\
          </div>\
          <div class="row padding-top-bottom-20">\
            <div class="col-md-6 col-sm-6 col-xs-6">\
              <span class="language-string">');  ngx.print(T"Save PIN to Router Memory"); ngx.print('</span>\
            </div>\
            <div class="col-md-6 col-sm-6 col-xs-6">\
              <div class="pull-right">\
                <div id="mobile-btn-savepin" class="button ');  if mobile_nw_content["save_pin"] ~= "0" then   ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print(' pin-enable"></div>\
              </div>\
            </div>\
          </div>\
          <div class="row padding-top-bottom-20">\
            <div class="col-md-12">\
              <div class="text-right">\
                <input id="mobile-btn-reset" class="button" value="');  ngx.print(T"Reset PIN"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
          <div>\
          </div>\
        </div>\
        <div class="pukshow hide">\
          <div class="vdf-table">\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"PUK"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="password" id ="mobile-txt-pukValue">\
              </div>\
            </div>\
          </div>\
          <div class="vdf-table">\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"New PIN"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="password" id ="mobile-txt-newpin">\
              </div>\
            </div>\
          </div>\
          <div class="row">\
            <div class="col-md-12">\
              <hr/>\
            </div>\
          </div>\
          <div class="vdf-table">\
            <div class="vdf-row">\
              <div class="left">\
                <span>');  ngx.print(T"Confirm PIN"); ngx.print('</span>\
              </div>\
              <div class="right">\
                <input type="password" id ="mobile-txt-confirmpin">\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
  <div class="modal fade" id="warning-popup" role="dialog" data-backdrop="static" data-keyboard="false">\
    <div class="modal-dialog">\
      <!-- Modal content-->\
      <div class="modal-content">\
        <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
        </div>\
        <div class="modal-body">\
          <p>');  ngx.print(T"The PIN has been reset successfully."); ngx.print('</p>\
        </div>\
        <div class="modal-footer">\
          <input class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Close"); ngx.print('" type="button" data-dismiss="modal" style="width: auto;">\
        </div>\
      </div>\
    </div>\
  </div>\
  <div class="table-wrapper">\
    <div class="message message-info  hide" id ="pin-Errmsg" >\
      ');  ngx.print(T"Invalid PIN"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="puk-Errmsg" >\
      ');  ngx.print(T"Invalid PUK"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="new-confirm-notmatch" >\
      ');  ngx.print(T"New PIN and Confirm PIN doesnot match"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="pinpuk-countmsg" >\
      <span style="font-weight:normal"></span>\
    </div>\
    <div class="message message-info hide" id="puk-infomsg" >\
      ');  ngx.print(T"SIM Card is locked, please enter the PUK and the new PIN."); ngx.print('\
    </div>\
  </div>\
</form>\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
\
\
<script type="text/javascript" src="js/global.js"></script>\
<script>\
var resetClick  = "0";\
$(function(){\
  $("#global-msg-lte").show();\
  $("#global-msg-umts").show();\
  if ("');  ngx.print(mobile_get.pin_state); ngx.print('" == "disabled" || "');  ngx.print(mobile_get.pin_state); ngx.print('" == "enabled_not_verified") {\
    $("#global-msg-lte-umts").show();\
    if("');  ngx.print(preferedNetwork); ngx.print('" == "4GPreferred" || "');  ngx.print(preferedNetwork); ngx.print('" == "4GOnly") {\
      $("#global-msg-umts").hide();\
    }\
    else {\
    }\
  }\
  var mobileEnable = "');  ngx.print(mobile_content and mobile_content.enable or "0" ); ngx.print('"\
   if (mobileEnable  == "0"){\
    $("#full-hide").removeClass("show").addClass("hide");\
   }\
   else{\
   $("#full-hide").removeClass("hide").addClass("show");\
  }\
  var mobilePinState = "');  ngx.print( mobile_get["pin_state"] and mobile_get["pin_state"] ); ngx.print('"\
  if ( mobilePinState == "blocked"){\
   $(".pinshow").removeClass("show").addClass("hide");\
   $(".pukshow").removeClass("hide").addClass("show");\
   $("#puk-infomsg").removeClass("hide").addClass("show");\
  }\
  function mobilePostHandler(target, params, post) {\
    $(\'#global-apply\').prop("disabled", true).addClass(\'table-button-faded\');\
    $("#pin-Errmsg").removeClass("show").addClass("hide");\
    $("#puk-Errmsg").removeClass("show").addClass("hide");\
    $("#pinpuk-countmsg").removeClass("show").addClass("hide");\
    var scrollTop = $(document).scrollTop();\
    var callback = function(response, status, XHR) {\
      response = post ? response.status : $("#post_status").val();\
      if (response == "success") {\
        $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");\
        // If POST succeeds, load the page\
        $("#content").load(target, function() {\
          $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
          $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");\
          setTimeout(function() {\
            $(".articlediv").removeClass("show").addClass("hide");\
          }, 3000);\
        });\
      } else {\
        $(".articlediv > .message-arrowbox-applied, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv, .articlediv > .msg-error").removeClass("hide").addClass("show");\
        var pinmsg = $("#post_status").attr("data-pinmsg");\
        var pukmsg = $("#post_status").attr("data-pukmsg");\
        if (pinmsg != "") { $("#pin-Errmsg").removeClass("hide").addClass("show");}\
        if (pukmsg != "") { $("#puk-Errmsg").removeClass("hide").addClass("show");}\
        if (mobilePinState != "blocked" || mobilePinState != "permanently_blocked" ){\
          var errpinCount = $("#post_status").attr("data-pinCount");\
          if  (errpinCount != ""){\
            $(\'#pinpuk-countmsg span\').text(\'');  ngx.print(T"The PIN you entered is incorrect. Please enter the correct PIN. You have "); ngx.print('\'+errpinCount+\'');  ngx.print(T "attempt(s) left"); ngx.print('\');\
            $("#pinpuk-countmsg").removeClass("hide").addClass("show");\
          }\
        }\
        if (mobilePinState == "blocked" ){\
          var errpukCount = $("#post_status").attr("data-pukCount");\
          if (errpukCount != ""){\
           $(\'#pinpuk-countmsg span\').text(\'');  ngx.print(T"The PUK you entered is incorrect. Please enter the correct PUK. You have "); ngx.print('\'+errpukCount+\'');  ngx.print(T "attempt(s) left"); ngx.print('\');\
           $("#pinpuk-countmsg").removeClass("hide").addClass("show");\
          }\
        }\
        setTimeout(function() {\
          $(".articlediv").removeClass("show").addClass("hide");\
          $(\'#global-apply\').prop("disabled", false).removeClass(\'table-button-faded\');\
        }, 3000);\
      }\
      $(document).scrollTop(scrollTop);\
    }\
    post ? $.post(target, params, callback) : $("#content").load(target, params, callback);\
}\
  if (mobilePinState == "blocked" || mobilePinState == "permanently_blocked" ){ $("#mobile-lbl-pin").css("color" , "#e60000");}\
  $("#mobile-btn-status").click(function(){\
    if ($(this).hasClass("button-off") && ((mobilePinState == "enabled_verified"  && $("#mobile-btn-pinenb").hasClass("button-on")  ) || (mobilePinState != "enabled_verified"  && $("#mobile-btn-pinenb").hasClass("button-off"))) ){\
      $("#full-hide").removeClass("show").addClass("hide");\
  }else{\
    $("#full-hide").removeClass("hide").addClass("show");}\
  });\
  var buttonChange = "0";\
  $("#mobile-btn-pinenb").click(function(){\
    if ($(this).hasClass("button-on")){\
       $("#pin-hide").removeClass("hide").addClass("show");\
    }else if($(this).hasClass("button-off") && $("#mobile-txt-pin").val() != "") {\
       $("#pin-hide").removeClass("show").addClass("hide");\
    }});\
    var  buttonClass = $("#mobile-btn-pinenb").attr("class");\
\
    function errorPopover(id,text){\
      $(id).addClass(\'error-tooltip\');\
      $(id).each(function() {\
        var $this = $(this);\
        $this.popover({\
          trigger: \'hover\',\
          placement: \'bottom\',\
          html: true,\
          content:text\
        });\
      });\
    }\
\
    $("#global-apply").click(function(){\
    $("#new-confirm-notmatch").removeClass("show").addClass("hide");\
    var newButtonClass = $("#mobile-btn-pinenb").attr("class");\
    if (buttonClass != newButtonClass){ buttonChange = "1" }\
    var params = [];\
    $("#mobile-txt-pin").removeClass(\'error-tooltip\');\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    var target = $("#mobile_form").attr("action");\
    var enable;\
    var oldmobilestatus = "');  ngx.print(mobile_content["enable"]); ngx.print('"\
    var nw_type = $("#mobile-sel-nwtyp").children("option").filter(":selected").val()\
    if ($("#mobile-btn-status").hasClass("button-on")) {\
      enable = "1";\
    }\
    else {\
      enable = "0";\
    }\
    var connect = $("#mobile-btn-connect").hasClass("button-on") ? 1 : 0;\
    var autofailover = $("#mobile-btn-autofailover").hasClass("button-on")? 1 : 0;\
    var pin = $.trim($("#mobile-txt-pin").val());\
    if (buttonChange == "1"){\
      if (($("#mobile-btn-pinenb").hasClass("button-on")) && ($("#full-hide").hasClass("show"))){\
         params.push({\
          name  : "pin_enable",\
          value : pin\
        })\
      }\
      else if (($("#mobile-btn-pinenb").hasClass("button-off")) && ($("#full-hide").hasClass("show"))){\
        params.push({\
          name  : "pin_disable",\
          value : pin\
        })\
      }\
    }\
    if (oldmobilestatus != enable){\
      params.push({\
        name  : "enable",\
        value : enable\
       })\
    }\
    if ($(".pukshow").hasClass("show")){\
      params.push({\
        name : "newpin",\
        value:  $("#mobile-txt-newpin").val()\
      },{\
        name : "puk",\
        value : $("#mobile-txt-pukValue").val()\
      })\
    }\
    params.push({\
      name  : "connect",\
      value : connect\
    },{\
      name  : "autofailover",\
      value : autofailover\
    },{\
      name : "network_type",\
      value : nw_type\
    },{\
      name : "save_pin",\
      value :$("#mobile-btn-savepin").hasClass("button-on")? "1" : "0"\
    },{\
      name : "action",\
      value : "SAVE"\
    },{\
      name : "CSRFtoken",\
      value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    })\
    var newpin = $.trim($("#mobile-txt-newpin").val());\
    var confirmpin = $.trim($("#mobile-txt-confirmpin").val());\
    var pukcode = $.trim($("#mobile-txt-pukValue").val());\
    if ($("#pin-hide").hasClass("show") && (buttonChange == "1" || resetClick == "1" )){\
      if ((pin == "") && ($("#full-hide").hasClass("show")) && ($(".pinshow").hasClass("show"))) {\
        console.log("entering in pin")\
        $("#mobile-txt-pin").addClass(\'error-tooltip\');\
        $(\'#mobile-txt-pin\').attr(\'data-content\',"');  ngx.print(T"Invalid PIN"); ngx.print('")\
        $(\'#mobile-txt-pin\').on(\'mouseover\', function () {\
        $(\'#mobile-txt-pin\').popover(\'show\');})\
        $(\'#mobile-txt-pin\').on(\'mouseleave\', function () {\
        $(\'#mobile-txt-pin\').popover(\'hide\');})\
      }\
      else if ($(".pukshow").hasClass("show")){\
        if (newpin == "") {\
           errorPopover("#mobile-txt-newpin","');  ngx.print(T"Invalid PIN"); ngx.print('" );\
        }\
        if (confirmpin == ""){\
          errorPopover("#mobile-txt-confirmpin","');  ngx.print(T"Invalid PIN"); ngx.print('" )\
        }\
        if (pukcode == ""){\
          errorPopover("#mobile-txt-pukValue","');  ngx.print(T"Invalid PUK"); ngx.print('" )\
        }\
        if(newpin != "" && confirmpin != "" && pukcode != ""){\
           if (newpin != confirmpin){\
              $("#new-confirm-notmatch").removeClass("hide").addClass("show");\
            } else {\
              mobilePostHandler(target, params);\
            }\
        }\
      } else{\
        mobilePostHandler(target, params);\
      }\
    }\
    else {\
      mobilePostHandler(target, params);\
    }\
  });\
  $("#mobile-chk-dispin").click(function(){\
      if (this.checked)\
      {\
        $("#mobile-txt-pin").removeAttr("type","password");\
        $("#mobile-txt-pin").attr("type","text");\
      }\
      else {\
        $("#mobile-txt-pin").removeAttr("type","text");\
        $("#mobile-txt-pin").attr("type","password");\
      }\
  });\
\
  $("#mobile-btn-reset").click(function(){\
    $("#warning-popup").modal();\
    var resetParams = []\
    resetParams.push({name: "reset", value: true},{name: "CSRFtoken", value : $("[name=CSRFtoken]").val() });\
    $.post("modals/mobile.lp", resetParams, function(responsetTxt, status, XHR){\
      if (responsetTxt.status == "success"){\
        $("#mobile-txt-pin").val("");\
    }});\
  });\
\
  $(\'#mobile-txt-pin\').focus(function () {\
    $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
    }).blur(function () {\
    $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
  });\
\
  $("#global-cancel").click(function(){\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    $("#content").load("/modals/mobile.lp");\
  });\
});\
$("#resetR, .resetR").click(function(){\
  resetClick = "1";\
    $("#mobile-sel-nwtyp").val("');  ngx.print(resetmobile["reset_preferred_network"]); ngx.print('").trigger("chosen:updated");\
    function changeButton(id, value, hiddenField) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenField).removeClass("hide").addClass("show");\
      } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenField).removeClass("show").addClass("hide");\
      }\
    }\
    changeButton("#mobile-btn-status", ');  ngx.print(resetmobile["reset_mobile_enabled"]); ngx.print(', "#full-hide");\
    changeButton("#mobile-btn-autofailover", ');  ngx.print(resetmobile["reset_autofailover"]); ngx.print(');\
    changeButton("#mobile-btn-connect", ');  ngx.print(resetmobile["reset_mobile_connect"]); ngx.print(');\
    var autofailover = $("#mobile-btn-autofailover").hasClass("button-on")? 1 : 0;\
    if (autofailover == 0) {\
      $("#mobile-section-connect").removeClass("hide").addClass("show");\
    } else {\
      $("#mobile-section-connect").removeClass("show").addClass("hide");\
    }\
    changeButton("#mobile-btn-pinenb", ');  ngx.print(resetmobile["reset_pin_enabled"]); ngx.print(');\
    $("#pin-hide").removeClass("show").addClass("hide");\
});\
\
</script>\
'); 
