--pretranslated: do not change this file
 
-- Enable localization
-- GHG-1386 Bridging card
-- Version 1.1  20.02.2016-------------------------------------------------------------------
-- correction done to assure that all 4 bridged Ports are also shown as 4 Ports bridged
-- Section relevant marked with mod: 160220
---------------------------------------------------------------------------------------------
-- Version 1.0 30.12.2015 -------------------------------------------------------------------
-- content_helper.getExactContent(mapTV) introduced 
-- to assure correct display from bridged ports of other services
---------------------------------------------------------------------------------------------
-- Version 0.2 19.07.2015 -------------------------------------------------------------------
-- Initial start based on CS implementation
---------------------------------------------------------------------------------------------

-- Enable localization
gettext.textdomain('webui-core')
local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local brlib = require("brlib_helper")

-------------------------------Data Checking which Ports are Bridged----mod: 160220-----------------------
local mapParams = {
					wanifname	="uci.network.interface.@wan.ifname",
					envdata		="uci.env.var.datavlan",
					enviptv		="uci.env.var.iptv",
				}
local mapTV	=	{
				iptvifname	="uci.network.interface.@iptv.ifname",
				}
content_helper.getExactContent(mapParams)
content_helper.getExactContent(mapTV)
states={}
local briableport = 4
local Port = format("%s", mapParams.wanifname)
local wanvlanlist = brlib.portscheck(format("%s",mapParams.envdata), briableport)
words = brlib.split(Port, "[%w_]+")

for h=1, briableport, 1 do
	for j=2, briableport+1, 1 do
		if words[j] == wanvlanlist[h] then
			states[h]=" "..h..","
			break
			else
			states[h]=""
		end
	end
end
------------------------------------------end-------------------------------

-------------------------------IPTV check which Ports are Bridged-------mod: 160220----------------------
TVtables={}
local IpTV = format("%s", mapTV.iptvifname)
local IPTVvlan = brlib.portscheck(format("%s",mapParams.enviptv), briableport)
IpTVlist = brlib.split(IpTV, "[%w_]+")

 for k=1, briableport, 1 do
	for l=2, briableport+1, 1 do
		if IpTVlist[l] == IPTVvlan[k] then
			TVtables[k]=" "..k..","
			break
		else
			TVtables[k]=""
		end
	end
end 
-------------------------------------------End------------------------


-----------------Deleting the "," after the last Portnumber-----"Data"---------
local str = brlib.resultcheck(states)
local leng =#str
local fin = string.sub(str, 0 ,leng-1)
-----------------------end------------------------------------------
-----------------Deleting the "," after the last Portnumber-----"IPTV"---------
local tv = brlib.resultcheck(TVtables)
local tvleng =#tv
local tvfin = string.sub(tv, 0 ,tvleng-1)

-----------------------end------------------------------------------

local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/bridgeports-LAN-modal.lp") then
modalPath = "/modals/bridgeports-LAN-modal.lp"
end

ngx.print('\
<div class="span3">\
	<div class="smallcard">');
	ngx.print(ui_helper.createCardHeader(T"Bridged Ports", modalPath, nil, nil))
	ngx.print('\
		<div class="content">\
	')
		if leng == 0 then
			ngx.print('\
            <p class="subinfos"><strong>\
			')
            ngx.print(T'Data: '); ngx.print('</strong>')
			ngx.print(fin)
			ngx.print('\
            </p>\
			')
		else
			ngx.print('\
            <p class="subinfos"><strong>\
			')
            ngx.print(T'Data: '); ngx.print('</strong>Port ')
			ngx.print(fin)
			ngx.print('\
            </p>\
			')
		end
			
		if tvleng == 0 then
			ngx.print('\
            <p class="subinfos"><strong>\
			')
            ngx.print(T'Other: '); ngx.print('</strong>')
			ngx.print(tvfin)
			ngx.print('\
            </p>\
			')
		else
			ngx.print('\
            <p class="subinfos"><strong>\
			')
            ngx.print(T'Other: '); ngx.print('</strong>Port ')
			ngx.print(tvfin)
			ngx.print('\
            </p>\
			')
		
		end
		
		
			
ngx.print('\
		</div>\
	</div>\
</div>\
')
