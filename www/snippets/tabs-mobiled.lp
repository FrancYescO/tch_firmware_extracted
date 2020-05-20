--pretranslated: do not change this file
 
local table = table
local utils = require("web.lte-utils")
local device_capabilities = utils.getContent("rpc.mobiled.device.@1.capabilities.")

local ngx = ngx

gettext.textdomain('webui-mobiled')

local ui_helper = require("web.ui_helper")
local ipairs, string = ipairs, string
local tinsert = table.insert

local items = {
	{"lte-modal.lp", T"Configuration"},
	{"lte-sim.lp", T"SIM"},
	{"lte-doctor.lp", T"Diagnostics"},
	{"lte-profiles.lp", T"Profiles"},
	{"lte-sms.lp", T"SMS"}
}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
	uri = uri .. "?" .. ngx.var.args
end

local accessTabs = {}
local session = ngx.ctx.session
for _,v in pairs(items) do
	if session:hasAccess("/modals/" .. v[1]) then
		accessTabs[#accessTabs+1] = v
	end
end

local tabs = {}
for _,v in ipairs(accessTabs) do
	local active = nil
	if uri == ("/modals/" .. v[1]) then
		active = "active"
	end

	local tab = {
		desc = v[2],
		active = active,
		target = "/modals/" .. v[1]
	}
	tinsert(tabs, tab)
end

ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
'); 