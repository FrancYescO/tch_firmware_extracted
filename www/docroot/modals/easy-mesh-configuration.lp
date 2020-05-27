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
  local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
  local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local securityModes = {
    {"wpa2-psk", T"<strong>WPA2-PSK</strong>"},
    {"wpa-wpa2-psk", T"<strong>WPA-WPA2-PSK</strong>"},
    {"wpa3-psk", T"<strong>WPA3-PSK</strong>"},
    {"wpa2-wpa3-psk", T"<strong>WPA2-WPA3-PSK</strong>"}
  }

  local backhaulState = ""
  if cardViewGFR then
    local wirelessValues = proxy.get("uci.wireless.wifi-iface.")
    wirelessValues = content_helper.convertResultToObject("uci.wireless.wifi-iface.", wirelessValues)
    for _, intf in ipairs(wirelessValues) do
      if intf.backhaul == "1" then
        backhaulState = intf.state
      end
    end
  end

  local preferredInterface = {
    {"radio_2G", T"<strong>2.4GHz</strong>"},
    {"radio_5Gu,radio_5Gl", T"<strong>5GHz</strong>"},
    {"radio_2G,radio_5Gu,radio_5Gl", T"<strong>Both</strong>"}
  }

  local function getValidateExtraSpaces(value)
    if match(value, "^%s+") or match(value, "%s+$") then
      return nil, T"Leading and trailing whitespaces are not allowed."
    end
    return true
  end

  local getCredentials = content_helper.convertResultToObject("uci.multiap.controller_credentials.", proxy.get("uci.multiap.controller_credentials."))

  local credParamIndex

  local content = {
    controllerMac = "uci.multiap.controller.macaddress",
    agentMac = "uci.multiap.agent.macaddress"
  }
  content_helper.getExactContent(content)

  local mapParams = {
    agentEnable = "uci.multiap.agent.enabled",
    controllerEnable = "uci.multiap.controller.enabled"
  }
  local mapValid = {
    agentEnable = validateBoolean,
    controllerEnable = validateBoolean
  }

  if not cardViewGFR then
    for _, data in pairs(getCredentials) do
      if data.fronthaul == "1" then
        credParamIndex = data.paramindex
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
      if post_helper.getVariantValue(variantHelper, "extenderInfo") then
        if cardViewGFR and backhaulState ~= "0" then
          html[#html + 1] = ui_helper.createLabel( T"Backhaul SSID", params.backHaulssid, ssidclass)
          html[#html + 1] = ui_helper.createLabel( T"Backhaul Password", params.backHaulPassword, pskclass)
          html[#html + 1] = ui_helper.createLabel(T"Security Mode", params.backHaulSecurityMode)
        elseif not cardViewGFR then
          html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Controller/Agent Services", "easyMeshEnable", ((params.agentEnable == "1" and params.controllerEnable == "1") and "1" or "0"))
          ngx.print(html)
          html = {}
          for _, data in pairs(getCredentials) do
            if data.fronthaul == "1" then
              credParamIndex = data.paramindex   ngx.print('\
              <legend>');  ngx.print( string.upper(string.sub(credParamIndex, 2, -1)) ); ngx.print('</legend>\
              ');  
              html[#html + 1] = ui_helper.createSwitch(T"State", "state" .. credParamIndex, params["state" ..credParamIndex])
              html[#html + 1] = ui_helper.createInputText( T"SSID", "ssid" .. credParamIndex, params["ssid" .. credParamIndex], ssidclass, helpmsg["ssid" .. credParamIndex])
              html[#html + 1] = ui_helper.createInputText( T"Password", "password"..credParamIndex, params["password" .. credParamIndex], pskclass, helpmsg["password" .. credParamIndex])
              html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "securityMode"..credParamIndex, securityModes, params["securityMode" .. credParamIndex])
              html[#html + 1] = ui_helper.createInputSelect(T"Preferred Interface", "frequency"..credParamIndex, preferredInterface, params["frequency" .. credParamIndex])
              html[#html + 1] = ui_helper.createSwitch(T"Fronthaul", "fronthaul" .. credParamIndex, params["fronthaul" ..credParamIndex])
              html[#html + 1] = ui_helper.createSwitch(T"Backhaul", "backhaul" .. credParamIndex, params["backhaul" ..credParamIndex])
            end
           ngx.print(html)
           html = {}
          end
        end
      elseif not cardViewGFR then
        html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshEnable", (params.agentEnable == "1" and "1" or "0"))
      end
      html[#html + 1] = ui_helper.createLabel(T"EasyMesh controller MAC Address", content.controllerMac, controllerClass)
      html[#html + 1] = ui_helper.createLabel(T"EasyMesh Agent MAC Address", content.agentMac, agentClass)

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
      if not cardViewGFR then
        html[#html+1] = ui_helper.createInputText(T"", "wifibandsteerEnable", params.wifibandsteerEnable, wifibandsteer_enable_class)
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
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">Close</div>\
  </div>\
  <div id="modal-changes" class="hide">\
    <div id="cancel-config-change" class="btn btn-large" data-dismiss="modal">Cancel</div>\
    <div id="save-config" class="btn btn-primary backHaulPassword_popup btn-large">Save</div>\
  </div>\
</div>\
<script src="/js/easy-mesh-configuration.js"></script>\
'); 