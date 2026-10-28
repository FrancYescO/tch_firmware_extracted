--pretranslated: do not change this file
 
    gettext.textdomain('webui-core')
    local post_helper = require("web.post_helper")
    local variant_helper = require("variant_helper")
    local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
    local proxy = require("datamodel")
    local ui_helper = require("web.ui_helper")
    local multiapAgent = proxy.get("rpc.multiap.X_000E50_AgentEnabled")[1].value
    local multiapController = proxy.get("rpc.multiap.X_000E50_ControllerEnabled")[1].value
    local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
    isNewLayout = isNewLayout and isNewLayout[1].value or "0"
    local AirtiesSmartWiFiSupported = post_helper.isFeatureEnabled("AirtiesSmartWiFiSupported")

    local items = {}
    if isNewLayout == "1" then
      if post_helper.getVariantValue(variantHelper, "showEMConfigPage") then
        items[#items + 1] = {"easymesh-configuration-modal-newEM.lp", T"EasyMesh Configuration"}
      end
      if post_helper.getVariantValue(variantHelper, "extenderInfo") and not AirtiesSmartWiFiSupported then
        if post_helper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager") then
          if multiapController == "1" and multiapAgent == "1" then
            items[#items + 1] = {"easymesh-topology-modal-newEM.lp", T"Topology"}
          end
        else
          items[#items + 1] = {"easymesh-topology-modal-newEM.lp", T"Topology"}
        end
        if post_helper.getVariantValue(variantHelper, "ShowWiFiDevicesWithoutHostManager") then
          if multiapController == "1" and multiapAgent == "1" then
            items[#items + 1] =  {"easymesh-devices-info-modal-newEM.lp", T"Devices", "easyMeshDevices"}
          end
        else
          items[#items + 1] =  {"easymesh-devices-info-modal-newEM.lp", T"Devices", "easyMeshDevices"}
        end
      end
    else
      if post_helper.getVariantValue(variantHelper, "easymeshConfig") then
        items[#items + 1] = {"easy-mesh-configuration.lp", T"EasyMesh Configuration"}
      end
      if post_helper.getVariantValue(variantHelper, "extenderInfo") then
        items[#items + 1] = {"wifi-extender-status.lp", T"Extender Info"}
      end
      if post_helper.getVariantValue(variantHelper, "agentAndStationInfo") then
        items[#items + 1] = {"agent-list.lp", T"Agent List"}
      end
      if post_helper.getVariantValue(variantHelper, "wifiDevicesList") then
        items[#items + 1] =  {"wifi-devices-info.lp", T"WiFi Devices"}
      end
    end
    local uri = ngx.var.args and string.len(ngx.var.args) > 0 and ngx.var.uri.. "?" .. ngx.var.args or  ngx.var.uri
    local fileName = string.match(uri, "/%S+/(%S+)")
    if string.match(fileName, "^agent") then
      items[3][1] = fileName
    end
    local html = ui_helper.createModalTabs(items, uri)
    ngx.print(html)
  ngx.print('\
'); 