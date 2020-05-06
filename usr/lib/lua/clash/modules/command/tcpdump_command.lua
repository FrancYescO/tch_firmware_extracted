      -- Functions made available from the CLI environment
local print, register, unregister, helper =
      print, register, unregister, helper

local cmd_assist = helper("command")

local cmd_name = "tcpdump"
local usage_msg = [[
  Dump traffic on a network
    -i (string) Listen on interface
    -s (string default 65535) Snarf snaplen bytes of data from each packet rather than the
        default of 65535 bytes
    -v  When parsing and printing, produce (slightly more) verbose output
    -n  Don't convert addresses to names
    -S  Print absolute, rather than relative, TCP sequence numbers
    <expression> (string default "") Selects which packets will be dumped.  If no expression is given,
        all packets on the net will be dumped. Otherwise, only packets for which
        expression is `true' will be dumped. Expression must be quoted.
]]

local function tcpdump_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the tcpdump command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = tcpdump_function,
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
