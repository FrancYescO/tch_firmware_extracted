--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

---
-- A module that contains the verification logic for a URL.
--
-- @module modules.verifier.URL

local type, error = type, error

local match = string.match

local cli_input = require("verifier.cli_input")
-- TODO create an explicit string type verifier.

local function raise_error()
  error("Malformed URL provided")
end

-- Common URL schemas we may expect.
local schemas = {
  ["http"]  = 1,
  ["https"] = 1,
  ["ftp"]   = 1,
  ["ftps"]  = 1,
}

--- Verify if the given input is a valid URL.
-- A URL has to be a string with schema `http`, `https`, `ftp` or `ftps`
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error Not a string.
-- @error No valid schema.
-- @error Malformed URL.
--
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)

  if type(input) ~= "string" then
    raise_error()
  else
    -- Expected: `schema`://`at least one char`
    local schema = match(input, "^([%a]+)://.+")
    if schema then
      if not schemas[schema] then
        raise_error()
      end
    else
      raise_error()
    end
  end

  return input
end

return verify
