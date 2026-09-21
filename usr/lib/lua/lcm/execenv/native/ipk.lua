local require, ipairs = require, ipairs

local digest = require("tch.crypto.digest")
local verify, SHA256 = digest.verify, digest.SHA256
local opkg_package_module = require("lcm.execenv.native.opkg_package")
local execute_cmd = require("lcm.execenv.native.common").execute_cmd

local Ipk = {}
Ipk.__index = Ipk

local expected_ipk_files = {
  ["debian-binary"] = true,
  ["control.tar.gz"] = true,
  ["data.tar.gz"] = true,
  ["checksums"] = true,
  ["signature.sig"] = true,
}

local function check_content_ipk(self)
  local ipk_path = self.ipk_path
  local tar_content = execute_cmd("tar -tzf " .. ipk_path)
  local expected = 5
  for _, file in ipairs(tar_content) do
    local stripped_file = file
    if file:match("^%./") then
      stripped_file = file:match("^%./(.*)$")
    end
    if not expected_ipk_files[stripped_file] then
      return false
    end
    expected = expected - 1
    self.files[stripped_file] = file
  end
  if expected == 0 then
    return true
  end
  return false
end

local allowed_control_files = {
  [""] = true,  -- control.tar.gz contains an entry "./" which after stripping is just empty string
  ["control"] = true,
  ["preinst"] = true,
  ["postinst"] = true,
  ["prerm"] = true,
  ["postrm"] = true,
  ["conffiles"] = true,
}

local function check_content_control_file(self)
  local ipk_path = self.ipk_path
  local files = self.files
  local cmd = "tar -xzOf " .. ipk_path .. " " .. files["control.tar.gz"] .. " | tar -xzOf - " .. files["control"]
  local control_file_content = execute_cmd(cmd)
  local opkg_package = opkg_package_module.new_package(control_file_content)
  if opkg_package then
    self.opkg_package = opkg_package
    return true
  end
  return false
end

-- This function should only be called if we are sure control.tar.gz is available
local function check_content_control_tar(self)
  local ipk_path = self.ipk_path
  local cmd = "tar -xzOf " .. ipk_path .. " " .. self.files["control.tar.gz"] .. " | tar -tzf -"
  local control_content = execute_cmd(cmd)
  local mandatory = false
  for _, file in ipairs(control_content) do
    local stripped_file = file
    if file:match("^%./") then
      stripped_file = file:match("^%./(.*)$")
    end
    if not allowed_control_files[stripped_file] then
      return false
    end
    if stripped_file == "control" then
      mandatory = true
    end
    self.files[stripped_file] = file
  end
  if not mandatory then
    return false
  end
  return check_content_control_file(self)
end

local function check_checksums(self)
  local ipk_path = self.ipk_path
  local checksums = "/tmp/checksums"
  local cmd = "tar -xzOf " .. ipk_path .. " " .. self.files["control.tar.gz"] .. " | sha256sum"
  local control_sha256sum = execute_cmd(cmd)
  cmd = "tar -xzOf " .. ipk_path .. " " .. self.files["data.tar.gz"] .. " | sha256sum"
  local data_sha256sum = execute_cmd(cmd)
  control_sha256sum = control_sha256sum[1]:match("^([%S]+)")
  data_sha256sum = data_sha256sum[1]:match("^([%S]+)")
  for line in io.lines(checksums) do
    if line:match("control.tar.gz") then
      local verified_sha = line:match("^([%S]+)")
      if verified_sha ~= control_sha256sum then
        return false
      end
    elseif line:match("data.tar.gz") then
      local verified_sha = line:match("^([%S]+)")
      if verified_sha ~= data_sha256sum then
        return false
      end
    end
  end
  return true
end

local function check_signature_ipk(self)
  local pubkey = "/etc/public.pem"
  local signature = "/tmp/signature.sig"
  local checksums = "/tmp/checksums"
  local ipk_path = self.ipk_path
  -- First we extract signature.sig and checksums to /tmp
  execute_cmd("tar -xzf " .. ipk_path .. " -C /tmp " .. self.files["checksums"] .. " " .. self.files["signature.sig"])
  if verify(SHA256, pubkey, signature, checksums) and check_checksums(self) then
    return true
  end
  return false
end

function Ipk:verify()
  if self.verified then
    -- Already verified this package
    return self.verified
  end
  local verified = true
  verified = verified and check_content_ipk(self)
  verified = verified and check_signature_ipk(self)
  verified = verified and check_content_control_tar(self)
  self.verified = verified
  return verified
end

-- Prerequisite: Verify needs to be called first and succeeded.
function Ipk:query(field_name)
  if not self:verify() then
    return nil, "This package failed verification and can not be queried"
  end
  if self.opkg_package[field_name] then
    return self.opkg_package[field_name]
  end
  return nil, "Unknown field name"
end

local M = {}

M.new = function(ipk_path)
  local self = {
    ipk_path = ipk_path,
    files = {},
  }
  return setmetatable(self, Ipk)
end

return M