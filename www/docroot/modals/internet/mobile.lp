--pretranslated: do not change this file
 --Enable localization

gettext.textdomain('webui-core')
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local gVIES = post_helper.getValidateInEnumSelect
local next, ngx, string, tonumber, ipairs = next, ngx, string, tonumber, ipairs
local format, untaint = string.format, string.untaint
local preferedNetwork, preferedNetworkIndex

local valid_network_types = {
  {"auto", T"Auto"},
  {"4GPreferred", T"4G Preferred"},
  {"3GPreferred", T"3G Preferred"},
  {"2GPreferred", T"2G Preferred"},
  {"4GOnly", T"4G Only"},
  {"3GOnly", T"3G Only"},
  {"2GOnly", T"2G Only"}
}

local pin_state = {
  ["enabled_verified"] = T"PIN verified",
  ["not_initialized"] = T"PIN not initialized",
  ["enabled_not_verified"] = T"PIN not verified",
  ["blocked"] = T"SIM Blocked. Awaiting PUK",
  ["permanently_blocked"] = T"PIN permanently Blocked",
  ["disabled"] = "",
}

local env_value = {
  variantParam = "uci.env.var.vodafone_variant",
  mobiled_enabled = "rpc.mobiled.enabled"
}
content_helper.getExactContent(env_value)

local tprint = require("tch.tableprint")

if env_value.variantParam == "NZ" then
  valid_network_types = {
    { "auto" , T"Auto"    },
    { "lte"  , T"4G Only" },
    { "umts"  , T"3G Only" },
--    { "gsm" , T"2G Only" },
  }
end

local mobile_params = {
  enable = "uci.mobiled.device_defaults.enabled",
}
if proxy.get("uci.mobiled.device.@1.enabled") then
  mobile_params.mobile_device_enable = "uci.mobiled.device.@1.enabled"
end

local mobile_nw_params = {
  save_pin = "uci.mobiled.globals.store_pin",
}

local device_entries = proxy.get("rpc.mobiled.DeviceNumberOfEntries")

local mobile_valid = {
  enable = post_helper.validateBoolean,
}

if env_value.mobiled_enabled == "0" then
  mobile_params.mobiled_enabled = "rpc.mobiled.enabled"
  mobile_valid.mobiled_enabled = function(value, object, key)
    object[key] = '1'
    return true
  end
end

local mobile_nw_valid = {
  save_pin = post_helper.validateBoolean,
}

if mobile_params.mobile_device_enable then
  mobile_valid.mobile_device_enable = function(value, object, key)
    object[key] = object["enable"]
    return true
  end
end

local function validateConnect(value, object, key)
  if object.autofailover == "1" then
    object[key] = nil
    return true
  end
  return post_helper.validateBoolean(value)
end

local wan_down
if env_value.variantParam == "NZ" then
  local content_ip = {
    wan = "rpc.network.interface.@wan.ipaddr",
    wan6 = "rpc.network.interface.@wan6.ip6addr",
  }
  content_helper.getExactContent(content_ip)
  wan_down = (content_ip.wan =="" and content_ip.wan6 =="")
  if wan_down then
    mobile_nw_params.connect = "uci.network.interface.@wwan.auto"
  end
  mobile_nw_params.autofailover = "uci.wansensing.global.autofailover"
  mobile_nw_valid.connect = validateConnect
  mobile_nw_valid.autofailover = post_helper.validateBoolean
end
local mobile_get, mobile_content ={}, {}

local mobile_nw_content = vdf_helper.handlePOST(post_helper.handleQuery, {mobile_nw_params, mobile_nw_valid})
local pinDetail = content_helper.convertResultToObject("uci.mobiled.sim.", proxy.get("uci.mobiled.sim."))

-- function to findout perfer network value for mobiled device
-- return string like("4G/3G/2G Preferred" or "4G/3G/2G only" or "auto") and index
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
  reset_mobile_autofailover = "uci.uci-defaults.mobile.mobile_autofailover",
  reset_preferred_network = "uci.uci-defaults.mobile.preferred_network",
  reset_pin_enabled = "uci.uci-defaults.mobile.pin_enabled"
}
content_helper.getExactContent(resetmobile)

