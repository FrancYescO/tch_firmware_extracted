--NG-70591 GUI : Unable to configure infinite lease time (-1) from GUI but data model allows
local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

gettext.textdomain('webui-tim')

local M = {}

function M.ethtrans()
	setlanguage()
    return {
				eth_infinit = T"infinite"
			}
end

function M.getValidateNumberInRange(min, max)
	local helptext = T"Input must be a number"
    if min and max then
        helptext = string.format(T"Input must be a number between %d and %d included", min, max)
    elseif not min and not max then
        helptext = T"Input must be a number"
    elseif not min then
        helptext = string.format(T"Input must be a number smaller than %d included", max)
    elseif not max then
        helptext = string.format(T"Input must be a number greater than %d included", min)
    end

	return function(value)
        local num = tonumber(value)
		local isNotNumber = string.find(value, "[^%d]+") 
		if isNotNumber then
			return nil, helptext
		end
        if not num then
            return nil, helptext
        end
        if min and num < min then
            return nil, helptext
        end
        if max and num > max then
            return nil, helptext
        end
        return true
	end
end

return M
