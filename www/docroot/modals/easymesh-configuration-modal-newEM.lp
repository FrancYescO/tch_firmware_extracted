--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local proxy = require("datamodel")
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local validatePSK = post_helper.validatePSK
  local content_helper = require("web.content_helper")
  local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
  local getAndValidation = post_helper.getAndValidation
  local getValidationIfPropInList = post_helper.getValidationIfPropInList
  local validateBoolean = post_helper.validateBoolean
  local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
  local message_helper = require("web.uimessage_helper")
  local match, format = string.match, string.format
  local variant_helper = require("variant_helper")
  local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
  local session = ngx.ctx.session
  local currentRole = session:getrole()
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  local json = require("dkjson")
  local AirtiesSmartWiFiSupported = post_helper.isFeatureEnabled("AirtiesSmartWiFiSupported")

  local securityModes = {}
  local APSec_modes = proxy.get("uci.multiap.controller.supported_security_modes") or ""
  APSec_modes = APSec_modes and APSec_modes[1].value or ""
  APSec_modes:gsub("[^%s]+", function(c)
    if c == "none" then
      securityModes[#securityModes+1] = { c, T("<strong>"..string.untaint(c:gsub("^%l", string.upper)).."</strong>")}
    else
      securityModes[#securityModes+1] = { c, T("<strong>"..string.untaint(string.upper(c)).."</strong>")}
    end
  end)

  local controllers = {
    {"telus", T"Telus"},
    {"disabled", T"Disabled"}
  }

  local frequencyBands = {
    {"radio_2G", T"2.4 GHz"},
    {"radio_5Gl", T"5 GHz Low"},
    {"radio_5Gu", T"5 GHz High"}
  }

  local function getValidateExtraSpaces(value)
    if match(value, "^%s+") or match(value, "%s+$") then
      return nil, T"Leading and trailing whitespaces are not allowed."
    end
    return true
  end

  local getCredentials = content_helper.convertResultToObject("uci.multiap.controller_credentials.", proxy.get("uci.multiap.controller_credentials."))

  if ngx.var.request_method == "GET" and not AirtiesSmartWiFiSupported then
    if  ngx.req.get_uri_args().action == "controllerStatus" then
      local getParams = {
        controllerStatus = "rpc.multiap.X_000E50_ControllerStatus",
      }
      content_helper.getExactContent(getParams)
      local responseData = {
        getParams = getParams
      }
      ngx.header.content_type = "application/json"
      ngx.print(json.encode(responseData))
      ngx.exit(ngx.OK)
    end
    if ngx.req.get_uri_args().action == "agentStatus" then
      local getParams = {
        agentStatus = "rpc.multiap.X_000E50_AgentStatus",
      }
      content_helper.getExactContent(getParams)
      local responseData = {
        getParams = getParams
      }
      ngx.header.content_type = "application/json"
      ngx.print(json.encode(responseData))
      ngx.exit(ngx.OK)
    end
  end
  local credParamIndex
  local controlSelection = post_helper.getVariantValue(variantHelper, "controlSelectionEnabled")
  local mapParams, mapValid = {}, {}

  if AirtiesSmartWiFiSupported then
    mapParams.smartWiFiEnable = "rpc.wireless.SmartWiFi.Active"
    mapValid.smartWiFiEnable = validateBoolean
  else
    local content = {
      controllerMac = "uci.multiap.controller.macaddress",
      agentMac = "uci.multiap.agent.macaddress"
    }
    content_helper.getExactContent(content)
    mapParams.agentEnable = "uci.multiap.agent.enabled"
    mapParams.controllerEnable = "uci.multiap.controller.enabled"
    mapValid.agentEnable = validateBoolean
    mapValid.controllerEnable = validateBoolean

    if post_helper.getVariantValue(variantHelper, "controlSelectionEnabled") then
      mapParams.control_select = "rpc.multiap.X_000E50_ControllerSelection"
      mapValid.control_select = getValidateInEnumSelect(controllers)
    end

    for _, data in pairs(getCredentials) do
      if data.backhaul == "1" then
        credParamIndex = data.paramindex
      end
    end
    if credParamIndex and post_helper.getVariantValue(variantHelper, "backhaulConfig") then
      mapParams["state" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".state"
      mapParams["broadcastssid"] = "uci.multiap.agent.hidden_backhaul"
      mapParams["ssid" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
      mapParams["securityMode" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
      mapParams["password" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
      mapParams["frequency" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"

      mapValid["state" .. credParamIndex] = validateBoolean
      mapValid["broadcastssid"] = validateBoolean
      mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
      mapValid["securityMode" .. credParamIndex] = getValidateInEnumSelect(securityModes)
      mapValid["password" .. credParamIndex] = getAndValidation(getValidationIfPropInList(validatePSK, "securityMode"..  credParamIndex, {"wpa2-psk", "wpa-wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk"}),getValidateExtraSpaces)
      mapValid["frequency" .. credParamIndex] = post_helper.validateNonEmptyString
    end

    if proxy.get("uci.wifi_conductor.global.multiap_enabled") then
      mapParams.wificonductorEnable = "uci.wifi_conductor.global.multiap_enabled"
      mapValid.wificonductorEnable = validateBoolean
    end

    local isGuest = false
    if controlSelection then
      if proxy.get("uci.wireless.wifi-bandsteer.@bs0.") then
        mapParams.wifibandsteerEnable = "uci.wireless.wifi-bandsteer.@bs0.state"
        mapValid.wifibandsteerEnable = validateBoolean
      end
      if proxy.get("uci.wireless.wifi-bandsteer.@bs1.") then
        isGuest = true
        mapParams.wifiGuestbandsteerEnable = "uci.wireless.wifi-bandsteer.@bs1.state"
        mapValid.wifiGuestbandsteerEnable = validateBoolean
      end
    end

    local tod_rule = false
    for k,v in ipairs(proxy.getPN("uci.tod.timer.", true)) do
      local key = match(v.path, "%@%l+(%w+)")
      local ssid = proxy.get("uci.tod.ap.@ap"..key..".ssid") and proxy.get("uci.tod.ap.@ap"..key..".ssid")[1].value
      if ssid == "all" and proxy.get("uci.tod.action.@action"..key..".enabled")[1].value == "0" then
        tod_rule = true
      end
    end
  end

  local params, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  if ngx.req.get_method() == "POST" and not next(helpmsg) and not AirtiesSmartWiFiSupported then
    if params.agentEnable == "1" and params.controllerEnable == "1" then
      proxy.set("uci.wireless.wifi-ap.@ap0.acl_mode", "disabled")
      proxy.set("uci.wireless.wifi-ap.@ap1.acl_mode", "disabled")
      proxy.del("uci.wireless.wifi-ap.@ap0.acl_accept_list.")
      proxy.del("uci.wireless.wifi-ap.@ap1.acl_accept_list.")
      proxy.del("uci.wireless.wifi-ap.@ap0.acl_deny_list.")
      proxy.del("uci.wireless.wifi-ap.@ap1.acl_deny_list.")
      if isGuest then
        proxy.set("uci.wireless.wifi-ap.@ap2.acl_mode", "disabled")
        proxy.set("uci.wireless.wifi-ap.@ap3.acl_mode", "disabled")
        proxy.del("uci.wireless.wifi-ap.@ap2.acl_accept_list.")
        proxy.del("uci.wireless.wifi-ap.@ap3.acl_accept_list.")
        proxy.del("uci.wireless.wifi-ap.@ap2.acl_deny_list.")
        proxy.del("uci.wireless.wifi-ap.@ap3.acl_deny_list.")
      end
      proxy.apply()
    end
  end

  local role =  proxy.get("rpc.multiap.X_000E50_Role")
  role = role and role[1].value or ""

  ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
\
<form class = "modal-body form-horizontal" style = "overflow-x:hidden" method = "post" action = "modals/easymesh-configuration-modal-newEM.lp">\
  ');  lp.include("tabs-easyMesh.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset id = "easy-mesh-configuration-tab">\
    <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
    ');  if (params.controllerEnable == "1" and params.agentEnable == "1" and tod_rule) then
      local tod_warning = {
        alert = {
          class = "alert-warning monitor-default-show todWarning"
        }
      }
      ngx.print(ui_helper.createAlertBlock(T"The Wi-Fi Schedule is currently enabled and your Wi-Fi connection will turn off as specified.", tod_warning))
    end  ngx.print('\
    ');  
      local ssidclass = {
        input = {
          pattern = "[!-~][ -~]{0,30}[!-~]",
          maxlength = "32",
          class = "span4"
        }
      }

      local pskclass = {
        group = {
          class = "monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
        },
        input = {
          class= "span4",
          maxlength = "63"
        }
      }

      local controllerClass = {
        span = {
          id = "controllermac"
        }
      }

      local agentClass = {
        span = {
          id = "agentmac"
        }
      }
      local html = {}
      if post_helper.getVariantValue(variantHelper, "extenderInfo") then
        if post_helper.getVariantValue(variantHelper, "controlSelectionEnabled") then
          html[#html + 1] = ui_helper.createInputSelect(T"Control Selection", "control_select", controllers, params["control_select"])
          if params["control_select"] == "disabled" then
            html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller", "easyMeshController", (params.controllerEnable == "1" and "1" or "0"))
            html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshAgent", (params.agentEnable == "1" and "1" or "0"))
          elseif params["control_select"] == "telus" then
            html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller", "easyMeshController", (role == "Controller" and "1" or "0"))
            html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshAgent", (params.agentEnable == "1" and "1" or "0"))
          end
        else
          if not post_helper.getVariantValue(variantHelper, "isExtender") then
            if currentRole == "engineer" then
              html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller", "easyMeshController", (params.controllerEnable == "1" and "1" or "0"), nil, nil, (params.controllerEnable == "1" and "controller" or nil))
              html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshAgent", (params.agentEnable == "1" and "1" or "0"), nil, nil, (params.agentEnable == "1" and "agent" or nil))
            elseif AirtiesSmartWiFiSupported then
              html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller/Agent Services", "smartWiFiEnable", (params.smartWiFiEnable == "1" and "1" or "0"), nil, nil, nil)
            else
              html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller/Agent Services", "easyMeshEnable", ((params.agentEnable == "1" and params.controllerEnable == "1") and "1" or "0"), nil, nil, ((params.agentEnable == "1" and params.controllerEnable == "1") and "controller" or nil))
            end
          else
             html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshAgent", (params.agentEnable == "1" and "1" or "0"), nil, nil, (params.agentEnable == "1" and "agent" or nil))
          end
        end
        ngx.print(html)
        html = {}
        if session:getrole() == "engineer" and credParamIndex and post_helper.getVariantValue(variantHelper, "backhaulConfig") and (params.agentEnable ~= "1" and params.controllerEnable ~= "1") then
            ngx.print('\
          <legend>');  ngx.print( T"Backhaul configuration" ); ngx.print('</legend>\
          ');  
          html[#html + 1] = ui_helper.createSwitch(T"State", "state" .. credParamIndex, params["state" ..credParamIndex])
          if params.broadcastssid then
            html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "broadcastssid", (params.broadcastssid == "1" and "1" or "0"))
          end
          html[#html + 1] = ui_helper.createInputText( T"SSID", "ssid" .. credParamIndex, params["ssid" .. credParamIndex], ssidclass, helpmsg["ssid" .. credParamIndex])
          html[#html + 1] = ui_helper.createInputText( T"Password", "password"..credParamIndex, params["password" .. credParamIndex], pskclass, helpmsg["password" .. credParamIndex])
          local checkbox2 = {
            checkbox = {
              class = "inline"
            },
            input = {
              id = "showpass"..credParamIndex,
              class = "no-save"
            },
          }
          if post_helper.getVariantValue(variantHelper, "showPassword") then
            html[#html + 1] = ui_helper.createCheckboxSwitch(T"Show Password", "showpass"..credParamIndex, "0", checkbox2)
          end
          if params["securityMode" .. credParamIndex] == "none" then
            local security_warning = {
              alert = {
                class = "alert-error monitor-security"..credParamIndex.." monitor-none"
              },
            }
            html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)
          end
          html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "securityMode"..credParamIndex, securityModes, params["securityMode" .. credParamIndex])
          local frequenciesChecked = {}
          getFrequency = params["frequency" .. credParamIndex]
          for value in string.gmatch(getFrequency, '([^,]+)') do
            frequenciesChecked[#frequenciesChecked + 1] = string.untaint(value)
          end
          html[#html + 1] =  ui_helper.createCheckboxGroup(T"Frequency Band(s)", "frequencyBands", frequencyBands, frequenciesChecked, {checkbox = { class="inline" }}, nil)
          local frequency_enable_class = {
            group = {
              class = "hide"
            },
            input = {
              class= "span4",
              id = "frequency"..credParamIndex
            }
          }
          html[#html+1] = ui_helper.createInputText(T"", "frequency"..credParamIndex, params["frequency" .. credParamIndex], frequency_enable_class)
       end
     end
     local agent_enable_class = {
       group = {
         class = "hide"
       },
       input = {
         class= "span4",
         id = "agentEnable"
       }
      }
      html[#html+1] = ui_helper.createInputText(T"", "agentEnable", params.agentEnable, agent_enable_class)
      local controller_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class= "span4",
          id = "controllerEnable"
        }
      }
      html[#html+1] = ui_helper.createInputText(T"", "controllerEnable", params.controllerEnable, controller_enable_class)
      if controlSelection then
        local wifibandsteer_enable_class = {
          group = {
            class = "hide"
          },
          input = {
            class= "span4",
            id = "wifibandsteerEnable"
          },
        }
        local wifiguestbandsteer_enable_class = {
          group = {
            class = "hide"
          },
          input = {
            class= "span4",
            id = "wifiGuestbandsteerEnable"
          },
        }
        html[#html+1] = ui_helper.createInputText(T"", "wifibandsteerEnable", params.wifibandsteerEnable, wifibandsteer_enable_class)
        if isGuest then
          html[#html+1] = ui_helper.createInputText(T"", "wifiGuestbandsteerEnable", params.wifiGuestbandsteerEnable, wifiguestbandsteer_enable_class)
        end
      end
      local wificonductor_enable_class = {
        group = {
          class = "hide"
        },
        input = {
              class= "span4",
              id = "wificonductorEnable"
        },
      }
      html[#html+1] = ui_helper.createInputText(T"", "wificonductorEnable", params.wificonductorEnable, wificonductor_enable_class)
      ngx.print(html)
      ngx.print('\
  </fieldset>\
</form>\
\
<!-- Explicit Save and Cancel written to confirm again to apply the changes -->\
<div class="modal-footer">\
  <div id="modal-no-change">\
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">');  ngx.print(T"Close"); ngx.print('</div>\
  </div>\
  <div id="modal-changes" class="hide">\
    <div id="cancel-config-change" class="btn btn-large" data-dismiss="modal">');  ngx.print(T"Cancel"); ngx.print('</div>\
    <div id="save-config" class="btn btn-primary backHaulPassword_popup btn-large">');  ngx.print(T"Save"); ngx.print('</div>\
  </div>\
</div>\
\
<script>\
  var credParamIndex = "');  ngx.print(credParamIndex); ngx.print('";\
  var multiapAgent = "');  ngx.print(params.agentEnable); ngx.print('";\
  var multiapContr = "');  ngx.print(params.controllerEnable); ngx.print('";\
  var controlSelect = "');  ngx.print(params.control_select); ngx.print('";\
  var isGuest = "');  ngx.print(isGuest); ngx.print('";\
  var controlSelection = "');  ngx.print(controlSelection); ngx.print('"\
  var currentRole = "');  ngx.print(currentRole); ngx.print('";\
  var isExtender = ');  ngx.print(post_helper.getVariantValue(variantHelper, "isExtender")); ngx.print(';\
  var showPass = ');  ngx.print(post_helper.getVariantValue(variantHelper, "showPassword")); ngx.print(';\
  var confirmPopup = ');  ngx.print(post_helper.getVariantValue(variantHelper, "easyMeshConfirmPopup")); ngx.print(';\
  var easyMeshDisableMessage = "');  ngx.print(T'EasyMesh is disabled.<br> You can safely enable Bandsteering, if needed'); ngx.print('";\
  var easyMeshEnableMessage = "');  ngx.print(T'EasyMesh is enabled.<br> This action will disable Bandsteering'); ngx.print('";\
  var enableTitle = "');  ngx.print(T'Enable EasyMesh'); ngx.print('";\
  var disableTitle = "');  ngx.print(T'Disable EasyMesh'); ngx.print('";\
  var AirtiesSmartWiFiSupported = ');  ngx.print(post_helper.isFeatureEnabled("AirtiesSmartWiFiSupported")); ngx.print(';\
\
  var T = {\
    "initializingController" : "');  ngx.print(T"[1/7] initializing"); ngx.print('",\
    "syncController" : "');  ngx.print(T"[2/7] synchronizing"); ngx.print('",\
    "startController" : "');  ngx.print(T"[3/7] starting"); ngx.print('",\
    "upController" : "');  ngx.print(T"[4/7] up"); ngx.print('",\
    "onboardProgressController" : "');  ngx.print(T"[5/7] local agent onboarding in progress"); ngx.print('",\
    "messageController" : "');  ngx.print(T"[6/7] checking messages from local agent"); ngx.print('",\
    "onboardSuccessController" : "');  ngx.print(T"[7/7] local agent onboarding success"); ngx.print('",\
    "initializingAgent" : "');  ngx.print(T"[1/6] initializing"); ngx.print('",\
    "syncAgent" : "');  ngx.print(T"[2/6] synchronizing"); ngx.print('",\
    "startAgent" : "');  ngx.print(T"[3/6] starting"); ngx.print('",\
    "upAgent" : "');  ngx.print(T"[4/6] up"); ngx.print('",\
    "onboardProgressAgent" : "');  ngx.print(T"[5/6] onboarding in progress"); ngx.print('",\
    "onboardSuccessAgent" : "');  ngx.print(T"[6/6] onboarding success"); ngx.print('"\
  }\
</script>\
<script src="/js/easymesh-configuration-modal-newEM.js"></script>\
'); 
