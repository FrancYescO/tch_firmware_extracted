--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber

local content_type = {
    l2 = "uci.wansensing.global.l2type",
}
content_helper.getExactContent(content_type)


local types = { "wan" }
local mapParams = {}

local cType = "PVC"

if content_type.l2 == "ETH" then
    cType = "VLAN"
    mapParams = {
        id_wan = "uci.network.bcmvopi.@eth4_v881.vid",
        ifname_wan = "uci.network.interface.@wan.ifname",
    }
elseif content_type.l2 == "VDSL" then
      cType = "VLAN"
      mapParams = {
        id_wan = "uci.network.bcmvopi.@ptm0_v881.vid",
        ifname_wan = "uci.network.interface.@wan.ifname",
      }
elseif content_type.l2 == "ADSL" then
      mapParams = {
        id_wan = "uci.network.bcmvopi.@atm_8_35_v0.vid",
        ifname_wan = "uci.network.interface.@wan.ifname",
      }
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
if ngx.var.request_method == "GET" then
    local content_dev = {
        device_wan = "rpc.network.interface.@wan.ppp.ll_dev",
    }
    content_helper.getExactContent(content_dev)

    for _,type in ipairs(types) do
        local tagged = "tagged_" .. type
        content[tagged] = '0'

        local vid = proxy.get("uci.network.bcmvopi.@"..content_dev["device_" .. type]..".vid")
        if vid and vid[1] and vid[1]["value"] ~=  "0" then
            content[tagged] = '1'
        end
    end
end

local function createVlan(legend, type, content, helpmsg)
    local html = {}
    local tagged = "tagged_" .. type
    local id = "id_" .. type
    html[#html + 1] = string.format([[<legend>%s</legend>]], legend)
    if content[tagged] then
        html[#html + 1] = ui_helper.createLabel(T"VLAN ID", content[id])
    end
    return html
end

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader("Broadband", true, true) ); ngx.print('\
\
<div class="modal-body update">\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-broadband.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/broadband-eth-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      ');  
        local html = {}
        if cType == "VLAN" then
            html[#html + 1] = createVlan(T"High Speed Internet", "wan", content, helpmsg)
        end
        ngx.print(html)
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 