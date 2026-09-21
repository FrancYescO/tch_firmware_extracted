-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")

local post_data = ngx.req.get_post_args()
if post_data.action == "get" and post_data.interface then
	local dataUsage = utils.getContent(string.format("rpc.datausage.interface.%s.", post_data.interface))

	local buffer = {}
	local ret = json.encode (dataUsage, { indent = false, buffer = buffer })
	if ret then
		utils.sendResponse(buffer)
	end
elseif post_data.action == "reset" and post_data.interface then
	proxy.set(string.format("rpc.datausage.interface.%s.reset", post_data.interface), "1")
end

utils.sendResponse("{}")
