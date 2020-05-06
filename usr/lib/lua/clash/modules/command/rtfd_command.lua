      -- Functions made available from the CLI environment
local print, register, unregister, helper =
      print, register, unregister, helper

local cmd_assist = helper("command")

local cmd_name = "rtfd"
local usage_msg = [[
  Perform return-to-factory-defaults of gateway
    --soft  Perform 'soft' return-to-factory-defaults, preserving settings
            which are configured to be so.
]]

local function rtfd_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the rtfd command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = rtfd_function,
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
