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
  local backhaulDetails = post_helper.getVariantValue(variantHelper, "backhaulDetails")
  local easyMeshButton = post_helper.getVariantValue(variantHelper, "easyMeshButton")
  local credShow = post_helper.getVariantValue(variantHelper, "credShow")
  local json = require("dkjson")

  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

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

  local backhaulState = ""
  if backhaulDetails then
    local wirelessValues = proxy.get("uci.wireless.wifi-iface.")
    wirelessValues = content_helper.convertResultToObject("uci.wireless.wifi-iface.", wirelessValues)
    for _, intf in ipairs(wirelessValues) do
      if intf.backhaul == "1" then
        backhaulState = intf.state
      end
    end
  end

  local preferredInterface = {
    {"radio_2G,radio_5Gu,radio_5Gl", T"<strong>Both</strong>"}
  }
  if post_helper.getVariantValue(variantHelper, "frequencySelection") then
    preferredInterface = {
      {"radio_2G", T"<strong>2.4GHz</strong>"},
      {"radio_5Gu,radio_5Gl", T"<strong>5GHz</strong>"},
      {"radio_2G,radio_5Gu,radio_5Gl", T"<strong>Both</strong>"}
    }
  end

  local function getValidateExtraSpaces(value)
    if match(value, "^%s+") or match(value, "%s+$") then
      return nil, T"Leading and trailing whitespaces are not allowed."
    end
    return true
  end

  local getCredentials = content_helper.convertResultToObject("uci.multiap.controller_credentials.", proxy.get("uci.multiap.controller_credentials."))

  local credParamIndex, ap

  local ap_details, guestAP = {}, {}
  local content = {
    controllerMac = "uci.multiap.controller.macaddress",
    agentMac = "uci.multiap.agent.macaddress"
  }
  if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
    content.ap0_state = "rpc.wireless.ap.@ap0.admin_state"
    content.ap1_state = "rpc.wireless.ap.@ap1.admin_state"
    if proxy.get("uci.wireless.wifi-bandsteer.@bs1.") then
      ap_details = proxy.get("uci.wireless.wifi-ap.")
      ap_details = content_helper.convertResultToObject("uci.wireless.wifi-ap.", ap_details)
      for _, apVal in ipairs(ap_details) do
        if apVal.bandsteer_id == "bs1" then
          ap = match(pathVal.paramindex, "@([^%.]+)")
          guestAP[#guestAP + 1] = ap
          content[ap] = "rpc.wireless.ap.@"..ap..".admin_state"
        end
      end
    end
  end
  content_helper.getExactContent(content)

  local mapParams = {
    agentEnable = "uci.multiap.agent.enabled",
    controllerEnable = "uci.multiap.controller.enabled"
  }
  local mapValid = {
    agentEnable = validateBoolean,
    controllerEnable = validateBoolean
  }
  local isGuest = false
  if not backhaulDetails then
    for _, data in pairs(getCredentials) do
      if data.fronthaul == "1" then
        if credShow then
          credParamIndex = "@cred0"
        else
          credParamIndex = data.paramindex
        end
        mapParams["state" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".state"
        mapParams["ssid" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
        mapParams["securityMode" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
        mapParams["password" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
        mapParams["frequency" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"
        mapParams["fronthaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".fronthaul"
        mapParams["backhaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".backhaul"

        mapValid["state" .. credParamIndex] = validateBoolean
        mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
        mapValid["securityMode" .. credParamIndex] = getValidateInEnumSelect(securityModes)
        mapValid["password" .. credParamIndex] = getValidationIfPropInList(validatePSK, "securityMode"..  credParamIndex, {"wpa2-psk", "wpa-wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk"})
        mapValid["frequency" .. credParamIndex] = getValidateInEnumSelect(preferredInterface)
        mapValid["fronthaul" .. credParamIndex] = validateBoolean
        mapValid["backhaul" .. credParamIndex] = validateBoolean

        if proxy.get("uci.wifi_conductor.global.multiap_enabled") then
          mapParams.wificonductorEnable = "uci.wifi_conductor.global.multiap_enabled"
          mapValid.wificonductorEnable = validateBoolean
        end
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
    end
  else
    for _, data in pairs(getCredentials) do
      if data.backhaul == "1" then
        credParamIndex = data.paramindex
      end
    end

    if credParamIndex then
      mapParams.backHaulssid = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
      mapParams.backHaulSecurityMode = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
      mapParams.backHaulPassword = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
      mapParams.controllerEnable = "uci.multiap.controller.enabled"
      mapParams.backHaulFrequency = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"

      mapValid.backHaulssid = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
      mapValid.backHaulSecurityMode = getValidateInEnumSelect(securityModes)
      mapValid.backHaulPassword = getValidationIfPropInList(validatePSK,"backHaulSecurityMode", {"wpa2-psk", "wpa-wpa2-psk"})
      mapValid.controllerEnable = validateBoolean
      mapValid.backHaulFrequency = getValidateInEnumSelect(preferredInterface)
    end
  end

  local params, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))  ngx.print('\
\
<form class = "modal-body form-horizontal" method = "post" action = "modals/easy-mesh-configuration.lp">\
  ');  lp.include("tabs-easyMesh.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset id = "easy-mesh-configuration-tab">\
    <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
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
      local selected_frequency = "radio_2G"
      if post_helper.getVariantValue(variantHelper, "extenderInfo") then
        if backhaulDetails and backhaulState ~= "0" then
          html[#html + 1] = ui_helper.createLabel( T"Backhaul SSID", params.backHaulssid, ssidclass)
          html[#html + 1] = ui_helper.createLabel( T"Backhaul Password", params.backHaulPassword, pskclass)
          html[#html + 1] = ui_helper.createLabel(T"Security Mode", params.backHaulSecurityMode)
        elseif easyMeshButton then
          html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller/Agent Services", "easyMeshEnable", ((params.agentEnable == "1" and params.controllerEnable == "1") and "1" or "0"))
          ngx.print(html)
          html = {}
          for _, data in pairs(getCredentials) do
            if data.fronthaul == "1" then
              if credShow and data.paramindex == "@cred0" or not credShow then
                credParamIndex = data.paramindex
                if post_helper.getVariantValue(variantHelper, "fronthaulString") then   ngx.print('\
                  <legend>');  ngx.print( T"Fronthaul Configuration" ); ngx.print('</legend>\
                ');  else   ngx.print('\
                  <legend>');  ngx.print( string.upper(string.sub(credParamIndex, 2, -1)) ); ngx.print('</legend>\
                ');  end
                if post_helper.getVariantValue(variantHelper, "credStatusSwitch") then
                  html[#html + 1] = ui_helper.createSwitch(T"State", "state" .. credParamIndex, params["state" ..credParamIndex])
                end
                html[#html + 1] = ui_helper.createInputText( T"SSID", "ssid" .. credParamIndex, params["ssid" .. credParamIndex], ssidclass, helpmsg["ssid" .. credParamIndex])
                html[#html + 1] = ui_helper.createInputText( T"Password", "password"..credParamIndex, params["password" .. credParamIndex], pskclass, helpmsg["password" .. credParamIndex])
                html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "securityMode"..credParamIndex, securityModes, params["securityMode" .. credParamIndex])

                --Condition to make one frequency band for all combinations of respective frequency band.
                if params["frequency" .. credParamIndex] and match(params["frequency" .. credParamIndex], 'radio_5G') then
                  selected_frequency = "radio_5Gu,radio_5Gl"
                  if match(params["frequency" .. credParamIndex], 'radio_2G') then
                    selected_frequency = "radio_2G,".. selected_frequency
                  end
                end
                html[#html + 1] = ui_helper.createInputSelect(T"Preferred Interface", "frequency"..credParamIndex, preferredInterface, selected_frequency)
                if post_helper.getVariantValue(variantHelper, "haulSwitch") then
                  html[#html + 1] = ui_helper.createSwitch(T"Fronthaul", "fronthaul" .. credParamIndex, params["fronthaul" ..credParamIndex])
                  html[#html + 1] = ui_helper.createSwitch(T"Backhaul", "backhaul" .. credParamIndex, params["backhaul" ..credParamIndex])
                end
             end
           end
           ngx.print(html)
           html = {}
          end
        end
    end
      if post_helper.getVariantValue(variantHelper, "controllerAgentMacAddress") then
        --html[#html + 1] = ui_helper.createLabel(T"Controller MAC Address", content.controllerMac, controllerClass)
        html[#html + 1] = ui_helper.createLabel(T"Agent MAC Address", content.agentMac, agentClass)
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
      if easyMeshButton then
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
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
  var multiapAgent = "');  ngx.print(params.agentEnable); ngx.print('";\
  var multiapContr = "');  ngx.print(params.controllerEnable); ngx.print('";\
  var ap0_state =  "');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role) and content.ap0_state or ""); ngx.print('";\
  var ap1_state =  "');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role) and content.ap1_state or ""); ngx.print('";\
  var confirmPopup = "');  ngx.print(post_helper.getVariantValue(variantHelper, "easyMeshConfirmPopup")); ngx.print('";\
  var easyMeshDisableMessage = "');  ngx.print(T'EasyMesh is disabled.<br> You can safely enable Bandsteering, if needed'); ngx.print('";\
  var easyMeshEnableMessage = "');  ngx.print(T'EasyMesh is enabled.<br> This action will disable Bandsteering'); ngx.print('";\
  var agentList = "');  ngx.print(T'Agent List'); ngx.print('";\
  var extenderInfo = "');  ngx.print(T'Extender Info'); ngx.print('";\
  var devicesList = "');  ngx.print(T'WiFi Devices'); ngx.print('";\
  var disableTitle = "');  ngx.print(T'Disable EasyMesh'); ngx.print('";\
  var enableTitle = "');  ngx.print(T'Enable EasyMesh'); ngx.print('";\
  var content = ');  ngx.print(json.encode(content) ); ngx.print(';\
  var guestAP = ');  ngx.print(json.encode(guestAP) ); ngx.print(';\
  var isGuest = ');  ngx.print(isGuest); ngx.print(';\
  var bandsteerDisabled = ');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role)); ngx.print(';\
</script>\
<script src="/js/easy-mesh-configuration.js"></script>\
'); 
