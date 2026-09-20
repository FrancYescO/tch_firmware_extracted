--pretranslated: do not change this file
 gettext.textdomain('webui-core')   ngx.print('\
<ul class="nav nav-list">\
');  
local ipairs, string, table = ipairs, string, table



local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local mapParams = {
					hardware_version = "uci.env.rip.board_mnemonic",
					}
content_helper.getExactContent(mapParams)

local wifi = {}
for i, v in ipairs(proxy.get("uci.wireless.wifi-iface.")) do
	if wifi[#wifi] ~= string.match(v.path, "@([%w_]+)%.") then
		wifi[#wifi+1] = string.match(v.path, "@([%w_]+)%.")
	end
end

local mapWifi = {}
for i,v in ipairs(wifi) do
	local base_path = "uci.wireless.wifi-iface.@"..tostring(v)
	mapWifi["device"..i]=tostring(base_path..".device")
end
content_helper.getExactContent(mapWifi)

local check = "0"
for i=1, #wifi, 1 do
	if string.format("%s", mapWifi["device"..i]) == "radio_5G" then
		check = "1"
		break
	end
end


local items = {
    T"Here, you can do the following actions",
    {"basicview-accesscode-modal.lp", T"1. Choose a new password for my router (Access Key)"},
    {"basicview-wifissid-modal.lp", T"2. Manage my wireless network (Wi-Fi)"},
    {
        {"basicview-wifissid-modal.lp?submenu=yes", T"A. Choose a name for my wireless network (SSID)"},
        {"basicview-wifipsk-modal.lp", T"B. Choose a new password for my wireless network"},
    },
    {"basicview-wifiguest-modal.lp", T"3. Manage a seperate wireless access for my family and friends (Guest Access)"},
}


	
if  check == "1" then
	table.insert(items, 3, T"2,4GHz Wireless Network")
	items[#items+1] = T"5GHz Wireless Network"
	items[#items+1] = {"basicview-wifissid5GHz-modal.lp", T"4. Manage my wireless network (Wi-Fi)"}
	items[#items+1] ={
						{"basicview-wifissid5GHz-modal.lp?submenu=yes", T"A. Choose a name for my wireless network (SSID)"},
						{"basicview-wifipsk5GHz-modal.lp", T"B. Choose a new password for my wireless network"},
					 }
	if string.format("%s", mapParams.hardware_version)~="VANT-W" then
		items[#items+1] = {"basicview-wifiguest5GHz-modal.lp", T"5. Manage a seperate wireless access for my family and friends (Guest Access)"}
	end		
end


local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

local function createListItem(item)
    local active = ""
    if uri == ("/modals/" .. item[1]) then
        active = "active"
    end
    return string.format('<li class="%s"><a href="#" data-remote="/modals/%s">%s</a></li>', active, item[1], item[2])
end

local html = {}
for _,v in ipairs(items) do
    if type(v) == "string" then
        html[#html+1] = string.format('<li class="nav-header">%s</a></li>',v)
    elseif type(v[1]) == "string" then
        html[#html+1] = createListItem(v)
    elseif type(v[1]) == "table" then
        html[#html+1] = '<ul class="nav nav-list">'
        for _,vv in ipairs(v) do
            html[#html+1] = createListItem(vv)
        end
        html[#html+1] = '</ul>'
    end
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 