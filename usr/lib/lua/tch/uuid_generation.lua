---
-- UUID generation as described in RFC4122
--
-- @module tch.uuid_generation
-- @usage
-- local generation = require("tch.uuid_generation")
-- local function foo()
--   local namespace = "12345678-90ab-cdef-1234-567890abcdef"
--   local name = "Technicolor"
--   local use_sha1 = true
--   local uuid = generation.name_based(namespace, name, use_sha1)
-- end

local bit = require("bit")
local crypto = require("tch.crypto")
local bor, band, tohex = bit.bor, bit.band, bit.tohex
local format, byte, char = string.format, string.byte, string.char
local sha1, md5 = crypto.sha1, crypto.md5
local tonumber = tonumber

local M = {}

M.name_based = function(namespace, name, use_sha1)
  local canonical_namespace = ""
  namespace = namespace:gsub("%-", "")
  namespace:gsub("..", function(cc)
    canonical_namespace = canonical_namespace .. char(tonumber(cc,16))
  end)

  local tohash = canonical_namespace..name
  local hash
  if use_sha1 then
    hash = sha1(tohash)
  else
    hash = md5(tohash)
  end

  local octets = {}
  hash:gsub("..", function (cc)
    if #octets >= 16 then
      return
    end
    octets[#octets + 1] = tonumber(cc, 16)
  end)

  -- put version bits
  if use_sha1 then
    octets[7] = bor(band(octets[7], 0x0F), 0x50)
  else
    octets[7] = bor(band(octets[7], 0x0F), 0x30)
  end

  -- put variant bits
  octets[9] = bor(band(octets[9], 0x3F), 0x80)

  local result = ""
  -- generate uuid byte per byte
  for i = 1, #octets, 1 do
    result = result .. tohex(octets[i], 2)
    if (i == 4 or i == 6 or i == 8 or i == 10) then
      result = result .. "-"
    end
  end

  return result
end

return M
