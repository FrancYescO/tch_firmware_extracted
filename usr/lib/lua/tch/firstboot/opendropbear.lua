
local uci = require('uci')
local cursor = uci.cursor()
local bit = require('bit')

local function enable_ssh_intf(intf)
  local all = (intf == nil)
  local cfg = cursor:get_all("dropbear") or {}
  for section, dbcfg in pairs(cfg) do
    if all or -- all interfaces must be updated
       dbcfg.Interface == nil or -- if dropbear section has no Interface, then update it
       dbcfg.Interface == intf -- simply update a matching interface
    then
      cursor:set("dropbear", section, "enable", 1)
      -- Disable root login for this dropbear section.
      if cursor:get("dropbear", section, "Interface") ~= "lan" then
         cursor:set("dropbear", section, "RootLogin", 0)
      end
    end
  end
  cursor:commit("dropbear")
end

local function enable_dropbear()
  local cfg = cursor:get_all("clash") or {}
  for _, v in pairs(cfg) do
    if v['.type'] == "user" then
      if v.ssh == "1" then
        enable_ssh_intf()
      else
        for _, intf in pairs(v.ssh_interface or {}) do
          enable_ssh_intf(intf)
        end
      end
    end
  end
end

local function is_closed_build()
  local cfg = cursor:get_all("version") or {}
  local version = next(cfg)
  version = cfg[version]
  if version then
    local mask = tonumber(version.mask, 16)
    local closed = bit.band(mask, 0x10000)
    return closed == 0 -- if specified bit not set: closed build
  end
end

local function setup()
  if is_closed_build() then
    enable_dropbear()
  end
end

setup()
