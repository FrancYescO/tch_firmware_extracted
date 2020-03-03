
local require = require
local ipairs = ipairs
local untaint = string.untaint

local ngx = ngx
local dm = require 'datamodel'

local M = {}

local function load_api_config()
	local config = {}
	local data = dm.get("uci.fastweb.api.") or {}
	for _, param in ipairs(data) do
		local name = param.path:match("@([^.]+)%.")
		if name then
			local obj = config[name]
			if not obj then
				obj = {}
				config[name] = obj
				config[#config+1] = obj
			end
			obj[param.param] = untaint(param.value)
		end
	end
	return config
end

local config

local function get_auth_code()
	local port = untaint(ngx.var.server_port)
	config = config or load_api_config()
	for _, cfg in ipairs(config) do
		if cfg.port == port then
			local required = cfg.auth_required == "1"
			if required and cfg.auth=="" then
				-- no auth code set
				return
			end
			return cfg.auth
		end
	end
end

local function authorized()
	local auth_code = get_auth_code()
	if not auth_code then
		-- no access defined. deny it
		return
	elseif auth_code~="" then
		local headers = ngx.req.get_headers()
		local auth_hdr = headers['Authorization']
		local auth = auth_hdr and auth_hdr:match("^Basic (.*)$") or ""
		return auth==auth_code
	end
	-- no auth code set, this means it is not required and access is always
	-- allowed.
	return true
end

function M.auth()
	if not authorized() then
		ngx.status = 401
		ngx.header["WWW-Authenticate"] = 'Basic realm="api"'
		ngx.exit(ngx.HTTP_OK)
	end
end

function M.sessionRequired()
	local port = untaint(ngx.var.server_port)
	config = config or load_api_config()
	for _, cfg in ipairs(config) do
		if cfg.port == port then
			return cfg.auth_required ~= "1"
		end
	end
	-- no auth code set, this means it is always session required
	return true
end

function M.reload()
	if ngx.var.server_addr == "127.0.0.1" then
		config = nil
		ngx.say("api config set for reload")
	else
		ngx.exit(ngx.HTTP_NOT_FOUND)
	end
end

return M
