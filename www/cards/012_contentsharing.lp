<%
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local attributes = { light = { } ,span = { class = "span4" } }
local content_helper = require("web.content_helper")
local format, find, sub = string.format, string.find, string.sub
local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/contentsharing-modal.lp") then
    modalPath = "/modals/contentsharing-modal.lp"
end
local content = {}

-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "r")
  if file_found==nil then
    return false
  else
    return true
  end
end

local samba_available = file_check("/etc/init.d/samba")
if samba_available then
	local sambaMapParams = {
		samba_enabled		= "uci.samba.samba.enabled",
		samba_name			= "uci.samba.samba.name",
	}
    for k,v in pairs(sambaMapParams) do
        content[k] = v
    end
end

local dlna_available = file_check("/etc/init.d/minidlna")
if dlna_available then
	local dlnaMapParams = {
		dlna_enabled	= "uci.minidlna.config.enabled",
		dlna_name		= "uci.minidlna.config.friendly_name",
	}
    for k,v in pairs(dlnaMapParams) do
        content[k] = v
    end
end
if samba_available or dlna_available then
	content_helper.getExactContent(content)
end

local sambastate, dlnastate
if samba_available then
	if content["samba_enabled"] == "1" then
		sambastate = T"Samba enabled"
	else
		sambastate = T"Samba disabled"
	end
end
if dlna_available then
	if content["dlna_enabled"] == "1" then
		dlnastate = T"DLNA enabled"
	else
		dlnastate = T"DLNA disabled"
	end
end
local usb_sys_path = "sys.usb.device."
local usb_sys_content = content_helper.getMatchedContent(usb_sys_path)

local usbtab = {}
for i, v in ipairs(usb_sys_content) do
	local basepath = string.match(v["basepath"], "sys%.usb%.device%.([^%.]+)")
	usb_interface = content_helper.getMatchedContent("sys.usb.device."..basepath..".interface.")
	local check = 0
	for x,y in ipairs(usb_interface) do
		if y["bInterfaceClassText"] == "Printer" then
			check = 1
		end
	end
	if check == 0 then
		local port = string.sub(v["path"],#v["path"])
		usbtab["usb"..port] = {value=T"USB Port"..port..": "..v["product"], usbcon = "green"}
	end
end
%>


<div class="span3">
	<div class="smallcard">
		<%=ui_helper.createCardHeader(T"Content Sharing", modalPath, nil, nil) %>
		<div class="content">
			<%
				local html = {}
				if samba_available then
					attributes.light.id = "Samba_Enabled_Led"
					attributes.span.id = "Samba_Enabled"
					tinsert(html, ui_helper.createSimpleLight(content["samba_enabled"], sambastate, attributes))
				end
				if dlna_available then
					attributes.light.id = "Dlna_Enabled_Led"
					attributes.span.id = "Dlna_Enabled"
					tinsert(html, ui_helper.createSimpleLight(content["dlna_enabled"], dlnastate, attributes))
				end
				for i,v in pairs(usbtab) do
					tinsert(html, ui_helper.createSimpleLight(nil, v.value, { light = { class = v.usbcon } }))
				end
				ngx.print(html)
			%>
		</div>
	</div>
</div>

