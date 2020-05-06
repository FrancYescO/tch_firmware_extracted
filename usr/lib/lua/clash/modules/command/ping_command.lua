      -- Functions made available from the CLI environment
local print, register, unregister, helper =
      print, register, unregister, helper

local cmd_assist = helper("command")

local cmd_name = "ping"
local usage_msg = [[
  Send ICMP ECHO_REQUEST to network hosts
    -q  Quiet, only displays output at start and when finished
    -c (string default 5) Only sent count pings
    -s (string default 56) Send SIZE data bytes in packets
    -W (string default 10) Seconds to wait for the first response
    -w (string default 9999) Seconds until ping exits (default:infinite)
    <host> (string) Host to ping
]]

local function ps_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the get command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ps_function,
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
