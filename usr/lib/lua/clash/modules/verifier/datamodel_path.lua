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
-- A module that contains the verification logic for a datamodel path.
--
-- @module modules.verifier.datamodel_path

local type, error = type, error

local match = string.match

local cli_input = require("verifier.cli_input")
-- TODO create an explicit string type verifier.

local function raise_error()
  error("Invalid datamodel path")
end

--- Verify if the given input is a valid datamodel path.
-- A datamodel path has to be a string, no longer then 256 characters
-- and contain no hyphens or colons. It's also not allowed to view
-- our internal 'Command.' paths.
--
-- @param input The input we need to verify.
-- @treturn string If the input is valid, it is returned.
-- @error Invalid CLI input.
-- @error Not a string.
-- @error Longer than 256 characters.
-- @error Contains a colon or hyphen.
-- @error The path is an internal 'Command.' path
--
-- @see {TR-106 specification|https://www.broadband-forum.org/technical/download/TR-106_Amendment-7.pdf}
-- @see {TR-069 datamodel XSD|https://www.broadband-forum.org/cwmp/cwmp-datamodel-1-5.xsd}
-- @see {XML schema|http://www.w3.org/TR/xmlschema-2/}
local function verify(input)
  -- Other verifiers will raise an error if input is invalid
  cli_input(input)
  -- Deliberatly not in 1 if to get correct code coverage!
  if type(input) ~= "string" then
    raise_error()
  elseif #input > 256 then
    raise_error()
  elseif match(input, "[:-]") then
    raise_error()
  elseif match(input, "^Command%.") then
    raise_error()
  end
  return input
end

return verify