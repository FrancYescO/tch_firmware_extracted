--pretranslated: do not change this file
 ngx.print('	');  
		gettext.textdomain('webui-core')
                local post_helper = require("web.post_helper")
                local variant_helper = require("variant_helper")
                local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
                local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
                local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

		local ui_helper = require("web.ui_helper")
		local items = {
			{"easy-mesh-configuration.lp", T"EasyMesh Configuration"},
		}
                if post_helper.getVariantValue(variantHelper, "extenderInfo") then
                  items[#items + 1] = {"wifi-extender-status.lp", T"Extender Info"}
                  if not cardViewGFR then
                    items[#items + 1] = {"agent-list.lp", T"Agent List"}
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