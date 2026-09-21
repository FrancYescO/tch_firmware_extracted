--pretranslated: do not change this file
 
-- Enable localization
-- GHG-1386 Bridging card
-- Version 1.4 20160120 ------------------------------------------------------------------------------
-- correction done, that when 4th Port to be bridged it is executed and NO Error message shown
--              Section commented out and marked with:  160220 removed to assure 4 Bridged Ports 
-- correction done to assure that all 4 bridged Ports are also shown as 4 Ports bridged
-- Section relevant marked with mod: 160220
------------------------------------------------------------------------------------------------------
-- Version 1.3 20160205  +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- local mapWiFi5G introduced and removed the value from the wifichip from the local parameter      ++
--        mapParams and also modified the logic in the file to get mapParams on eth4 (string.match instead of wordsalso working
--        for non 5GHz platforms
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Version 0.3 20150710  +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Modal to provide Possibility to select Ethernet Ports to be bridged								++ 
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Version 0.4 20150713
-- function adaptations
-- to do: 	-createTable
-- at the moment:	-Button with Description(Port X)
-- 					-if IPTV than Lable with Text(Used by IPTV)
------------------------------------------------------------------------------------------------------
--Version 0.5 20150713
--ADSL/VDSL/ETH4/OWNIT Version
--with reboot
--with CS functions
------------------------------------------------------------------------------------------------------
--Version 0.6 20150715
--order of the proxy.set because wantypetemp befor wantemp
--if all states[x] are "0" then wantypetemp is set wantypetemp=eth4/adsl/vdsl
----------------------------------------------------------------------------------------------------
--Version 0.7 20151007
--functions are external in brlib_helper.lua
--also new: serfswitch and lanswitch will be sort
------------------------------------------------------------------------------------------------------
--Version 0.8 20151012
--control via env.var
--env.var has to be filled, if not, modal do not load
--dynamic how many ports will be bridged
--to do: portnamelist has to be dynamic
		--also configurations for wlan
------------------------------------------------------------------------------------------------------
-----------------Version V1.2 22.11.2015----------------------
-- Basis SW: 	Product: vant-w_telenor_r15-4
--				Release: Crimson (15.4)
--				Version: 15.45.6353-1770000-20151104154404-b081c26a216f9fb625bb633a03a36f57289944a2
-- CQ/Jira:

--------------------------------------------------------------------------------
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, string = table, string
local tonumber = tonumber
local attributes = { span = { class = "span3 simple-desc" } }
local brlib = require("brlib_helper")
local format, find, sub = string.format, string.find, string.sub
check="0"
---------------------------------------------------------Funktions-----------------------
-- wantemp = wan ifname expect "string"
-- lantemp = lan ifname expect "string"
-- lanstemp = lanswitch.ports expect "string"
-- serftemp = serswitch.ports expect "string"
-- lanvlan = expect "string" which port you want to set/delete example: "eth0_vlan1"
-- wanvlan = expect "string"  which port you want to set/delete example: "eth0_vlan2"
--switchport = expect "string" which port you want to set on lanswitch or serfswitch example: "1*"
--a = expect "string" which port you want to delete, but here you need to enter your Port also with an " " example: " 2%*"
--b = expect "string" which port you want to delete, but here you need to enter your Port also with an " " example: "2%* "
-- a and b are needed for deleting the Port from the serfswitch or from the lanswitch. Also you need the the "%" because "*" is a magic character 
--so that the function could interpret the "*".

------------------------------------------Functions end-----------------------------------------------
local mapParams = {
					wanifname	="uci.network.interface.@wan.ifname",
					lanifname	="uci.network.interface.@lan.ifname",
					lanswport	="uci.network.switch_vlan.@lansw.ports",
					serfswport	="uci.network.switch_vlan.@datasw.ports",
					wantype		="uci.network.interface.@wan.type",
				}

local mapWiFi5G =	{
					wifichip	="uci.wireless.wifi-device.@radio_5G.type",
				}

				
local mapTV =	{
					iptvifname	="uci.network.interface.@iptv.ifname",
				}
				
local mapEnv = {
					envlan		="uci.env.var.lanvlan",
					envdata		="uci.env.var.datavlan",
					envswitch	="uci.env.var.switch",
					enviptv		="uci.env.var.iptv",
				}
content_helper.getExactContent(mapParams)
content_helper.getExactContent(mapEnv)
content_helper.getExactContent(mapTV)
	if format("%s",mapWiFi5G.wifichip) == "quantenna" then
		briableport = 4
	else
		briableport = 4
	end
	local portnamelist = { "port1", "port2", "port3", "port4", "port5"}
	local lanvlanlist = brlib.portscheck(format("%s",mapEnv.envlan), briableport)
	local serflanlist =  brlib.split(format("%s",mapEnv.envswitch), "[%w%*]+")
	local spacetemp = brlib.split(format("%s",mapEnv.envswitch), "[+-]?%d+")
	local spacelist = brlib.spacesw(spacetemp)
	local listspace = brlib.swspace(spacetemp)
	local wanvlanlist = brlib.portscheck(format("%s",mapEnv.envdata), briableport)
	local IPTVvlan =  brlib.portscheck(format("%s",mapEnv.enviptv),  briableport)
	--------------------------------------By pressing one or more switchbutton---------------------------
if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
	if content["action"]=="SAVE" then
	wantemp = format("%s",mapParams.wanifname)
	lantemp = format("%s",mapParams.lanifname)
	serftemp= format("%s",mapParams.serfswport)
	lanstemp= format("%s",mapParams.lanswport)
--------------------------------------checking for which button is used-----------------------
	for i=1, #portnamelist, 1 do 
		if IPTVstates[i]~="1" then
			if content[portnamelist[i]] ~= states[i] then
			--checking on which state the button is and fill the variables with the correct values-----
				if content[portnamelist[i]] == "0" then
					 wantemp, lantemp, lanstemp, serftemp = brlib.routed(wantemp, lantemp, lanstemp, serftemp, lanvlanlist[i], wanvlanlist[i], serflanlist[i], spacelist[i], listspace[i])
				elseif content[portnamelist[i]] == "1" then
					  wantemp, lantemp, lanstemp, serftemp = brlib.briding(wantemp, lantemp, lanstemp, serftemp, lanvlanlist[i], wanvlanlist[i], serflanlist[i], spacelist[i], listspace[i])
				end
				
			end
		end
	end
	-----------------------------------end-----------------------------------------------
				
-----------------------------------------Data bridge check-------mod: 160220---------------------------
		--creating a table with entries of the wan.ifname
		states = {}
		local Port = wantemp
		words = brlib.split(Port, "[%w_]+")

		--checking the entries of the table(words)
			for h=1, briableport, 1 do
				for j=2, briableport+1, 1 do
					if words[j] == wanvlanlist[h] then
						states[h]="1"
						break
					else
						states[h]="0"
					end
				end
			end
------------------------------Checking how many ports are bridged--------------------------
--if more than 1 port is bridged than wantypetemp=bridged
--if no port is bridged than wantypetemp=""
-------------------------------------------------------------------------------------------
			for k=1, #states, 1 do
				if states[k]=="1"then
					wantypetemp="bridge"
					break
				else
					wantypetemp=""
					
				end
			end
------------------------------Checking how many ports are bridged end--------------------------
-------------------------------Wantemp if all statest are "0"---------------------------
-- Need to be done, if the wan.ifname has only one entry, then it is converted from list to string format and
-- we get a space after the ifname for ADSL, VDSL or ETH (for exampel (ETH): 'eth ')
-- if we do nit delete the space, we couldn't access to the internet
		local rep = 1
		local checker = 0
		while rep <= #states do
			if states[rep] == "0" then
				checker = checker + 1
				rep = rep + 1
			else
				break
			end
		end

		if checker == #states then
			wantemp = words[1]
		end
-----------------------------------------------end--------------------------------------------
		local words = {}
---------------------------------------------------end------------------------------------------------	
		check="1"
--------------------------sort and post the data for bridging or routed (atm only switch) on the device-----------------------
--[[ --- 160220 removed to assure 4 Bridged Ports -------
		local serf = brlib.split(serftemp, "[%w%*]+")
		local serfz = brlib.split(serftemp, "[+-]?%d+")
		serftemp = brlib.sort(serfz, serf)
		local lanf = brlib.split(lanstemp, "[%w%*]+")
		local lanfz = brlib.split(lanstemp, "[+-]?%d+")
		lanstemp = brlib.sort(lanfz, lanf)
		local lanff = brlib.split(lantemp, "[%w_]+")
		local lanffz = brlib.split(lantemp, "[+-]?%d+")
		lantemp = brlib.sort(lanffz, lanff)
]]		
		proxy.set("uci.network.interface.@wan.type",wantypetemp)
		proxy.set("uci.network.interface.@lan.ifname",lantemp)
		proxy.set("uci.network.switch_vlan.@lansw.ports",lanstemp)
		proxy.set("uci.network.switch_vlan.@datasw.ports",serftemp)
		proxy.set("uci.network.interface.@wan.ifname",wantemp)
		proxy.apply()
------------------------------------------------end---------------------------------------------------
	end
end
----------------------------------------------POST/SAVE end-------------------

--------------------------------------------Reboot------------------------------------
--Function for actioning the reboot
local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end
--Check for Reboot request in POST

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
    if action == "system_reboot" then
      return resetreboot("rpc.system.reboot", "GUI")
    end
end
---------------------------------------Reboot end----------script part also Reboot----

-----------------------------------------Data bridge check---------mod: 160220-------------------------
--First check if the Page is loaded and no POST was used
--after a POST this part is not used
--has the same function like in the POST part
if check=="0" then
states = {}

local Port = format("%s", mapParams.wanifname)
words = brlib.split(Port, "[%w_]+")

for h=1, briableport, 1 do
	for j=2, briableport+1, 1 do
		if words[j] == wanvlanlist[h] then
			states[h]="1"
			break
			else
			states[h]="0"
		end
	end
end
local words = {}
end
-------------------------------------------Data bridge check end-----------------------------------------------------------
-------------------------------IPTV check----------mod: 160220-------------------
--checking if there is any Port bridged for IPTV
--if this Port is used for IPTV it can't be bridged by enduser
--Same function like the Data bridge check
IPTVstates = {}

local IpTV = format("%s", mapTV.iptvifname)
IpTVlist = brlib.split(IpTV, "[%w_]+")

for k=1, briableport, 1 do
	for l=2, briableport+1, 1 do
		if IpTVlist[l] == IPTVvlan[k] then
			IPTVstates[k]="1"
			break
			else
			IPTVstates[k]="0"
		end
	end
end

local IpTVlist = {}
-----------------------------------------IPTV end------------------------



ngx.print( ui_helper.createHeader(T"Bridged Ports", false, true) )
ngx.print('\
<div class="modal-body update">\
	<form class="form-horizontal" method="post" action="modals/bridgeports-LAN-modal.lp">\
		\
		<fieldset id="bridgeports-LAN-tab">\
			<legend>')ngx.print(T"LAN Ports" ); ngx.print('</legend>')
		
			local infoclass = {
				alert = {
				  class = "alert-info",
				}
			  }
			  local SUB_PF_CSS = {
              alert = {
                  class = "alert-danger"
              },
          }
			
			portnum = brlib.portsort(briableport)
		if string.format("%s", mapParams.wanifname)== "" then
			ngx.print(ui_helper.createAlertBlock(T"Please connect your device to the internet to enable bridging configuration capabilities",SUB_PF_CSS))
			for i=1, #portnum, 1 do
				ngx.print{ui_helper.createLabel(portnum[i], T"Bridging not available", attributes)}
			end
		else
			ngx.print(ui_helper.createAlertBlock(T"Select the Port you want to bridge directly to the Internet", infoclass))
			for i=1, #portnum, 1 do
				if IPTVstates[i]~="1" and wanvlanlist[i]~="no bridge" then
					ngx.print{ui_helper.createSwitch(portnum[i], portnamelist[i], states[i])}
				elseif IPTVstates[i]=="1" and wanvlanlist[i]~="no bridge" then
					ngx.print{ui_helper.createLabel(portnum[i], T"Used by IPTV")}
				elseif IPTVstates[i]=="1" and wanvlanlist[i]=="no bridge" then
					ngx.print{ui_helper.createLabel(portnum[i], T"Used by IPTV")}
				elseif wanvlanlist[i]=="no bridge" then
					ngx.print{ui_helper.createLabel(portnum[i], T"Bridging not available", attributes)}
				end
			end
		end
ngx.print('\
		</fieldset>\
	</form>\
</div>\
')
ngx.print( ui_helper.createFooter() )
ngx.print('\
<script>\
function PopupRemove(){  \
      $(".popUpBG").remove();\
      $("#popUp").remove();\
      $("html, body").css({"overflow": "auto","height": "auto"});\
    }\
function PopupWarning(x){\
\
        var moveLeft = 10;\
        var moveRight = -390;\
        var moveDown = -50;')
		ngx.print('\
       $("body").append("'); ngx.print("<div class='popUpBG'></div>")
	   ngx.print('")'); ngx.print("\
       $('body').append('"); ngx.print('<div id="popUp"  class="popUp smallcard" style="width:300px;">'); ngx.print(ui_helper.createCardHeader(T"Warning!", nil, nil, nil)); ngx.print('<div id="Poptxt" class="content"></div>'); ngx.print("')")
	   ngx.print('\
       $("#popUp").append("'); ngx.print("<div id='cstyle' style='position:absolute; left:50%; margin-left:-84px;bottom:15px; '></div>")
	   ngx.print('")\
	   $("#cstyle").append("'); ngx.print("<div class='btn btn-large' id='csoff'>Cancel</div>")
	   ngx.print('")\
       $("#cstyle").append("'); ngx.print("<div class='btn btn-primary btn-large' style='margin-left:3px;' id='confwarn'>Confirm</div>")
	   ngx.print('")\
\
       $("#Poptxt").html(x);\
       $d = $("#popUp");\
       var pagewidth = $("body").width();\
       var thiswidth = $d.width();\
       var center = (pagewidth / 2) - (thiswidth / 2);\
       var width = window.innerWidth || document.documentElement.clientWidth;\
       $d.css({"left": center, "height": "300px", "margin": "0px"}).appendTo("body").slideDown("fast");\
       $("html, body").css({"overflow": "hidden","height": "100%"});\
\
	$("#confwarn").click(function(){\
	PopupRemove();\
	});\
	$("#csoff").click(function(){\
          var a=$(".modal form").attr("action");\
		  PopupRemove();\
		  tch.refreshModal(a);\
		  });\
    }\
\
$(document).ready(function() {\
\
    $(".switch").click(function(){\
	var b = $(this).children("input:last-child").attr("value")\
	if(b == "0"){');
	------------CQ:-------start 22.11.2015/05.02.2016-----------------------------------------------
if string.match(mapParams.wanifname, "eth4") then

	ngx.print('\
	PopupWarning("'); ngx.print(T'Please make sure, that you are not connected to this Ethernet Port<br><br>Please press the confirm button, if you want to proceed bridging this port');
	ngx.print('")\
	$d = $("#popUp");\
    $d.css({"height": "230px"}).appendTo("body").slideDown("fast");')
   
else
	ngx.print('\
	PopupWarning("'); ngx.print(T'Please make sure, that you are not connected to this Ethernet Port<br><br>Please make sure, that no Settop Box is connected to this Ethernet Port<br><br>Please press the confirm button, if you want to proceed bridging this port');
	ngx.print('")\
	')
end
	---------------------end 22.11.2015----------------------------------------------------------------
	ngx.print('\
	}\
	});\
});\
</script>\
')