-- If user tries to Change Mobile button, mobile device (not mobile daemon) shall be enabled/disabled.
-- This parameter will be updated only when user changes the button value.
if ngx.req.get_method() ~= "POST" or ngx.req.get_post_args().enable then
  mobile_content = vdf_helper.handlePOST(post_helper.handleQuery, {mobile_params, mobile_valid})
else
  mobile_content["enable"] = proxy.get("uci.mobiled.device_defaults.enabled")[1].value
end

if mobile_content.mobiled_enabled == "0" then
   mobile_content["enable"] = "0"
end

if device_entries and tonumber(device_entries[1].value) > 0 then
  mobile_get["pin_state"] = "rpc.mobiled.device.@1.sim.pin.pin_state"
  mobile_get["sim_state"] = "rpc.mobiled.device.@1.sim.sim_state"
  mobile_get["pinCount"] = "rpc.mobiled.device.@1.sim.pin.unlock_retries_left"
  mobile_get["pukCount"] = "rpc.mobiled.device.@1.sim.pin.unblock_retries_left"
  mobile_get["iccid"] = "rpc.mobiled.device.@1.sim.iccid"
  content_helper.getExactContent(mobile_get)
  preferedNetwork, preferedNetworkIndex = preferNetworkMethod()
end

-- Function to validate pin or puk should contain numbers only.
-- @param : pinpuk contain value of either pin or puk
-- @param : pukValid in order to differentiate validation from
-- pin and puk in order to return corresponding error  message
-- return boolean
local function pinValidation(pinPuk, pukValid)
  local result = post_helper.validatePositiveNum(pinPuk)
  local lengthValidation
  if result then
    -- Validation to check length of PIN and PUK Number.
    if not pukValid then
      lengthValidation = post_helper.getValidateStringLengthInRange(4,4)
    else
      lengthValidation = post_helper.getValidateStringLengthInRange(8,8)
    end
    result = lengthValidation(pinPuk)
 end
  if not result then
    if pukValid then
      return nil, T"Invalid UMTS PUK"
    else
      return nil, T"Invalid UMTS PIN"
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
  local  isPinValid,  networkValidation, isValidNetworkPref, isNewPinValid, isPukValid, isNewSimPinValid
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
      if postArgs["pin_enable"] and errorFlag ~= true then
        setTable["rpc.mobiled.device.@1.sim.pin.enable"] = postArgs["pin_enable"]
      end

      -- When user tries to disable to Pin. Correct pin value will be updated in parameter disable.
      if postArgs["pin_disable"] and errorFlag ~= true then
        setTable["rpc.mobiled.device.@1.sim.pin.disable"] = postArgs["pin_disable"]
      end

      -- When user tries to change the Pin. Correct pin value will be updated in parameter change.
      -- In order to change pin. User need to enter old pin and new pin with comma separated.
      if postArgs["changesimpin"] and errorFlag ~= true then
        -- When pin state is blocked. New pin will be validated
        isNewSimPinValid, pinErrMsg = pinValidation(ngx.req.get_post_args().newsimpin)
        if not isNewSimPinValid then
          errorFlag = true
        else
          setTable["rpc.mobiled.device.@1.sim.pin.change"] =  postArgs["changesimpin"]
        end
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
        setTable["rpc.mobiled.device.@1.sim.pin.unblock"] = postArgs["changepin"]
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
    mobile_get["iccid"] = "rpc.mobiled.device.@1.sim.iccid"
    content_helper.getExactContent(mobile_get)
    preferedNetwork = preferNetworkMethod()

    -- When wrong pin entered pin count will decrease and sendpin will return currentpincount
    if mobile_get["pin_state"] ~= "blocked" and mobile_get["pin_state"] ~= "permanently_blocked" then
      if  mobile_get["pinCount"] and currentPinCount and mobile_get["pinCount"] ~= "" and tonumber(mobile_get["pinCount"]) < currentPinCount then
        sendpin = mobile_get["pinCount"]
        errorFlag = true
      end
    else
      -- When wrong pin entered puk count will decrease and sendpuk will return currentpukcount
      if mobile_get["pukCount"] ~= "" and mobile_get["pin_state"] == "blocked" and tonumber(mobile_get["pukCount"]) < currentPukCount and  mobile_get["pinCount"] == "0" then
        sendpuk = mobile_get["pukCount"]
        errorFlag = true
      end
    end
  end
  if errorFlag ~= true then   ngx.print('\
    <input type="hidden" id="postStatus" value="success">\
     ');  else  ngx.print('\
    <input type="hidden" id="postStatus" value="error" data-pukmsg= \'');  ngx.print(pukErrMsg and pukErrMsg or ""); ngx.print('\' data-pinmsg=\'');  ngx.print(pinErrMsg and pinErrMsg or ""); ngx.print('\' data-pinCount=\'');  ngx.print(sendpin and sendpin or ""); ngx.print('\' data-pukCount=\'');  ngx.print(sendpuk and sendpuk or ""); ngx.print('\' >\
  ');  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<div class="row">\
  <div class="col-md-12">\
    <h1>');  ngx.print(T"Mobile"); ngx.print('</h1>\
  </div>\
