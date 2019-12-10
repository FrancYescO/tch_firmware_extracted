--pretranslated: do not change this file
 
local utils = require("web.lte-utils")
local device_capabilities = utils.getContent("rpc.mobiled.device.@1.capabilities.")

gettext.textdomain('webui-mobiled')

local ui_helper = require("web.ui_helper")

local tinsert = table.insert

local items = {
	{"lte-modal.lp", T"Configuration"},
	{"lte-sim.lp", T"SIM"},
	{"lte-doctor.lp", T"LTE Doctor"},
	{"lte-profiles.lp", T"Profiles"}
}

-- #NG-93140 only show in case session has access (Engineer in case of TI)
if device_capabilities.sms_reading == "true" and ngx.ctx.session:hasAccess("/ajax/sms.lua") then
	table.insert(items, {"lte-sms.lp", T"SMS"})
end

local tabs = {}
local session = ngx.ctx.session
for _, tab in ipairs(items) do
    if session:hasAccess("/modals/" .. tab[1]) then
        local active
        if ngx.var.uri == "/modals/" .. tab[1] then
            active = "active"
        end

        local tab = {
            desc = tab[2],
            active = active,
            target = "/modals/" .. tab[1]
        }
        tinsert(tabs, tab)
    end
end

ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
'); 