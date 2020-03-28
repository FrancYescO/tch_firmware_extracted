local intl = require("web.intl")
local function log_gettext_error(msg)
	ngx.log(ngx.NOTICE, msg)
end

local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext

gettext.textdomain('webui-mobiled')

local M = {}

local params = {
    modal_title = T"Mobile",
    card_title = T"Mobile"
}

function M.get_params()
    return params
end

return M
