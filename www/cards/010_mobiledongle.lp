<%
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-mobiledongle')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local format, find, sub = string.format, string.find, string.sub
local session = ngx.ctx.session
if session:hasAccess("/modals/mobiledongle-information-modal.lp") then



local content = {
	interface_enabled = "uci.mobiledongle.config.enabled",
	state		= "uci.mobiledongle.info.state",
	--network		= "uci.mobiledongle.parm.network",
}

local mobiledongle_state_map = {
	["DEVICE_DISCONNECTED"]		= T"Disconnected",
	["DEVICE_OFFLINE"]			= T"Disconnected",
	["NO_NETWORK_CONNECTED"]	= T"Disconnected",
	["NETWORK_CONNECTED"]		= T"Registered",
	["DATA_SESSION_ACTIVE"]		= T"Connected",
	["PIN_REQUIRED"] 			= T"Enter PIN",
	["PUK_REQUIRED"] 			= T"Enter PUK",
	["APN_REQUIRED"] 			= T"Enter APN",
	["NO_SIM"]					= T"Insert SIM",
	["SIM_ERROR"]				= T"SIM error",
	["DISABLED"] 				= T"Disabled",
	["RELOADING"] 				= T"Reloading",
	["PPP_SELECT_REQUIRED"] 	= T"PPP Selection required",
	["PPP_AUTH_REQUIRED"] 		= T"PPP Authentication required",
	["UNKNOWN"] 				= T"Disconnected",
}

local mobiledongle_enabled = "0"
local mobiledongle_enabled_string = T"Mobile disabled"
local mobiledongle_state = mobiledongle_state_map["UNKNOWN"]
--local mobiledongle_network
local wwan_ip_rpc           

content_helper.getExactContent(content)
if content ~= nil then
	for k,v in pairs(content) do
	   if v then
		cv = format("%s",v)
		--ngx.log(ngx.ERR, "content k=" .. k .. " v=" .. cv)
		if (k == "state") then
			mobiledongle_state = mobiledongle_state_map[cv]
			if not mobiledongle_state then
			  mobiledongle_state = T"Disconnected"
			end
		elseif  (k == "interface_enabled") then
			mobiledongle_enabled = cv
			if (cv == "1") then
				mobiledongle_enabled_string = T"Mobile enabled"
			end
--[[
		elseif  (k == "network") then
      		mobiledongle_network = cv 
      		mobiledongle_network = "wwan" --overrule due wansensing only 1 intf
]]
		end
		  
	   end
	end 
end

autoRefresh=nil

-- Display the card but do not give access if not allowed
local switchName = nil
local modalPath = nil

-- switchName = "interface_enabled"

local session = ngx.ctx.session
if session:hasAccess("/modals/mobiledongle-information-modal.lp") then
    switchName = "interface_enabled"
    modalPath = "/modals/mobiledongle-information-modal.lp"
end

--[[local result, val
local mobiledongle_wwan_up= "0"
result = proxy.get("rpc.network.interface." .. content["network"] .. ".")
if result ~= nil then
	_, val = next(result)
	if val ~= nil then
		if val.value == "1" then
			mobiledongle_wwan_up = "DATA_SESSION_ACTIVE"
		end
	end
	ngx.log(ngx.ERR, "wwan_up=" .. mobiledongle_wwan_up)
end
]]
wwan_ip_rpc = {
	wwan_ipaddr = "rpc.network.interface.@wwan.ipaddr",
}
content_helper.getExactContent(wwan_ip_rpc)
        
%>


<div class="span3">
	<div class="smallcard">
		<%=ui_helper.createCardHeader(T"Mobile 3G/4G", modalPath, nil, nil) %>
		<div class="content">
			<%
				if  mobiledongle_state == T"Disconnected" then
				  mobiledongle_enabled_string = mobiledongle_state			  
				  mobiledongle_enabled = '0'
				end
				local html = {
					ui_helper.createSimpleLight(mobiledongle_enabled, mobiledongle_enabled_string, { light = { id =  "MobileDongle_Status" }, span = { id =  "MobileDongle_LED_Status" } })
				}
				if mobiledongle_enabled == "1" then
					tinsert(html, format('<p class="subinfos">' .. T"State: <strong>%s</strong></br>", mobiledongle_state))
					if wwan_ip_rpc["wwan_ipaddr"] ~= nil and wwan_ip_rpc["wwan_ipaddr"] ~= "" then
							tinsert(html, format(T"IPv4: <strong>%s</strong></br>", wwan_ip_rpc["wwan_ipaddr"]))
					else
						tinsert(html, T"IPv4: <strong>None</strong></br>")
					end
					tinsert(html, "</p>")
				end
				ngx.print(html)
			%>
		</div>
	</div>
</div>

<%
end
%>
