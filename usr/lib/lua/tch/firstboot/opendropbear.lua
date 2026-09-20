
local uci = require('uci')
local cursor = uci.cursor()
local bit = require('bit')

local function disable_ssh_service()
  local cfg = cursor:get_all("dropbear") or {}
  for section, dbcfg in pairs(cfg) do
    cursor:set("dropbear", section, "enable", 0)
    -- Disable root login for this dropbear section.
    -- This is an extra level of security, additional to setting root shell to false
    cursor:set("dropbear", section, "RootLogin", 0)
  end
  cursor:commit("dropbear")

  -- Set SSHMode as None for Vodafone by Default on Closed Builds
  cursor:set("firewall", "Allow_SSH_Vodafone_lan", "target", "DROP")
  cursor:set("firewall", "Allow_SSH_Vodafone_wan", "target", "DROP")
  cursor:commit("firewall")
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
    disable_ssh_service()
  end
end

setup()
