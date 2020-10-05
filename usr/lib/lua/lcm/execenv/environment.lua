local require = require
local setmetatable = setmetatable

local M = {}

local lxc_pid = require "lcm.execenv.native.lxc_pid"

local Environment = {}
Environment.__index = Environment

function Environment:nativePath(path)
  return path
end

function Environment:nativeEssential()
  return false
end

function Environment:exec_args(exe, argv)
  return exe, argv
end

function Environment:nativePID(pid)
  return pid
end


local LXC = setmetatable({}, Environment)
LXC.__index = LXC

function LXC:nativePath(path)
  local sep = path:match("^/") and "" or "/"
  return "/srv/lxc/" .. self.name .. "/rootfs" .. sep .. path
end

function LXC:nativeEssential(package)
  return package.Essential == "yes"
end

function LXC:exec_args(exe, argv)
  local args = {"-n", self.name, "--", exe}
  for _, arg in ipairs(argv) do
    args[#args+1] = arg
  end
  return "/usr/bin/lxc-attach", args
end

function LXC:nativePID(pid)
  return lxc_pid.host_pid(self.name, pid)
end

local function newEnvironment(ee_type, name, _tp)
  _tp = _tp or Environment
  return setmetatable({
    ee_type = ee_type,
    name = name,
  }, _tp)
end

function M.Native(ee_type, name)
  return newEnvironment(ee_type, name)
end

function M.LXC(ee_type, name)
  return newEnvironment(ee_type, name, LXC)
end

return M