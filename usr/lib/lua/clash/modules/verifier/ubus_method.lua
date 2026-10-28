--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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
-- A module that contains the verification logic for an UBUS method name.
--
-- @module modules.verifier.ubus_method

local type, error = type, error

local match = string.match

local cli_input = require("verifier.cli_input")
-- TODO create an explicit string type verifier.

local function raise_error()
  error("Invalid UBUS method name")
end

--- Verify if the given input looks like a valid UBUS method name.
-- A UBUS method name has to be a string.
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error Not a string.
-- @error Not a valid UBUS method name.
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)

  if type(input) ~= "string" then
    raise_error()
  -- UBUS method names start with a letter
  elseif not match(input, "^[%a]") then
    raise_error()
  end
  return input
end

return verify
