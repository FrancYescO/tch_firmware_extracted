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
local print = print

local cli_input = require("verifier.cli_input")
-- TODO create an explicit string type verifier.

local function raise_error()
  error("boolean should be (false|true)")  
end

--- Verify if the given input is a valid boolean.
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error Not a boolean
--
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)

  if type(input) ~= "string" then
    raise_error()
  else
    --return input  
    if match("true", "^" .. input) or  match("false", "^" .. input) then
        return input
    end  
  end

  raise_error()
end

return verify
