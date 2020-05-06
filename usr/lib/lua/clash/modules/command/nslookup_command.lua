      -- Functions made available from the CLI environment
local print, register, unregister, helper =
      print, register, unregister, helper

local cmd_assist = helper("command")

local cmd_name = "nslookup"
local usage_msg = [[
  Query the nameserver for the IP address of the given HOST
    optionally using a specified DNS server

    <host>   (string) Look up information for host using the
              current default server or using server, if specified
    <server> (string default "") Use specified server
]]

local function nslookup_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the nslookup command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = nslookup_function,
}

local M = {}

M.name = command.name

M.init = function()
  register(command)
end

M.destroy = function()
  unregister(command)
end

return M
