--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local string = string
local format, find, floor = string.format, string.find, math.floor
local math, tonumber = math, tonumber

local mobileInfo = {
  rssi               =   "rpc.mobiled.device.@1.radio.signal_quality.rssi",
  plmn_name          =   "rpc.mobiled.device.@1.network.serving_system.network_desc",
  ps_state           =   "rpc.mobiled.device.@1.network.serving_system.ps_state",
  imsi               =   "rpc.mobiled.device.@1.sim.imsi",
  imei               =   "rpc.mobiled.device.@1.info.imei",
  radio_interface    =   "rpc.mobiled.device.@1.radio.signal_quality.radio_interface",
}
content_helper.getExactContent(mobileInfo)


ngx.print('\
  <script>\
    $(function() {\
      $(\'select\').chosen({\
        disable_search_threshold: 100000,\
        allow_single_deselect: true\
       });\
    });\
  </script>\
');

local mobile_status = {
  rssi       = T"RSSI(DB)",
  plmn_name  = T"PLMN Name",
  ps_state   = T"Status",
  imsi       = T"IMSI",
  imei       = T"IMEI",
  radio_interface = T"Radio Interface"
}

html = {}
html[#html +1] = string.format([[
           		<h1><span>%s</span></h1><h3><span>%s</span></h3>
		   		]],T"Mobile Status",T"3G/4G")
html[#html +1] = "<div class=\"h3-content mobile-padding-bottom-lg\">"

for i,v in pairs(mobile_status) do
  html[#html +1] = string.format([[
                   <div class="row padding-top-bottom-20"><div class="col-md-3 col-sm-3 col-xs-6"><span>%s</span></div> 
	               ]],v)
  html[#html +1] = string.format([[			
			     <div class="col-md-9 col-sm-9 col-xs-6"><span class="pull-right" id="mobile_rssi">%s</span></div></div>
				 ]], mobileInfo[i] or "")
  html[#html +1] = " <div class=\"row not-flex-row\"><div class=\"col-md-12\"><hr/></div></div>"
end
  html[#html +1 ] ="</div>"

ngx.print(html)

