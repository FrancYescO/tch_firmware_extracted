
local xdslctl = require('transformer.shared.xdslctl')

local function xdslctl_cmd (arg)
  if not arg[1] then
    print("missing argument")
    return 1
  end

  local cmd = arg[1]
  local cmd_handler = xdslctl[cmd]

  if cmd_handler == nil then
    print("invalid command: " .. cmd)
    return 1
  end

  table.remove(arg, 1)
  local output = cmd_handler(unpack(arg))

  print(output)
end

local rv = xdslctl_cmd(arg)
os.exit(rv)

