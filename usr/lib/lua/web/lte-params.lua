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
