      -- Functions made available from the CLI environment
local print, register, unregister, helper =
      print, register, unregister, helper

local cmd_assist = helper("command")

local cmd_name = "top"
local usage_msg = [[
  Display Linux tasks
]]

local function top_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Output only one iteration
  args["-n"] = "1"
  -- In batch mode to avoid top clearing terminal; argument value '1' is a dummy
  args["-b"] = "1"

  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the top command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = top_function,
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
