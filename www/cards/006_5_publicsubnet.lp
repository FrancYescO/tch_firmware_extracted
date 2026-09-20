--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format
local session = ngx.ctx.session
local intfexists = 0
local publicpath = "uci.network.interface.@lan_public."
local modalpath = "modals/subnet-modal.lp"
for _, v in ipairs (proxy.getPN("uci.network.interface.", true)) do
   if v["path"] == publicpath then
      intfexists = 1
      break
   end
end

if intfexists == 1 then
    local mapParams = {
        ip = publicpath .. "ipaddr",
        mask = publicpath .. "netmask",
    }
    content_helper.getExactContent(mapParams)

    local ip = mapParams["ip"]
    local mask = mapParams["mask"]
    if ip ~= "" and mask ~= "" then
        ngx.print('\
        <div class="span3">\
          <div class="smallcard">',
            ui_helper.createCardHeader(T"Public Subnet", modalpath), '\
            <div class="content card_bg" data-bg-text="&#xf047;">\
              <div class="divtable">');
                local html = {}
                html[#html+1] = format('<div class=\"subinfos\"><span>%s: </span><span><b>%s</b></span></div>',T"Gateway",ip)
                html[#html+1] = format('<div class=\"subinfos\"><span>%s: </span><span><b>%s</b></span></div>',T"Netmask",mask)
                ngx.print(html, '\
              </div>\
            </div>\
          </div>\
        </div>');
    end
end