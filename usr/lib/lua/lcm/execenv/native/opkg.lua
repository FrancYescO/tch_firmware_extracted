local opkg_package_module = require("lcm.execenv.native.opkg_package")
local lines, popen = io.lines, io.popen
local ipairs = ipairs
local concat = table.concat

local control_extension = ".control"

local Opkg = {}
Opkg.__index = Opkg

local function get_status_paragraphs(self)
  local paragraph
  local paragraphs = {}
  for line in lines(self.status_file_path) do
    if not line:match("^%s*$") then
      if not paragraph then
        paragraph = {}
      end
      paragraph[#paragraph + 1] = line
    else
      if paragraph then
        paragraphs[#paragraphs + 1] = paragraph
        paragraph = nil
      end
    end
  end
  if paragraph then
    paragraphs[#paragraphs + 1] = paragraph
  end
  return paragraphs
end

function Opkg:list()
  local package_info_path = self.package_info_path
  local packages = {}
  for _, paragraph in ipairs(get_status_paragraphs(self)) do
    local opkg_package = opkg_package_module.new_package(paragraph)
    -- TODO catch error and do something with it
    local control_filename = package_info_path .. opkg_package["Package"] .. control_extension
    local control_file = io.open(control_filename, "r")
    if control_file then
      control_file:close()
      opkg_package_module.update_package(opkg_package, control_filename)
    end
    packages[#packages + 1] = opkg_package
  end
  return packages
end

local function run_cmd(cmd)
  local f = popen(cmd)
  local output = {}
  for line in f:lines() do
    output[#output + 1] = line
  end
  f:close()
  if #output > 0 then
    return nil, table.concat(output, "\n")
  end
  return true
end

local function opkg_action(self, action, info)
  local exec_cmd, argv = self.env:exec_args("/bin/opkg", {
    "--nodeps",
    "--verbosity=0",
    "--offline-root="..self.install_root,
    action,
    info
  })

  return run_cmd(exec_cmd.." "..concat(argv, " "))
end

function Opkg:install(ipk)
  return opkg_action(self, "install", ipk.ipk_path)
end

function Opkg:uninstall(name)
  return opkg_action(self, "remove", name)
end

local M = {}

M.new = function(install_root, environment)
  local self = {
    install_root = install_root,
    package_info_path = environment:nativePath(install_root .. "usr/lib/opkg/info/"),
    status_file_path = environment:nativePath(install_root .. "usr/lib/opkg/status"),
    env = environment
  }
  return setmetatable(self, Opkg)
end

return M