</div>\
<div class="row">\
  <div class="col-md-12">\
    ');  if env_value.variantParam ~= "NZ" then  ngx.print('\
    <h2>&nbsp;</h2>\
    ');  else  ngx.print('\
    <h2>');  ngx.print(T"Mobile Charges will apply when connecting via cellular network"); ngx.print('</h2>\
    ');  end  ngx.print('\
  </div>\
</div>\
\
<form id="mobile_form" class="form-horizontal" method="post" action="modals/internet/mobile.lp">\
  <div class="h3-content no-padding-bottom">\
    ');  
        local mobile_row = {
          element = ui_helper.createButton({
            id = "mobile-btn-status",
            class = (mobile_content and mobile_content["enable"] == "1") and "button button-on pull-right" or "button button-off pull-right"
          }),
          rowClass = "row",
          colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          label = T"Mobile"
        }
        ngx.print(ui_helper.createRow(mobile_row))
        ngx.print('\
  </div>\
  <div id="full-hide" class="show">\
    <div class="h3-content no-padding-bottom">\
      ');  
        if env_value.variantParam == "NZ" then
          local auto_fail_over_row = {
            element = ui_helper.createButton({
              id = "mobile-btn-autofailover",
              class = (mobile_nw_content and mobile_nw_content["autofailover"] == "1") and "button button-on pull-right" or "button button-off pull-right"
            }),
            rowClass = "row",
            colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
            colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
            label = T"Auto Fail Over"
          }
          ngx.print(ui_helper.createRow(auto_fail_over_row))
          if wan_down then
            local connect_row = {
              element = ui_helper.createButton({
                id = "mobile-btn-connect",
                class = (mobile_nw_content and mobile_nw_content["connect"] == "1") and "button button-on pull-right" or "button button-off pull-right"
              }),
              rowClass = "row mobile-connect-row",
              colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
              colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
              label = T"Connect"
            }
            ngx.print(ui_helper.createRow(connect_row))
          end
        end
        local preferred_network_row = {
          rowClass = "row",
          label = T"Preferred Network Type",
          colLeftClass = "col-md-6 col-sm-6 col-xs-12  padding-top-bottom-20 mobile-padding-bottom-none",
          labelClass = "font-bold",
          colRightClass = "col-md-6 col-sm-6 col-xs-12 mobile-padding-top-none padding-top-bottom-20",
          colRightId = "mobile-dropdown-select",
          element = format('<div id="top-info-mode" class="rel mobile-pull-left umts">%s</div>', ui_helper.createDropDown({
            id = "mobile-sel-nwtyp",
            name = "network_type",
            style = "width: 165px;"
          }, valid_network_types, preferedNetwork))
        }
        ngx.print(ui_helper.createRow(preferred_network_row))
        ngx.print('\
    </div>\
    <div id="pin-hide2"  class=\'');  if mobile_get["pin_state"] and ( mobile_get["pin_state"] == "disabled" or mobile_get["pin_state"] == "enabled_not_verified" or mobile_get["pin_state"] == "enabled_verified" ) then   ngx.print(' show ');  else  ngx.print(' hide ');  end   ngx.print('\'>\
    ');  
        local PIN_enabled_row = {
          element = format('<div class=" pull-right">%s</div>', ui_helper.createButton({
            id = "mobile-btn-pinenb",
            class = (mobile_get["pin_state"] and (mobile_get["pin_state"] == "enabled_verified" or mobile_get["pin_state"] == "enabled_not_verified")) and "button button-on" or "button button-off"
          })),
          rowClass = "row",
          labelClass = "font-bold",
          colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          label = T"PIN Enabled"
        }
        ngx.print(ui_helper.createRow(PIN_enabled_row))
        local PIN_Status_row = {
          element = format('<div class=" pull-right">%s</div>',ui_helper.createOnlyText({
            id = "mobile-lbl-pin"
          }, mobile_get["pin_state"] and pin_state[untaint(mobile_get["pin_state"])] or pin_state["not_initialized"])),
          rowClass = "row",
          colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          label = T"PIN Status"
        }
        ngx.print(ui_helper.createRow(PIN_Status_row))
        ngx.print('\
    </div>\
    <div id="pin-hide"  class=\'');  if mobile_get["pin_state"] and mobile_get["pin_state"] == "enabled_not_verified" then ngx.print(' show ');  else  ngx.print(' hide ');  end   ngx.print('\'>\
      <div class="h3-content mobile-no-float">\
        <div class="row">\
          <div class="col-md-12">\
            <hr/>\
          </div>\
        </div>\
        <div class="pinshow show">\
        ');  
          local datPin = "";
          for _, data in ipairs(pinDetail) do
            if data and mobile_get["iccid"] == data.iccid then
              datPin = data.pin
            end
            break
          end
          local dataplacement = "data-placement"
          local PIN_row = {
          element = format('<div class=" pull-right">%s</div>',ui_helper.createTextField({
            type = "password",
            class = "form-control pin-show",
            id = "mobile-txt-pin",
            placeholder = "********",
            name = "mobile_pin",
            value = datPin,
            ["data-placement"] = "bottom",
            ["data-toggle"] = "popover"
          })),
          rowClass = "row",
          colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
          label = T"PIN"
          }
          ngx.print(ui_helper.createRow(PIN_row))
          ngx.print('\
          <div class="row padding-top-bottom-20 text-right">\
            <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
              <span >');  ngx.print(T"You have "); ngx.print(mobile_get["pinCount"]);  ngx.print(T " attempt(s) left"); ngx.print('</span>\
            </div>\
            <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
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
          ');  
            local Save_PIN_row = {
              element = format('<div class=" pull-right">%s</div>',ui_helper.createButton({
                id = "mobile-btn-savepin",
                class = mobile_nw_content["save_pin"] ~= "0" and "button button-on pin-enable" or "button button-off pin-enable"
              })),
              rowClass = "row padding-top-bottom-20",
              colLeftClass = "col-md-6 col-sm-6 col-xs-6",
              colRightClass = "col-md-6 col-sm-6 col-xs-6",
              label = T"Save PIN",
              labelClass = "language-string"
            }
            ngx.print(ui_helper.createRow(Save_PIN_row))
            ngx.print('\
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
      </div>\
    </div>\
    <div id="puk-hide"  class=\'');  if mobile_get["pin_state"] and ( mobile_get["pin_state"] == "blocked" ) then   ngx.print(' show ');  else  ngx.print(' hide ');  end   ngx.print('\'>\
      <div class="h3-content mobile-no-float">\
        <div class="pukshow hide">\
        ');  
          local PUK_row = {
          {
              label = T"PUK",
              element = ui_helper.createTextField({
                type = "password",
                id = "mobile-txt-pukValue"
              })
          },
          {
              label = T"New PIN",
              element = ui_helper.createTextField({
                type = "password",
                id = "mobile-txt-newpin"
              })
          }
          }
          ngx.print(ui_helper.createTable(PUK_row, "", "vdf-table"))
           ngx.print('\
          <div class="row">\
            <div class="col-md-12">\
              <hr/>\
            </div>\
          </div>\
          <div class="vdf-table">\
          ');  
            local confirm_PIN_row = {
              label = T"Confirm PIN",
              element = ui_helper.createTextField({
                type = "password",
                id = "mobile-txt-confirmpin"
              })
            }
            ngx.print(ui_helper.createRow(confirm_PIN_row))
            ngx.print('\
          </div>\
        </div>\
      </div>\
    </div>\
    <div id="changepin-hide" class="'); if mobile_get["pin_state"] and mobile_get["pin_state"] == "enabled_verified" then ngx.print(' show '); else  ngx.print(' hide '); end  ngx.print('">');
      local PIN_SIM_enabled_row = {
        element = format('<div class="pull-right">%s</div>', ui_helper.createButton({
          id = "mobile-btn-changepin",
          class = "button button-off"
        })),
        rowClass = "row",
        labelClass = "font-bold",
        colLeftClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
        colRightClass = "col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20",
        label = T"Change PIN"
      }
      ngx.print(ui_helper.createRow(PIN_SIM_enabled_row))
      ngx.print('\
    </div>\
    <div id="simpinnew" class="hide">\
      ');  
        local Old_SIM_PIN_row = {
          {
            label = T"Old PIN",
            element = ui_helper.createTextField({
              type = "password",
              id = "mobile-txt-oldsimpin"
            })
          },
          {
            label = T"New PIN",
            element = ui_helper.createTextField({
              type = "password",
              id = "mobile-txt-newsimpin"
            })
          }
        }
        ngx.print(ui_helper.createTable(Old_SIM_PIN_row, "", "vdf-table"))
        ngx.print('\
        <div class="row">\
          <div class="col-md-12">\
            <hr/>\
          </div>\
        </div>\
        <div class="vdf-table">\
        ');  
          local confirm_SIM_PIN_row = {
            label = T"Confirm PIN",
            element = ui_helper.createTextField({
              type = "password",
              id = "mobile-txt-confirmsimpin"
            })
          }
          ngx.print(ui_helper.createRow(confirm_SIM_PIN_row))
          ngx.print('\
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
          <input class="button button-cancel mob-button-width mob-apply-cancel" id="mobile-reset-close" value="');  ngx.print(T"Close"); ngx.print('" type="button" data-dismiss="modal" style="width: auto;">\
        </div>\
      </div>\
    </div>\
  </div>\
  <div class="table-wrapper">\
    <div class="message message-info  hide" id ="pin-Err" >\
       ');  ngx.print(T"Empty PIN found. You forget to provide a PIN Code"); ngx.print('\
    </div>\
    <div class="message message-info  hide" id ="pin-Errmsg" >\
      ');  ngx.print(T"Invalid UMTS PIN"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="puk-Errmsg" >\
      ');  ngx.print(T"Invalid UMTS PUK"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="new-confirm-notmatch" >\
      ');  ngx.print(T"New PIN and Confirm PIN does not match"); ngx.print('\
    </div>\
    <div class="message message-info hide" id="pinpuk-countmsg" >\
      <span style="font-weight:normal"></span>\
    </div>\
    <div class="message message-info hide" id="puk-infomsg" >\
      ');  ngx.print(T"SIM Card is locked, please enter the PUK and the new PIN.<br/>You have "); ngx.print(mobile_get["pukCount"]);  ngx.print(T " attempt(s) left"); ngx.print('\
    </div>\
  </div>\
</form>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script type="text/javascript" src="js/global-min.js"></script>\
<script>\
var resetClick  = "0";\
var variant = "');  ngx.print(env_value.variantParam); ngx.print('";\
$(function() {\
    $("#global-msg-lte").show();\
    $("#global-msg-umts").show();\
    if (("');  ngx.print(mobile_get.pin_state); ngx.print('" == "disabled" && variant != "NZ") || "');  ngx.print(mobile_get.pin_state); ngx.print('" == "enabled_not_verified") {\
      $("#global-msg-lte-umts").show();\
      if("');  ngx.print(preferedNetwork); ngx.print('" == "4GPreferred" || "');  ngx.print(preferedNetwork); ngx.print('" == "4GOnly") {\
	$("#global-msg-umts").hide();\
      }\
      else {\
	$("#global-msg-lte").hide();\
      }\
    }\
    else {\
      $("#global-msg-lte-umts").hide();\
    }\
  var mobileEnable = "');  ngx.print(mobile_content and mobile_content.enable or "0" ); ngx.print('"\
  if (mobileEnable  == "0") {\
    $("#full-hide").removeClass("show").addClass("hide");\
  } else {\
    $("#full-hide").removeClass("hide").addClass("show");\
  }\
  if (variant == "NZ") {\
    var autofailover = $("#mobile-btn-autofailover").hasClass("button-on")? 1 : 0;\
    if (autofailover == "0") {\
      $(".mobile-connect-row").removeClass("hide").addClass("show");\
    } else {\
      $(".mobile-connect-row").removeClass("show").addClass("hide");\
    }\
  }\
  var mobilePinState = "');  ngx.print( mobile_get["pin_state"] and mobile_get["pin_state"] ); ngx.print('"\
  if ( mobilePinState == "blocked") {\
    $(".pinshow").removeClass("show").addClass("hide");\
    $(".pukshow").removeClass("hide").addClass("show");\
    $("#puk-infomsg").removeClass("hide").addClass("show");\
  }\
  function mobilePostHandler(target, params, post) {\
    applyCancelPopupHide();\
    if (variant == "NZ" && typeof(Storage) !== "undefined") {\
      sessionStorage.setItem("user_interacted", "pristine");\
    }\
    $(\'#global-apply\').prop("disabled", true).addClass(\'table-button-faded\');\
    $("#pin-Errmsg").removeClass("show").addClass("hide");\
    $("#puk-Errmsg").removeClass("show").addClass("hide");\
    $("#pinpuk-countmsg").removeClass("show").addClass("hide");\
    var scrollTop = $(document).scrollTop();\
    var callback = function(response, status, XHR) {\
      response = post ? response.status : $("#postStatus").val();\
      if (response == "success") {\
        $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");\
        // If POST succeeds, load the page\
        $("#content").load(target, function() {\
          bindChosen();\
          $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
          $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");\
          setTimeout(function() {\
            $(".articlediv").removeClass("show").addClass("hide");\
          }, 3000);\
        });\
      } else {\
        $(".articlediv > .message-arrowbox-applied, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv, .articlediv > .msg-error").removeClass("hide").addClass("show");\
        var pinmsg = $("#postStatus").attr("data-pinmsg");\
        var pukmsg = $("#postStatus").attr("data-pukmsg");\
        if (pinmsg != "") {\
          $("#pin-Errmsg").removeClass("hide").addClass("show");\
        }\
        if (pukmsg != "") {\
          $("#puk-Errmsg").removeClass("hide").addClass("show");\
        }\
        if (mobilePinState != "blocked" || mobilePinState != "permanently_blocked") {\
          var errpinCount = $("#postStatus").attr("data-pinCount");\
          if (errpinCount != "") {\
            $(\'#pinpuk-countmsg span\').text(\'');  ngx.print(T"The PIN you entered is incorrect. Please enter the correct PIN. You have "); ngx.print('\'+errpinCount+\'');  ngx.print(T " attempt(s) left"); ngx.print('\');\
            $("#pinpuk-countmsg").removeClass("hide").addClass("show");\
          }\
        }\
        if (mobilePinState == "blocked" ) {\
          var errpukCount = $("#postStatus").attr("data-pukCount");\
          if (errpukCount != "") {\
            $(\'#pinpuk-countmsg span\').text(\'');  ngx.print(T"The PUK you entered is incorrect. Please enter the correct PUK. You have "); ngx.print('\'+errpukCount+\'');  ngx.print(T " attempt(s) left"); ngx.print('\');\
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
  if (mobilePinState == "blocked" || mobilePinState == "permanently_blocked") {\
    $("#mobile-lbl-pin").css("color" , "#e60000");\
  }\
  $("#mobile-btn-status").click(function() {\
    if ($(this).hasClass("button-off") && ((mobilePinState == "enabled_verified"  && $("#mobile-btn-pinenb").hasClass("button-on")) || (mobilePinState != "enabled_verified"  && $("#mobile-btn-pinenb").hasClass("button-off")))) {\
      $("#full-hide").removeClass("show").addClass("hide");\
    } else {\
      $("#full-hide").removeClass("hide").addClass("show");\
    }\
  });\
  var buttonChange = "0";\
  var pin_state = "');  ngx.print(mobile_get["pin_state"]); ngx.print('";\
  $("#mobile-btn-pinenb").click(function() {\
    if ($(this).hasClass("button-on")) {\
      if (pin_state == "enabled_not_verified" || pin_state == "disabled"){\
        $("#pin-hide").removeClass("hide").addClass("show");\
      } else {\
        $("#pin-Err").removeClass("show").addClass("hide");\
        $("#pin-hide").removeClass("show").addClass("hide");\
        if (pin_state == "enabled_verified") {\
          $("#changepin-hide").removeClass("hide").addClass("show");\
        }\
	  }\
    }else if($(this).hasClass("button-off") ) {\
      if (pin_state == "enabled_not_verified" || pin_state == "enabled_verified" ){\
        $("#pin-hide").removeClass("hide").addClass("show");\
      }else{\
        $("#pin-Err").removeClass("show").addClass("hide");\
        $("#pin-hide").removeClass("show").addClass("hide");\
	  }\
      $("#changepin-hide").removeClass("show").addClass("hide");\
    }});\
  $("#mobile-btn-changepin").click(function(){\
    if($(this).hasClass("button-on") ) {\
       $("#simpinnew").removeClass("hide").addClass("show");\
    }else if($(this).hasClass("button-off") ) {\
      $("#simpinnew").removeClass("show").addClass("hide");\
    }});\
  var  buttonClass = $("#mobile-btn-pinenb").attr("class");\
\
  function errorPopover(id,text) {\
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
  $("#global-apply, #modal-apply").click(function() {\
    $("#new-confirm-notmatch").removeClass("show").addClass("hide");\
    var newButtonClass = $("#mobile-btn-pinenb").attr("class");\
    if (buttonClass != newButtonClass) { buttonChange = "1" }\
	if ("');  ngx.print(mobile_get["pin_state"]); ngx.print('" == "enabled_not_verified"){ buttonChange = "1" }\
    var params = [];\
    $("#mobile-txt-pin").removeClass(\'error-tooltip\');\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    var target = $("#mobile_form").attr("action");\
    var enable;\
    var oldmobilestatus = "');  ngx.print(mobile_content["enable"]); ngx.print('"\
    var nw_type = $("#mobile-sel-nwtyp").children("option").filter(":selected").val()\
    if ($("#mobile-btn-status").hasClass("button-on")) {\
      enable = "1";\
    } else {\
      enable = "0";\
    }\
    var pin = $.trim($("#mobile-txt-pin").val());\
    if (buttonChange == "1") {\
      if (($("#mobile-btn-pinenb").hasClass("button-on")) && ($("#full-hide").hasClass("show"))) {\
        params.push({\
          name  : "pin_enable",\
          value : pin\
        })\
      } else if (($("#mobile-btn-pinenb").hasClass("button-off")) && ($("#full-hide").hasClass("show"))) {\
        params.push({\
          name  : "pin_disable",\
          value : pin\
        })\
      }\
    }\
    if (oldmobilestatus != enable) {\
      params.push({\
        name  : "enable",\
        value : enable\
      })\
    }\
    if ($(".pukshow").hasClass("show")) {\
      params.push({\
        name : "newpin",\
        value:  $("#mobile-txt-newpin").val()\
      },{\
        name : "puk",\
        value : $("#mobile-txt-pukValue").val()\
      },{\
        name : "changepin",\
        value:  $("#mobile-txt-newpin").val()+","+$("#mobile-txt-pukValue").val()\
      })\
    }\
    if ($("#simpinnew").hasClass("show")){\
      params.push({\
        name : "newsimpin",\
        value:  $("#mobile-txt-newsimpin").val()\
      },{\
        name : "changesimpin",\
        value:  $("#mobile-txt-oldsimpin").val()+","+$("#mobile-txt-newsimpin").val()\
      })\
    }\
    if (variant == "NZ") {\
      var connect = $("#mobile-btn-connect").hasClass("button-on") ? 1 : 0;\
      var autofailover = $("#mobile-btn-autofailover").hasClass("button-on")? 1 : 0;\
      params.push({\
        name  : "connect",\
        value : connect\
      },{\
        name  : "autofailover",\
        value : autofailover\
      });\
    }\
    params.push({\
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
    var newsimpin = $.trim($("#mobile-txt-newsimpin").val());\
    var confirmsimpin = $.trim($("#mobile-txt-confirmsimpin").val());\
    var oldsimpin = $.trim($("#mobile-txt-oldsimpin").val());\
    if ($("#pin-hide").hasClass("show") && (buttonChange == "1" || resetClick == "1" )) {\
      if ((pin == "") && ($("#full-hide").hasClass("show")) && ($(".pinshow").hasClass("show"))) {\
        $("#mobile-txt-pin").addClass(\'error-tooltip\');\
        $(\'#mobile-txt-pin\').attr(\'data-content\',"');  ngx.print(T"Invalid UMTS PIN"); ngx.print('")\
        $(\'#mobile-txt-pin\').on(\'mouseover\', function () {\
          $(\'#mobile-txt-pin\').popover(\'show\');\
        })\
        $(\'#mobile-txt-pin\').on(\'mouseleave\', function () {\
          $(\'#mobile-txt-pin\').popover(\'hide\');\
        })\
      } else{\
        mobilePostHandler(target, params);\
      }\
    } else if ($(".pukshow").hasClass("show")) {\
      if (newpin == "") {\
        errorPopover("#mobile-txt-newpin","');  ngx.print(T"Invalid UMTS PIN"); ngx.print('");\
      }\
      if (confirmpin == "") {\
        errorPopover("#mobile-txt-confirmpin","');  ngx.print(T"Invalid UMTS PIN"); ngx.print('")\
      }\
      if (pukcode == "") {\
        errorPopover("#mobile-txt-pukValue","');  ngx.print(T"Invalid UMTS PUK"); ngx.print('")\
      }\
      if(newpin != "" && confirmpin != "" && pukcode != "") {\
        if (newpin != confirmpin) {\
          $("#new-confirm-notmatch").removeClass("hide").addClass("show");\
        } else {\
          mobilePostHandler(target, params);\
        }\
      }\
    } else if ($("#simpinnew").hasClass("show")){\
      if (newsimpin == "") {\
         errorPopover("#mobile-txt-newsimpin","');  ngx.print(T"Invalid PIN"); ngx.print('" );\
      }\
      if (confirmsimpin == ""){\
        errorPopover("#mobile-txt-confirmsimpin","');  ngx.print(T"Invalid PIN"); ngx.print('" )\
      }\
      if (oldsimpin == ""){\
        errorPopover("#mobile-txt-oldsimpin","');  ngx.print(T"Invalid PIN"); ngx.print('" )\
      }\
      if(newsimpin != "" && confirmsimpin != "" && oldsimpin != ""){\
         if (newsimpin != confirmsimpin){\
            $("#new-confirm-notmatch").removeClass("hide").addClass("show");\
          } else {\
            mobilePostHandler(target, params);\
          }\
      }\
    } else {\
      mobilePostHandler(target, params);\
    }\
  });\
  $("#mobile-chk-dispin").click(function() {\
    if (this.checked) {\
      $("#mobile-txt-pin").removeAttr("type","password");\
      $("#mobile-txt-pin").attr("type","text");\
    } else {\
      $("#mobile-txt-pin").removeAttr("type","text");\
      $("#mobile-txt-pin").attr("type","password");\
    }\
  });\
\
  $("#mobile-btn-reset").click(function() {\
    $("#warning-popup").modal();\
    var resetParams = []\
    resetParams.push({name: "reset", value: true},{name: "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") });\
    $.post("modals/internet/mobile.lp", resetParams, function(responsetTxt, status, XHR) {\
      if (responsetTxt.status == "success") {\
        $("#mobile-txt-pin").val("");\
      }\
    });\
  });\
\
  $(\'#mobile-txt-pin\').focus(function () {\
    $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
  }).blur(function () {\
    if ($("#mobile-txt-pin").val() == "") {\
      $("#mobile-txt-pin").addClass("input-error");\
      $("#pin-Err").removeClass("hide").addClass("show");\
    }\
    else {\
      $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
      $("#mobile-txt-pin").removeClass("input-error");\
      $("#pin-Err").removeClass("show").addClass("hide");\
    }\
  });\
\
});\
\
$("#resetR, .resetR").click(function() {\
  resetClick = "1";\
  $("#mobile-sel-nwtyp").val("');  ngx.print(resetmobile["reset_preferred_network"]); ngx.print('").trigger("chosen:updated");\
  changeButton("#mobile-btn-status", ');  ngx.print(resetmobile["reset_mobile_enabled"]); ngx.print(', "#full-hide");\
  changeButton("#mobile-btn-pinenb", ');  ngx.print(resetmobile["reset_pin_enabled"]); ngx.print(');\
  if (variant == "NZ") {\
    changeButton("#mobile-btn-connect", ');  ngx.print(resetmobile["reset_mobile_connect"]); ngx.print(');\
    changeButton("#mobile-btn-autofailover", ');  ngx.print(resetmobile["reset_mobile_autofailover"]); ngx.print(');\
  }\
  $("#pin-hide").removeClass("show").addClass("hide");\
});\
</script>\
');
