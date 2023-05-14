local json = require("dkjson")
local uci = require 'uci'
local ngx = ngx
local M = {}


local filter_command = nil

--- Read UCI debug configuration for webAPI 
--- UCI configuration for webservice: 
--- webservice.debugreqresp list of commands separated by "space" or "*" for all commands
-- @param: None
-- @return: _debug, _filter
local function _read_uci_configure()
  local cursor = uci.cursor()
  local _commands = cursor:get("webservice", "debug", "debugreqresp") or nil
  if _commands and type(_commands) == "table" then
    filter_command = {}
    --- get command filter
    for i,v in ipairs(_commands) do
        filter_command[v] = '1'
    end
  end
end

local function _init_module()
  _read_uci_configure()
   _init_module=function() end
end
--- log module

function M.logJson(request)
  if not request then
    return
  end
  _init_module()
  if not filter_command then
    return
  end
  if filter_command['*'] or filter_command[request.command] then
    local str = json.encode (request, { indent = true })
    ngx.log(ngx.DEBUG, "Data: " .. str)
  end
end


return M
