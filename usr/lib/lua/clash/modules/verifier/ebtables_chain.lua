--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2019 - 2019  -  Technicolor Delivery Technologies, SAS **
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

local type, error = type, error

local match = string.match

local cli_input = require("verifier.cli_input")

local function raise_error()
  error("Invalid ebtables chain name")
end

--- Verify if the given input looks like a valid ebtables chain name.
-- An ebtables name has to be a string.
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error Not a string.
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)

  -- Very simple pro-forma verifier for ebtables_chain type.
  -- ebtables will report back when chain is invalid, anyway.
  if type(input) ~= "string" then
    raise_error()
  -- Although ebtables seems to accept otherwise, assume sensible chain names start with letter and/or digit
  elseif not match(input, "^[%a%d]") then
    raise_error()
  end
  return input
end

return verify
